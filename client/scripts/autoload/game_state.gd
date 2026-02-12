extends Node

## Client-side game state, updated by server messages.

const VERSION: String = "0.15"
const BUILD_DATE: String = "20260213_025546"

signal state_changed
signal hand_updated
signal auction_started(data: Dictionary)
signal auction_bid(data: Dictionary)
signal auction_ended(data: Dictionary)
signal round_ended(data: Dictionary)
signal game_ended(data: Dictionary)
signal turn_changed
signal error_received(msg: String)
signal room_list_updated(rooms: Array)
signal room_joined(data: Dictionary)
signal room_created(data: Dictionary)
signal player_joined(data: Dictionary)
signal player_left(data: Dictionary)
signal game_started(data: Dictionary)
signal card_played(data: Dictionary)
signal double_requested(data: Dictionary)

# Lobby state
var room_id: String = ""
var player_name: String = ""
var player_id: String = ""
var is_host: bool = false

# Game state
var players: Array = []  # [{id, name, money, paintings_count}]
var my_index: int = -1
var hand: Array = []  # [{artist, auction_type, card_id}]
var current_round: int = 0
var current_turn_player: int = -1
var is_my_turn: bool = false

# Auction state
var auction_active: bool = false
var auction_type: String = ""
var auction_card: Dictionary = {}
var auction_seller: int = -1
var auction_current_bid: int = 0
var auction_current_bidder: int = -1
var auction_fixed_price: int = 0
var auction_can_act: bool = false
var auction_bids_info: Array = []

# Board state
var board: Dictionary = {}  # {artist_name: count} cards played this round (includes pending auction)
var settled_board: Dictionary = {}  # {artist_name: count} cards whose auction has completed
var market: Dictionary = {}  # {artist_name: cumulative_value}
var my_paintings: Array = []  # paintings I've acquired this round
var auction_log: Array = []   # [{seller_name, winner_name, artist, auction_type, price, round}]

# Constants
const ARTISTS := ["Orange Tarou", "Green Tarou", "Blue Tarou", "Yellow Tarou", "Red Tarou"]
const ARTIST_COLORS := {
	"Orange Tarou": Color(0.95, 0.55, 0.15),   # Orange
	"Green Tarou": Color(0.2, 0.75, 0.35),     # Green
	"Blue Tarou": Color(0.25, 0.5, 0.9),       # Blue
	"Yellow Tarou": Color(0.95, 0.85, 0.2),    # Yellow
	"Red Tarou": Color(0.9, 0.2, 0.25),        # Red
}
const AUCTION_TYPES := ["open", "once_around", "sealed", "fixed_price", "double"]

func _ready() -> void:
	Network.message_received.connect(_on_message_received)
	reset_state()

func reset_state() -> void:
	room_id = ""
	is_host = false
	players = []
	my_index = -1
	hand = []
	current_round = 0
	current_turn_player = -1
	is_my_turn = false
	auction_active = false
	board = {}
	settled_board = {}
	market = {}
	my_paintings = []
	for artist in ARTISTS:
		board[artist] = 0
		settled_board[artist] = 0
		market[artist] = 0

func _on_message_received(data: Dictionary) -> void:
	var msg_type: String = data.get("type", "")
	match msg_type:
		"room_created":
			room_id = data.get("room_id", "")
			player_id = data.get("player_id", "")
			is_host = true
			if data.has("players"):
				players = data["players"]
			room_created.emit(data)
		"room_joined":
			room_id = data.get("room_id", "")
			player_id = data.get("player_id", "")
			players = data.get("players", [])
			room_joined.emit(data)
		"room_list":
			room_list_updated.emit(data.get("rooms", []))
		"player_joined":
			players = data.get("players", [])
			player_joined.emit(data)
		"player_left":
			players = data.get("players", [])
			player_left.emit(data)
		"game_started":
			_handle_game_started(data)
		"your_turn":
			is_my_turn = true
			current_turn_player = data.get("player_index", -1)
			turn_changed.emit()
		"turn_changed":
			current_turn_player = data.get("player_index", -1)
			is_my_turn = (current_turn_player == my_index)
			turn_changed.emit()
		"card_played":
			_handle_card_played(data)
		"double_request":
			double_requested.emit(data)
		"auction_started":
			_handle_auction_started(data)
		"bid_update":
			_handle_bid_update(data)
		"auction_result":
			_handle_auction_result(data)
		"round_ended":
			_handle_round_ended(data)
		"game_ended":
			_handle_game_ended(data)
		"state_sync":
			_handle_state_sync(data)
		"error":
			error_received.emit(data.get("message", "Unknown error"))

func _handle_game_started(data: Dictionary) -> void:
	hand = data.get("hand", [])
	players = data.get("players", [])
	my_index = data.get("your_index", -1)
	current_round = data.get("round", 1)
	current_turn_player = data.get("current_turn", 0)
	is_my_turn = (current_turn_player == my_index)
	# Reset board for new game
	for artist in ARTISTS:
		board[artist] = 0
		market[artist] = 0
	my_paintings = []
	auction_log = []
	game_started.emit(data)
	hand_updated.emit()

func _handle_card_played(data: Dictionary) -> void:
	var artist: String = data.get("artist", "")
	if artist != "":
		board[artist] = data.get("board_count", board.get(artist, 0))
	card_played.emit(data)

var _auction_is_double: bool = false

func _handle_auction_started(data: Dictionary) -> void:
	auction_active = true
	auction_type = data.get("auction_type", "")
	auction_card = data.get("card", {})
	auction_seller = data.get("seller_index", -1)
	auction_current_bid = data.get("current_bid", 0)
	auction_current_bidder = -1
	auction_fixed_price = data.get("fixed_price", 0)
	auction_can_act = data.get("can_act", false)
	auction_bids_info = []
	_auction_is_double = data.has("double_card")
	auction_started.emit(data)

func _handle_bid_update(data: Dictionary) -> void:
	auction_current_bid = data.get("amount", auction_current_bid)
	auction_current_bidder = data.get("player_index", -1)
	auction_can_act = data.get("can_act", false)
	auction_bid.emit(data)

func _handle_auction_result(data: Dictionary) -> void:
	auction_active = false
	var winner_index: int = data.get("winner_index", -1)
	if winner_index == my_index:
		var card_info: Dictionary = data.get("card", auction_card)
		my_paintings.append(card_info)
	# Update player money
	if data.has("players"):
		players = data["players"]
	auction_can_act = false

	# Record auction log entry
	var card: Dictionary = data.get("card", {})
	var seller_name: String = ""
	if auction_seller >= 0 and auction_seller < players.size():
		seller_name = players[auction_seller].get("name", "???")
	var winner_name: String = data.get("winner_name", "")
	var price: int = data.get("price", 0)
	var no_buyer: bool = (winner_index == auction_seller)
	auction_log.append({
		"round": current_round,
		"seller_name": seller_name,
		"winner_name": winner_name,
		"artist": card.get("artist", ""),
		"auction_type": card.get("auction_type", ""),
		"price": price,
		"no_buyer": no_buyer,
		"is_double": _auction_is_double,
	})

	# Settle board: pending cards for this artist are now confirmed
	var settled_artist: String = card.get("artist", "")
	if settled_artist != "":
		settled_board[settled_artist] = board.get(settled_artist, 0)

	auction_ended.emit(data)

func _handle_round_ended(data: Dictionary) -> void:
	current_round = data.get("next_round", current_round + 1)
	if data.has("market"):
		market = data["market"]
	if data.has("players"):
		players = data["players"]
	if data.has("new_hand"):
		hand = data["new_hand"]
	# Reset board for next round
	for artist in ARTISTS:
		board[artist] = 0
		settled_board[artist] = 0
	my_paintings = []
	# Emit round_ended before hand_updated so listeners can request deal animation
	round_ended.emit(data)
	if data.has("new_hand"):
		hand_updated.emit()

func _handle_game_ended(data: Dictionary) -> void:
	if data.has("players"):
		players = data["players"]
	game_ended.emit(data)

func _handle_state_sync(data: Dictionary) -> void:
	if data.has("hand"):
		hand = data["hand"]
	if data.has("players"):
		players = data["players"]
	if data.has("round"):
		current_round = data["round"]
	if data.has("board"):
		board = data["board"]
	if data.has("market"):
		market = data["market"]
	if data.has("my_paintings"):
		my_paintings = data["my_paintings"]
	if data.has("current_turn"):
		current_turn_player = data["current_turn"]
		is_my_turn = (current_turn_player == my_index)
	if data.has("your_index"):
		my_index = data["your_index"]
	hand_updated.emit()
	state_changed.emit()

func remove_card_from_hand(card_index: int) -> void:
	if card_index >= 0 and card_index < hand.size():
		hand.remove_at(card_index)
		hand_updated.emit()

func get_my_money() -> int:
	if my_index >= 0 and my_index < players.size():
		return players[my_index].get("money", 0)
	return 0

func get_artist_display_name(artist: String) -> String:
	return Locale.t(artist)

func get_auction_type_display_name(atype: String) -> String:
	return Locale.t("auction_" + atype)
