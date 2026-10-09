extends Control

const GAME_SCENE := preload("res://scenes/main.tscn")

@onready var start_button: Button = $MenuContent/StartButton
@onready var exit_button: Button = $MenuContent/ExitButton
@onready var menu_content: VBoxContainer = $MenuContent
@onready var title_label: Label = $MenuContent/MenuTitle
@onready var subtitle_label: Label = $MenuContent/MenuSubtitle
@onready var language_label: Label = $MenuContent/LanguageRow/LanguageLabel
@onready var language_option: OptionButton = $MenuContent/LanguageRow/LanguageOption


func _ready() -> void:
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()
	var active_locale := TranslationServer.get_locale()
	var locale := "ru" if active_locale.begins_with("ru") else "en"
	TranslationServer.set_locale(locale)
	language_option.add_item("English")
	language_option.add_item("Русский")
	language_option.select(1 if locale == "ru" else 0)
	language_option.item_selected.connect(_on_language_selected)
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_update_menu_text()
	start_button.grab_focus()


func _update_responsive_layout() -> void:
	var content_width := minf(380.0, maxf(1.0, size.x - 32.0))
	var content_height := minf(370.0, maxf(1.0, size.y - 24.0))
	menu_content.offset_left = -content_width / 2.0
	menu_content.offset_right = content_width / 2.0
	menu_content.offset_top = -content_height / 2.0
	menu_content.offset_bottom = content_height / 2.0

	var compact := size.x < 420.0 or size.y < 500.0
	title_label.add_theme_font_size_override("font_size", 32 if compact else 44)
	menu_content.add_theme_constant_override("separation", 10 if compact else 16)
	language_option.custom_minimum_size.y = 48
	start_button.custom_minimum_size.y = 52
	exit_button.custom_minimum_size.y = 52


func _on_start_pressed() -> void:
	get_tree().change_scene_to_packed(GAME_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_language_selected(index: int) -> void:
	TranslationServer.set_locale("ru" if index == 1 else "en")
	_update_menu_text()


func _update_menu_text() -> void:
	title_label.text = tr("GAME_TITLE")
	subtitle_label.text = tr("MENU_TAGLINE")
	start_button.text = tr("MENU_START")
	exit_button.text = tr("MENU_EXIT")
	language_label.text = tr("MENU_LANGUAGE")
