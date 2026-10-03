class_name BuildOverlay
extends Node2D
## Grid + footprint validity overlay drawn only while building.

var controller: BuildController
var map_size := Vector2i.ONE


func _ready() -> void:
	z_index = 50
	visible = false


func _draw() -> void:
	if controller == null or controller.data == null:
		return
	var t := ParkGrid.TILE
	var grid_col := Color(1, 1, 1, 0.10)
	for x in map_size.x + 1:
		draw_line(Vector2(x * t, 0), Vector2(x * t, map_size.y * t), grid_col, 1.0)
	for y in map_size.y + 1:
		draw_line(Vector2(0, y * t), Vector2(map_size.x * t, y * t), grid_col, 1.0)
	var data := controller.data
	var overall_ok := controller.reason() == ""
	for y in data.size.y:
		for x in data.size.x:
			var c := controller.cell + Vector2i(x, y)
			var ok := ParkState.is_cell_free(c)
			var col := Color(0.35, 1.0, 0.45, 0.35) if ok and overall_ok else (Color(1.0, 0.85, 0.3, 0.35) if ok else Color(1.0, 0.25, 0.25, 0.45))
			var r := Rect2(Vector2(c) * t, Vector2(t, t)).grow(-1)
			draw_rect(r, col)
			draw_rect(r, Color(col, 0.9), false, 1.0)
