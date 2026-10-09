extends ColorRect
class_name Candy

signal clicked(candy: Candy)

var row: int = 0
var col: int = 0
var candy_type: int = 0
var is_selected: bool = false
var special_type: String = "none"
var base_color: Color = Color.WHITE
var special_colors: Dictionary = {}


func _ready() -> void:
    gui_input.connect(_on_gui_input)
    update_selection_visual()


func setup(
    p_row: int, p_col: int, p_type: int, color_value: Color, p_special_colors: Dictionary
) -> void:
    row = p_row
    col = p_col
    candy_type = p_type
    base_color = color_value
    special_colors = p_special_colors
    special_type = "none"
    color = base_color
    name = "Candy_%d_%d" % [row, col]
    custom_minimum_size = Vector2(48, 48)
    mouse_filter = Control.MOUSE_FILTER_PASS
    update_selection_visual()


func get_position_key() -> String:
    return "%d,%d" % [row, col]


func set_grid_position(p_row: int, p_col: int) -> void:
    row = p_row
    col = p_col
    name = "Candy_%d_%d" % [row, col]


func set_selected(selected: bool) -> void:
    is_selected = selected
    update_selection_visual()


func set_special_type(type_name: String) -> void:
    special_type = type_name
    update_selection_visual()


func update_selection_visual() -> void:
    if special_type == "none":
        color = base_color
    else:
        color = special_colors.get(special_type, base_color)

    if is_selected:
        modulate = Color(1.25, 1.25, 1.25, 1.0)
        scale = Vector2(1.12, 1.12)
        pivot_offset = size / 2.0
    else:
        modulate = Color(1, 1, 1, 1)
        scale = Vector2(1.0, 1.0)
        pivot_offset = Vector2.ZERO


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        clicked.emit(self)
