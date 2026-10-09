extends Control
class_name Candy

signal clicked(candy: Candy)

var row: int = 0
var col: int = 0
var candy_type: int = 0
var is_selected: bool = false
var special_type: String = "none"
var base_color: Color = Color.WHITE
var special_colors: Dictionary = {}
var selection_tween: Tween
@onready var visual: ColorRect = $Visual

const CLEAR_ANIMATION_DURATION := 0.15


func _ready() -> void:
    gui_input.connect(_on_gui_input)
    update_selection_visual()


func setup(
    p_row: int,
    p_col: int,
    p_type: int,
    color_value: Color,
    p_special_colors: Dictionary,
    p_cell_size: float = 48.0
) -> void:
    row = p_row
    col = p_col
    candy_type = p_type
    base_color = color_value
    special_colors = p_special_colors
    special_type = "none"
    is_selected = false
    name = "Candy_%d_%d" % [row, col]
    set_cell_size(p_cell_size)
    mouse_filter = Control.MOUSE_FILTER_PASS


func set_cell_size(cell_size: float) -> void:
    custom_minimum_size = Vector2(cell_size, cell_size)


func get_position_key() -> String:
    return "%d,%d" % [row, col]


func set_grid_position(p_row: int, p_col: int) -> void:
    row = p_row
    col = p_col
    name = "Candy_%d_%d" % [row, col]


func set_selected(selected: bool) -> void:
    if is_selected == selected:
        return

    is_selected = selected
    update_selection_visual()

    if selection_tween != null and selection_tween.is_running():
        selection_tween.kill()

    var target_scale := Vector2(1.12, 1.12) if selected else Vector2.ONE
    selection_tween = create_tween()
    selection_tween.set_trans(Tween.TRANS_CUBIC)
    selection_tween.set_ease(Tween.EASE_OUT)
    selection_tween.tween_property(visual, "scale", target_scale, 0.12)


func set_special_type(type_name: String) -> void:
    special_type = type_name
    update_selection_visual()


func add_clear_animation(tween: Tween) -> void:
    if selection_tween != null and selection_tween.is_running():
        selection_tween.kill()

    is_selected = false
    var fade_tweener := tween.tween_property(
        visual, "modulate:a", 0.0, CLEAR_ANIMATION_DURATION
    )
    fade_tweener.set_trans(Tween.TRANS_CUBIC)
    fade_tweener.set_ease(Tween.EASE_IN)
    var shrink_tweener := tween.tween_property(
        visual, "scale", Vector2(0.25, 0.25), CLEAR_ANIMATION_DURATION
    )
    shrink_tweener.set_trans(Tween.TRANS_CUBIC)
    shrink_tweener.set_ease(Tween.EASE_IN)


func add_grid_offset_tween(tween: Tween, offset: Vector2, duration: float) -> void:
    visual.position = offset
    var tweener := tween.tween_property(visual, "position", Vector2.ZERO, duration)
    tweener.set_trans(Tween.TRANS_CUBIC)
    tweener.set_ease(Tween.EASE_OUT)


func add_shuffle_rotation_tween(tween: Tween, duration: float, direction: float) -> void:
    visual.rotation = 0.0
    var tweener := tween.tween_property(visual, "rotation", direction * TAU, duration)
    tweener.set_trans(Tween.TRANS_CUBIC)
    tweener.set_ease(Tween.EASE_IN_OUT)


func add_spawn_animation(tween: Tween, duration: float) -> void:
    visual.position = Vector2(0, -visual.size.y)
    visual.modulate.a = 0.0
    visual.scale = Vector2(0.75, 0.75)

    var position_tweener := tween.tween_property(visual, "position", Vector2.ZERO, duration)
    position_tweener.set_trans(Tween.TRANS_CUBIC)
    position_tweener.set_ease(Tween.EASE_OUT)
    var alpha_tweener := tween.tween_property(visual, "modulate:a", 1.0, duration)
    alpha_tweener.set_trans(Tween.TRANS_CUBIC)
    alpha_tweener.set_ease(Tween.EASE_OUT)
    var scale_tweener := tween.tween_property(visual, "scale", Vector2.ONE, duration)
    scale_tweener.set_trans(Tween.TRANS_BACK)
    scale_tweener.set_ease(Tween.EASE_OUT)


func get_visual_color() -> Color:
    return visual.color


func add_visual_color_tween(tween: Tween, target_color: Color, duration: float) -> void:
    var color_tweener := tween.tween_property(visual, "color", target_color, duration)
    color_tweener.set_trans(Tween.TRANS_CUBIC)
    color_tweener.set_ease(Tween.EASE_IN_OUT)


func add_range_highlight_tween(tween: Tween, highlight_color: Color, duration: float) -> void:
    var target_color := visual.color.lerp(highlight_color, 0.7)
    add_visual_color_tween(tween, target_color, duration)


func update_selection_visual() -> void:
    visual.pivot_offset = visual.size / 2.0
    if special_type == "none":
        visual.color = base_color
    else:
        visual.color = special_colors.get(special_type, base_color)

    if is_selected:
        visual.modulate = Color(1.25, 1.25, 1.25, 1.0)
    else:
        visual.modulate = Color(1, 1, 1, 1)


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        clicked.emit(self)
