class_name BuildController
extends Node
## Grid placement mode: shows a ghost of the building, colours the footprint green/red and
## places it on confirm. Paths and fences are placed directly on every tap for fast painting.

signal mode_changed(active: bool)
signal preview_changed(data: BuildingData, reason: String)

var park: Node
var data: BuildingData
var cell := Vector2i.ZERO
var ghost: BuildingNode
var overlay: BuildOverlay


func setup(park_node: Node, overlay_node: BuildOverlay) -> void:
	park = park_node
	overlay = overlay_node
	overlay.controller = self


func is_active() -> bool:
	return data != null


func start(building: BuildingData) -> void:
	stop()
	data = building
	ghost = BuildingFactory.create(data, null, true)
	ghost.modulate = Color(1, 1, 1, 0.75)
	park.objects.add_child(ghost)
	var center := ParkGrid.world_to_cell(park.camera.position) - data.size / 2
	_set_cell(_find_near_valid(center))
	overlay.visible = true
	overlay.queue_redraw()
	mode_changed.emit(true)


func stop() -> void:
	if ghost:
		ghost.queue_free()
		ghost = null
	var was_active := data != null
	data = null
	if overlay:
		overlay.visible = false
	if was_active:
		mode_changed.emit(false)


func reason() -> String:
	return ParkState.check_placement(data, cell) if data else ""


func handle_tap(world_pos: Vector2) -> void:
	move_to_world(world_pos)
	if data.connects:
		confirm()


func move_to_world(world_pos: Vector2) -> void:
	if data == null:
		return
	var c := ParkGrid.world_to_cell(world_pos)
	_set_cell(c - Vector2i((data.size.x - 1) / 2, (data.size.y - 1) / 2))


func _set_cell(c: Vector2i) -> void:
	cell = c
	ghost.set_cell(c)
	var r := reason()
	ghost.modulate = Color(0.75, 1.0, 0.75, 0.8) if r == "" else Color(1.0, 0.55, 0.55, 0.7)
	overlay.queue_redraw()
	preview_changed.emit(data, r)


## Starts the ghost on a valid cell near the camera when possible (nicer first impression).
func _find_near_valid(center: Vector2i) -> Vector2i:
	for radius in range(0, 10):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := center + Vector2i(dx, dy)
				if ParkState.check_placement(data, c, true) == "":
					return c
	return center


func confirm() -> BuildingInstance:
	if data == null:
		return null
	var r := reason()
	if r != "":
		EventBus.toast(r, "close", "bad")
		AudioManager.play_sfx(&"error")
		_shake_ghost()
		return null
	var placed_data := data
	var b := ParkState.place(placed_data, cell)
	if b == null:
		return null
	AudioManager.play_sfx(&"build", 0.05)
	var node: BuildingNode = park.get_building_node(b.uid)
	if node:
		node.play_placed_effect()
	if placed_data.cost_credits > 0:
		Fx.float_text(park.effects, b.center_world() + Vector2(0, -placed_data.size.y * 16),
			"-%s" % GameEnums.format_number(placed_data.cost_credits), UITheme.BAD, 14, 30, 1.0, "credits")
	if placed_data.connects:
		_set_cell(cell)
	else:
		stop()
	return b


func _shake_ghost() -> void:
	if ghost == null:
		return
	var base := ghost.position
	var tw := ghost.create_tween()
	for i in 3:
		tw.tween_property(ghost, "position", base + Vector2(4, 0), 0.04)
		tw.tween_property(ghost, "position", base - Vector2(4, 0), 0.04)
	tw.tween_property(ghost, "position", base, 0.04)
