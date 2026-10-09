extends Control
class_name Board

const ROWS := 8
const COLS := 8
const CANDY_TYPES := 6
const SWAP_ANIMATION_DURATION := 0.16
const FALL_ANIMATION_DURATION := 0.2
const SPAWN_ANIMATION_DURATION := 0.16
const SHUFFLE_ANIMATION_DURATION := 0.8
const RANGE_HIGHLIGHT_DURATION := 0.12
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
var candy_size: float = 48.0
var selected_candy: Candy = null
var flow_state: FlowState = FlowState.IDLE
var board_matcher: RefCounted = BOARD_MATCHER_SCRIPT.new()
var board_ui: RefCounted = BOARD_UI_SCRIPT.new()

@onready var game_state: Node = get_node_or_null("GameState")
@onready var stats_grid: GridContainer = $Layout/StatsGrid
@onready var grid: GridContainer = $Layout/PlayArea/CenterContainer/GridContainer

var candies: Array = []


func _ready() -> void:
	if game_state == null:
		push_error("Board scene is missing its GameState child node.")
		return
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()
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


func _update_responsive_layout() -> void:
	if stats_grid == null:
		return

	var landscape := size.x > size.y
	stats_grid.columns = 4 if landscape else 2
	var stats_rows := 1 if landscape else 2
	var available_width := maxf(1.0, size.x - 16.0)
	var available_height := maxf(1.0, size.y - 16.0 - (stats_rows * 32.0) - 48.0 - 16.0)
	var grid_side := minf(available_width, available_height)
	candy_size = maxf(1.0, floor((grid_side - ((COLS - 1) * 2.0)) / COLS))

	for row in candies:
		for candy in row:
			if candy != null and is_instance_valid(candy):
				candy.set_cell_size(candy_size)


func build_board() -> void:
	grid.columns = COLS
	while true:
		candies.clear()
		for row in range(ROWS):
			var row_candies: Array = []
			for col in range(COLS):
				var candy: Candy = CANDY_SCENE.instantiate()
				var candy_type := get_random_starting_type(row, col, row_candies)
				candy.setup(
					row, col, candy_type, CANDY_COLORS[candy_type], SPECIAL_CANDY_COLORS, candy_size
				)
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
	await swap_candies(first, second)

	var matches: Array = board_matcher.find_matches(candies, ROWS, COLS)
	var creates_match_for_swap := false
	var preferred_special_candy: Candy = null
	for match_group in matches:
		if match_group.has(first) or match_group.has(second):
			creates_match_for_swap = true
			if match_group.size() >= 4 and preferred_special_candy == null:
				preferred_special_candy = first if match_group.has(first) else second

	if creates_match_for_swap and game_state.register_move():
		resolve_matches(preferred_special_candy)
		return

	await swap_candies(first, second)
	_transition_flow(FlowEvent.INVALID_SWAP)
	first.set_selected(false)
	second.set_selected(true)
	selected_candy = second
	if (
		board_matcher.find_matches(candies, ROWS, COLS).is_empty()
		and not board_matcher.has_possible_move(candies, ROWS, COLS)
	):
		shuffle_board_until_match_possible()


func resolve_matches(preferred_special_candy: Candy = null) -> void:
	if flow_state != FlowState.RESOLVING and not _transition_flow(FlowEvent.BEGIN_RESOLVE):
		return

	while true:
		var matches: Array = board_matcher.find_matches(candies, ROWS, COLS)
		if matches.is_empty():
			_transition_flow(FlowEvent.FINISH_RESOLVE)
			if selected_candy != null and is_instance_valid(selected_candy):
				selected_candy.set_selected(false)
			selected_candy = null
			game_state.evaluate_end_conditions()
			if game_state.can_play() and not board_matcher.has_possible_move(candies, ROWS, COLS):
				shuffle_board_until_match_possible()
			return

		var start_positions: Dictionary = await clear_matches(matches, preferred_special_candy)
		preferred_special_candy = null
		apply_gravity()
		var new_candies: Array = refill_board()
		await animate_candy_settle(start_positions, new_candies)


func swap_candies(first: Candy, second: Candy) -> void:
	var first_start_position := first.position
	var second_start_position := second.position
	var first_row := first.row
	var first_col := first.col
	var second_row := second.row
	var second_col := second.col

	candies[first_row][first_col] = second
	candies[second_row][second_col] = first

	first.set_grid_position(second_row, second_col)
	second.set_grid_position(first_row, first_col)
	sync_grid_order()
	await get_tree().process_frame

	var first_target_position := first.position
	var second_target_position := second.position

	var swap_tween := create_tween().set_parallel(true)
	first.add_grid_offset_tween(
		swap_tween, first_start_position - first_target_position, SWAP_ANIMATION_DURATION
	)
	second.add_grid_offset_tween(
		swap_tween, second_start_position - second_target_position, SWAP_ANIMATION_DURATION
	)
	await swap_tween.finished


func clear_matches(matches: Array, preferred_special_candy: Candy = null) -> Dictionary:
	var special_targets: Array = []
	for match in matches:
		if match.size() >= 4:
			var target: Candy = match[0]
			if preferred_special_candy != null and match.has(preferred_special_candy):
				target = preferred_special_candy
			if not special_targets.has(target):
				if target == preferred_special_candy:
					special_targets.push_front(target)
				else:
					special_targets.append(target)

	var to_remove: Array = []
	for match in matches:
		for candy in match:
			if candy != null and not special_targets.has(candy) and not to_remove.has(candy):
				to_remove.append(candy)

	var start_positions := _capture_candy_positions(to_remove)

	var total_cleared := to_remove.size() + special_targets.size()
	var match_bonus: int = 0
	for match in matches:
		match_bonus += max(0, match.size() - 2) * 5

	game_state.add_score((total_cleared * 10) + match_bonus)
	var clear_tween := create_tween().set_parallel(true)

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

		candy.add_clear_animation(clear_tween)

	for candy in special_targets:
		if candy == null:
			continue
		var match_type := "cross"
		if candy == special_targets[0]:
			match_type = "rainbow" if board_matcher.is_line_of_five(candy, matches) else "cross"
		candy.set_special_type(match_type)
		candies[candy.row][candy.col] = candy

	if not to_remove.is_empty():
		await clear_tween.finished

	for candy in to_remove:
		if is_instance_valid(candy):
			grid.remove_child(candy)
			candy.queue_free()
	return start_positions


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


func refill_board() -> Array:
	var new_candies: Array = []
	for row in range(ROWS):
		for col in range(COLS):
			if candies[row][col] == null:
				var candy: Candy = CANDY_SCENE.instantiate()
				var candy_type := randi() % CANDY_TYPES
				candy.setup(
					row, col, candy_type, CANDY_COLORS[candy_type], SPECIAL_CANDY_COLORS, candy_size
				)
				candy.clicked.connect(_on_candy_clicked)
				grid.add_child(candy)
				candies[row][col] = candy
				candy.set_selected(false)
				new_candies.append(candy)

	sync_grid_order()
	return new_candies


func _capture_candy_positions(excluded: Array = []) -> Dictionary:
	var positions: Dictionary = {}
	for row in candies:
		for candy in row:
			if candy != null and not excluded.has(candy):
				positions[candy] = candy.position
	return positions


func animate_candy_settle(
	start_positions: Dictionary,
	new_candies: Array,
	fall_duration: float = FALL_ANIMATION_DURATION
) -> void:
	await get_tree().process_frame
	var settle_tween := create_tween().set_parallel(true)
	var has_animations := false

	for candy in start_positions:
		if not is_instance_valid(candy):
			continue
		var target_position: Vector2 = candy.position
		var start_position: Vector2 = start_positions[candy]
		var offset := start_position - target_position
		if offset.is_zero_approx():
			continue
		candy.add_grid_offset_tween(settle_tween, offset, fall_duration)
		has_animations = true

	for candy in new_candies:
		if not is_instance_valid(candy):
			continue
		candy.add_spawn_animation(settle_tween, SPAWN_ANIMATION_DURATION)
		has_animations = true

	if has_animations:
		await settle_tween.finished


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
	await get_tree().process_frame
	var start_positions := _capture_candy_positions()

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
			await animate_candy_shuffle(start_positions)
			_transition_flow(FlowEvent.FINISH_SHUFFLE)
			return


func animate_candy_shuffle(start_positions: Dictionary) -> void:
	await get_tree().process_frame
	var shuffle_tween := create_tween().set_parallel(true)
	var has_animations := false

	for candy in start_positions:
		if not is_instance_valid(candy):
			continue
		var target_position: Vector2 = candy.position
		var start_position: Vector2 = start_positions[candy]
		var offset := start_position - target_position
		if not offset.is_zero_approx():
			candy.add_grid_offset_tween(shuffle_tween, offset, SHUFFLE_ANIMATION_DURATION)
		var rotation_direction := 1.0 if (candy.row + candy.col) % 2 == 0 else -1.0
		candy.add_shuffle_rotation_tween(
			shuffle_tween, SHUFFLE_ANIMATION_DURATION, rotation_direction
		)
		has_animations = true

	if has_animations:
		await shuffle_tween.finished


func activate_special_candy(candy: Candy) -> void:
	if candy == null or _is_flow_busy() or not game_state.can_play():
		return
	if not game_state.register_move():
		return

	if not _transition_flow(FlowEvent.BEGIN_RESOLVE):
		return
	if selected_candy != null and is_instance_valid(selected_candy):
		selected_candy.set_selected(false)
	selected_candy = null

	var start_positions := _capture_candy_positions()
	var affected_candies := get_special_candy_range(candy)
	await animate_special_range(affected_candies, SPECIAL_CANDY_COLORS[candy.special_type])

	if candy.special_type == "cross":
		clear_row_and_column(candy.row, candy.col)
	elif candy.special_type == "rainbow":
		clear_all_of_type(candy.candy_type)

	candies[candy.row][candy.col] = null
	grid.remove_child(candy)
	candy.queue_free()
	game_state.add_score(50)

	apply_gravity()
	var new_candies: Array = refill_board()
	await animate_candy_settle(start_positions, new_candies)
	resolve_matches()


func get_special_candy_range(candy: Candy) -> Array:
	var affected_candies: Array = []
	if candy.special_type == "cross":
		for col in range(COLS):
			var row_candy: Candy = candies[candy.row][col]
			if row_candy != null:
				affected_candies.append(row_candy)
		for row in range(ROWS):
			var column_candy: Candy = candies[row][candy.col]
			if column_candy != null and not affected_candies.has(column_candy):
				affected_candies.append(column_candy)
	elif candy.special_type == "rainbow":
		for row in range(ROWS):
			for col in range(COLS):
				var target: Candy = candies[row][col]
				if target != null and target.candy_type == candy.candy_type:
					affected_candies.append(target)
	return affected_candies


func animate_special_range(affected_candies: Array, highlight_color: Color) -> void:
	if affected_candies.is_empty():
		return

	var original_colors: Dictionary = {}
	var highlight_tween := create_tween().set_parallel(true)
	for target in affected_candies:
		if not is_instance_valid(target):
			continue
		original_colors[target] = target.get_visual_color()
		target.add_range_highlight_tween(
			highlight_tween, highlight_color, RANGE_HIGHLIGHT_DURATION
		)
	await highlight_tween.finished

	var restore_tween := create_tween().set_parallel(true)
	for target in original_colors:
		if is_instance_valid(target):
			target.add_visual_color_tween(
				restore_tween, original_colors[target], RANGE_HIGHLIGHT_DURATION
			)
	await restore_tween.finished


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
	await shuffle_board_until_match_possible()


func _transition_flow(event: FlowEvent) -> bool:
	var state_transitions: Dictionary = FLOW_TRANSITIONS.get(flow_state, {})
	if not state_transitions.has(event):
		return false

	flow_state = state_transitions[event]
	return true


func _is_flow_busy() -> bool:
	return flow_state in [FlowState.SWAPPING, FlowState.RESOLVING, FlowState.SHUFFLING]
