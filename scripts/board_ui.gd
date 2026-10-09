extends RefCounted
class_name BoardUI

signal pause_requested
signal restart_requested
signal resume_requested
signal next_level_requested
signal main_menu_requested

var board_root: Control
var game_state: Node
var in_game_menu: Node
var score_label: Label
var moves_label: Label
var target_label: Label
var level_label: Label
var pause_button: Button
var restart_button: Button


func setup(root: Control, state: Node) -> void:
	board_root = root
	game_state = state
	score_label = root.get_node("ScoreLabel")
	moves_label = root.get_node("MovesLabel")
	target_label = root.get_node("TargetLabel")
	level_label = root.get_node("LevelLabel")
	pause_button = root.get_node("PauseButton")
	restart_button = root.get_node("RestartButton")
	in_game_menu = root.get_node("InGameMenu")
	in_game_menu.setup(state)

	pause_button.pressed.connect(_on_pause_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	in_game_menu.resume_requested.connect(_on_resume_pressed)
	in_game_menu.restart_requested.connect(_on_restart_pressed)
	in_game_menu.next_level_requested.connect(_on_next_level_pressed)
	in_game_menu.main_menu_requested.connect(_on_main_menu_pressed)


func update_stats() -> void:
	score_label.text = board_root.tr("HUD_SCORE") % game_state.score
	moves_label.text = board_root.tr("HUD_MOVES") % game_state.moves_left
	target_label.text = board_root.tr("HUD_TARGET") % game_state.target_score
	level_label.text = board_root.tr("HUD_LEVEL") % game_state.level


func update_static_text() -> void:
	pause_button.text = board_root.tr("BUTTON_PAUSE")
	restart_button.text = board_root.tr("BUTTON_RESTART")


func _on_pause_pressed() -> void:
	pause_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_next_level_pressed() -> void:
	next_level_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
