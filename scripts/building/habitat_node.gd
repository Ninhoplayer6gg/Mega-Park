class_name HabitatNode
extends BuildingNode
## Fenced habitat: own ground, fence ring, gate, feeder, decorations, wandering creatures and a
## floating coin bubble when there is production to collect.

const GATE_WIDTH := 2

var habitat_type: HabitatTypeData
var actors := {}             # creature uid -> CreatureActor
var bubble: Node2D
var _bubble_label: Label
var _ground: Node2D


func _build_visual() -> void:
	habitat_type = DataRegistry.get_habitat_type(data.habitat_type)
	var w := data.size.x
	var h := data.size.y
	var origin := Vector2(-w * ParkGrid.TILE * 0.5, -h * ParkGrid.TILE)
	_ground = HabitatGround.new()
	_ground.setup(habitat_type, data.size, origin)
	_ground.z_index = -5
	add_child(_ground)
	var gate_x0 := (w - GATE_WIDTH) / 2
	var ring := {}
	for x in w:
		ring[Vector2i(x, 0)] = true
		ring[Vector2i(x, h - 1)] = true
	for y in h:
		ring[Vector2i(0, y)] = true
		ring[Vector2i(w - 1, y)] = true
	for x in range(gate_x0, gate_x0 + GATE_WIDTH):
		ring.erase(Vector2i(x, h - 1))
	var dirs := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for c in ring:
		var mask := 0
		for i in 4:
			var n: Vector2i = c + dirs[i]
			var is_gate: bool = n.y == h - 1 and n.x >= gate_x0 and n.x < gate_x0 + GATE_WIDTH
			if ring.has(n) or is_gate:
				mask |= 1 << i
		var s := Sprite2D.new()
		s.texture = habitat_type.fence_texture
		s.hframes = 16
		s.frame = mask
		s.centered = false
		s.offset = Vector2(-16, -48)
		s.position = origin + Vector2(c.x * ParkGrid.TILE + 16, (c.y + 1) * ParkGrid.TILE)
		add_child(s)
	var gate := Sprite2D.new()
	gate.texture = habitat_type.gate_texture
	gate.centered = false
	gate.offset = Vector2(-gate.texture.get_width() * 0.5, -gate.texture.get_height())
	gate.position = origin + Vector2((gate_x0 + GATE_WIDTH * 0.5) * ParkGrid.TILE, h * ParkGrid.TILE)
	add_child(gate)
	_add_prop(habitat_type.feeder_texture, origin, Vector2i(1, 1))
	var decor_cells := [Vector2i(w - 2, 1), Vector2i(1, h - 3), Vector2i(w - 3, h - 3)]
	for i in decor_cells.size():
		if habitat_type.decor_textures.is_empty():
			break
		_add_prop(habitat_type.decor_textures[i % habitat_type.decor_textures.size()], origin, decor_cells[i])
	content = Node2D.new()
	content.name = "Content"
	content.y_sort_enabled = true
	add_child(content)
	if not preview:
		_build_bubble(origin)


func _add_prop(tex: Texture2D, origin: Vector2, c: Vector2i) -> void:
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	s.position = origin + Vector2(c.x * ParkGrid.TILE + 16, (c.y + 1) * ParkGrid.TILE - 2)
	add_child(s)


func _build_bubble(origin: Vector2) -> void:
	bubble = Node2D.new()
	bubble.z_index = 40
	bubble.position = Vector2(0, origin.y - 6)
	bubble.visible = false
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/effects/bubble.png")
	bg.scale = Vector2(2, 2)
	bg.position = Vector2(0, -26)
	bubble.add_child(bg)
	var coin := Sprite2D.new()
	coin.texture = DataRegistry.icon("credits")
	coin.scale = Vector2(2, 2)
	coin.position = Vector2(0, -30)
	bubble.add_child(coin)
	_bubble_label = Label.new()
	_bubble_label.add_theme_font_size_override("font_size", 12)
	_bubble_label.add_theme_color_override("font_outline_color", UITheme.OUTLINE)
	_bubble_label.add_theme_constant_override("outline_size", 4)
	_bubble_label.position = Vector2(-30, -10)
	_bubble_label.custom_minimum_size = Vector2(60, 0)
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_child(_bubble_label)
	add_child(bubble)
	var tw := bubble.create_tween().set_loops()
	tw.tween_property(bg, "position:y", -30.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(coin, "position:y", -34.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bg, "position:y", -26.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(coin, "position:y", -30.0, 0.6).set_trans(Tween.TRANS_SINE)


func _ready() -> void:
	super._ready()
	if not preview:
		sync_creatures()
		tick()


## Inner walkable area in local coordinates (inside the fence ring).
func wander_rect() -> Rect2:
	var w := data.size.x * ParkGrid.TILE
	var h := data.size.y * ParkGrid.TILE
	var origin := Vector2(-w * 0.5, -h)
	return Rect2(origin + Vector2(ParkGrid.TILE * 1.6, ParkGrid.TILE * 1.8),
		Vector2(w - ParkGrid.TILE * 3.2, h - ParkGrid.TILE * 2.8))


func sync_creatures() -> void:
	if preview or instance == null:
		return
	var wanted := {}
	for c in CreatureRoster.in_habitat(instance.uid):
		wanted[c.uid] = c
		if not actors.has(c.uid):
			var actor := CreatureActor.new()
			actor.setup(c, wander_rect())
			content.add_child(actor)
			actors[c.uid] = actor
	for uid in actors.keys():
		if not wanted.has(uid):
			actors[uid].queue_free()
			actors.erase(uid)


func tick() -> void:
	if bubble == null or instance == null:
		return
	var pending := CreatureRoster.habitat_pending(instance.uid)
	bubble.visible = pending > 0
	_bubble_label.text = "+%d" % pending


func bubble_rect() -> Rect2:
	if bubble == null or not bubble.visible:
		return Rect2()
	return Rect2(position + bubble.position + Vector2(-30, -60), Vector2(60, 64))


func pick_rect() -> Rect2:
	return footprint_rect()


## Inner class: draws the habitat ground once (no per-frame cost).
class HabitatGround extends Node2D:
	var ht: HabitatTypeData
	var size := Vector2i.ONE
	var origin := Vector2.ZERO

	func setup(t: HabitatTypeData, s: Vector2i, o: Vector2) -> void:
		ht = t
		size = s
		origin = o

	func _draw() -> void:
		if ht == null or ht.ground_texture == null:
			return
		var variants := maxi(ht.ground_variants, 1)
		for y in size.y:
			for x in size.x:
				var v := ((x * 7 + y * 13) ^ (x * y)) % variants
				draw_texture_rect_region(ht.ground_texture,
					Rect2(origin + Vector2(x, y) * ParkGrid.TILE, Vector2(ParkGrid.TILE, ParkGrid.TILE)),
					Rect2(Vector2(v * ParkGrid.TILE, 0), Vector2(ParkGrid.TILE, ParkGrid.TILE)))
