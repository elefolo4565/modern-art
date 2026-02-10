"""WebSocket message protocol definitions."""

import json
from typing import Any, Dict


def make_message(msg_type: str, **kwargs) -> str:
    """Create a JSON message string."""
    data = {"type": msg_type}
    data.update(kwargs)
    return json.dumps(data, ensure_ascii=False)


def parse_message(text: str) -> Dict[str, Any]:
    """Parse a JSON message string."""
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {"type": "error", "message": "Invalid JSON"}


# --- Server → Client message builders ---

def msg_error(message: str) -> str:
    return make_message("error", message=message)

def msg_room_created(room_id: str, player_id: str, players: list = None) -> str:
    data = dict(room_id=room_id, player_id=player_id)
    if players:
        data["players"] = players
    return make_message("room_created", **data)

def msg_room_joined(room_id: str, player_id: str, players: list) -> str:
    return make_message("room_joined", room_id=room_id, player_id=player_id, players=players)

def msg_room_list(rooms: list) -> str:
    return make_message("room_list", rooms=rooms)

def msg_player_joined(players: list, player_name: str) -> str:
    return make_message("player_joined", players=players, player_name=player_name)

def msg_player_left(players: list, player_name: str) -> str:
    return make_message("player_left", players=players, player_name=player_name)

def msg_game_started(hand: list, players: list, your_index: int,
                     round_num: int, current_turn: int) -> str:
    return make_message("game_started",
                        hand=hand, players=players, your_index=your_index,
                        round=round_num, current_turn=current_turn)

def msg_your_turn(player_index: int) -> str:
    return make_message("your_turn", player_index=player_index)

def msg_turn_changed(player_index: int) -> str:
    return make_message("turn_changed", player_index=player_index)

def msg_card_played(artist: str, board_count: int, player_index: int,
                    player_name: str, auction_type: str,
                    is_double: bool = False) -> str:
    data = dict(artist=artist, board_count=board_count,
                player_index=player_index, player_name=player_name,
                auction_type=auction_type)
    if is_double:
        data["is_double"] = True
    return make_message("card_played", **data)

def msg_double_request(player_index: int, artist: str) -> str:
    return make_message("double_request", player_index=player_index, artist=artist)

def msg_auction_started(auction_type: str, card: dict, seller_index: int,
                        current_bid: int = 0, can_act: bool = False,
                        fixed_price: int = 0, double_card: dict = None) -> str:
    data = dict(auction_type=auction_type, card=card, seller_index=seller_index,
                current_bid=current_bid, can_act=can_act, fixed_price=fixed_price)
    if double_card:
        data["double_card"] = double_card
    return make_message("auction_started", **data)

def msg_bid_update(player_index: int, player_name: str, amount: int,
                   can_act: bool = False) -> str:
    return make_message("bid_update",
                        player_index=player_index, player_name=player_name,
                        amount=amount, can_act=can_act)

def msg_auction_result(winner_index: int, winner_name: str, price: int,
                       card: dict, players: list) -> str:
    return make_message("auction_result",
                        winner_index=winner_index, winner_name=winner_name,
                        price=price, card=card, players=players)

def msg_round_ended(round_values: dict, market: dict, players: list,
                    earnings: dict, next_round: int, new_hand: list = None) -> str:
    data = dict(round_values=round_values, market=market, players=players,
                earnings=earnings, next_round=next_round)
    if new_hand is not None:
        data["new_hand"] = new_hand
    return make_message("round_ended", **data)

def msg_game_ended(players: list, winner_index: int, winner_name: str) -> str:
    return make_message("game_ended",
                        players=players, winner_index=winner_index,
                        winner_name=winner_name)

def msg_state_sync(hand: list, players: list, round_num: int, board: dict,
                   market: dict, my_paintings: list, current_turn: int,
                   your_index: int) -> str:
    return make_message("state_sync",
                        hand=hand, players=players, round=round_num,
                        board=board, market=market, my_paintings=my_paintings,
                        current_turn=current_turn, your_index=your_index)
