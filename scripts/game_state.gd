extends Node
class_name GameState

enum Phase { PLAYING, PAUSED, LEVEL_COMPLETE, GAME_OVER }
enum Event { TOGGLE_PAUSE, RESUME, TARGET_REACHED, NO_MOVES_REMAINING, RESTART, NEXT_LEVEL }

const TRANSITIONS := {
	Phase.PLAYING: {
		Event.TOGGLE_PAUSE: Phase.PAUSED,
		Event.TARGET_REACHED: Phase.LEVEL_COMPLETE,
		Event.NO_MOVES_REMAINING: Phase.GAME_OVER,
		Event.RESTART: Phase.PLAYING,
	},
	Phase.PAUSED: {
		Event.TOGGLE_PAUSE: Phase.PLAYING,
		Event.RESUME: Phase.PLAYING,
		Event.RESTART: Phase.PLAYING,
	},
	Phase.LEVEL_COMPLETE: {
		Event.RESTART: Phase.PLAYING,
		Event.NEXT_LEVEL: Phase.PLAYING,
	},
	Phase.GAME_OVER: {
		Event.RESTART: Phase.PLAYING,
	},
}

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
		_transition(Event.TARGET_REACHED)
	elif moves_left <= 0:
		_transition(Event.NO_MOVES_REMAINING)


func toggle_pause() -> void:
	_transition(Event.TOGGLE_PAUSE)


func resume() -> void:
	_transition(Event.RESUME)


func restart() -> void:
	score = 0
	moves_left = STARTING_MOVES
	target_score = STARTING_TARGET
	total_moves = 0
	level = 1
	_transition(Event.RESTART)
	stats_changed.emit()


func start_next_level() -> void:
	if phase != Phase.LEVEL_COMPLETE:
		return

	level += 1
	target_score += TARGET_INCREASE_PER_LEVEL
	moves_left = STARTING_MOVES
	_transition(Event.NEXT_LEVEL)
	stats_changed.emit()


func _transition(event: Event) -> bool:
	var phase_transitions: Dictionary = TRANSITIONS.get(phase, {})
	if not phase_transitions.has(event):
		return false

	var next_phase: Phase = phase_transitions[event]
	if phase == next_phase:
		return true

	phase = next_phase
	phase_changed.emit(phase)
	return true