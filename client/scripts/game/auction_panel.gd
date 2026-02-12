extends PanelContainer

## Auction panel handling all 5 auction types with appropriate UI controls.

@onready var auction_title: Label = $MarginContainer/VBox/AuctionTitle
@onready var auction_card_bar: ColorRect = $MarginContainer/VBox/CardDisplayRow/Card1Col/AuctionCardBar
@onready var auction_art_area: ColorRect = $MarginContainer/VBox/CardDisplayRow/Card1Col/AuctionArtArea
@onready var artist_label: Label = $MarginContainer/VBox/CardDisplayRow/Card1Col/ArtistLabel
@onready var card2_col: VBoxContainer = $MarginContainer/VBox/CardDisplayRow/Card2Col
@onready var double_card_bar: ColorRect = $MarginContainer/VBox/CardDisplayRow/Card2Col/DoubleCardBar
@onready var double_art_area: ColorRect = $MarginContainer/VBox/CardDisplayRow/Card2Col/DoubleArtArea
@onready var double_artist_label: Label = $MarginContainer/VBox/CardDisplayRow/Card2Col/DoubleArtistLabel
@onready var auction_type_label: Label = $MarginContainer/VBox/AuctionTypeLabel
@onready var seller_label: Label = $MarginContainer/VBox/SellerLabel
@onready var bid_info_label: Label = $MarginContainer/VBox/BidInfoLabel
@onready var bid_input: SpinBox = $MarginContainer/VBox/BidInputRow/BidInput
@onready var bid_input_row: HBoxContainer = $MarginContainer/VBox/BidInputRow
@onready var action_row: HBoxContainer = $MarginContainer/VBox/ActionRow
@onready var bid_button: Button = $MarginContainer/VBox/ActionRow/BidButton
@onready var pass_button: Button = $MarginContainer/VBox/ActionRow/PassButton
@onready var accept_button: Button = $MarginContainer/VBox/ActionRow/AcceptButton
@onready var set_price_button: Button = $MarginContainer/VBox/ActionRow/SetPriceButton
@onready var quick_bid_row: HBoxContainer = $MarginContainer/VBox/QuickBidRow
@onready var bid_5k: Button = $MarginContainer/VBox/QuickBidRow/Bid5K
@onready var bid_10k: Button = $MarginContainer/VBox/QuickBidRow/Bid10K
@onready var bid_20k: Button = $MarginContainer/VBox/QuickBidRow/Bid20K
@onready var bid_50k: Button = $MarginContainer/VBox/QuickBidRow/Bid50K
@onready var result_label: Label = $MarginContainer/VBox/ResultLabel

var _current_type: String = ""
var _min_bid: int = 0
var _auction_generation: int = 0  # Incremented each auction to cancel stale timers

func _ready() -> void:
	bid_button.pressed.connect(_on_bid_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	accept_button.pressed.connect(_on_accept_pressed)
	set_price_button.pressed.connect(_on_set_price_pressed)
	bid_5k.pressed.connect(_on_quick_bid.bind(5))
	bid_10k.pressed.connect(_on_quick_bid.bind(10))
	bid_20k.pressed.connect(_on_quick_bid.bind(20))
	bid_50k.pressed.connect(_on_quick_bid.bind(50))

	GameState.auction_started.connect(_on_auction_started)
	GameState.auction_bid.connect(_on_auction_bid)
	GameState.auction_ended.connect(_on_auction_ended)
	GameState.turn_changed.connect(_on_turn_changed)

func _on_auction_started(data: Dictionary) -> void:
	_auction_generation += 1  # Cancel any pending hide timer
	visible = true
	result_label.visible = false
	# Reset disabled state from sealed auctions
	bid_button.disabled = false
	pass_button.disabled = false
	_current_type = data.get("auction_type", "")

	var card: Dictionary = data.get("card", {})
	var artist: String = card.get("artist", "")
	var color: Color = GameState.ARTIST_COLORS.get(artist, Color.WHITE)

	auction_title.text = Locale.t("auction_title")
	auction_card_bar.color = color
	auction_art_area.color = Color(color.r, color.g, color.b, 0.3)
	artist_label.text = Locale.t(artist)
	artist_label.add_theme_color_override("font_color", color)

	# Double card display
	var double_card: Dictionary = data.get("double_card", {})
	if not double_card.is_empty():
		card2_col.visible = true
		var artist2: String = double_card.get("artist", "")
		var color2: Color = GameState.ARTIST_COLORS.get(artist2, Color.WHITE)
		double_card_bar.color = color2
		double_art_area.color = Color(color2.r, color2.g, color2.b, 0.3)
		double_artist_label.text = Locale.t(artist2)
		double_artist_label.add_theme_color_override("font_color", color2)
	else:
		card2_col.visible = false

	var type_text := Locale.t("auction_" + _current_type)
	if not double_card.is_empty():
		type_text = "%s [%s]" % [type_text, Locale.t("double_play")]
	auction_type_label.text = type_text

	var seller_idx: int = data.get("seller_index", -1)
	var seller_name := ""
	if seller_idx >= 0 and seller_idx < GameState.players.size():
		seller_name = GameState.players[seller_idx].get("name", "???")
	seller_label.text = "%s: %s" % [Locale.t("auction_seller"), seller_name]

	bid_info_label.text = ""
	_min_bid = 0

	var can_act: bool = data.get("can_act", false)
	_update_controls(can_act)

func _update_controls(can_act: bool) -> void:
	# Reset visibility
	bid_button.visible = false
	pass_button.visible = false
	accept_button.visible = false
	set_price_button.visible = false
	bid_input_row.visible = false
	quick_bid_row.visible = false

	# Prominent turn indicator
	if can_act:
		auction_title.text = Locale.t("auction_your_turn")
		auction_title.add_theme_color_override("font_color", Color(0.8, 0.6, 0.1))
	else:
		auction_title.text = Locale.t("auction_title")
		auction_title.remove_theme_color_override("font_color")

	if not can_act:
		# Keep current bid/price info visible (don't clear bid_info_label)
		return

	match _current_type:
		"open":
			bid_button.visible = true
			bid_button.text = Locale.t("auction_bid")
			pass_button.visible = true
			pass_button.text = Locale.t("auction_pass")
			bid_input_row.visible = true
			quick_bid_row.visible = true
			var min_k: int = max((_min_bid / 1000) + 1, 1)
			bid_input.value = min_k
			bid_input.min_value = min_k
		"once_around":
			bid_button.visible = true
			bid_button.text = Locale.t("auction_bid")
			pass_button.visible = true
			pass_button.text = Locale.t("auction_pass")
			bid_input_row.visible = true
			quick_bid_row.visible = true
			var min_k_oa: int = max((_min_bid / 1000) + 1, 1)
			bid_input.value = min_k_oa
			bid_input.min_value = min_k_oa
		"sealed":
			bid_button.visible = true
			bid_button.text = Locale.t("auction_bid")
			pass_button.visible = true
			pass_button.text = Locale.t("auction_pass")
			bid_input_row.visible = true
			bid_input.value = 1
			bid_input.min_value = 1
			bid_info_label.text = Locale.t("auction_enter_bid")
		"fixed_price":
			if GameState.auction_seller == GameState.my_index:
				# Seller sets price
				set_price_button.visible = true
				set_price_button.text = Locale.t("auction_set_price")
				bid_input_row.visible = true
				bid_input.value = 1
				bid_input.min_value = 1
			else:
				# Others accept or decline
				accept_button.visible = true
				accept_button.text = Locale.t("auction_accept")
				pass_button.visible = true
				pass_button.text = Locale.t("auction_decline")
				# Show the price clearly
				if _min_bid > 0:
					bid_info_label.text = Locale.tf("auction_price_display", [Locale.format_money(_min_bid)])

func _on_auction_bid(data: Dictionary) -> void:
	var amount: int = data.get("amount", 0)
	var pname: String = data.get("player_name", "")
	var can_act: bool = data.get("can_act", false)

	if amount > 0:
		_min_bid = amount
		bid_info_label.text = "%s: %s - %s" % [
			Locale.t("auction_current_bid"),
			Locale.format_money(amount),
			pname
		]

	_update_controls(can_act)

func _on_auction_ended(data: Dictionary) -> void:
	var winner_name: String = data.get("winner_name", "")
	var price: int = data.get("price", 0)

	result_label.visible = true
	if winner_name != "" and price > 0:
		result_label.text = Locale.tf("auction_winner", [winner_name, Locale.format_money(price)])
	elif winner_name != "":
		result_label.text = Locale.t("auction_no_buyer")

	# Hide controls
	bid_button.visible = false
	pass_button.visible = false
	accept_button.visible = false
	set_price_button.visible = false
	bid_input_row.visible = false
	quick_bid_row.visible = false

	# Auto-hide after delay (guarded: cancel if new auction started)
	var gen := _auction_generation
	await get_tree().create_timer(2.0).timeout
	if _auction_generation == gen:
		visible = false

func _on_turn_changed() -> void:
	# Turn advanced = auction is over; hide panel immediately
	if not GameState.auction_active:
		_auction_generation += 1  # Cancel pending hide timer
		visible = false

func _on_bid_pressed() -> void:
	var amount := int(bid_input.value) * 1000
	if _current_type == "sealed":
		Network.send_bid(amount)
		bid_button.disabled = true
		pass_button.disabled = true
		bid_info_label.text = "Bid: %s" % Locale.format_money(amount)
	else:
		Network.send_bid(amount)

func _on_pass_pressed() -> void:
	Network.send_pass()
	if _current_type == "sealed":
		bid_button.disabled = true
		pass_button.disabled = true

func _on_accept_pressed() -> void:
	Network.send_accept()

func _on_set_price_pressed() -> void:
	var price := int(bid_input.value) * 1000
	Network.send_set_price(price)

func _on_quick_bid(increment: int) -> void:
	bid_input.value += increment
