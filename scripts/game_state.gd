extends Node
class_name GameState

enum Phase { PLAYING, PAUSED, LEVEL_COMPLETE, GAME_OVER }

signal stats_changed
signal phase_changed(phase: Phase)

const STARTING_MOVES := 30
const STARTING_TARGET := 1000
const TARGET_INCREASE_PER_LEVEL := 500

var score: int = 0
var moves_left: int = STARTING_MOVES
var target_score: int = STARTING_TARGET
var total_moves: int = 0
var level: int = 1
var phase: Phase = Phase.PLAYING


func can_play() -> bool:
	return phase == Phase.PLAYING and moves_left > 0


func register_move() -> bool:
	if not can_play():
		return false

	moves_left -= 1
	total_moves += 1
	stats_changed.emit()
	return true


func add_score(points: int) -> void:
	if points <= 0:
		return

	score += points
	stats_changed.emit()


func evaluate_end_conditions() -> void:
	if phase != Phase.PLAYING:
		return

	if score >= target_score:
		_set_phase(Phase.LEVEL_COMPLETE)
	elif moves_left <= 0:
		_set_phase(Phase.GAME_OVER)


func toggle_pause() -> void:
	if phase == Phase.PLAYING:
		_set_phase(Phase.PAUSED)
	elif phase == Phase.PAUSED:
		_set_phase(Phase.PLAYING)


func resume() -> void:
	if phase == Phase.PAUSED:
		_set_phase(Phase.PLAYING)


func restart() -> void:
	score = 0
	moves_left = STARTING_MOVES
	target_score = STARTING_TARGET
	total_moves = 0
	level = 1
	_set_phase(Phase.PLAYING)
	stats_changed.emit()


func start_next_level() -> void:
	if phase != Phase.LEVEL_COMPLETE:
		return

	level += 1
	target_score += TARGET_INCREASE_PER_LEVEL
	moves_left = STARTING_MOVES
	_set_phase(Phase.PLAYING)
	stats_changed.emit()


func _set_phase(next_phase: Phase) -> void:
	if phase == next_phase:
		return

	phase = next_phase
	phase_changed.emit(phase)