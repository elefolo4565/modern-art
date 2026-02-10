extends Control

signal go_to_lobby

@onready var title_label: Label = $VBox/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel
@onready var play_button: Button = $VBox/PlayButton
@onready var lang_button: Button = $VBox/LangButton
@onready var connection_label: Label = $ConnectionLabel
@onready var version_label: Label = $VersionLabel

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	lang_button.pressed.connect(_on_lang_pressed)
	Network.connected.connect(_on_connected)
	Network.disconnected.connect(_on_disconnected)
	Locale.language_changed.connect(_update_texts)
	_update_texts()

	version_label.text = "v" + GameState.VERSION + " (" + GameState.BUILD_DATE + ")"

	# Start connecting to server
	connection_label.text = Locale.t("connecting")
	Network.connect_to_server()

func _update_texts() -> void:
	title_label.text = Locale.t("app_title")
	play_button.text = Locale.t("title_play")
	if Network.is_connected_to_server():
		connection_label.text = ""
	else:
		connection_label.text = Locale.t("connecting")

func _on_play_pressed() -> void:
	if not Network.is_connected_to_server():
		Network.connect_to_server()
	go_to_lobby.emit()

func _on_lang_pressed() -> void:
	Locale.toggle_language()

func _on_connected() -> void:
	connection_label.text = ""
	play_button.disabled = false

func _on_disconnected() -> void:
	connection_label.text = Locale.t("disconnected")
