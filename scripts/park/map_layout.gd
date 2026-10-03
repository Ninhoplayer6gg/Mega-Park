class_name MapLayout
extends RefCounted
## Parses an ASCII park map (data/maps/*.txt). See tools/gen_map.py for the legend.

const DECOR := {
	"T": {"texture": "res://assets/environment/tree_round.png"},
	"P": {"texture": "res://assets/environment/tree_pine.png"},
	"C": {"texture": "res://assets/environment/cycad.png"},
	"b": {"texture": "res://assets/environment/bush.png"},
	"B": {"texture": "res://assets/environment/bush_berries.png"},
	"r": {"texture": "res://assets/environment/rock_small.png"},
	"R": {"texture": "res://assets/environment/rock_big.png"},
}

var width := 0
var height := 0
var terrain: Array[PackedStringArray] = []    # [y][x] -> "grass" | "flowers" | "dirt" | "sand" | "water"
var decor := {}                                # Vector2i -> char
var start_paths: Array[Vector2i] = []
var entrance_cell := Vector2i(-1, -1)


static func load_file(path: String) -> MapLayout:
	var layout := MapLayout.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MapLayout: cannot open %s" % path)
		return layout
	var lines := file.get_as_text().strip_edges().split("\n")
	layout.height = lines.size()
	for line in lines:
		layout.width = maxi(layout.width, line.strip_edges().length())
	for y in layout.height:
		var row := PackedStringArray()
		var line := lines[y].strip_edges()
		for x in layout.width:
			var ch := line[x] if x < line.length() else "."
			var t := "grass"
			match ch:
				",":
					t = "flowers"
				"d":
					t = "dirt"
				"s":
					t = "sand"
				"w":
					t = "water"
				"p":
					layout.start_paths.append(Vector2i(x, y))
				"E":
					layout.entrance_cell = Vector2i(x, y)
				_:
					if DECOR.has(ch):
						layout.decor[Vector2i(x, y)] = ch
			row.append(t)
		layout.terrain.append(row)
	return layout


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func terrain_at(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return ""
	return terrain[cell.y][cell.x]


func is_water(cell: Vector2i) -> bool:
	return terrain_at(cell) == "water"


func pixel_size() -> Vector2:
	return Vector2(width, height) * ParkGrid.TILE
