extends Control

## Main game board - orchestrates all game UI elements.

signal go_to_result
signal go_to_title

@onready var round_label: Label = $MainVBox/InfoBar/RoundLabel
@onready var money_label: Label = $MainVBox/InfoBar/MoneyLabel
@onready var turn_label: Label = $MainVBox/TurnLabel
@onready var player_list_box: HBoxContainer = $MainVBox/PlayerListBox
@onready var auction_panel: PanelContainer = $MainVBox/CenterArea/AuctionPanel
@onready var play_card_button: Button = $MainVBox/CenterArea/PlayCardButton
@onready var double_panel: VBoxContainer = $MainVBox/CenterArea/DoublePanel
@onready var double_label: Label = $MainVBox/CenterArea/DoublePanel/DoubleLabel
@onready var double_yes_btn: Button = $MainVBox/CenterArea/DoublePanel/DoubleButtons/DoubleYesButton
@onready var double_no_btn: Button = $MainVBox/CenterArea/DoublePanel/DoubleButtons/DoubleNoButton
@onready var card_preview: PanelContainer = $MainVBox/CenterArea/CardPreview
@onready var preview_artist_bar: ColorRect = $MainVBox/CenterArea/CardPreview/Margin/VBox/PreviewArtistBar
@onready var preview_artist_label: Label = $MainVBox/CenterArea/CardPreview/Margin/VBox/PreviewArtistLabel
@onready var preview_art_area: TextureRect = $MainVBox/CenterArea/CardPreview/Margin/VBox/PreviewArtArea
@onready var preview_auction_label: Label = $MainVBox/CenterArea/CardPreview/Margin/VBox/PreviewAuctionLabel
@onready var market_board: PanelContainer = $MainVBox/MarketBoard
@onready var hand_area: PanelContainer = $MainVBox/HandArea
@onready var recent_log: VBoxContainer = $MainVBox/RecentLog
@onready var log_overlay: PanelContainer = $LogOverlay
@onready var log_title_label: Label = $LogOverlay/LogMargin/LogVBox/LogTitleBar/LogTitleLabel
@onready var log_scroll: ScrollContainer = $LogOverlay/LogMargin/LogVBox/LogScroll
@onready var log_content: VBoxContainer = $LogOverlay/LogMargin/LogVBox/LogScroll/LogContent
@onready var log_close_button: Button = $LogOverlay/LogMargin/LogVBox/LogTitleBar/LogCloseButton

const PLAYER_INFO_SCENE := preload("res://scenes/components/player_info.tscn")
const AUCTION_ICONS := {"open": ">>", "once_around": "->", "sealed": "[]", "fixed_price": "$=", "double": "x2"}

var _selected_card_index: int = -1
var _double_second_index: int = -1
var _player_infos: Array = []
var _preview_tween: Tween = null
var _preview_gen: int = 0

func _ready() -> void:
	play_card_button.pressed.connect(_on_play_card_pressed)
	double_yes_btn.pressed.connect(_on_double_yes)
	double_no_btn.pressed.connect(_on_double_no)
	hand_area.card_selected.connect(_on_card_selected)
	market_board.log_button_pressed.connect(_on_log_button_pressed)
	log_close_button.pressed.connect(_on_log_close_pressed)
	log_title_label.text = Locale.t("log_title")

	GameState.game_started.connect(_on_game_started)
	GameState.turn_changed.connect(_update_turn)
	GameState.card_played.connect(_on_card_played)
	GameState.double_requested.connect(_on_double_requested)
	GameState.auction_started.connect(_on_auction_started)
	GameState.auction_ended.connect(_on_auction_ended)
	GameState.round_ended.connect(_on_round_ended)
	GameState.game_ended.connect(_on_game_ended)
	GameState.hand_updated.connect(_update_hand_state)
	GameState.state_changed.connect(_refresh_all)
	Locale.language_changed.connect(_update_texts)

	# Initialize if game already started (scene reload)
	if GameState.players.size() > 0:
		_build_player_list()
		_refresh_all()

func _on_game_started(_data: Dictionary) -> void:
	_build_player_list()
	_refresh_all()
	_update_recent_log()
	hand_area.refresh_hand()

func _build_player_list() -> void:
	# Clear
	for child in player_list_box.get_children():
		child.queue_free()
	_player_infos.clear()

	for i in range(GameState.players.size()):
		var info = PLAYER_INFO_SCENE.instantiate()
		player_list_box.add_child(info)
		info.setup(i)
		_player_infos.append(info)

func _refresh_all() -> void:
	_update_info_bar()
	_update_turn()
	_update_player_infos()

func _update_info_bar() -> void:
	round_label.text = "%s %d/4" % [Locale.t("game_round"), GameState.current_round]
	money_label.text = Locale.format_money(GameState.get_my_money())

func _update_turn() -> void:
	if GameState.is_my_turn and not GameState.auction_active:
		turn_label.text = Locale.t("game_your_turn")
		play_card_button.visible = true
	else:
		if GameState.current_turn_player >= 0 and GameState.current_turn_player < GameState.players.size():
			var name: String = GameState.players[GameState.current_turn_player].get("name", "???")
			turn_label.text = Locale.tf("game_waiting_turn", [name])
		else:
			turn_label.text = ""
		if GameState.auction_active:
			play_card_button.visible = false

	_update_player_infos()
	_update_play_button()

func _update_player_infos() -> void:
	for info in _player_infos:
		if info and is_instance_valid(info):
			info.update_display()

func _update_hand_state() -> void:
	_selected_card_index = -1
	_update_play_button()
	_update_info_bar()
	_hide_card_preview()

func _update_play_button() -> void:
	play_card_button.disabled = not (GameState.is_my_turn and _selected_card_index >= 0 and not GameState.auction_active)
	play_card_button.text = Locale.t("game_play_card")

func _update_texts() -> void:
	_refresh_all()
	play_card_button.text = Locale.t("game_play_card")
	double_label.text = Locale.t("auction_select_double")

func _on_card_selected(card_index: int) -> void:
	if not GameState.is_my_turn or GameState.auction_active:
		hand_area.clear_selection()
		return
	_selected_card_index = card_index
	_update_play_button()
	_show_card_preview(card_index)

func _on_play_card_pressed() -> void:
	if _selected_card_index < 0:
		return
	var idx := _selected_card_index
	Network.send_play_card(idx)
	GameState.remove_card_from_hand(idx)
	_selected_card_index = -1
	play_card_button.disabled = true

func _on_card_played(data: Dictionary) -> void:
	_update_info_bar()
	market_board.update_display()
	_update_player_infos()
	if data.get("is_double", false):
		var pname: String = data.get("player_name", "???")
		var artist: String = Locale.t(data.get("artist", ""))
		turn_label.text = "%s: %s %s" % [pname, artist, Locale.t("double_play")]

func _on_double_requested(data: Dictionary) -> void:
	var artist: String = data.get("artist", "")
	if data.get("player_index", -1) != GameState.my_index:
		return

	# Show double selection panel
	double_panel.visible = true
	play_card_button.visible = false
	double_label.text = "%s - %s" % [Locale.t("auction_select_double"), Locale.t(artist)]

	# Player needs to select a second card from hand
	# The hand_area will be used for selection
	_double_second_index = -1
	hand_area.clear_selection()

func _on_double_yes() -> void:
	# Use selected card as second card
	if _selected_card_index >= 0:
		var idx := _selected_card_index
		Network.send_message({"type": "double_response", "card_index": idx})
		GameState.remove_card_from_hand(idx)
		_selected_card_index = -1
	else:
		# No card selected, play without double
		Network.send_message({"type": "double_response", "card_index": -1})
	double_panel.visible = false

func _on_double_no() -> void:
	# Decline double
	Network.send_message({"type": "double_response", "card_index": -1})
	double_panel.visible = false

func _on_auction_started(_data: Dictionary) -> void:
	play_card_button.visible = false
	_hide_card_preview()
	_update_turn()

func _on_auction_ended(_data: Dictionary) -> void:
	_update_info_bar()
	_update_player_infos()
	_update_recent_log()

func _on_round_ended(_data: Dictionary) -> void:
	_update_info_bar()
	market_board.update_display()
	_update_player_infos()
	_update_recent_log()
	# hand_area.refresh_hand() は hand_updated シグナル経由で既に呼ばれる

func _on_game_ended(_data: Dictionary) -> void:
	# Transition to result screen after a delay
	await get_tree().create_timer(1.0).timeout
	go_to_result.emit()

func _show_card_preview(card_index: int) -> void:
	if card_index < 0 or card_index >= GameState.hand.size():
		_hide_card_preview()
		return
	var data: Dictionary = GameState.hand[card_index]
	var artist: String = data.get("artist", "")
	var atype: String = data.get("auction_type", "")
	var color: Color = GameState.ARTIST_COLORS.get(artist, Color.WHITE)

	preview_artist_bar.color = color
	var card_id: String = data.get("card_id", "")
	var img_path := "res://assets/cards/%s.png" % card_id
	if card_id != "" and ResourceLoader.exists(img_path):
		preview_art_area.texture = load(img_path)
		preview_art_area.self_modulate = Color.WHITE
	else:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(color.r, color.g, color.b, 0.3))
		preview_art_area.texture = ImageTexture.create_from_image(img)
		preview_art_area.self_modulate = Color.WHITE
	preview_artist_label.text = Locale.t(artist)
	preview_artist_label.add_theme_color_override("font_color", color)
	var icon: String = AUCTION_ICONS.get(atype, "?")
	preview_auction_label.text = "%s %s" % [icon, Locale.t("auction_" + atype)]

	# Slide-in from right (wait for layout to settle before animating position)
	if _preview_tween:
		_preview_tween.kill()
	_preview_gen += 1
	var gen := _preview_gen
	card_preview.visible = true
	card_preview.modulate = Color(1, 1, 1, 0)
	await get_tree().process_frame
	if gen != _preview_gen or not is_inside_tree():
		return
	var target_x := card_preview.position.x
	card_preview.position.x = target_x + 300
	_preview_tween = create_tween().set_parallel(true)
	_preview_tween.tween_property(card_preview, "modulate", Color(1, 1, 1, 1), 0.25).set_ease(Tween.EASE_OUT)
	_preview_tween.tween_property(card_preview, "position:x", target_x, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _hide_card_preview() -> void:
	if not card_preview.visible:
		return
	_preview_gen += 1
	if _preview_tween:
		_preview_tween.kill()
	_preview_tween = create_tween().set_parallel(true)
	_preview_tween.tween_property(card_preview, "modulate", Color(1, 1, 1, 0), 0.15).set_ease(Tween.EASE_IN)
	_preview_tween.tween_property(card_preview, "position:x", card_preview.position.x + 300, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_preview_tween.chain().tween_callback(func(): card_preview.visible = false)

func _on_log_button_pressed() -> void:
	_build_log_content()
	log_overlay.visible = true

func _on_log_close_pressed() -> void:
	log_overlay.visible = false

func _update_recent_log() -> void:
	for child in recent_log.get_children():
		child.queue_free()

	var entries: Array = GameState.auction_log
	if entries.is_empty():
		recent_log.visible = false
		return

	recent_log.visible = true
	var start := maxi(entries.size() - 3, 0)
	for i in range(start, entries.size()):
		var entry: Dictionary = entries[i]
		var lbl := Label.new()
		var rd: int = entry.get("round", 0)
		var seller: String = entry.get("seller_name", "???")
		var artist: String = Locale.t(entry.get("artist", ""))
		var atype: String = Locale.t("auction_" + entry.get("auction_type", ""))
		var color: Color = GameState.ARTIST_COLORS.get(entry.get("artist", ""), Color.WHITE)
		var double_tag: String = " [%s]" % Locale.t("double_play") if entry.get("is_double", false) else ""

		if entry.get("no_buyer", false):
			lbl.text = "R%d: %s [%s]%s %s" % [rd, artist, atype, double_tag, Locale.t("auction_no_buyer")]
		else:
			var winner: String = entry.get("winner_name", "???")
			var price: String = Locale.format_money(entry.get("price", 0))
			lbl.text = "R%d: %s [%s]%s %s->%s (%s)" % [rd, artist, atype, double_tag, seller, winner, price]

		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", color)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		recent_log.add_child(lbl)

func _build_log_content() -> void:
	for child in log_content.get_children():
		child.queue_free()

	log_title_label.text = Locale.t("log_title")

	if GameState.auction_log.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = Locale.t("log_empty")
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate = Color(1, 1, 1, 0.5)
		log_content.add_child(empty_lbl)
		return

	for entry in GameState.auction_log:
		var lbl := Label.new()
		var rd: int = entry.get("round", 0)
		var seller: String = entry.get("seller_name", "???")
		var artist: String = Locale.t(entry.get("artist", ""))
		var atype: String = Locale.t("auction_" + entry.get("auction_type", ""))
		var color: Color = GameState.ARTIST_COLORS.get(entry.get("artist", ""), Color.WHITE)
		var double_tag: String = " [%s]" % Locale.t("double_play") if entry.get("is_double", false) else ""

		if entry.get("no_buyer", false):
			lbl.text = "R%d: %s [%s]%s %s" % [rd, artist, atype, double_tag, Locale.t("auction_no_buyer")]
		else:
			var winner: String = entry.get("winner_name", "???")
			var price: String = Locale.format_money(entry.get("price", 0))
			lbl.text = "R%d: %s [%s]%s %s -> %s (%s)" % [rd, artist, atype, double_tag, seller, winner, price]

		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", color)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_content.add_child(lbl)
