class_name BuildOverlay
extends Node2D
## Build-mode overlay: a subtle pixel grid plus pixel-art corner markers on the footprint
## (green = ok, yellow = cell free but rule not met, red = blocked).

const DOT := preload("res://assets/effects/grid_dot.png")
const CELL_OK := preload("res://assets/effects/cell_ok.png")
const CELL_WARN := preload("res://assets/effects/cell_warn.png")
const CELL_BAD := preload("res://assets/effects/cell_bad.png")

var controller: BuildController
var map_size := Vector2i.ONE


func _ready() -> void:
	z_index = 50
	visible = false


func _draw() -> void:
	if controller == null or controller.data == null:
		return
	var t := ParkGrid.TILE
	for y in map_size.y:
		for x in map_size.x:
			draw_texture(DOT, Vector2(x * t, y * t))
	var data := controller.data
	var overall_ok := controller.reason() == ""
	for y in data.size.y:
		for x in data.size.x:
			var c := controller.cell + Vector2i(x, y)
			var free := ParkState.is_cell_free(c)
			var tex: Texture2D = CELL_OK if free and overall_ok else (CELL_WARN if free else CELL_BAD)
			draw_texture(tex, Vector2(c) * t)
