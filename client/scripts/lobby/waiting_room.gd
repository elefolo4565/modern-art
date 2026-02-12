extends Control

signal go_to_lobby
signal go_to_game

@onready var header_label: Label = $MarginContainer/VBox/HeaderLabel
@onready var room_id_label: Label = $MarginContainer/VBox/RoomIdLabel
@onready var status_label: Label = $MarginContainer/VBox/StatusLabel
@onready var players_label: Label = $MarginContainer/VBox/PlayersLabel
@onready var player_list: VBoxContainer = $MarginContainer/VBox/PlayerList
@onready var ai_button_row: HBoxContainer = $MarginContainer/VBox/AIButtonRow
@onready var add_ai_button: Button = $MarginContainer/VBox/AIButtonRow/AddAIButton
@onready var remove_ai_button: Button = $MarginContainer/VBox/AIButtonRow/RemoveAIButton
@onready var difficulty_row: HBoxContainer = $MarginContainer/VBox/DifficultyRow
@onready var easy_btn: Button = $MarginContainer/VBox/DifficultyRow/EasyBtn
@onready var normal_btn: Button = $MarginContainer/VBox/DifficultyRow/NormalBtn
@onready var hard_btn: Button = $MarginContainer/VBox/DifficultyRow/HardBtn
@onready var start_button: Button = $MarginContainer/VBox/StartButton
@onready var back_button: Button = $MarginContainer/VBox/BackButton
@onready var bg_rect: ColorRect = $BG

var _ai_difficulty: String = "normal"

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	add_ai_button.pressed.connect(_on_add_ai_pressed)
	remove_ai_button.pressed.connect(_on_remove_ai_pressed)
	easy_btn.pressed.connect(_on_difficulty_selected.bind("easy"))
	normal_btn.pressed.connect(_on_difficulty_selected.bind("normal"))
	hard_btn.pressed.connect(_on_difficulty_selected.bind("hard"))

	GameState.player_joined.connect(_on_players_changed)
	GameState.player_left.connect(_on_players_changed)
	GameState.game_started.connect(_on_game_started)
	GameState.error_received.connect(_on_error)
	Locale.language_changed.connect(_update_texts)
	Settings.bg_color_changed.connect(func(): bg_rect.color = Settings.get_bg_color())
	bg_rect.color = Settings.get_bg_color()

	_update_texts()
	_update_player_list()
	_update_difficulty_buttons()

func _update_texts() -> void:
	room_id_label.text = "%s: %s" % [Locale.t("lobby_room_id"), GameState.room_id]
	status_label.text = Locale.t("lobby_waiting")
	players_label.text = Locale.t("lobby_players") + ":"
	start_button.text = Locale.t("lobby_start")
	back_button.text = Locale.t("back")
	add_ai_button.text = Locale.t("ai_add")
	remove_ai_button.text = Locale.t("ai_remove")

	# Only host can start and manage AI
	var is_host := GameState.is_host
	start_button.visible = is_host
	ai_button_row.visible = is_host
	difficulty_row.visible = is_host

func _update_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()

	var ai_count := 0
	for i in range(GameState.players.size()):
		var p: Dictionary = GameState.players[i]
		var lbl := Label.new()
		var pname: String = p.get("name", "???")
		var is_ai: bool = p.get("is_ai", false)

		if is_ai:
			ai_count += 1
			lbl.text = "%d. %s (AI)" % [i + 1, pname]
			lbl.add_theme_color_override("font_color", Color(0.3, 0.55, 0.8, 1))
		elif i == 0:
			lbl.text = "%d. %s (Host)" % [i + 1, pname]
			lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.1, 1))
		else:
			lbl.text = "%d. %s" % [i + 1, pname]

		lbl.add_theme_font_size_override("font_size", 24)
		player_list.add_child(lbl)

	# Enable/disable AI buttons
	var count := GameState.players.size()
	add_ai_button.disabled = count >= 5
	remove_ai_button.disabled = ai_count == 0

	# Enable start if 3-5 players and we are host
	start_button.disabled = not (GameState.is_host and count >= 3 and count <= 5)

	if count < 3:
		status_label.text = Locale.t("lobby_waiting") + " (%d/3)" % count
	else:
		status_label.text = "%d %s" % [count, Locale.t("lobby_players")]

func _update_difficulty_buttons() -> void:
	easy_btn.button_pressed = (_ai_difficulty == "easy")
	normal_btn.button_pressed = (_ai_difficulty == "normal")
	hard_btn.button_pressed = (_ai_difficulty == "hard")

func _on_difficulty_selected(diff: String) -> void:
	_ai_difficulty = diff
	_update_difficulty_buttons()

func _on_add_ai_pressed() -> void:
	Network.send_add_ai(_ai_difficulty)

func _on_remove_ai_pressed() -> void:
	Network.send_remove_ai()

func _on_players_changed(_data: Dictionary) -> void:
	_update_player_list()

func _on_start_pressed() -> void:
	Network.send_start_game()

func _on_back_pressed() -> void:
	Network.disconnect_from_server()
	GameState.reset_state()
	go_to_lobby.emit()

func _on_game_started(_data: Dictionary) -> void:
	go_to_game.emit()

func _on_error(msg: String) -> void:
	status_label.text = msg
