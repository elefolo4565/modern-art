extends PanelContainer

## Fan-style hand area: all cards visible without scrolling, overlapping as needed.

signal card_selected(card_index: int)

const CARD_SCENE := preload("res://scenes/game/card.tscn")
const CARD_W := 120.0
const CARD_H := 170.0

@onready var card_container: Control = $CardContainer

var selected_index: int = -1

func _ready() -> void:
	GameState.hand_updated.connect(refresh_hand)
	card_container.resized.connect(_layout_cards)

func refresh_hand() -> void:
	for child in card_container.get_children():
		child.queue_free()
	selected_index = -1

	var atype_order := {"open": 0, "once_around": 1, "sealed": 2, "fixed_price": 3, "double": 4}

	var indices: Array = range(GameState.hand.size())
	indices.sort_custom(func(a: int, b: int) -> bool:
		var artist_a: String = GameState.hand[a].get("artist", "")
		var artist_b: String = GameState.hand[b].get("artist", "")
		if artist_a != artist_b:
			return GameState.ARTISTS.find(artist_a) < GameState.ARTISTS.find(artist_b)
		var at_a: int = atype_order.get(GameState.hand[a].get("auction_type", ""), 0)
		var at_b: int = atype_order.get(GameState.hand[b].get("auction_type", ""), 0)
		return at_a < at_b
	)

	for i in indices:
		var card_data: Dictionary = GameState.hand[i]
		var card_node = CARD_SCENE.instantiate()
		card_container.add_child(card_node)
		card_node.setup(card_data, i)
		card_node.card_pressed.connect(_on_card_pressed)

	await get_tree().process_frame
	_layout_cards()

func _layout_cards() -> void:
	var cards: Array[Node] = []
	for c in card_container.get_children():
		if not c.is_queued_for_deletion():
			cards.append(c)
	var count := cards.size()
	if count == 0:
		return

	var area_w := card_container.size.x
	var area_h := card_container.size.y

	# Scale cards to fit height (leave room for selection pop-up)
	var card_h := minf(CARD_H, area_h - 14.0)
	var card_w := CARD_W * (card_h / CARD_H)

	# Calculate spacing: overlap when cards exceed area width
	var max_spacing := card_w + 4.0
	var spacing: float
	if count == 1:
		spacing = 0.0
	else:
		spacing = minf(max_spacing, (area_w - card_w) / (count - 1))

	# Center horizontally, align to bottom
	var total_w := card_w + spacing * maxf(count - 1, 0)
	var start_x := (area_w - total_w) / 2.0
	var base_y := area_h - card_h

	for i in range(count):
		var card: Control = cards[i]
		card.custom_minimum_size = Vector2(card_w, card_h)
		card.size = Vector2(card_w, card_h)
		var y_off := -12.0 if card.is_selected else 0.0
		card.position = Vector2(start_x + i * spacing, base_y + y_off)
		card.z_index = 100 if card.is_selected else i

func _on_card_pressed(card_index: int) -> void:
	if selected_index == card_index:
		selected_index = -1
	else:
		selected_index = card_index

	for child in card_container.get_children():
		if child.has_method("set_selected"):
			child.set_selected(child.card_index == selected_index)

	_layout_cards()
	card_selected.emit(selected_index)

func get_selected_index() -> int:
	return selected_index

func clear_selection() -> void:
	selected_index = -1
	for child in card_container.get_children():
		if child.has_method("set_selected"):
			child.set_selected(false)
	_layout_cards()
