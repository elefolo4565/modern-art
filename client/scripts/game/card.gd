extends PanelContainer

## Visual card component showing artist and auction type.

signal card_pressed(card_index: int)

@onready var artist_bar: ColorRect = $VBox/ArtistBar
@onready var artist_label: Label = $VBox/ArtistLabel
@onready var art_area: ColorRect = $VBox/ArtArea
@onready var auction_label: Label = $VBox/AuctionLabel

var card_data: Dictionary = {}
var card_index: int = -1
var is_selected: bool = false

# Auction type icons
const AUCTION_ICONS := {
	"open": ">>",
	"once_around": "->",
	"sealed": "[]",
	"fixed_price": "$=",
	"double": "x2",
}

func setup(data: Dictionary, idx: int) -> void:
	card_data = data
	card_index = idx
	_update_display()

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _update_display() -> void:
	var artist: String = card_data.get("artist", "")
	var atype: String = card_data.get("auction_type", "")
	var color: Color = GameState.ARTIST_COLORS.get(artist, Color.WHITE)

	artist_bar.color = color
	art_area.color = Color(color.r, color.g, color.b, 0.3)
	artist_label.text = Locale.t(artist)
	artist_label.add_theme_color_override("font_color", color)

	var icon: String = AUCTION_ICONS.get(atype, "?")
	auction_label.text = "%s %s" % [icon, Locale.t("auction_" + atype)]

func set_selected(selected: bool) -> void:
	is_selected = selected
	if is_selected:
		modulate = Color(1.2, 1.2, 1.4, 1)
	else:
		modulate = Color.WHITE

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			card_pressed.emit(card_index)
