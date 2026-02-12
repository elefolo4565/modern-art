extends Node

## Display settings manager (background color, etc.)

signal bg_color_changed

const SAVE_PATH := "user://settings.cfg"

const BG_PRESETS := [
	{"key": "cream",  "color": Color(0.95, 0.93, 0.88, 1)},
	{"key": "blue",   "color": Color(0.88, 0.93, 0.98, 1)},
	{"key": "green",  "color": Color(0.89, 0.96, 0.90, 1)},
	{"key": "pink",   "color": Color(0.98, 0.90, 0.93, 1)},
	{"key": "purple", "color": Color(0.93, 0.90, 0.98, 1)},
	{"key": "white",  "color": Color(0.97, 0.97, 0.97, 1)},
]

var bg_color_index: int = 0

func _ready() -> void:
	_load_settings()
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is Button:
		node.button_down.connect(_on_button_down.bind(node))
		node.button_up.connect(_on_button_up.bind(node))

func _on_button_down(btn: Button) -> void:
	if not is_instance_valid(btn) or not btn.is_inside_tree():
		return
	btn.pivot_offset = btn.size / 2.0
	btn.scale = Vector2(0.92, 0.92)
	btn.modulate = Color(0.85, 0.85, 0.85, 1)

func _on_button_up(btn: Button) -> void:
	if not is_instance_valid(btn) or not btn.is_inside_tree():
		return
	btn.pivot_offset = btn.size / 2.0
	btn.scale = Vector2(1.0, 1.0)
	btn.modulate = Color.WHITE

func get_bg_color() -> Color:
	return BG_PRESETS[bg_color_index].color

func set_bg_color_index(idx: int) -> void:
	bg_color_index = clampi(idx, 0, BG_PRESETS.size() - 1)
	_save_settings()
	bg_color_changed.emit()

func get_flow_text_color() -> Color:
	var bg := get_bg_color()
	return Color(bg.r - 0.07, bg.g - 0.08, bg.b - 0.10, 0.25)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		bg_color_index = clampi(config.get_value("display", "bg_color_index", 0), 0, BG_PRESETS.size() - 1)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("display", "bg_color_index", bg_color_index)
	config.save(SAVE_PATH)
