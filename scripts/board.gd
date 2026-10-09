extends Control
class_name Board

const ROWS := 8
const COLS := 8
const CANDY_TYPES := 6
const CANDY_SCENE := preload("res://scenes/candy.tscn")
const BOARD_MATCHER_SCRIPT := preload("res://scripts/board_matcher.gd")
const BOARD_UI_SCRIPT := preload("res://scripts/board_ui.gd")

enum FlowState { IDLE, CANDY_SELECTED, SWAPPING, RESOLVING, SHUFFLING }
enum FlowEvent { SELECT_CANDY, DESELECT_CANDY, BEGIN_SWAP, INVALID_SWAP, BEGIN_RESOLVE, FINISH_RESOLVE, BEGIN_SHUFFLE, FINISH_SHUFFLE, RESET }

const FLOW_TRANSITIONS := {
	FlowState.IDLE: {
		FlowEvent.SELECT_CANDY: FlowState.CANDY_SELECTED,
		FlowEvent.BEGIN_RESOLVE: FlowState.RESOLVING,
		FlowEvent.RESET: FlowState.IDLE,
	},
	FlowState.CANDY_SELECTED: {
		FlowEvent.SELECT_CANDY: FlowState.CANDY_SELECTED,
		FlowEvent.DESELECT_CANDY: FlowState.IDLE,
		FlowEvent.BEGIN_SWAP: FlowState.SWAPPING,
		FlowEvent.BEGIN_RESOLVE: FlowState.RESOLVING,
		FlowEvent.BEGIN_SHUFFLE: FlowState.SHUFFLING,
		FlowEvent.RESET: FlowState.IDLE,
	},
	FlowState.SWAPPING: {
		FlowEvent.INVALID_SWAP: FlowState.CANDY_SELECTED,
		FlowEvent.BEGIN_RESOLVE: FlowState.RESOLVING,
		FlowEvent.RESET: FlowState.IDLE,
	},
	FlowState.RESOLVING: {
		FlowEvent.FINISH_RESOLVE: FlowState.IDLE,
		FlowEvent.BEGIN_SHUFFLE: FlowState.SHUFFLING,
		FlowEvent.RESET: FlowState.IDLE,
	},
	FlowState.SHUFFLING: {
		FlowEvent.FINISH_SHUFFLE: FlowState.IDLE,
		FlowEvent.RESET: FlowState.IDLE,
	},
}

var CANDY_COLORS: Array = []
var SPECIAL_CANDY_COLORS: Dictionary = {}
var selected_candy: Candy = null
var flow_state: FlowState = FlowState.IDLE
var board_matcher: RefCounted = BOARD_MATCHER_SCRIPT.new()
var board_ui: RefCounted = BOARD_UI_SCRIPT.new()

@onready var game_state: Node = $GameState
@onready var grid: GridContainer = $GridContainer

var candies: Array = []


func _ready() -> void:
	var palette: RefCounted = load("res://scripts/color_palette.gd").new()
	var palette_data: Dictionary = palette.load_palette("res://data/candy_colors.csv")
	CANDY_COLORS = palette_data["ordered"]
	var named_colors: Dictionary = palette_data["named"]
	SPECIAL_CANDY_COLORS = {
		"cross": named_colors["cross"],
		"rainbow": named_colors["rainbow"],
	}
	board_ui.setup(self, game_state)
	board_ui.pause_requested.connect(toggle_pause)
	board_ui.restart_requested.connect(restart_game)
	board_ui.resume_requested.connect(resume_game)
	board_ui.next_level_requested.connect(start_next_level)
	board_ui.main_menu_requested.connect(return_to_main_menu)
	game_state.stats_changed.connect(board_ui.update_stats)
	build_board()
	board_ui.update_static_text()
	board_ui.update_stats()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()


func build_board() -> void:
	grid.columns = COLS
	while true:
		candies.clear()
		for row in range(ROWS):
			var row_candies: Array = []
			for col in range(COLS):
				var candy: Candy = CANDY_SCENE.instantiate()
				var candy_type := get_random_starting_type(row, col, row_candies)
				candy.setup(row, col, candy_type, CANDY_COLORS[candy_type], SPECIAL_CANDY_COLORS)
				candy.clicked.connect(_on_candy_clicked)
				grid.add_child(candy)
				row_candies.append(candy)
			candies.append(row_candies)

		if board_matcher.has_possible_move(candies, ROWS, COLS):
			return

		for row in candies:
			for candy in row:
				grid.remove_child(candy)
				candy.queue_free()


func get_random_starting_type(row: int, col: int, row_candies: Array) -> int:
	var candy_type := randi_range(0, CANDY_TYPES - 1)
	var makes_match := true
	while makes_match:
		var makes_horizontal_match: bool = (
			col >= 2
			and row_candies[col - 1].candy_type == candy_type
			and row_candies[col - 2].candy_type == candy_type
		)
		var makes_vertical_match: bool = (
			row >= 2
			and candies[row - 1][col].candy_type == candy_type
			and candies[row - 2][col].candy_type == candy_type
		)
		makes_match = makes_horizontal_match or makes_vertical_match
		if makes_match:
			candy_type = randi_range(0, CANDY_TYPES - 1)
	return candy_type


func _on_candy_clicked(candy: Candy) -> void:
	if _is_flow_busy() or not game_state.can_play():
		return

	if candy != null and candy.special_type != "none":
		activate_special_candy(candy)
		return

	if selected_candy == null:
		_transition_flow(FlowEvent.SELECT_CANDY)
		selected_candy = candy
		selected_candy.set_selected(true)
		return

	if selected_candy == candy:
		_transition_flow(FlowEvent.DESELECT_CANDY)
		selected_candy.set_selected(false)
		selected_candy = null
		return

	if is_adjacent(selected_candy, candy):
		try_swap(selected_candy, candy)
		return

	_transition_flow(FlowEvent.SELECT_CANDY)
	selected_candy.set_selected(false)
	selected_candy = candy
	selected_candy.set_selected(true)


func is_adjacent(first: Candy, second: Candy) -> bool:
	var row_delta: int = absi(first.row - second.row)
	var col_delta: int = absi(first.col - second.col)
	return (row_delta == 1 and col_delta == 0) or (row_delta == 0 and col_delta == 1)


func try_swap(first: Candy, second: Candy) -> void:
	if first == null or second == null or not is_adjacent(first, second):
		return

	if not game_state.can_play():
		return

	if not _transition_flow(FlowEvent.BEGIN_SWAP):
		return
	swap_candies(first, second)

	if (
		board_matcher.swap_creates_match_for(candies, first, second, ROWS, COLS)
		and game_state.register_move()
	):
		resolve_matches()
		return

	swap_candies(first, second)
	_transition_flow(FlowEvent.INVALID_SWAP)
	first.set_selected(false)
	second.set_selected(true)
	selected_candy = second
	if (
		board_matcher.find_matches(candies, ROWS, COLS).is_empty()
		and not board_matcher.has_possible_move(candies, ROWS, COLS)
	):
		shuffle_board_until_match_possible()


func resolve_matches() -> void:
	if flow_state != FlowState.RESOLVING and not _transition_flow(FlowEvent.BEGIN_RESOLVE):
		return

	while true:
		var matches: Array = board_matcher.find_matches(candies, ROWS, COLS)
		if matches.is_empty():
			_transition_flow(FlowEvent.FINISH_RESOLVE)
			if selected_candy != null:
				selected_candy.set_selected(false)
			selected_candy = null
			game_state.evaluate_end_conditions()
			if game_state.can_play() and not board_matcher.has_possible_move(candies, ROWS, COLS):
				shuffle_board_until_match_possible()
			return

		await clear_matches(matches)
		apply_gravity()
		refill_board()


func swap_candies(first: Candy, second: Candy) -> void:
	var first_row := first.row
	var first_col := first.col
	var second_row := second.row
	var second_col := second.col

	candies[first_row][first_col] = second
	candies[second_row][second_col] = first

	first.set_grid_position(second_row, second_col)
	second.set_grid_position(first_row, first_col)
	sync_grid_order()


func clear_matches(matches: Array) -> void:
	var special_targets: Array = []
	for match in matches:
		if match.size() >= 5:
			special_targets.append(match[0])
		elif match.size() == 4:
			special_targets.append(match[0])

	var to_remove: Array = []
	for match in matches:
		for candy in match:
			if candy != null and not special_targets.has(candy) and not to_remove.has(candy):
				to_remove.append(candy)

	var total_cleared := to_remove.size() + special_targets.size()
	var match_bonus: int = 0
	for match in matches:
		match_bonus += max(0, match.size() - 2) * 5

	game_state.add_score((total_cleared * 10) + match_bonus)
	var clear_tweens: Array = []

	for candy in special_targets:
		if candy == null:
			continue
		if match_bonus > 0:
			candy.set_special_type("rainbow" if candy == special_targets[0] else "cross")
		else:
			candy.set_special_type("cross")

	for candy in to_remove:
		var row_index: int = candy.row
		var col_index: int = candy.col
		candies[row_index][col_index] = null

		var tween := create_tween()
		tween.tween_property(candy, "modulate:a", 0.0, 0.15)
		clear_tweens.append(tween)

	for candy in special_targets:
		if candy == null:
			continue
		var match_type := "cross"
		if candy == special_targets[0]:
			match_type = "rainbow" if board_matcher.is_line_of_five(candy, matches) else "cross"
		candy.set_special_type(match_type)
		candies[candy.row][candy.col] = candy

	for tween in clear_tweens:
		await tween.finished

	for candy in to_remove:
		if is_instance_valid(candy):
			grid.remove_child(candy)
			candy.queue_free()


func apply_gravity() -> void:
	for col in range(COLS):
		var active: Array = []
		for row in range(ROWS - 1, -1, -1):
			var candy: Candy = candies[row][col]
			if candy != null:
				active.append(candy)

		for row in range(ROWS - 1, -1, -1):
			if active.size() > 0:
				var candy: Candy = active.pop_front()
				candies[row][col] = candy
				candy.set_grid_position(row, col)
			else:
				candies[row][col] = null


func refill_board() -> void:
	for row in range(ROWS):
		for col in range(COLS):
			if candies[row][col] == null:
				var candy: Candy = CANDY_SCENE.instantiate()
				var candy_type := randi() % CANDY_TYPES
				candy.setup(row, col, candy_type, CANDY_COLORS[candy_type], SPECIAL_CANDY_COLORS)
				candy.clicked.connect(_on_candy_clicked)
				grid.add_child(candy)
				candies[row][col] = candy
				candy.set_selected(false)

	sync_grid_order()


func sync_grid_order() -> void:
	for row in range(ROWS):
		for col in range(COLS):
			grid.move_child(candies[row][col], row * COLS + col)


func shuffle_board_until_match_possible() -> void:
	if not _transition_flow(FlowEvent.BEGIN_SHUFFLE):
		return
	if selected_candy != null:
		selected_candy.set_selected(false)
	selected_candy = null

	var shuffled_candies: Array = []
	for row in candies:
		shuffled_candies.append_array(row)

	while true:
		shuffled_candies.shuffle()
		var index := 0
		for row in range(ROWS):
			for col in range(COLS):
				var candy: Candy = shuffled_candies[index]
				candies[row][col] = candy
				candy.set_grid_position(row, col)
				index += 1

		if (
			board_matcher.find_matches(candies, ROWS, COLS).is_empty()
			and board_matcher.has_possible_move(candies, ROWS, COLS)
		):
			sync_grid_order()
			_transition_flow(FlowEvent.FINISH_SHUFFLE)
			return


func activate_special_candy(candy: Candy) -> void:
	if candy == null or _is_flow_busy() or not game_state.can_play():
		return
	if not game_state.register_move():
		return

	if not _transition_flow(FlowEvent.BEGIN_RESOLVE):
		return
	if candy.special_type == "cross":
		clear_row_and_column(candy.row, candy.col)
	elif candy.special_type == "rainbow":
		clear_all_of_type(candy.candy_type)

	if selected_candy == candy:
		selected_candy = null

	candies[candy.row][candy.col] = null
	candy.queue_free()
	game_state.add_score(50)

	apply_gravity()
	refill_board()
	resolve_matches()


func clear_row_and_column(row_index: int, col_index: int) -> void:
	for col in range(COLS):
		var candy: Candy = candies[row_index][col]
		if candy != null:
			candies[row_index][col] = null
			grid.remove_child(candy)
			candy.queue_free()

	for row in range(ROWS):
		var candy: Candy = candies[row][col_index]
		if candy != null:
			candies[row][col_index] = null
			grid.remove_child(candy)
			candy.queue_free()


func clear_all_of_type(candy_type_value: int) -> void:
	for row in range(ROWS):
		for col in range(COLS):
			var candy: Candy = candies[row][col]
			if candy != null and candy.candy_type == candy_type_value:
				candies[row][col] = null
				grid.remove_child(candy)
				candy.queue_free()


func toggle_pause() -> void:
	if _is_flow_busy():
		return
	game_state.toggle_pause()


func resume_game() -> void:
	game_state.resume()


func return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func restart_game() -> void:
	_transition_flow(FlowEvent.RESET)
	for row in candies:
		for candy in row:
			if candy != null and is_instance_valid(candy):
				grid.remove_child(candy)
				candy.queue_free()
	candies.clear()
	selected_candy = null
	game_state.restart()
	build_board()


func start_next_level() -> void:
	_transition_flow(FlowEvent.RESET)
	for row in candies:
		for candy in row:
			if candy != null and is_instance_valid(candy):
				grid.remove_child(candy)
				candy.queue_free()
	candies.clear()
	selected_candy = null
	game_state.start_next_level()
	build_board()


func _transition_flow(event: FlowEvent) -> bool:
	var state_transitions: Dictionary = FLOW_TRANSITIONS.get(flow_state, {})
	if not state_transitions.has(event):
		return false

	flow_state = state_transitions[event]
	return true


func _is_flow_busy() -> bool:
	return flow_state in [FlowState.SWAPPING, FlowState.RESOLVING, FlowState.SHUFFLING]
