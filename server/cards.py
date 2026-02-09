"""Card definitions and deck management for Modern Art."""

import random
from dataclasses import dataclass, field
from typing import List, Dict

ARTISTS = ["Orange Tarou", "Green Tarou", "Blue Tarou", "Yellow Tarou", "Red Tarou"]

AUCTION_TYPES = ["open", "once_around", "sealed", "fixed_price", "double"]

# Card distribution: (artist, total_cards)
ARTIST_CARD_COUNTS = {
    "Orange Tarou": 12,
    "Green Tarou": 13,
    "Blue Tarou": 14,
    "Yellow Tarou": 15,
    "Red Tarou": 16,
}

# Auction type distribution per artist
# [open, once_around, sealed, fixed_price, double]
AUCTION_DISTRIBUTION = {
    "Orange Tarou":  [3, 2, 2, 2, 3],   # 12
    "Green Tarou":   [3, 3, 2, 2, 3],   # 13
    "Blue Tarou":    [3, 3, 3, 2, 3],   # 14
    "Yellow Tarou":  [3, 3, 3, 3, 3],   # 15
    "Red Tarou":     [3, 3, 3, 3, 4],   # 16
}

# Cards dealt per round based on player count
# {player_count: [round1, round2, round3, round4]}
DEAL_COUNTS = {
    3: [10, 6, 6, 6],
    4: [9, 4, 4, 4],
    5: [8, 3, 3, 3],
}

# Value awarded to top artists each round
ROUND_VALUES = {
    1: 30000,  # Most popular
    2: 20000,  # Second
    3: 10000,  # Third
}

STARTING_MONEY = 100000
MAX_ROUNDS = 4
ROUND_END_CARD_COUNT = 5


@dataclass
class Card:
    card_id: int
    artist: str
    auction_type: str

    def to_dict(self) -> Dict:
        return {
            "card_id": self.card_id,
            "artist": self.artist,
            "auction_type": self.auction_type,
        }


def create_deck() -> List[Card]:
    """Create the full 70-card deck."""
    deck = []
    card_id = 0
    for artist in ARTISTS:
        distribution = AUCTION_DISTRIBUTION[artist]
        for type_idx, count in enumerate(distribution):
            auction_type = AUCTION_TYPES[type_idx]
            for _ in range(count):
                deck.append(Card(card_id=card_id, artist=artist, auction_type=auction_type))
                card_id += 1
    return deck


def shuffle_deck(deck: List[Card]) -> List[Card]:
    """Shuffle the deck in place and return it."""
    random.shuffle(deck)
    return deck


def deal_cards(deck: List[Card], num_players: int, round_num: int) -> List[List[Card]]:
    """Deal cards to players for the given round.

    Returns a list of hands (one per player).
    Cards are removed from the front of the deck.
    """
    if num_players not in DEAL_COUNTS:
        raise ValueError(f"Invalid player count: {num_players}")
    if round_num < 1 or round_num > MAX_ROUNDS:
        raise ValueError(f"Invalid round: {round_num}")

    count = DEAL_COUNTS[num_players][round_num - 1]
    hands = [[] for _ in range(num_players)]

    for _ in range(count):
        for player_idx in range(num_players):
            if deck:
                hands[player_idx].append(deck.pop(0))

    return hands


def calculate_round_values(board: Dict[str, int]) -> Dict[str, int]:
    """Calculate artist values for the round based on cards played.

    Args:
        board: {artist_name: count_of_cards_played}

    Returns:
        {artist_name: value_earned_this_round}
    """
    # Sort artists by cards played (descending), filter out zero
    sorted_artists = sorted(
        [(artist, count) for artist, count in board.items() if count > 0],
        key=lambda x: (-x[1], ARTISTS.index(x[0]))  # Tie-break by artist order
    )

    values = {}
    for artist in ARTISTS:
        values[artist] = 0

    for rank, (artist, count) in enumerate(sorted_artists):
        rank_1based = rank + 1
        if rank_1based in ROUND_VALUES:
            values[artist] = ROUND_VALUES[rank_1based]

    return values
