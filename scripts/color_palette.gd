extends RefCounted


func load_palette(csv_path: String) -> Dictionary:
    var ordered_colors: Array = []
    var named_colors: Dictionary = {}
    var file := FileAccess.open(csv_path, FileAccess.READ)

    if file == null:
        push_error("Could not open candy palette CSV at: %s" % csv_path)
        return {"ordered": ordered_colors, "named": named_colors}

    var is_header := true
    while not file.eof_reached():
        var line := file.get_line().strip_edges()
        if line == "":
            continue

        if is_header:
            is_header = false
            continue

        var values := line.split(";")
        if values.size() < 4:
            continue

        var color_name := values[0].strip_edges()
        var red := float(values[1].strip_edges()) / 255.0
        var green := float(values[2].strip_edges()) / 255.0
        var blue := float(values[3].strip_edges()) / 255.0

        var color := Color(red, green, blue, 1.0)
        ordered_colors.append(color)
        named_colors[color_name] = color

    file.close()
    return {"ordered": ordered_colors, "named": named_colors}
