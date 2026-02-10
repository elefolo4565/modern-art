extends PanelContainer

## Compact market board showing artist values and board counts.

signal log_button_pressed

@onready var hbox: HBoxContainer = $HBox
@onready var header_label: Label = $HBox/HeaderLabel
@onready var log_button: Button = $HBox/LogButton

var _artist_labels: Dictionary = {}
var _count_labels: Dictionary = {}

func _ready() -> void:
	log_button.text = Locale.t("log_button")
	log_button.pressed.connect(func(): log_button_pressed.emit())
	_build_board()
	GameState.state_changed.connect(update_display)
	GameState.hand_updated.connect(update_display)
	Locale.language_changed.connect(_rebuild)

func _rebuild() -> void:
	log_button.text = Locale.t("log_button")
	_build_board()

func _build_board() -> void:
	# Remove old dynamic children (keep LogButton and HeaderLabel)
	for child in hbox.get_children():
		if child != header_label and child != log_button:
			child.queue_free()

	_artist_labels.clear()
	_count_labels.clear()

	header_label.text = Locale.t("game_market")

	# Add separator
	var sep := VSeparator.new()
	hbox.add_child(sep)

	for artist in GameState.ARTISTS:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(col)

		# Artist abbreviation with color
		var abbr := _get_abbreviation(artist)
		var name_lbl := Label.new()
		name_lbl.text = abbr
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var color: Color = GameState.ARTIST_COLORS.get(artist, Color.WHITE)
		name_lbl.add_theme_color_override("font_color", color)
		col.add_child(name_lbl)
		_artist_labels[artist] = name_lbl

		# Value + count
		var val_lbl := Label.new()
		val_lbl.text = "--"
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(val_lbl)
		_count_labels[artist] = val_lbl

	update_display()

func update_display() -> void:
	for artist in GameState.ARTISTS:
		if artist not in _count_labels:
			continue
		var market_val: int = GameState.market.get(artist, 0)
		var board_count: int = GameState.board.get(artist, 0)
		var settled_count: int = GameState.settled_board.get(artist, 0)
		var pending_count: int = board_count - settled_count

		var text := ""
		if market_val > 0:
			text = Locale.format_money(market_val)
		else:
			text = "--"

		if settled_count > 0 and pending_count > 0:
			text += " [%d+%d]" % [settled_count, pending_count]
		elif settled_count > 0:
			text += " [%d]" % settled_count
		elif pending_count > 0:
			text += " [+%d]" % pending_count

		_count_labels[artist].text = text

func _get_abbreviation(artist: String) -> String:
	match artist:
		"Orange Tarou": return "OT"
		"Green Tarou": return "GT"
		"Blue Tarou": return "BT"
		"Yellow Tarou": return "YT"
		"Red Tarou": return "RT"
	return artist.left(2).to_upper()
