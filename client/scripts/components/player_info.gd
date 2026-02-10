extends PanelContainer

@onready var name_label: Label = $VBox/NameLabel
@onready var money_label: Label = $VBox/MoneyLabel
@onready var hand_label: Label = $VBox/HandLabel
@onready var paintings_box: HBoxContainer = $VBox/PaintingsBox

var player_index: int = -1
var _pulse_tween: Tween
var _active_style: StyleBoxFlat
var _normal_style: StyleBoxFlat

func _ready() -> void:
	# Normal: transparent background, no border
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(1, 1, 1, 0.05)
	_normal_style.set_corner_radius_all(6)
	_normal_style.set_border_width_all(0)
	_normal_style.set_content_margin_all(4)

	# Active: yellow rounded border
	_active_style = StyleBoxFlat.new()
	_active_style.bg_color = Color(1, 0.9, 0.3, 0.08)
	_active_style.border_color = Color(1, 0.9, 0.3, 1)
	_active_style.set_corner_radius_all(10)
	_active_style.set_border_width_all(2)
	_active_style.set_content_margin_all(4)

	add_theme_stylebox_override("panel", _normal_style)

func setup(idx: int) -> void:
	player_index = idx
	update_display()

func update_display() -> void:
	if player_index < 0 or player_index >= GameState.players.size():
		return

	var p: Dictionary = GameState.players[player_index]
	var is_current := (player_index == GameState.current_turn_player)
	var is_me := (player_index == GameState.my_index)

	var pname: String = p.get("name", "???")
	if is_me:
		pname += " *"

	name_label.text = pname
	money_label.text = Locale.format_money(p.get("money", 0))
	hand_label.text = "x%d" % p.get("hand_count", 0)

	if is_current:
		name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	elif is_me:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1, 1))
	else:
		name_label.add_theme_color_override("font_color", Color.WHITE)

	# Active player border
	if is_current:
		add_theme_stylebox_override("panel", _active_style)
		_start_pulse()
	else:
		add_theme_stylebox_override("panel", _normal_style)
		_stop_pulse()

	# Paintings display
	_update_paintings(p.get("paintings", {}))

func _update_paintings(paintings: Dictionary) -> void:
	for child in paintings_box.get_children():
		child.queue_free()

	for artist in GameState.ARTISTS:
		var count: int = paintings.get(artist, 0)
		if count <= 0:
			continue
		var lbl := Label.new()
		lbl.text = "%s%d" % [_abbrev(artist), count]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", GameState.ARTIST_COLORS.get(artist, Color.WHITE))
		paintings_box.add_child(lbl)

func _abbrev(artist: String) -> String:
	match artist:
		"Orange Tarou": return "O"
		"Green Tarou": return "G"
		"Blue Tarou": return "B"
		"Yellow Tarou": return "Y"
		"Red Tarou": return "R"
	return artist.left(1)

func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_active_style, "border_color",
		Color(1, 0.9, 0.3, 0.3), 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_active_style, "border_color",
		Color(1, 0.9, 0.3, 1.0), 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
