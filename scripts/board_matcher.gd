extends RefCounted
class_name BoardMatcher


func find_matches(candies: Array, rows: int, columns: int) -> Array:
	var matches: Array = []
	_append_axis_matches(candies, matches, rows, columns, true)
	_append_axis_matches(candies, matches, rows, columns, false)
	return matches


func has_possible_move(candies: Array, rows: int, columns: int) -> bool:
	for row in range(rows):
		for column in range(columns):
			if column + 1 < columns and swap_creates_match(candies, row, column, row, column + 1, rows, columns):
				return true
			if row + 1 < rows and swap_creates_match(candies, row, column, row + 1, column, rows, columns):
				return true
	return false


func swap_creates_match(
	candies: Array,
	first_row: int,
	first_column: int,
	second_row: int,
	second_column: int,
	rows: int,
	columns: int
) -> bool:
	var first: Candy = candies[first_row][first_column]
	var second: Candy = candies[second_row][second_column]
	candies[first_row][first_column] = second
	candies[second_row][second_column] = first
	var creates_match := not find_matches(candies, rows, columns).is_empty()
	candies[first_row][first_column] = first
	candies[second_row][second_column] = second
	return creates_match


func swap_creates_match_for(
	candies: Array, first: Candy, second: Candy, rows: int, columns: int
) -> bool:
	for match_group in find_matches(candies, rows, columns):
		if match_group.has(first) or match_group.has(second):
			return true
	return false


func is_line_of_five(candy: Candy, matches: Array) -> bool:
	for match_group in matches:
		if match_group.size() >= 5 and match_group.has(candy):
			return true
	return false


func _append_axis_matches(
	candies: Array, matches: Array, rows: int, columns: int, horizontal: bool
) -> void:
	var outer_count := rows if horizontal else columns
	var inner_count := columns if horizontal else rows

	for outer_index in range(outer_count):
		var run: Array = []
		for inner_index in range(inner_count):
			var row := outer_index if horizontal else inner_index
			var column := inner_index if horizontal else outer_index
			var candy: Candy = candies[row][column]

			if candy == null:
				if run.size() >= 3:
					matches.append(run.duplicate())
				run.clear()
				continue

			if run.is_empty() or run[-1].candy_type == candy.candy_type:
				run.append(candy)
			else:
				if run.size() >= 3:
					matches.append(run.duplicate())
				run = [candy]

		if run.size() >= 3:
			matches.append(run.duplicate())
