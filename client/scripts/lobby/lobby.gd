extends Control

signal go_to_title
signal go_to_waiting

@onready var header_label: Label = $MarginContainer/VBox/HeaderLabel
@onready var name_label: Label = $MarginContainer/VBox/NameLabel
@onready var name_input: LineEdit = $MarginContainer/VBox/NameInput
@onready var create_button: Button = $MarginContainer/VBox/ButtonRow/CreateButton
@onready var refresh_button: Button = $MarginContainer/VBox/ButtonRow/RefreshButton
@onready var room_id_input: LineEdit = $MarginContainer/VBox/JoinRow/RoomIdInput
@onready var join_button: Button = $MarginContainer/VBox/JoinRow/JoinButton
@onready var room_list_label: Label = $MarginContainer/VBox/RoomListLabel
@onready var room_list: VBoxContainer = $MarginContainer/VBox/RoomListScroll/RoomList
@onready var no_rooms_label: Label = $MarginContainer/VBox/RoomListScroll/RoomList/NoRoomsLabel
@onready var back_button: Button = $MarginContainer/VBox/BackButton
@onready var error_label: Label = $MarginContainer/VBox/ErrorLabel

const SAVE_PATH := "user://settings.cfg"

func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)

	GameState.room_created.connect(_on_room_created)
	GameState.room_joined.connect(_on_room_joined)
	GameState.room_list_updated.connect(_on_room_list_updated)
	GameState.error_received.connect(_on_error)

	Network.connected.connect(_on_connected)
	Network.disconnected.connect(_on_disconnected)
	Locale.language_changed.connect(_update_texts)

	# Restore player name: from GameState (same session) or saved file
	if GameState.player_name != "":
		name_input.text = GameState.player_name
	else:
		var config := ConfigFile.new()
		if config.load(SAVE_PATH) == OK:
			name_input.text = config.get_value("player", "name", "")

	_update_texts()
	_update_connection_state()

	# Auto-refresh room list when already connected
	if Network.is_connected_to_server():
		Network.send_list_rooms()

func _update_texts() -> void:
	header_label.text = Locale.t("lobby_title")
	name_label.text = Locale.t("lobby_player_name") + ":"
	name_input.placeholder_text = Locale.t("lobby_enter_name")
	create_button.text = Locale.t("lobby_create")
	refresh_button.text = Locale.t("lobby_refresh")
	join_button.text = Locale.t("lobby_join")
	room_list_label.text = Locale.t("lobby_room_list") + ":"
	no_rooms_label.text = Locale.t("lobby_no_rooms")
	back_button.text = Locale.t("back")
	room_id_input.placeholder_text = Locale.t("lobby_room_id")

func _get_player_name() -> String:
	var pname := name_input.text.strip_edges()
	if pname == "":
		error_label.text = Locale.t("lobby_enter_name")
		return ""
	GameState.player_name = pname
	# Persist for next session
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("player", "name", pname)
	config.save(SAVE_PATH)
	return pname

func _on_create_pressed() -> void:
	var pname := _get_player_name()
	if pname == "":
		return
	error_label.text = ""
	Network.send_create_room(pname)

func _on_join_pressed() -> void:
	var pname := _get_player_name()
	if pname == "":
		return
	var rid := room_id_input.text.strip_edges().to_upper()
	if rid == "":
		error_label.text = Locale.t("lobby_room_id")
		return
	error_label.text = ""
	Network.send_join_room(rid, pname)

func _on_refresh_pressed() -> void:
	Network.send_list_rooms()

func _on_back_pressed() -> void:
	go_to_title.emit()

func _on_room_created(_data: Dictionary) -> void:
	go_to_waiting.emit()

func _on_room_joined(_data: Dictionary) -> void:
	go_to_waiting.emit()

func _on_room_list_updated(rooms: Array) -> void:
	# Clear existing room buttons (keep NoRoomsLabel)
	for child in room_list.get_children():
		if child != no_rooms_label:
			child.queue_free()

	if rooms.is_empty():
		no_rooms_label.visible = true
		return

	no_rooms_label.visible = false
	for room_data in rooms:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		var rid: String = room_data.get("room_id", "")
		var host_name: String = room_data.get("host", "")
		var count: int = room_data.get("player_count", 0)
		btn.text = "%s  |  %s  (%d/5)" % [rid, host_name, count]
		btn.pressed.connect(_on_room_button_pressed.bind(rid))
		room_list.add_child(btn)

func _on_room_button_pressed(rid: String) -> void:
	room_id_input.text = rid
	_on_join_pressed()

func _on_error(msg: String) -> void:
	error_label.text = msg

func _on_connected() -> void:
	_update_connection_state()
	Network.send_list_rooms()

func _on_disconnected() -> void:
	_update_connection_state()

func _update_connection_state() -> void:
	var connected := Network.is_connected_to_server()
	create_button.disabled = not connected
	join_button.disabled = not connected
	refresh_button.disabled = not connected
	if not connected:
		error_label.text = Locale.t("connecting")
