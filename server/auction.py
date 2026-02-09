"""Auction mechanics for all 5 auction types in Modern Art."""

from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple
from enum import Enum


class AuctionState(Enum):
    WAITING_FOR_BIDS = "waiting_for_bids"
    WAITING_FOR_PRICE = "waiting_for_price"
    WAITING_FOR_ACCEPT = "waiting_for_accept"
    WAITING_FOR_DOUBLE = "waiting_for_double"
    RESOLVED = "resolved"


@dataclass
class AuctionResult:
    winner_index: int  # -1 if no winner (seller keeps)
    price: int
    seller_index: int


@dataclass
class Auction:
    """Manages auction state and resolution for all 5 auction types."""
    auction_type: str
    seller_index: int
    card: dict  # Card info dict
    num_players: int
    double_card: Optional[dict] = None  # For double auctions

    # State
    state: AuctionState = AuctionState.WAITING_FOR_BIDS
    current_bid: int = 0
    current_bidder: int = -1
    fixed_price: int = 0

    # Tracking
    bids: Dict[int, int] = field(default_factory=dict)
    passed: List[int] = field(default_factory=list)
    current_turn_index: int = -1  # For once_around and fixed_price
    sealed_bids_received: int = 0

    def __post_init__(self):
        if self.auction_type == "fixed_price":
            self.state = AuctionState.WAITING_FOR_PRICE
        elif self.auction_type == "double":
            # Double auction: will be set up after second card is known
            pass

    def get_next_player(self, from_index: int) -> int:
        """Get next player index (clockwise from from_index, skipping passed players)."""
        for i in range(1, self.num_players):
            idx = (from_index + i) % self.num_players
            if idx not in self.passed:
                return idx
        return -1

    def get_can_act_player(self) -> int:
        """Get the player index who can currently act, or -1."""
        if self.state == AuctionState.RESOLVED:
            return -1

        if self.auction_type == "open":
            return -1  # Anyone can bid in open auction

        if self.auction_type == "once_around":
            return self.current_turn_index

        if self.auction_type == "sealed":
            return -1  # Everyone bids simultaneously

        if self.auction_type == "fixed_price":
            if self.state == AuctionState.WAITING_FOR_PRICE:
                return self.seller_index
            return self.current_turn_index

        return -1

    # --- Open Auction ---
    def open_bid(self, player_index: int, amount: int) -> Optional[str]:
        """Process a bid in an open auction. Returns error message or None."""
        if self.auction_type != "open":
            return "Wrong auction type"
        if player_index == self.seller_index:
            return "Seller cannot bid"
        if amount <= self.current_bid:
            return f"Bid must be higher than {self.current_bid}"
        if amount % 1000 != 0:
            return "Bid must be in multiples of 1000"

        self.current_bid = amount
        self.current_bidder = player_index
        self.bids[player_index] = amount
        return None

    def open_pass(self, player_index: int) -> None:
        """Player passes in open auction."""
        if player_index not in self.passed:
            self.passed.append(player_index)

    def check_open_resolved(self) -> Optional[AuctionResult]:
        """Check if open auction is resolved (all non-seller players passed)."""
        active = [i for i in range(self.num_players)
                  if i != self.seller_index and i not in self.passed]
        if len(active) == 0 or (len(active) == 1 and active[0] == self.current_bidder
                                 and self.current_bid > 0):
            self.state = AuctionState.RESOLVED
            if self.current_bidder == -1:
                # No one bid - seller gets the card for free
                return AuctionResult(
                    winner_index=self.seller_index, price=0,
                    seller_index=self.seller_index
                )
            return AuctionResult(
                winner_index=self.current_bidder, price=self.current_bid,
                seller_index=self.seller_index
            )
        return None

    # --- Once Around ---
    def start_once_around(self) -> None:
        """Initialize once-around auction."""
        self.current_turn_index = self.get_next_player(self.seller_index)
        self.state = AuctionState.WAITING_FOR_BIDS

    def once_around_bid(self, player_index: int, amount: int) -> Optional[str]:
        """Process a bid in once-around auction."""
        if player_index != self.current_turn_index:
            return "Not your turn"
        if amount <= self.current_bid:
            return f"Bid must be higher than {self.current_bid}"
        if amount % 1000 != 0:
            return "Bid must be in multiples of 1000"

        self.current_bid = amount
        self.current_bidder = player_index
        self.bids[player_index] = amount
        # Move to next player
        self.passed.append(player_index)
        self.current_turn_index = self.get_next_player(player_index)
        return None

    def once_around_pass(self, player_index: int) -> None:
        """Player passes in once-around."""
        if player_index not in self.passed:
            self.passed.append(player_index)
        self.current_turn_index = self.get_next_player(player_index)

    def check_once_around_resolved(self) -> Optional[AuctionResult]:
        """Check if once-around is complete (back to seller or all passed)."""
        # Resolved when we've gone around to the seller
        if self.current_turn_index == self.seller_index or self.current_turn_index == -1:
            self.state = AuctionState.RESOLVED
            if self.current_bidder == -1:
                return AuctionResult(
                    winner_index=self.seller_index, price=0,
                    seller_index=self.seller_index
                )
            return AuctionResult(
                winner_index=self.current_bidder, price=self.current_bid,
                seller_index=self.seller_index
            )
        return None

    # --- Sealed Bid ---
    def sealed_bid(self, player_index: int, amount: int) -> Optional[str]:
        """Submit a sealed bid."""
        if player_index == self.seller_index:
            return "Seller cannot bid"
        if player_index in self.bids:
            return "Already submitted a bid"
        if amount < 0:
            return "Invalid bid amount"
        if amount % 1000 != 0:
            return "Bid must be in multiples of 1000"

        self.bids[player_index] = amount
        self.sealed_bids_received += 1
        return None

    def sealed_pass(self, player_index: int) -> None:
        """Pass on sealed bid (bid 0)."""
        if player_index not in self.bids and player_index != self.seller_index:
            self.bids[player_index] = 0
            self.sealed_bids_received += 1

    def check_sealed_resolved(self) -> Optional[AuctionResult]:
        """Check if all non-seller players have submitted bids."""
        expected = self.num_players - 1  # Everyone except seller
        if self.sealed_bids_received >= expected:
            self.state = AuctionState.RESOLVED
            if not self.bids or max(self.bids.values()) == 0:
                return AuctionResult(
                    winner_index=self.seller_index, price=0,
                    seller_index=self.seller_index
                )
            # Highest bid wins (tie: first bidder wins - by lowest index)
            winner = max(self.bids.items(), key=lambda x: (x[1], -x[0]))
            return AuctionResult(
                winner_index=winner[0], price=winner[1],
                seller_index=self.seller_index
            )
        return None

    # --- Fixed Price ---
    def set_fixed_price(self, price: int) -> Optional[str]:
        """Seller sets the fixed price."""
        if self.state != AuctionState.WAITING_FOR_PRICE:
            return "Not waiting for price"
        if price <= 0:
            return "Price must be positive"
        if price % 1000 != 0:
            return "Price must be in multiples of 1000"

        self.fixed_price = price
        self.current_bid = price
        self.state = AuctionState.WAITING_FOR_ACCEPT
        self.current_turn_index = self.get_next_player(self.seller_index)
        return None

    def fixed_price_accept(self, player_index: int) -> Optional[AuctionResult]:
        """Player accepts the fixed price."""
        if player_index != self.current_turn_index:
            return None
        self.state = AuctionState.RESOLVED
        return AuctionResult(
            winner_index=player_index, price=self.fixed_price,
            seller_index=self.seller_index
        )

    def fixed_price_decline(self, player_index: int) -> None:
        """Player declines the fixed price."""
        if player_index not in self.passed:
            self.passed.append(player_index)
        self.current_turn_index = self.get_next_player(player_index)

    def check_fixed_price_resolved(self) -> Optional[AuctionResult]:
        """Check if fixed price offer went around with no takers."""
        if self.state != AuctionState.WAITING_FOR_ACCEPT:
            return None
        if self.current_turn_index == -1 or self.current_turn_index == self.seller_index:
            # No one accepted - seller buys at own price
            self.state = AuctionState.RESOLVED
            return AuctionResult(
                winner_index=self.seller_index, price=self.fixed_price,
                seller_index=self.seller_index
            )
        return None

    # --- Double Auction ---
    def setup_double(self, effective_type: str) -> None:
        """Set up the double auction with the effective auction type."""
        self.auction_type = effective_type
        if effective_type == "once_around":
            self.start_once_around()
        elif effective_type == "fixed_price":
            self.state = AuctionState.WAITING_FOR_PRICE
        elif effective_type == "sealed":
            self.state = AuctionState.WAITING_FOR_BIDS
        else:  # open
            self.state = AuctionState.WAITING_FOR_BIDS

    def process_action(self, player_index: int, action: str,
                       amount: int = 0) -> Tuple[Optional[str], Optional[AuctionResult]]:
        """Process a player action and return (error, result).

        This is the main entry point for processing auction actions.
        """
        error = None
        result = None

        if self.auction_type == "open":
            if action == "bid":
                error = self.open_bid(player_index, amount)
                if not error:
                    result = self.check_open_resolved()
            elif action == "pass":
                self.open_pass(player_index)
                result = self.check_open_resolved()

        elif self.auction_type == "once_around":
            if action == "bid":
                error = self.once_around_bid(player_index, amount)
                if not error:
                    result = self.check_once_around_resolved()
            elif action == "pass":
                self.once_around_pass(player_index)
                result = self.check_once_around_resolved()

        elif self.auction_type == "sealed":
            if action == "bid":
                error = self.sealed_bid(player_index, amount)
                if not error:
                    result = self.check_sealed_resolved()
            elif action == "pass":
                self.sealed_pass(player_index)
                result = self.check_sealed_resolved()

        elif self.auction_type == "fixed_price":
            if action == "set_price":
                error = self.set_fixed_price(amount)
                if not error:
                    result = self.check_fixed_price_resolved()
            elif action == "accept":
                result = self.fixed_price_accept(player_index)
            elif action == "pass" or action == "decline":
                self.fixed_price_decline(player_index)
                result = self.check_fixed_price_resolved()

        return error, result
