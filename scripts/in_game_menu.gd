extends Control

signal resume_requested
signal restart_requested
signal next_level_requested
signal main_menu_requested

const GAME_STATE_SCRIPT := preload("res://scripts/game_state.gd")

@onready var overlay_title: Label = $Panel/Content/OverlayTitle
@onready var resume_button: Button = $Panel/Content/ResumeButton
@onready var next_level_button: Button = $Panel/Content/NextLevelButton
@onready var restart_button: Button = $Panel/Content/OverlayRestartButton
@onready var main_menu_button: Button = $Panel/Content/MainMenuButton
@onready var panel: PanelContainer = $Panel

var game_state: Node


func _ready() -> void:
	resized.connect(_update_panel_layout)
	for button in [resume_button, next_level_button, restart_button, main_menu_button]:
		button.custom_minimum_size.y = 48
	resume_button.pressed.connect(_on_resume_pressed)
	next_level_button.pressed.connect(_on_next_level_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	_update_static_text()
	_update_panel_layout()


func _update_panel_layout() -> void:
	var panel_width := minf(360.0, maxf(1.0, size.x - 24.0))
	var available_height := maxf(1.0, size.y - 24.0)
	var panel_height := minf(maxf(300.0, panel.get_combined_minimum_size().y), available_height)
	panel.offset_left = -panel_width / 2.0
	panel.offset_right = panel_width / 2.0
	panel.offset_top = -panel_height / 2.0
	panel.offset_bottom = panel_height / 2.0


func setup(state: Node) -> void:
	game_state = state
	game_state.phase_changed.connect(display_phase)
	display_phase(game_state.phase)


func display_phase(phase: int) -> void:
	match phase:
		GAME_STATE_SCRIPT.Phase.PLAYING:
			visible = false
		GAME_STATE_SCRIPT.Phase.PAUSED:
			show_menu(tr("STATE_PAUSED"), true, false)
		GAME_STATE_SCRIPT.Phase.LEVEL_COMPLETE:
			show_menu(tr("STATE_LEVEL_COMPLETE") % game_state.level, false, true)
		GAME_STATE_SCRIPT.Phase.GAME_OVER:
			show_menu(tr("STATE_GAME_OVER"), false, false)


func show_menu(title: String, can_resume: bool, can_advance: bool) -> void:
	overlay_title.text = title
	resume_button.visible = can_resume
	next_level_button.visible = can_advance
	restart_button.visible = true
	visible = true


func _update_static_text() -> void:
	resume_button.text = tr("BUTTON_RESUME")
	next_level_button.text = tr("BUTTON_NEXT_LEVEL")
	restart_button.text = tr("BUTTON_RESTART")
	main_menu_button.text = tr("BUTTON_MAIN_MENU")


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_next_level_pressed() -> void:
	next_level_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
