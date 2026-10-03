class_name ParkMap
extends Node2D
## Renders the static terrain of a MapLayout with TileMapLayers (ground + autotiled water).

const TERRAIN_TEX := "res://assets/environment/terrain_tiles.png"
const WATER_TEX := "res://assets/environment/water_tiles.png"
const DIRT_TEX := "res://assets/environment/dirt_tiles.png"
const GRASS_PLAIN := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0)]
const GRASS_FLOWERS := [Vector2i(2, 0), Vector2i(4, 0)]

var ground: TileMapLayer
var water: TileMapLayer
var shore: TileMapLayer
var patches: TileMapLayer


func build(layout: MapLayout) -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(ParkGrid.TILE, ParkGrid.TILE)
	ts.add_source(_atlas(load(TERRAIN_TEX), Vector2i(8, 2)), 0)
	ts.add_source(_atlas(load(WATER_TEX), Vector2i(4, 5)), 1)
	ts.add_source(_atlas(load(DIRT_TEX), Vector2i(4, 4)), 2)
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	ground.z_index = -20
	add_child(ground)
	water = TileMapLayer.new()
	water.name = "Water"
	water.tile_set = ts
	water.z_index = -19
	add_child(water)
	patches = TileMapLayer.new()
	patches.name = "DirtPatches"
	patches.tile_set = ts
	patches.z_index = -19
	add_child(patches)
	shore = TileMapLayer.new()
	shore.name = "Shore"
	shore.tile_set = ts
	shore.z_index = -18
	add_child(shore)
	for y in layout.height:
		for x in layout.width:
			var cell := Vector2i(x, y)
			var h := _hash(cell)
			match layout.terrain_at(cell):
				"dirt":
					ground.set_cell(cell, 0, GRASS_PLAIN[h % GRASS_PLAIN.size()])
					var dm := _mask(layout, cell, "dirt")
					patches.set_cell(cell, 2, Vector2i(dm % 4, dm / 4))
				"sand":
					ground.set_cell(cell, 0, Vector2i(2, 1))
				"flowers":
					ground.set_cell(cell, 0, GRASS_FLOWERS[h % GRASS_FLOWERS.size()])
				_:
					ground.set_cell(cell, 0, GRASS_PLAIN[h % GRASS_PLAIN.size()])
			if layout.is_water(cell):
				var mask := 0
				var dirs := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
				for i in 4:
					var n: Vector2i = cell + dirs[i]
					if not layout.in_bounds(n) or layout.is_water(n):
						mask |= 1 << i
				water.set_cell(cell, 1, Vector2i(mask % 4, mask / 4))
				_inner_corner(layout, cell, mask)


func _mask(layout: MapLayout, cell: Vector2i, terrain: String) -> int:
	var mask := 0
	var dirs := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i in 4:
		if layout.terrain_at(cell + dirs[i]) == terrain:
			mask |= 1 << i
	return mask


## Concave corners (water on two sides, land on the diagonal) get a small rounded shore overlay.
func _inner_corner(layout: MapLayout, cell: Vector2i, mask: int) -> void:
	var corners := [[1, 2, Vector2i(1, -1)], [4, 2, Vector2i(1, 1)], [4, 8, Vector2i(-1, 1)], [1, 8, Vector2i(-1, -1)]]
	for i in corners.size():
		var c: Array = corners[i]
		if mask & c[0] and mask & c[1]:
			var diag: Vector2i = cell + c[2]
			if layout.in_bounds(diag) and not layout.is_water(diag):
				shore.set_cell(cell, 1, Vector2i(i, 4))
				return


func _atlas(tex: Texture2D, grid: Vector2i) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(ParkGrid.TILE, ParkGrid.TILE)
	for y in grid.y:
		for x in grid.x:
			src.create_tile(Vector2i(x, y))
	return src


static func _hash(cell: Vector2i) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663)) % 9973
