extends Control

signal go_to_title

@onready var title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var lang_label: Label = $MarginContainer/VBox/LangLabel
@onready var lang_button: Button = $MarginContainer/VBox/LangButton
@onready var bg_color_label: Label = $MarginContainer/VBox/BGColorLabel
@onready var color_grid: HBoxContainer = $MarginContainer/VBox/ColorGrid
@onready var back_button: Button = $MarginContainer/VBox/BackButton
@onready var bg_rect: ColorRect = $BG

var _color_buttons: Array[Button] = []

func _ready() -> void:
	lang_button.pressed.connect(_on_lang_pressed)
	back_button.pressed.connect(_on_back_pressed)
	Locale.language_changed.connect(_update_texts)
	Settings.bg_color_changed.connect(_on_bg_color_changed)

	_create_color_buttons()
	_update_texts()
	bg_rect.color = Settings.get_bg_color()

func _create_color_buttons() -> void:
	for i in range(Settings.BG_PRESETS.size()):
		var preset: Dictionary = Settings.BG_PRESETS[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var style := StyleBoxFlat.new()
		style.bg_color = preset.color
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.border_color = Color(0.4, 0.4, 0.4, 1)

		if i == Settings.bg_color_index:
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
		else:
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.text = ""
		btn.pressed.connect(_on_color_pressed.bind(i))
		color_grid.add_child(btn)
		_color_buttons.append(btn)

func _update_color_selection() -> void:
	for i in range(_color_buttons.size()):
		var style: StyleBoxFlat = _color_buttons[i].get_theme_stylebox("normal") as StyleBoxFlat
		if i == Settings.bg_color_index:
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color(0.2, 0.2, 0.3, 1)
		else:
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.4, 0.4, 0.4, 1)

func _update_texts() -> void:
	title_label.text = Locale.t("settings_title")
	lang_label.text = Locale.t("settings_language")
	bg_color_label.text = Locale.t("settings_bg_color")
	back_button.text = Locale.t("back")
	if Locale.get_language() == "ja":
		lang_button.text = "English"
	else:
		lang_button.text = "日本語"

func _on_lang_pressed() -> void:
	Locale.toggle_language()

func _on_color_pressed(idx: int) -> void:
	Settings.set_bg_color_index(idx)

func _on_bg_color_changed() -> void:
	bg_rect.color = Settings.get_bg_color()
	_update_color_selection()

func _on_back_pressed() -> void:
	go_to_title.emit()
