extends Control

## Final game result screen showing rankings and market values.

signal go_to_title

@onready var title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var winner_label: Label = $MarginContainer/VBox/WinnerLabel
@onready var results_label: Label = $MarginContainer/VBox/ResultsLabel
@onready var player_results: VBoxContainer = $MarginContainer/VBox/PlayerResults
@onready var market_label: Label = $MarginContainer/VBox/MarketLabel
@onready var market_results: VBoxContainer = $MarginContainer/VBox/MarketResults
@onready var back_button: Button = $MarginContainer/VBox/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	Locale.language_changed.connect(_update_texts)
	_display_results()

func _display_results() -> void:
	_update_texts()

	# Sort players by money (descending)
	var sorted_players := GameState.players.duplicate()
	sorted_players.sort_custom(func(a, b): return a.get("money", 0) > b.get("money", 0))

	# Display player rankings
	for child in player_results.get_children():
		child.queue_free()

	for i in range(sorted_players.size()):
		var p: Dictionary = sorted_players[i]
		var row := HBoxContainer.new()
		row.theme_override_constants = 10

		var rank_label := Label.new()
		rank_label.text = "#%d" % (i + 1)
		rank_label.add_theme_font_size_override("font_size", 24)
		rank_label.custom_minimum_size = Vector2(50, 0)
		if i == 0:
			rank_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
		row.add_child(rank_label)

		var name_lbl := Label.new()
		name_lbl.text = p.get("name", "???")
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 0:
			name_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
		row.add_child(name_lbl)

		var money_lbl := Label.new()
		money_lbl.text = Locale.format_money(p.get("money", 0))
		money_lbl.add_theme_font_size_override("font_size", 24)
		money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if i == 0:
			money_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
		row.add_child(money_lbl)

		player_results.add_child(row)

	# Display final market values
	for child in market_results.get_children():
		child.queue_free()

	for artist in GameState.ARTISTS:
		var value: int = GameState.market.get(artist, 0)
		var row := HBoxContainer.new()

		var artist_lbl := Label.new()
		artist_lbl.text = Locale.t(artist)
		artist_lbl.add_theme_font_size_override("font_size", 18)
		artist_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var color: Color = GameState.ARTIST_COLORS.get(artist, Color.WHITE)
		artist_lbl.add_theme_color_override("font_color", color)
		row.add_child(artist_lbl)

		var val_lbl := Label.new()
		val_lbl.text = Locale.format_money(value) if value > 0 else "--"
		val_lbl.add_theme_font_size_override("font_size", 18)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)

		market_results.add_child(row)

func _update_texts() -> void:
	title_label.text = Locale.t("game_end_title")
	results_label.text = Locale.t("game_end_final")
	market_label.text = Locale.t("game_market")
	back_button.text = Locale.t("game_end_back_lobby")

	# Find winner
	var winner_idx := 0
	var max_money := 0
	for i in range(GameState.players.size()):
		var money: int = GameState.players[i].get("money", 0)
		if money > max_money:
			max_money = money
			winner_idx = i
	if GameState.players.size() > 0:
		var winner_name: String = GameState.players[winner_idx].get("name", "???")
		winner_label.text = Locale.tf("game_end_winner", [winner_name])

func _on_back_pressed() -> void:
	Network.disconnect_from_server()
	GameState.reset_state()
	go_to_title.emit()
