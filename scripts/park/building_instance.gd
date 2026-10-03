class_name BuildingInstance
extends RefCounted
## A building placed in the park (saved). Visuals are created by the park scene from this.

var uid := ""
var building_id: StringName
var cell := Vector2i.ZERO
var data: BuildingData
var placed_at := 0.0


func rect_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in data.size.y:
		for x in data.size.x:
			cells.append(cell + Vector2i(x, y))
	return cells


func center_world() -> Vector2:
	return ParkGrid.cell_to_world(cell) + Vector2(data.size) * ParkGrid.TILE * 0.5


func to_dict() -> Dictionary:
	return {"uid": uid, "id": String(building_id), "x": cell.x, "y": cell.y, "placed_at": placed_at}


static func from_dict(d: Dictionary) -> BuildingInstance:
	var data: BuildingData = DataRegistry.get_building(StringName(d.get("id", "")))
	if data == null:
		push_warning("Save references unknown building %s; skipped" % d.get("id"))
		return null
	var b := BuildingInstance.new()
	b.data = data
	b.building_id = data.id
	b.uid = str(d.get("uid", Uid.make("bd")))
	b.cell = Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))
	b.placed_at = float(d.get("placed_at", 0.0))
	return b
