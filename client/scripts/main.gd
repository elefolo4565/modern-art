extends Control

## Main scene manager - handles scene transitions.

const TITLE_SCENE := "res://scenes/title/title.tscn"
const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"
const WAITING_SCENE := "res://scenes/lobby/waiting_room.tscn"
const GAME_SCENE := "res://scenes/game/game_board.tscn"
const RESULT_SCENE := "res://scenes/game/result.tscn"
const SETTINGS_SCENE := "res://scenes/settings/settings.tscn"

var _current_scene: Control = null

func _ready() -> void:
	_change_scene(TITLE_SCENE)

func _change_scene(scene_path: String) -> void:
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null

	var scene_res := load(scene_path) as PackedScene
	if scene_res:
		_current_scene = scene_res.instantiate() as Control
		add_child(_current_scene)

		# Connect navigation signals if available
		if _current_scene.has_signal("go_to_lobby"):
			_current_scene.connect("go_to_lobby", _on_go_to_lobby)
		if _current_scene.has_signal("go_to_title"):
			_current_scene.connect("go_to_title", _on_go_to_title)
		if _current_scene.has_signal("go_to_waiting"):
			_current_scene.connect("go_to_waiting", _on_go_to_waiting)
		if _current_scene.has_signal("go_to_game"):
			_current_scene.connect("go_to_game", _on_go_to_game)
		if _current_scene.has_signal("go_to_result"):
			_current_scene.connect("go_to_result", _on_go_to_result)
		if _current_scene.has_signal("go_to_settings"):
			_current_scene.connect("go_to_settings", _on_go_to_settings)

func _on_go_to_title() -> void:
	_change_scene(TITLE_SCENE)

func _on_go_to_lobby() -> void:
	_change_scene(LOBBY_SCENE)

func _on_go_to_waiting() -> void:
	_change_scene(WAITING_SCENE)

func _on_go_to_game() -> void:
	_change_scene(GAME_SCENE)

func _on_go_to_result() -> void:
	_change_scene(RESULT_SCENE)

func _on_go_to_settings() -> void:
	_change_scene(SETTINGS_SCENE)
