extends Control
class_name Board

const ROWS := 8
const COLS := 8
const CANDY_TYPES := 6
const CANDY_SCENE := preload("res://scenes/candy.tscn")
const GAME_STATE_SCRIPT := preload("res://scripts/game_state.gd")

var CANDY_COLORS: Array = []
var SPECIAL_CANDY_COLORS: Dictionary = {}
var selected_candy: Candy = null
var is_animating: bool = false

@onready var game_state: Node = $GameState
@onready var grid: GridContainer = $GridContainer
@onready var score_label: Label = $ScoreLabel
@onready var moves_label: Label = $MovesLabel
@onready var target_label: Label = $TargetLabel
@onready var level_label: Label = $LevelLabel
@onready var pause_button: Button = $PauseButton
@onready var restart_button: Button = $RestartButton
@onready var screen_overlay: Control = $ScreenOverlay
@onready var overlay_title: Label = $ScreenOverlay/Panel/Content/OverlayTitle
@onready var resume_button: Button = $ScreenOverlay/Panel/Content/ResumeButton
@onready var next_level_button: Button = $ScreenOverlay/Panel/Content/NextLevelButton
@onready var overlay_restart_button: Button = $ScreenOverlay/Panel/Content/OverlayRestartButton
@onready var main_menu_button: Button = $ScreenOverlay/Panel/Content/MainMenuButton

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
	game_state.stats_changed.connect(_on_game_stats_changed)
	game_state.phase_changed.connect(_on_game_phase_changed)
	build_board()
	_update_static_ui_text()
	_on_game_stats_changed()
	pause_button.pressed.connect(toggle_pause)
	restart_button.pressed.connect(restart_game)
	resume_button.pressed.connect(resume_game)
	next_level_button.pressed.connect(start_next_level)
	overlay_restart_button.pressed.connect(restart_game)
	main_menu_button.pressed.connect(return_to_main_menu)


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

		if has_possible_move():
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


func has_possible_move() -> bool:
	for row in range(ROWS):
		for col in range(COLS):
			if col + 1 < COLS and swap_creates_match(row, col, row, col + 1):
				return true
			if row + 1 < ROWS and swap_creates_match(row, col, row + 1, col):
				return true
	return false


func swap_creates_match(first_row: int, first_col: int, second_row: int, second_col: int) -> bool:
	var first: Candy = candies[first_row][first_col]
	var second: Candy = candies[second_row][second_col]
	candies[first_row][first_col] = second
	candies[second_row][second_col] = first
	var creates_match := not find_matches().is_empty()
	candies[first_row][first_col] = first
	candies[second_row][second_col] = second
	return creates_match


func _on_candy_clicked(candy: Candy) -> void:
	if is_animating or not game_state.can_play():
		return

	if candy != null and candy.special_type != "none":
		activate_special_candy(candy)
		return

	if selected_candy == null:
		selected_candy = candy
		selected_candy.set_selected(true)
		return

	if selected_candy == candy:
		selected_candy.set_selected(false)
		selected_candy = null
		return

	if is_adjacent(selected_candy, candy):
		try_swap(selected_candy, candy)
		return

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

	is_animating = true
	swap_candies(first, second)

	if swap_creates_match_for(first, second):
		game_state.register_move()
		resolve_matches()
		return

	swap_candies(first, second)
	first.set_selected(false)
	second.set_selected(true)
	selected_candy = second
	is_animating = false
	if find_matches().is_empty() and not has_possible_move():
		shuffle_board_until_match_possible()


func resolve_matches() -> void:
	while true:
		var matches: Array = find_matches()
		if matches.is_empty():
			is_animating = false
			if selected_candy != null:
				selected_candy.set_selected(false)
			selected_candy = null
			game_state.evaluate_end_conditions()
			if game_state.can_play() and not has_possible_move():
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


func swap_creates_match_for(first: Candy, second: Candy) -> bool:
	for match_group in find_matches():
		if match_group.has(first) or match_group.has(second):
			return true
	return false


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
			match_type = "rainbow" if is_line_of_five(candy, matches) else "cross"
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
	is_animating = true
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

		if find_matches().is_empty() and has_possible_move():
			sync_grid_order()
			is_animating = false
			return


func activate_special_candy(candy: Candy) -> void:
	if candy == null or not game_state.register_move():
		return

	is_animating = true
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


func is_line_of_five(candy: Candy, matches: Array) -> bool:
	for match in matches:
		if match.size() >= 5 and match.has(candy):
			return true
	return false


func update_score_display() -> void:
	if score_label != null:
		score_label.text = tr("HUD_SCORE") % game_state.score


func update_move_display() -> void:
	if moves_label != null:
		moves_label.text = tr("HUD_MOVES") % game_state.moves_left


func update_target_display() -> void:
	if target_label != null:
		target_label.text = tr("HUD_TARGET") % game_state.target_score


func update_level_display() -> void:
	level_label.text = tr("HUD_LEVEL") % game_state.level


func _on_game_stats_changed() -> void:
	update_score_display()
	update_move_display()
	update_target_display()
	update_level_display()


func _update_static_ui_text() -> void:
	pause_button.text = tr("BUTTON_PAUSE")
	restart_button.text = tr("BUTTON_RESTART")
	resume_button.text = tr("BUTTON_RESUME")
	next_level_button.text = tr("BUTTON_NEXT_LEVEL")
	overlay_restart_button.text = tr("BUTTON_RESTART")
	main_menu_button.text = tr("BUTTON_MAIN_MENU")


func _on_game_phase_changed(phase: int) -> void:
	match phase:
		GAME_STATE_SCRIPT.Phase.PLAYING:
			screen_overlay.visible = false
		GAME_STATE_SCRIPT.Phase.PAUSED:
			show_overlay(tr("STATE_PAUSED"), true, false)
		GAME_STATE_SCRIPT.Phase.LEVEL_COMPLETE:
			show_overlay(tr("STATE_LEVEL_COMPLETE") % game_state.level, false, true)
		GAME_STATE_SCRIPT.Phase.GAME_OVER:
			show_overlay(tr("STATE_GAME_OVER"), false, false)


func show_overlay(title: String, can_resume: bool, can_advance: bool) -> void:
	overlay_title.text = title
	resume_button.visible = can_resume
	next_level_button.visible = can_advance
	overlay_restart_button.visible = true
	screen_overlay.visible = true


func toggle_pause() -> void:
	if is_animating:
		return
	game_state.toggle_pause()


func resume_game() -> void:
	game_state.resume()


func return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func restart_game() -> void:
	for row in candies:
		for candy in row:
			if candy != null and is_instance_valid(candy):
				grid.remove_child(candy)
				candy.queue_free()
	candies.clear()
	selected_candy = null
	is_animating = false
	game_state.restart()
	build_board()


func start_next_level() -> void:
	for row in candies:
		for candy in row:
			if candy != null and is_instance_valid(candy):
				grid.remove_child(candy)
				candy.queue_free()
	candies.clear()
	selected_candy = null
	game_state.start_next_level()
	build_board()


func find_matches() -> Array:
	var matches: Array = []

	for row in range(ROWS):
		var run: Array = []
		for col in range(COLS):
			var candy: Candy = candies[row][col]

			if candy == null:
				if run.size() >= 3:
					matches.append(run.duplicate())
				run.clear()
				continue

			if run.size() > 0 and run[-1].candy_type == candy.candy_type:
				run.append(candy)
			else:
				if run.size() >= 3:
					matches.append(run.duplicate())
				run = [candy]

		if run.size() >= 3:
			matches.append(run.duplicate())

	for col in range(COLS):
		var run: Array = []
		for row in range(ROWS):
			var candy: Candy = candies[row][col]

			if candy == null:
				if run.size() >= 3:
					matches.append(run.duplicate())
				run.clear()
				continue

			if run.size() > 0 and run[-1].candy_type == candy.candy_type:
				run.append(candy)
			else:
				if run.size() >= 3:
					matches.append(run.duplicate())
				run = [candy]

		if run.size() >= 3:
			matches.append(run.duplicate())

	return matches


func has_match_on_board() -> bool:
	return find_matches().size() > 0
