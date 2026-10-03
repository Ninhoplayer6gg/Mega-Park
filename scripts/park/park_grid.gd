class_name ParkGrid
extends RefCounted
## Grid constants and conversions shared by the park systems.

const TILE := 32


static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) * 0.5


static func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


## World position used as origin for a building: bottom-centre of its footprint (good for Y-sort).
static func footprint_anchor(cell: Vector2i, size: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + size.x * TILE * 0.5, (cell.y + size.y) * TILE)


static func footprint_rect(cell: Vector2i, size: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * TILE, Vector2(size) * TILE)
