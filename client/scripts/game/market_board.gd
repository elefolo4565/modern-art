extends PanelContainer

## Compact market board showing artist values and board counts.

signal log_button_pressed
signal paintings_button_pressed

@onready var hbox: HBoxContainer = $HBox
@onready var guide_col: VBoxContainer = $HBox/GuideCol
@onready var log_button: Button = $HBox/ButtonsBox/LogButton
@onready var paintings_button: Button = $HBox/ButtonsBox/PaintingsButton

var _artist_labels: Dictionary = {}
var _value_labels: Dictionary = {}
var _settled_labels: Dictionary = {}
var _pending_labels: Dictionary = {}

func _ready() -> void:
	log_button.text = Locale.t("log_button")
	paintings_button.text = Locale.t("paintings_button")
	log_button.pressed.connect(func(): log_button_pressed.emit())
	paintings_button.pressed.connect(func(): paintings_button_pressed.emit())
	_build_board()
	GameState.state_changed.connect(update_display)
	GameState.hand_updated.connect(update_display)
	GameState.auction_ended.connect(func(_data): update_display())
	Locale.language_changed.connect(_rebuild)

func _rebuild() -> void:
	log_button.text = Locale.t("log_button")
	paintings_button.text = Locale.t("paintings_button")
	_build_board()

func _build_board() -> void:
	# Remove old dynamic children (keep ButtonsBox and GuideCol)
	var buttons_box = $HBox/ButtonsBox
	for child in hbox.get_children():
		if child != guide_col and child != buttons_box:
			child.queue_free()

	_artist_labels.clear()
	_value_labels.clear()
	_settled_labels.clear()
	_pending_labels.clear()

	# Build guide column labels
	for child in guide_col.get_children():
		child.queue_free()
	var guide_color := Color(0.45, 0.43, 0.4, 1)
	var guide_rows := ["", "market_value", "market_count", "market_bid"]
	for key in guide_rows:
		var lbl := Label.new()
		lbl.text = Locale.t(key) if key != "" else ""
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", guide_color)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		guide_col.add_child(lbl)

	# Add separator
	var sep := VSeparator.new()
	hbox.add_child(sep)

	for artist in GameState.ARTISTS:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(col)

		var color: Color = GameState.ARTIST_COLORS.get(artist, Color.WHITE)

		# Row 1: Artist abbreviation
		var name_lbl := Label.new()
		name_lbl.text = _get_abbreviation(artist)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", color)
		col.add_child(name_lbl)
		_artist_labels[artist] = name_lbl

		# Row 2: Cumulative market value
		var val_lbl := Label.new()
		val_lbl.text = "0"
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(val_lbl)
		_value_labels[artist] = val_lbl

		# Row 3: Settled count (completed auctions this round)
		var settled_lbl := Label.new()
		settled_lbl.text = ""
		settled_lbl.add_theme_font_size_override("font_size", 11)
		settled_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		settled_lbl.add_theme_color_override("font_color", Color(0.2, 0.6, 0.3))
		col.add_child(settled_lbl)
		_settled_labels[artist] = settled_lbl

		# Row 4: Pending count (currently in auction)
		var pending_lbl := Label.new()
		pending_lbl.text = ""
		pending_lbl.add_theme_font_size_override("font_size", 11)
		pending_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pending_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.1))
		col.add_child(pending_lbl)
		_pending_labels[artist] = pending_lbl

	update_display()

func update_display() -> void:
	for artist in GameState.ARTISTS:
		if artist not in _value_labels:
			continue
		var market_val: int = GameState.market.get(artist, 0)
		var board_count: int = GameState.board.get(artist, 0)
		var settled_count: int = GameState.settled_board.get(artist, 0)
		var pending_count: int = board_count - settled_count

		# Row 2: Market value
		_value_labels[artist].text = Locale.format_money(market_val)

		# Row 3: Settled count
		if settled_count > 0:
			_settled_labels[artist].text = "%d" % settled_count
		else:
			_settled_labels[artist].text = ""

		# Row 4: Pending count
		if pending_count > 0:
			_pending_labels[artist].text = "+%d" % pending_count
		else:
			_pending_labels[artist].text = ""

func _get_abbreviation(artist: String) -> String:
	match artist:
		"Orange Tarou": return "OT"
		"Green Tarou": return "GT"
		"Blue Tarou": return "BT"
		"Yellow Tarou": return "YT"
		"Red Tarou": return "RT"
	return artist.left(2).to_upper()
