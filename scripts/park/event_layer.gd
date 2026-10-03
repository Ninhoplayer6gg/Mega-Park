class_name EventLayer
extends Node2D
## Visual side of park events: "!" markers over the affected habitat/creature, rain during storms,
## a flickering power warning and a dimensional rift near the entrance. Rebuilt only when the
## event list changes; markers follow their target with a cheap timer.

const MARKER := preload("res://assets/effects/event_marker.png")
const PORTAL := preload("res://assets/effects/portal.png")
const RAIN := preload("res://assets/effects/rain.png")

var park: Node
var markers := {}           # event uid -> Sprite2D
var _rain_layer: CanvasLayer
var _portal: AnimatedSprite2D
var _follow: Timer


func setup(park_node: Node) -> void:
	park = park_node


func _ready() -> void:
	z_index = 60
	EventManager.events_changed.connect(rebuild)
	_follow = Timer.new()
	_follow.wait_time = 0.2
	_follow.autostart = true
	_follow.timeout.connect(_update_positions)
	add_child(_follow)
	rebuild()


func rebuild() -> void:
	for uid in markers.keys():
		if not EventManager.active.has(uid):
			markers[uid].queue_free()
			markers.erase(uid)
	var storm := false
	var portal := false
	for uid in EventManager.active:
		var ev := EventManager.data_of(uid)
		if ev == null:
			continue
		match ev.kind:
			&"storm":
				storm = true
			&"dimensional_anomaly":
				portal = true
		if not markers.has(uid):
			var m := Sprite2D.new()
			m.texture = MARKER
			m.scale = Vector2(2, 2)
			m.offset = Vector2(0, -12)
			add_child(m)
			var tw := m.create_tween().set_loops()
			tw.tween_property(m, "offset:y", -16.0, 0.4).set_trans(Tween.TRANS_SINE)
			tw.tween_property(m, "offset:y", -12.0, 0.4).set_trans(Tween.TRANS_SINE)
			markers[uid] = m
	_set_rain(storm)
	_set_portal(portal)
	_update_positions()


## World position for an event marker (habitat top, creature head or near the entrance).
func marker_position(uid: String) -> Vector2:
	var e: Dictionary = EventManager.active.get(uid, {})
	var ev := EventManager.data_of(uid)
	var target := str(e.get("target", ""))
	if ev and ev.kind in [&"stressed_creature", &"rare_behavior"]:
		var actor: CreatureActor = park.find_actor(target)
		if actor:
			return actor.global_position + Vector2(0, -actor.data.foot_y * actor.look_scale - 26)
	var b := ParkState.get_building(target)
	if b:
		var r := ParkGrid.footprint_rect(b.cell, b.data.size)
		return Vector2(r.get_center().x, r.position.y - 8)
	var entrance := ParkState.of_category(&"landmark")
	var base: Vector2 = entrance[0].center_world() if not entrance.is_empty() else Vector2.ZERO
	var i := EventManager.active.keys().find(uid)
	return base + Vector2(-60 + i * 120, -150)


func _update_positions() -> void:
	for uid in markers:
		markers[uid].position = marker_position(uid)
	if _portal:
		var entrance := ParkState.of_category(&"landmark")
		if not entrance.is_empty():
			_portal.position = entrance[0].center_world() + Vector2(150, -40)


## Event uid whose marker contains the world point, or "".
func marker_at(world_pos: Vector2) -> String:
	for uid in markers:
		var m: Sprite2D = markers[uid]
		if Rect2(m.position + Vector2(-22, -64), Vector2(44, 56)).has_point(world_pos):
			return uid
	if _portal and Rect2(_portal.position + Vector2(-64, -64), Vector2(128, 128)).has_point(world_pos):
		return EventManager.uid_of_kind(&"dimensional_anomaly")
	return ""


func _set_rain(on: bool) -> void:
	if on and _rain_layer == null:
		_rain_layer = CanvasLayer.new()
		_rain_layer.layer = 5
		var p := CPUParticles2D.new()
		p.texture = RAIN
		p.amount = 140
		p.lifetime = 1.1
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		var vp := get_viewport_rect().size
		p.position = Vector2(vp.x * 0.5, -20)
		p.emission_rect_extents = Vector2(vp.x * 0.7, 10)
		p.direction = Vector2(-0.25, 1)
		p.spread = 4.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 700.0
		p.initial_velocity_max = 900.0
		p.scale_amount_min = 2.0
		p.scale_amount_max = 2.0
		p.color = Color(0.75, 0.85, 1.0, 0.7)
		_rain_layer.add_child(p)
		var tint := ColorRect.new()
		tint.color = Color(0.1, 0.15, 0.3, 0.18)
		tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rain_layer.add_child(tint)
		add_child(_rain_layer)
	elif not on and _rain_layer:
		_rain_layer.queue_free()
		_rain_layer = null


func _set_portal(on: bool) -> void:
	if on and _portal == null:
		_portal = AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.set_animation_speed(&"default", 6.0)
		for i in 4:
			var at := AtlasTexture.new()
			at.atlas = PORTAL
			at.region = Rect2(i * 64, 0, 64, 64)
			sf.add_frame(&"default", at)
		_portal.sprite_frames = sf
		_portal.scale = Vector2(2, 2)
		_portal.play(&"default")
		add_child(_portal)
		_update_positions()
	elif not on and _portal:
		_portal.queue_free()
		_portal = null
