extends Control

## Background flowing "modern art" text effect.
## Add as a child of the BG ColorRect (must be behind main content).

var _font: Font
var _spawn_timer: float = 0.0
var _texts: Array[Label] = []

const SPAWN_INTERVAL := 1.8
const TEXT := "modern art"
const FALLBACK_COLOR := Color(0.88, 0.85, 0.78, 0.25)
const MIN_SIZE := 28
const MAX_SIZE := 64
const MIN_SPEED := 15.0
const MAX_SPEED := 35.0
const MIN_Y_SPEED := 8.0
const MAX_Y_SPEED := 20.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = preload("res://assets/fonts/DelaGothicOne-Regular.ttf")
	if Settings:
		Settings.bg_color_changed.connect(_on_bg_color_changed)
	# Seed some initial texts so screen isn't empty at start
	for i in range(6):
		_spawn_text(true)

func _get_text_color() -> Color:
	if Settings:
		return Settings.get_flow_text_color()
	return FALLBACK_COLOR

func _on_bg_color_changed() -> void:
	var c := _get_text_color()
	for label in _texts:
		label.add_theme_color_override("font_color", c)

func _process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_spawn_text(false)

	var to_remove: Array[Label] = []
	for label in _texts:
		label.position.x += label.get_meta("speed_x") * delta
		label.position.y += label.get_meta("speed_y") * delta
		var dir: int = label.get_meta("dir")
		if dir > 0 and label.position.x > size.x:
			to_remove.append(label)
		elif dir < 0 and label.position.x < -label.size.x:
			to_remove.append(label)
		elif label.position.y > size.y or label.position.y < -label.size.y:
			to_remove.append(label)

	for label in to_remove:
		label.queue_free()
		_texts.erase(label)

func _spawn_text(initial: bool) -> void:
	var label := Label.new()
	label.text = TEXT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)

	var font_size := randi_range(MIN_SIZE, MAX_SIZE)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", _get_text_color())

	# Random horizontal direction: left-to-right or right-to-left
	var dir := 1 if randf() > 0.5 else -1
	var speed_x := randf_range(MIN_SPEED, MAX_SPEED) * dir
	# Random vertical drift (up or down)
	var y_dir := 1 if randf() > 0.5 else -1
	var speed_y := randf_range(MIN_Y_SPEED, MAX_Y_SPEED) * y_dir
	label.set_meta("speed_x", speed_x)
	label.set_meta("speed_y", speed_y)
	label.set_meta("dir", dir)

	# Diagonal rotation matching movement direction
	var angle := atan2(speed_y, speed_x)
	label.rotation = angle * 0.3 + randf_range(-0.05, 0.05)

	var y := randf_range(-20, size.y - font_size + 20)
	label.position.y = y

	if initial:
		# Place randomly across the screen
		label.position.x = randf_range(-100, size.x)
	elif dir > 0:
		label.position.x = -400
	else:
		label.position.x = size.x + 50

	add_child(label)
	_texts.append(label)
