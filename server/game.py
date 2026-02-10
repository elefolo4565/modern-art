"""Game state management and turn progression for Modern Art."""

import asyncio
import logging
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Set

log = logging.getLogger("game")
from cards import (
    Card, create_deck, shuffle_deck, deal_cards, calculate_round_values,
    ARTISTS, STARTING_MONEY, MAX_ROUNDS, ROUND_END_CARD_COUNT
)
from auction import Auction, AuctionResult, AuctionState
from protocol import *


@dataclass
class Player:
    player_id: str
    name: str
    ws: object  # WebSocket connection (None for AI players)
    money: int = STARTING_MONEY
    hand: List[Card] = field(default_factory=list)
    paintings: List[Card] = field(default_factory=list)
    is_ai: bool = False

    def to_dict(self, hide_hand: bool = True) -> Dict:
        d = {
            "id": self.player_id,
            "name": self.name,
            "money": self.money,
            "hand_count": len(self.hand),
            "paintings_count": len(self.paintings),
            "is_ai": self.is_ai,
        }
        if not hide_hand:
            d["hand"] = [c.to_dict() for c in self.hand]
        return d

    def to_public_dict(self) -> Dict:
        return self.to_dict(hide_hand=True)


class Game:
    """Manages the full game state for one room."""

    def __init__(self, players: List[Player], ai_controller=None):
        self.players = players
        self.num_players = len(players)
        self.deck: List[Card] = []
        self.round_num: int = 0
        self.current_turn: int = 0
        self.board: Dict[str, int] = {a: 0 for a in ARTISTS}
        self.market: Dict[str, int] = {a: 0 for a in ARTISTS}
        self.current_auction: Optional[Auction] = None
        self.round_active: bool = False
        self.game_over: bool = False
        self.waiting_for_double: bool = False
        self.double_base_card: Optional[Card] = None
        self.double_player_index: int = -1
        self.ai_controller = ai_controller  # AIPlayerController instance
        self._ai_processing = False  # Guard against recursive AI triggers

    def _is_ai(self, player_index: int) -> bool:
        return (0 <= player_index < len(self.players)
                and self.players[player_index].is_ai)

    def _pname(self, idx: int) -> str:
        """Helper: player name for logging."""
        if 0 <= idx < len(self.players):
            p = self.players[idx]
            return f"P{idx}:{p.name}{'(AI)' if p.is_ai else ''}"
        return f"P{idx}:?"

    async def start(self) -> None:
        """Initialize and start the game."""
        log.info("=== GAME START === players=%s",
                 [self._pname(i) for i in range(self.num_players)])
        self.deck = shuffle_deck(create_deck())
        self.round_num = 1
        self.current_turn = 0
        self.round_active = True

        # Deal initial hands
        hands = deal_cards(self.deck, self.num_players, self.round_num)
        for i, player in enumerate(self.players):
            player.hand = hands[i]

        # Send game_started to each player with their hand
        for i, player in enumerate(self.players):
            await self._send(player, msg_game_started(
                hand=[c.to_dict() for c in player.hand],
                players=[p.to_public_dict() for p in self.players],
                your_index=i,
                round_num=self.round_num,
                current_turn=self.current_turn,
            ))

        # Notify current player it's their turn
        await self._send(self.players[self.current_turn],
                         msg_your_turn(self.current_turn))

        # If first player is AI, trigger their turn
        await self._trigger_ai_turn_if_needed()

    async def _trigger_ai_turn_if_needed(self) -> None:
        """If current turn player is AI, trigger their action in a loop."""
        if self._ai_processing:
            log.debug("_trigger_ai_turn: SKIP (already processing)")
            return
        if not self.ai_controller:
            return
        self._ai_processing = True
        log.debug("_trigger_ai_turn: START loop, current_turn=%s", self._pname(self.current_turn))
        try:
            while (self.round_active and not self.game_over
                    and self.current_auction is None
                    and not self.waiting_for_double
                    and self._is_ai(self.current_turn)):
                log.info("[AI TURN] %s (round=%d, board=%s)",
                         self._pname(self.current_turn), self.round_num,
                         {a: c for a, c in self.board.items() if c > 0})
                await self.ai_controller.process_turn(self, self.current_turn)
                log.debug("_trigger_ai_turn: after process_turn, state: round_active=%s game_over=%s auction=%s turn=%s",
                          self.round_active, self.game_over,
                          self.current_auction is not None, self.current_turn)
        finally:
            self._ai_processing = False
            log.debug("_trigger_ai_turn: END loop")

    async def _trigger_ai_auction_if_needed(self) -> None:
        """Trigger AI actions for auction participants."""
        if not self.ai_controller or not self.current_auction:
            return

        auction = self.current_auction
        auction_type = auction.auction_type
        log.debug("[AI AUCTION] trigger type=%s seller=%s", auction_type, self._pname(auction.seller_index))

        if auction_type == "open":
            # In open auction, all AI non-sellers act
            await self._trigger_ai_open_auction()
        elif auction_type == "once_around":
            # One AI at a time, in order
            await self._trigger_ai_sequential_auction()
        elif auction_type == "sealed":
            # All AI bid simultaneously
            await self._trigger_ai_sealed_auction()
        elif auction_type == "fixed_price":
            await self._trigger_ai_fixed_price_auction()

    async def _trigger_ai_open_auction(self) -> None:
        """Handle AI bidding in open auction.

        Each trigger does one full pass: every eligible AI gets exactly one
        chance to bid or pass.  If a human can still act afterwards, we
        stop so they can respond.  If only AIs remain active, we loop for
        another round until all AIs pass or the auction resolves.
        """
        if not self.current_auction:
            return
        auction_ref = self.current_auction
        while (self.current_auction is auction_ref
               and auction_ref.state != AuctionState.RESOLVED):
            any_acted = False
            # One full pass: each eligible AI acts once
            for i, player in enumerate(self.players):
                if (player.is_ai and i != auction_ref.seller_index
                        and i not in auction_ref.passed
                        and self.current_auction is auction_ref
                        and auction_ref.state != AuctionState.RESOLVED):
                    await self.ai_controller.process_auction_action(self, i)
                    if self.current_auction is not auction_ref:
                        return  # Auction resolved during AI action
                    any_acted = True
            if not any_acted:
                break  # No AI could act, done
            # If a human player can still bid, pause so they can respond
            human_can_act = any(
                not p.is_ai and i != auction_ref.seller_index
                and i not in auction_ref.passed
                for i, p in enumerate(self.players)
            )
            if human_can_act:
                break  # Wait for human before next AI round

    async def _trigger_ai_sequential_auction(self) -> None:
        """Handle AI in once_around where one player acts at a time (loop)."""
        if not self.current_auction:
            return
        auction_ref = self.current_auction
        while (self.current_auction is auction_ref
               and auction_ref.state != AuctionState.RESOLVED):
            can_act = auction_ref.get_can_act_player()
            if can_act >= 0 and self._is_ai(can_act):
                await self.ai_controller.process_auction_action(self, can_act)
                if self.current_auction is not auction_ref:
                    return  # Auction resolved
            else:
                break  # Human's turn or no one can act

    async def _trigger_ai_sealed_auction(self) -> None:
        """Handle AI sealed bids."""
        if not self.current_auction:
            return
        auction_ref = self.current_auction
        for i, player in enumerate(self.players):
            if (player.is_ai and i != auction_ref.seller_index
                    and i not in auction_ref.bids
                    and self.current_auction is auction_ref):
                await self.ai_controller.process_auction_action(self, i)
                if self.current_auction is not auction_ref:
                    return  # Auction resolved

    async def _trigger_ai_fixed_price_auction(self) -> None:
        """Handle AI in fixed price auction (loop through price setting + accepts)."""
        if not self.current_auction:
            return
        auction_ref = self.current_auction
        # AI seller sets price first
        if (auction_ref.state == AuctionState.WAITING_FOR_PRICE
                and self._is_ai(auction_ref.seller_index)):
            await self.ai_controller.process_auction_action(
                self, auction_ref.seller_index)
            if self.current_auction is not auction_ref:
                return  # Auction resolved
        # Then loop through AI accept/decline
        while (self.current_auction is auction_ref
               and auction_ref.state == AuctionState.WAITING_FOR_ACCEPT):
            can_act = auction_ref.get_can_act_player()
            if can_act >= 0 and self._is_ai(can_act):
                await self.ai_controller.process_auction_action(self, can_act)
                if self.current_auction is not auction_ref:
                    return  # Auction resolved
            else:
                break  # Human's turn or no one can act

    async def handle_play_card(self, player_index: int, card_index: int,
                                double_card_index: int = -1) -> None:
        """Handle a player playing a card from their hand."""
        if self.game_over or not self.round_active:
            await self._send_error(self.players[player_index], "Game not active")
            return

        if self.current_auction is not None:
            await self._send_error(self.players[player_index], "Auction in progress")
            return

        if player_index != self.current_turn:
            await self._send_error(self.players[player_index], "Not your turn")
            return

        player = self.players[player_index]
        if card_index < 0 or card_index >= len(player.hand):
            await self._send_error(player, "Invalid card index")
            return

        card = player.hand[card_index]

        # Check for double auction
        if card.auction_type == "double":
            if double_card_index >= 0:
                if double_card_index >= len(player.hand) or double_card_index == card_index:
                    await self._send_error(player, "Invalid double card index")
                    return
                second_card = player.hand[double_card_index]
                if second_card.artist != card.artist:
                    await self._send_error(player, "Double card must be same artist")
                    return
                await self._play_double(player_index, card, card_index,
                                         second_card, double_card_index)
                return
            else:
                has_match = any(
                    c.artist == card.artist and i != card_index
                    for i, c in enumerate(player.hand)
                )
                if has_match:
                    self.waiting_for_double = True
                    self.double_base_card = card
                    self.double_player_index = player_index
                    player.hand.pop(card_index)
                    await self._broadcast(msg_double_request(player_index, card.artist))
                    # If this is an AI player, auto-respond to double
                    if player.is_ai and self.ai_controller:
                        await self.ai_controller.process_double_response(
                            self, player_index, card.artist)
                    return
                else:
                    card.auction_type = "open"

        await self._play_single_card(player_index, card, card_index)

    async def handle_double_response(self, player_index: int,
                                      second_card_index: int = -1) -> None:
        """Handle response to double request."""
        if not self.waiting_for_double or player_index != self.double_player_index:
            return

        player = self.players[player_index]
        base_card = self.double_base_card
        self.waiting_for_double = False
        self.double_base_card = None
        self.double_player_index = -1

        if second_card_index >= 0 and second_card_index < len(player.hand):
            second_card = player.hand[second_card_index]
            if second_card.artist == base_card.artist:
                player.hand.pop(second_card_index)
                self.board[base_card.artist] += 1
                if self._check_round_end(base_card.artist):
                    await self._end_round()
                    return

                self.board[base_card.artist] += 1
                if self._check_round_end(base_card.artist):
                    await self._end_round()
                    return

                effective_type = second_card.auction_type
                if effective_type == "double":
                    effective_type = "open"

                await self._broadcast(msg_card_played(
                    artist=base_card.artist,
                    board_count=self.board[base_card.artist],
                    player_index=player_index,
                    player_name=player.name,
                    auction_type=effective_type,
                    is_double=True,
                ))
                await self._start_auction(player_index, base_card,
                                           effective_type, second_card)
                return

        # No second card - play base card as open auction
        self.board[base_card.artist] += 1
        if self._check_round_end(base_card.artist):
            await self._end_round()
            return

        await self._broadcast(msg_card_played(
            artist=base_card.artist,
            board_count=self.board[base_card.artist],
            player_index=player_index,
            player_name=player.name,
            auction_type="open",
        ))
        await self._start_auction(player_index, base_card, "open")

    async def _play_single_card(self, player_index: int, card: Card,
                                 card_index: int) -> None:
        """Play a single card and start its auction."""
        log.info("[PLAY] %s plays %s (%s), board[%s]=%d",
                 self._pname(player_index), card.artist, card.auction_type,
                 card.artist, self.board.get(card.artist, 0) + 1)
        player = self.players[player_index]
        player.hand.pop(card_index)

        self.board[card.artist] += 1

        if self._check_round_end(card.artist):
            await self._broadcast(msg_card_played(
                artist=card.artist,
                board_count=self.board[card.artist],
                player_index=player_index,
                player_name=player.name,
                auction_type=card.auction_type,
            ))
            await self._end_round()
            return

        await self._broadcast(msg_card_played(
            artist=card.artist,
            board_count=self.board[card.artist],
            player_index=player_index,
            player_name=player.name,
            auction_type=card.auction_type,
        ))

        await self._start_auction(player_index, card, card.auction_type)

    async def _play_double(self, player_index: int, card1: Card, idx1: int,
                            card2: Card, idx2: int) -> None:
        """Play two cards for a double auction."""
        player = self.players[player_index]

        indices = sorted([idx1, idx2], reverse=True)
        for idx in indices:
            player.hand.pop(idx)

        self.board[card1.artist] += 1
        if self._check_round_end(card1.artist):
            await self._broadcast(msg_card_played(
                artist=card1.artist,
                board_count=self.board[card1.artist],
                player_index=player_index,
                player_name=player.name,
                auction_type="double",
                is_double=True,
            ))
            await self._end_round()
            return

        self.board[card1.artist] += 1
        if self._check_round_end(card1.artist):
            await self._broadcast(msg_card_played(
                artist=card1.artist,
                board_count=self.board[card1.artist],
                player_index=player_index,
                player_name=player.name,
                auction_type="double",
                is_double=True,
            ))
            await self._end_round()
            return

        effective_type = card2.auction_type
        if effective_type == "double":
            effective_type = "open"

        await self._broadcast(msg_card_played(
            artist=card1.artist,
            board_count=self.board[card1.artist],
            player_index=player_index,
            player_name=player.name,
            auction_type=effective_type,
            is_double=True,
        ))

        await self._start_auction(player_index, card1, effective_type, card2)

    async def _start_auction(self, seller_index: int, card: Card,
                              auction_type: str,
                              double_card: Card = None) -> None:
        """Start an auction for the given card."""
        log.info("[AUCTION START] type=%s seller=%s artist=%s%s",
                 auction_type, self._pname(seller_index), card.artist,
                 " (double)" if double_card else "")
        self.current_auction = Auction(
            auction_type=auction_type,
            seller_index=seller_index,
            card=card.to_dict(),
            num_players=self.num_players,
            double_card=double_card.to_dict() if double_card else None,
        )

        if auction_type == "once_around":
            self.current_auction.start_once_around()

        for i, player in enumerate(self.players):
            can_act_player = self.current_auction.get_can_act_player()
            can_act = False
            if auction_type == "open":
                can_act = (i != seller_index)
            elif auction_type == "sealed":
                can_act = (i != seller_index)
            else:
                can_act = (i == can_act_player)

            await self._send(player, msg_auction_started(
                auction_type=auction_type,
                card=card.to_dict(),
                seller_index=seller_index,
                current_bid=0,
                can_act=can_act,
                fixed_price=0,
                double_card=double_card.to_dict() if double_card else None,
            ))

        # Trigger AI auction actions
        await self._trigger_ai_auction_if_needed()

    async def handle_bid(self, player_index: int, amount: int) -> None:
        """Handle a bid from a player."""
        log.info("[BID] %s bids %d (type=%s)", self._pname(player_index), amount,
                 self.current_auction.auction_type if self.current_auction else "?")
        if not self.current_auction:
            return

        player = self.players[player_index]
        if amount > player.money:
            await self._send_error(player, "Not enough money")
            return

        error, result = self.current_auction.process_action(
            player_index, "bid", amount
        )

        if error:
            await self._send_error(player, error)
            return

        if self.current_auction.auction_type != "sealed":
            for i, p in enumerate(self.players):
                can_act_player = self.current_auction.get_can_act_player()
                can_act = False
                if self.current_auction.auction_type == "open":
                    can_act = (i != self.current_auction.seller_index and
                               i != player_index and
                               i not in self.current_auction.passed)
                else:
                    can_act = (i == can_act_player)
                await self._send(p, msg_bid_update(
                    player_index=player_index,
                    player_name=player.name,
                    amount=amount,
                    can_act=can_act,
                ))
        else:
            await self._send(player, make_message("bid_confirmed", amount=amount))

        if result:
            await self._resolve_auction(result)
        elif not self._is_ai(player_index):
            # Only trigger AI follow-ups after human actions
            await self._trigger_ai_auction_if_needed()

    async def handle_pass(self, player_index: int) -> None:
        """Handle a pass from a player."""
        log.info("[PASS] %s passes (type=%s)", self._pname(player_index),
                 self.current_auction.auction_type if self.current_auction else "?")
        if not self.current_auction:
            return

        error, result = self.current_auction.process_action(player_index, "pass")
        if error:
            await self._send_error(self.players[player_index], error)
            return

        if self.current_auction.auction_type != "sealed":
            for i, p in enumerate(self.players):
                can_act_player = self.current_auction.get_can_act_player()
                can_act = False
                if self.current_auction.auction_type == "open":
                    can_act = (i != self.current_auction.seller_index and
                               i not in self.current_auction.passed)
                else:
                    can_act = (i == can_act_player)
                await self._send(p, msg_bid_update(
                    player_index=player_index,
                    player_name=self.players[player_index].name,
                    amount=0,
                    can_act=can_act,
                ))

        if result:
            await self._resolve_auction(result)
        elif not self._is_ai(player_index):
            # Only trigger AI follow-ups after human actions
            await self._trigger_ai_auction_if_needed()

    async def handle_accept(self, player_index: int) -> None:
        """Handle accept in fixed price auction."""
        log.info("[ACCEPT] %s accepts fixed_price=%d", self._pname(player_index),
                 self.current_auction.fixed_price if self.current_auction else 0)
        if not self.current_auction:
            return
        if self.current_auction.auction_type != "fixed_price":
            return
        if self.current_auction.fixed_price > self.players[player_index].money:
            await self._send_error(self.players[player_index], "Not enough money")
            return

        error, result = self.current_auction.process_action(player_index, "accept")
        if error:
            await self._send_error(self.players[player_index], error)
            return
        if result:
            await self._resolve_auction(result)

    async def handle_set_price(self, player_index: int, price: int) -> None:
        """Handle seller setting fixed price."""
        log.info("[SET_PRICE] %s sets price=%d", self._pname(player_index), price)
        if not self.current_auction:
            return
        if self.current_auction.auction_type != "fixed_price":
            return
        if player_index != self.current_auction.seller_index:
            return

        error, result = self.current_auction.process_action(
            player_index, "set_price", price
        )

        if error:
            await self._send_error(self.players[player_index], error)
            return

        for i, p in enumerate(self.players):
            can_act_player = self.current_auction.get_can_act_player()
            await self._send(p, msg_bid_update(
                player_index=player_index,
                player_name=self.players[player_index].name,
                amount=price,
                can_act=(i == can_act_player),
            ))

        if result:
            await self._resolve_auction(result)
        elif not self._is_ai(player_index):
            # Only trigger AI follow-ups after human actions
            await self._trigger_ai_auction_if_needed()

    async def _resolve_auction(self, result: AuctionResult) -> None:
        """Resolve an auction and transfer money/paintings."""
        log.info("[AUCTION END] winner=%s price=%d seller=%s",
                 self._pname(result.winner_index), result.price,
                 self._pname(result.seller_index))
        winner = self.players[result.winner_index]
        seller = self.players[result.seller_index]

        card_info = self.current_auction.card

        if result.winner_index != result.seller_index:
            winner.money -= result.price
            seller.money += result.price

        winner.paintings.append(card_info)
        self.current_auction = None

        await self._broadcast(msg_auction_result(
            winner_index=result.winner_index,
            winner_name=winner.name,
            price=result.price,
            card=card_info,
            players=[p.to_public_dict() for p in self.players],
        ))

        await asyncio.sleep(2.0)
        await self._advance_turn()

    async def _advance_turn(self) -> None:
        """Move to the next player's turn."""
        log.debug("[ADVANCE] from %s", self._pname(self.current_turn))
        has_cards = any(len(p.hand) > 0 for p in self.players)
        if not has_cards:
            await self._end_round()
            return

        for i in range(1, self.num_players + 1):
            next_idx = (self.current_turn + i) % self.num_players
            if len(self.players[next_idx].hand) > 0:
                self.current_turn = next_idx
                break

        await self._broadcast(msg_turn_changed(self.current_turn))
        await self._send(self.players[self.current_turn],
                         msg_your_turn(self.current_turn))

        # Trigger AI turn if needed
        await self._trigger_ai_turn_if_needed()

    def _check_round_end(self, artist: str) -> bool:
        return self.board[artist] >= ROUND_END_CARD_COUNT

    async def _end_round(self) -> None:
        """End the current round, calculate scores, and start next round."""
        log.info("=== ROUND %d END === board=%s", self.round_num, dict(self.board))
        self.round_active = False

        round_values = calculate_round_values(self.board)

        for artist in ARTISTS:
            self.market[artist] += round_values[artist]

        earnings = {}
        for i, player in enumerate(self.players):
            player_earnings = 0
            for painting in player.paintings:
                artist = painting.get("artist", painting.get("artist", ""))
                value = self.market.get(artist, 0)
                player_earnings += value
            player.money += player_earnings
            earnings[player.name] = player_earnings
            player.paintings = []

        self.round_num += 1
        if self.round_num > MAX_ROUNDS:
            await self._end_game(round_values, earnings)
            return

        for artist in ARTISTS:
            self.board[artist] = 0

        new_hands = deal_cards(self.deck, self.num_players, self.round_num)
        for i, player in enumerate(self.players):
            player.hand.extend(new_hands[i])

        for i, player in enumerate(self.players):
            await self._send(player, msg_round_ended(
                round_values=round_values,
                market=self.market,
                players=[p.to_public_dict() for p in self.players],
                earnings=earnings,
                next_round=self.round_num,
                new_hand=[c.to_dict() for c in player.hand],
            ))

        self.round_active = True
        self.current_turn = 0

        await asyncio.sleep(2.0)
        await self._broadcast(msg_turn_changed(self.current_turn))
        await self._send(self.players[self.current_turn],
                         msg_your_turn(self.current_turn))

        await self._trigger_ai_turn_if_needed()

    async def _end_game(self, last_round_values: dict, last_earnings: dict) -> None:
        log.info("=== GAME END === scores=%s",
                 {self._pname(i): p.money for i, p in enumerate(self.players)})
        self.game_over = True

        winner_index = max(range(self.num_players),
                          key=lambda i: self.players[i].money)

        for i, player in enumerate(self.players):
            await self._send(player, msg_round_ended(
                round_values=last_round_values,
                market=self.market,
                players=[p.to_public_dict() for p in self.players],
                earnings=last_earnings,
                next_round=self.round_num,
            ))

        await asyncio.sleep(2.0)

        await self._broadcast(msg_game_ended(
            players=[p.to_public_dict() for p in self.players],
            winner_index=winner_index,
            winner_name=self.players[winner_index].name,
        ))

    async def _broadcast(self, message: str) -> None:
        for player in self.players:
            await self._send(player, message)

    async def _send(self, player: Player, message: str) -> None:
        """Send a message to a player. Skip AI players (no WebSocket)."""
        if player.is_ai:
            return  # AI players don't have WebSocket connections
        try:
            await player.ws.send_str(message)
        except Exception:
            pass

    async def _send_error(self, player: Player, message: str) -> None:
        await self._send(player, msg_error(message))
