class_name BuildingNode
extends Node2D
## Visual for a placed building (or a ghost preview while in build mode). Origin is the
## bottom-centre of the footprint so Y-sorting works naturally.

var instance: BuildingInstance
var data: BuildingData
var cell := Vector2i.ZERO
var preview := false
var sprite: Sprite2D
var overlay: Sprite2D
var content: Node2D
var _anim_timer: Timer


func setup(building_data: BuildingData, building_instance: BuildingInstance, is_preview := false) -> void:
	data = building_data
	instance = building_instance
	preview = is_preview
	cell = instance.cell if instance else Vector2i.ZERO


func _ready() -> void:
	y_sort_enabled = true
	if data.ground_layer:
		z_index = -6
	position = ParkGrid.footprint_anchor(cell, data.size)
	_build_visual()
	refresh_connections()


func _build_visual() -> void:
	if data.sprite:
		sprite = Sprite2D.new()
		sprite.texture = data.sprite
		sprite.hframes = maxi(data.hframes, 1)
		sprite.centered = false
		var fw := data.sprite.get_width() / sprite.hframes
		sprite.offset = Vector2(-fw * 0.5, -data.sprite.get_height())
		add_child(sprite)
		if data.anim_fps > 0.0 and data.hframes > 1 and not data.connects:
			_anim_timer = Timer.new()
			_anim_timer.wait_time = 1.0 / data.anim_fps
			_anim_timer.autostart = true
			_anim_timer.timeout.connect(func(): sprite.frame = (sprite.frame + 1) % sprite.hframes)
			add_child(_anim_timer)
	content = Node2D.new()
	content.name = "Content"
	add_child(content)
	if data.overlay_texture:
		overlay = Sprite2D.new()
		overlay.texture = data.overlay_texture
		overlay.centered = false
		overlay.offset = Vector2(-data.overlay_texture.get_width() * 0.5, -data.overlay_texture.get_height())
		add_child(overlay)


func set_cell(new_cell: Vector2i) -> void:
	cell = new_cell
	position = ParkGrid.footprint_anchor(cell, data.size)
	refresh_connections()


func refresh_connections() -> void:
	if data.connects and sprite:
		sprite.frame = ParkState.connection_mask(cell, data.id)


func footprint_rect() -> Rect2:
	return ParkGrid.footprint_rect(cell, data.size)


## Area that reacts to taps (sprite bounds, at least the footprint).
func pick_rect() -> Rect2:
	var r := footprint_rect()
	if sprite and sprite.texture:
		var fw := sprite.texture.get_width() / sprite.hframes
		var h := sprite.texture.get_height()
		r = r.merge(Rect2(position + Vector2(-fw * 0.5, -h), Vector2(fw, h)))
	return r


func set_selected(value: bool) -> void:
	if value:
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1.4, 1.4, 1.2), 0.08)
		tw.tween_property(self, "modulate", Color.WHITE, 0.25)


func play_placed_effect() -> void:
	scale = Vector2(1.0, 0.6)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.08), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var r := footprint_rect()
	for i in clampi(data.size.x * data.size.y, 2, 10):
		Fx.burst(get_parent(), &"dust", Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y + r.size.y * 0.5, r.end.y)), 2.0)


## Called once per second by the park so dynamic buildings can refresh indicators cheaply.
func tick() -> void:
	pass
