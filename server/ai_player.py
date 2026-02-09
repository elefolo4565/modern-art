"""AI player logic for Modern Art.

Implements decision-making for card selection, bidding, and auction behavior.
Three difficulty levels with different strategies.
"""

import random
import asyncio
import logging
from typing import List, Dict, Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from game import Game, Player

from cards import ARTISTS, ROUND_END_CARD_COUNT

log = logging.getLogger("ai")


class AIBrain:
    """AI decision-making engine."""

    # Difficulty affects bid aggressiveness and card play strategy
    DIFFICULTY_EASY = "easy"
    DIFFICULTY_NORMAL = "normal"
    DIFFICULTY_HARD = "hard"

    def __init__(self, difficulty: str = DIFFICULTY_NORMAL):
        self.difficulty = difficulty
        # Personality variance: adds randomness to decisions
        self._variance = {
            self.DIFFICULTY_EASY: 0.4,
            self.DIFFICULTY_NORMAL: 0.2,
            self.DIFFICULTY_HARD: 0.1,
        }.get(difficulty, 0.2)

    def choose_card_to_play(self, hand: List[Dict], board: Dict[str, int],
                            market: Dict[str, int], round_num: int,
                            num_players: int) -> int:
        """Choose which card to play from hand. Returns card index."""
        if not hand:
            return -1

        scores = []
        for i, card in enumerate(hand):
            score = self._evaluate_card_play(card, hand, board, market, round_num)
            # Add random variance
            score += random.uniform(-self._variance * 20, self._variance * 20)
            scores.append((i, score))

        # Sort by score descending
        scores.sort(key=lambda x: -x[1])
        return scores[0][0]

    def _evaluate_card_play(self, card: Dict, hand: List[Dict],
                            board: Dict[str, int], market: Dict[str, int],
                            round_num: int) -> float:
        """Score a card for playing. Higher = better to play now."""
        artist = card["artist"]
        auction_type = card["auction_type"]
        board_count = board.get(artist, 0)

        score = 0.0

        # Prefer artists that are already popular (closer to scoring well)
        score += board_count * 8

        # Prefer artists with existing market value (cumulative bonus)
        market_val = market.get(artist, 0)
        if market_val > 0:
            score += 15

        # Count how many cards of this artist we hold
        my_artist_count = sum(1 for c in hand if c["artist"] == artist)

        # Prefer playing artists we have many of (we can drive the market)
        score += my_artist_count * 5

        # Avoid pushing an artist to 5 if we hold many paintings of it
        # (round would end, possibly before we can benefit)
        if board_count >= 3 and my_artist_count <= 1:
            score += 10  # Ending round with an artist we don't hold is fine
        elif board_count >= 4:
            score -= 15  # 5th card ends round without auction

        # Auction type preferences
        if auction_type == "fixed_price":
            # Fixed price is good when we're the seller - we control the price
            score += 5
        elif auction_type == "double":
            # Double is powerful if we have another card of same artist
            if my_artist_count >= 2:
                score += 12
            else:
                score -= 3
        elif auction_type == "sealed":
            # Sealed bid can yield good profits
            score += 3

        return score

    def choose_double_card(self, hand: List[Dict], base_artist: str) -> int:
        """Choose a second card for double auction. Returns index or -1 to skip."""
        matching = [(i, c) for i, c in enumerate(hand) if c["artist"] == base_artist]
        if not matching:
            return -1

        # Prefer non-double cards for the second card (their auction type is used)
        # Prefer fixed_price or open for better control
        preferred_types = ["fixed_price", "open", "once_around", "sealed", "double"]
        matching.sort(key=lambda x: preferred_types.index(x[1].get("auction_type", "open"))
                      if x[1].get("auction_type", "open") in preferred_types else 99)

        if self.difficulty == self.DIFFICULTY_EASY:
            # Easy AI sometimes skips the double
            if random.random() < 0.3:
                return -1

        return matching[0][0]

    def decide_bid_open(self, card: Dict, current_bid: int, my_money: int,
                        board: Dict[str, int], market: Dict[str, int],
                        is_double: bool = False) -> Optional[int]:
        """Decide bid for open auction. Returns bid amount or None to pass."""
        max_value = self._estimate_card_value(card, board, market, is_double)

        # Determine max willingness to pay
        willingness = max_value * self._get_aggression_factor()

        # Don't bid more than we have
        willingness = min(willingness, my_money)

        # Must beat current bid
        min_bid = current_bid + 1000

        if min_bid > willingness:
            return None  # Pass

        # Bid slightly above current
        bid_increment = random.choice([1000, 2000, 3000, 5000])
        if self.difficulty == self.DIFFICULTY_HARD:
            bid_increment = 1000  # Hard AI bids minimally to save money

        bid = current_bid + bid_increment
        bid = min(bid, int(willingness))
        bid = max(bid, min_bid)
        bid = (bid // 1000) * 1000  # Round to 1000

        if bid > my_money:
            return None

        return bid

    def decide_bid_once_around(self, card: Dict, current_bid: int, my_money: int,
                                board: Dict[str, int], market: Dict[str, int],
                                is_double: bool = False) -> Optional[int]:
        """Decide bid for once-around auction."""
        max_value = self._estimate_card_value(card, board, market, is_double)
        willingness = max_value * self._get_aggression_factor()
        willingness = min(willingness, my_money)

        min_bid = max(current_bid + 1000, 1000)

        if min_bid > willingness:
            return None

        # In once-around, bid higher since you only get one chance
        bid = int(willingness * random.uniform(0.6, 0.9))
        bid = max(bid, min_bid)
        bid = (bid // 1000) * 1000

        if bid > my_money:
            return None

        return bid

    def decide_bid_sealed(self, card: Dict, my_money: int,
                          board: Dict[str, int], market: Dict[str, int],
                          num_players: int,
                          is_double: bool = False) -> int:
        """Decide sealed bid amount."""
        max_value = self._estimate_card_value(card, board, market, is_double)
        willingness = max_value * self._get_aggression_factor()
        willingness = min(willingness, my_money)

        if willingness < 1000:
            return 0  # Pass (bid 0)

        # Bid a fraction of willingness (unknown what others will bid)
        bid = int(willingness * random.uniform(0.4, 0.75))
        bid = max(bid, 1000)
        bid = (bid // 1000) * 1000

        if bid > my_money:
            return 0

        return bid

    def decide_fixed_price_accept(self, card: Dict, price: int, my_money: int,
                                   board: Dict[str, int],
                                   market: Dict[str, int],
                                   is_double: bool = False) -> bool:
        """Decide whether to accept a fixed price offer."""
        if price > my_money:
            return False

        max_value = self._estimate_card_value(card, board, market, is_double)
        threshold = max_value * self._get_aggression_factor()

        return price <= threshold

    def choose_fixed_price(self, card: Dict, board: Dict[str, int],
                           market: Dict[str, int],
                           is_double: bool = False) -> int:
        """Choose a fixed price as seller."""
        max_value = self._estimate_card_value(card, board, market, is_double)

        # Set price slightly above estimated value to profit
        if self.difficulty == self.DIFFICULTY_EASY:
            price = int(max_value * random.uniform(0.5, 0.8))
        elif self.difficulty == self.DIFFICULTY_HARD:
            price = int(max_value * random.uniform(0.7, 1.0))
        else:
            price = int(max_value * random.uniform(0.6, 0.9))

        price = max(price, 1000)
        price = (price // 1000) * 1000
        return price

    def _estimate_card_value(self, card: Dict, board: Dict[str, int],
                             market: Dict[str, int],
                             is_double: bool = False) -> float:
        """Estimate the monetary value of a painting card."""
        artist = card["artist"]
        board_count = board.get(artist, 0)
        current_market = market.get(artist, 0)

        # Predict this round's value contribution
        # Estimate where this artist will rank
        all_counts = [(a, board.get(a, 0)) for a in ARTISTS]
        # Add the card being auctioned
        simulated = dict(all_counts)
        simulated[artist] = board_count + (2 if is_double else 1)

        # Sort by count
        sorted_artists = sorted(simulated.items(), key=lambda x: -x[1])
        rank = next((i for i, (a, _) in enumerate(sorted_artists) if a == artist), 4)

        round_value = {0: 30000, 1: 20000, 2: 10000}.get(rank, 0)

        # Total expected value = current market + predicted round value
        expected_value = current_market + round_value

        # Discount for uncertainty
        if board_count <= 1:
            expected_value *= 0.5  # Early in round, uncertain
        elif board_count >= 3:
            expected_value *= 0.85  # Fairly certain of ranking

        return expected_value

    def _get_aggression_factor(self) -> float:
        """Get bid aggression multiplier based on difficulty."""
        base = {
            self.DIFFICULTY_EASY: 0.6,
            self.DIFFICULTY_NORMAL: 0.75,
            self.DIFFICULTY_HARD: 0.85,
        }.get(self.difficulty, 0.75)
        return base + random.uniform(-0.1, 0.1)


class AIPlayerController:
    """Controls AI players within a game, processing their turns asynchronously."""

    # AI player name pool
    AI_NAMES = [
        "Claude", "Monet", "Picasso", "Warhol", "Banksy",
        "Frida", "Vermeer", "Pollock", "Basquiat", "Hockney",
    ]

    AI_TIMEOUT = 5.0  # Timeout per AI action in seconds

    def __init__(self, difficulty: str = AIBrain.DIFFICULTY_NORMAL):
        self.brain = AIBrain(difficulty)
        self.difficulty = difficulty
        self._used_names: List[str] = []

    def get_ai_name(self) -> str:
        """Get a unique AI player name."""
        available = [n for n in self.AI_NAMES if n not in self._used_names]
        if not available:
            name = f"AI_{random.randint(100, 999)}"
        else:
            name = random.choice(available)
        self._used_names.append(name)
        return name

    async def process_turn(self, game: "Game", player_index: int) -> None:
        """Process an AI player's turn (card selection)."""
        player = game.players[player_index]
        if not player.hand:
            log.warning("AI process_turn: P%d %s has no cards", player_index, player.name)
            return

        log.debug("AI process_turn: P%d %s thinking... (hand=%d cards)",
                  player_index, player.name, len(player.hand))

        card_index = 0
        double_index = -1

        try:
            card_index, double_index = await asyncio.wait_for(
                self._think_card(game, player_index), timeout=self.AI_TIMEOUT
            )
        except asyncio.TimeoutError:
            log.warning("AI TIMEOUT: P%d %s - playing random card", player_index, player.name)
            card_index = random.randint(0, len(player.hand) - 1)
            double_index = -1

        log.debug("AI process_turn: P%d %s chose card=%s(%s) double=%d",
                  player_index, player.name,
                  player.hand[card_index].artist if card_index < len(player.hand) else "?",
                  player.hand[card_index].auction_type if card_index < len(player.hand) else "?",
                  double_index)
        await game.handle_play_card(player_index, card_index, double_index)

    async def _think_card(self, game: "Game", player_index: int) -> tuple:
        """Think phase for card selection (can be timed out safely)."""
        player = game.players[player_index]
        await asyncio.sleep(random.uniform(1.0, 2.5))

        hand_dicts = [c.to_dict() for c in player.hand]
        card_index = self.brain.choose_card_to_play(
            hand_dicts, game.board, game.market, game.round_num, game.num_players
        )

        if card_index < 0:
            card_index = 0

        card = player.hand[card_index]
        double_index = -1

        if card.auction_type == "double":
            matching = [
                i for i, c in enumerate(player.hand)
                if c.artist == card.artist and i != card_index
            ]
            if matching:
                hand_without_first = [c.to_dict() for i, c in enumerate(player.hand)
                                       if i != card_index]
                double_choice = self.brain.choose_double_card(
                    hand_without_first, card.artist
                )
                if double_choice >= 0:
                    remaining_indices = [i for i in range(len(player.hand))
                                          if i != card_index]
                    if double_choice < len(remaining_indices):
                        double_index = remaining_indices[double_choice]

        return card_index, double_index

    async def process_double_response(self, game: "Game", player_index: int,
                                       artist: str) -> None:
        """Process AI response to a double request."""
        player = game.players[player_index]
        await asyncio.sleep(random.uniform(0.5, 1.5))

        hand_dicts = [c.to_dict() for c in player.hand]
        choice = self.brain.choose_double_card(hand_dicts, artist)
        await game.handle_double_response(player_index, choice)

    async def process_auction_action(self, game: "Game", player_index: int) -> None:
        """Process an AI player's auction action."""
        if not game.current_auction:
            log.warning("AI auction_action: P%d no auction active", player_index)
            return

        player = game.players[player_index]
        auction = game.current_auction

        log.debug("AI auction_action: P%d %s type=%s cur_bid=%d",
                  player_index, player.name, auction.auction_type, auction.current_bid)

        try:
            action, value = await asyncio.wait_for(
                self._think_auction(game, player_index), timeout=self.AI_TIMEOUT
            )
        except asyncio.TimeoutError:
            log.warning("AI TIMEOUT auction: P%d %s - defaulting to pass",
                        player_index, player.name)
            action, value = "pass", 0

        # Execute the decided action (never cancelled by timeout)
        if action == "bid":
            log.debug("AI auction_action: P%d %s %s bid=%d",
                      player_index, player.name, auction.auction_type, value)
            await game.handle_bid(player_index, value)
        elif action == "set_price":
            log.debug("AI auction_action: P%d %s fixed_price set=%d",
                      player_index, player.name, value)
            await game.handle_set_price(player_index, value)
        elif action == "accept":
            log.debug("AI auction_action: P%d %s fixed_price accept", player_index, player.name)
            await game.handle_accept(player_index)
        else:
            log.debug("AI auction_action: P%d %s %s pass",
                      player_index, player.name, auction.auction_type)
            await game.handle_pass(player_index)

    async def _think_auction(self, game: "Game", player_index: int) -> tuple:
        """Think phase for auction decision (can be timed out safely)."""
        player = game.players[player_index]
        auction = game.current_auction
        card = auction.card
        is_double = auction.double_card is not None

        await asyncio.sleep(random.uniform(0.8, 2.0))

        if auction.auction_type == "open":
            bid = self.brain.decide_bid_open(
                card, auction.current_bid, player.money,
                game.board, game.market, is_double
            )
            return ("bid", bid) if bid is not None else ("pass", 0)

        elif auction.auction_type == "once_around":
            bid = self.brain.decide_bid_once_around(
                card, auction.current_bid, player.money,
                game.board, game.market, is_double
            )
            return ("bid", bid) if bid is not None else ("pass", 0)

        elif auction.auction_type == "sealed":
            bid = self.brain.decide_bid_sealed(
                card, player.money, game.board, game.market,
                game.num_players, is_double
            )
            return ("bid", bid) if bid > 0 else ("pass", 0)

        elif auction.auction_type == "fixed_price":
            if auction.seller_index == player_index:
                price = self.brain.choose_fixed_price(
                    card, game.board, game.market, is_double
                )
                return ("set_price", price)
            else:
                accept = self.brain.decide_fixed_price_accept(
                    card, auction.fixed_price, player.money,
                    game.board, game.market, is_double
                )
                return ("accept", 0) if accept else ("pass", 0)

        return ("pass", 0)
