class_name IncubatorNode
extends BuildingNode
## Incubator: shows the species egg inside the dome, a progress bar while incubating and a
## bouncing "ready" bubble when the creature can be collected.

var egg: Sprite2D
var bar: IncubatorBar
var ready_icon: Sprite2D
var _wobble: Tween
var _state := ""


func _build_visual() -> void:
	super._build_visual()
	egg = Sprite2D.new()
	egg.position = Vector2(0, -36)
	egg.visible = false
	content.add_child(egg)
	if preview:
		return
	bar = IncubatorBar.new()
	bar.position = Vector2(-26, 4)
	bar.z_index = 30
	bar.visible = false
	add_child(bar)
	ready_icon = Sprite2D.new()
	ready_icon.texture = load("res://assets/effects/arrow_down.png")
	ready_icon.scale = Vector2(2, 2)
	ready_icon.position = Vector2(0, -96)
	ready_icon.z_index = 40
	ready_icon.visible = false
	add_child(ready_icon)
	var tw := ready_icon.create_tween().set_loops()
	tw.tween_property(ready_icon, "position:y", -104.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ready_icon, "position:y", -96.0, 0.4).set_trans(Tween.TRANS_SINE)


func _ready() -> void:
	super._ready()
	tick()


func tick() -> void:
	if preview or instance == null:
		return
	var species := IncubationManager.species_in(instance.uid)
	var state := "idle"
	if species:
		state = "ready" if IncubationManager.is_ready(instance.uid) else "running"
		egg.texture = species.egg_texture
		egg.scale = Vector2(1.5, 1.5)
	egg.visible = species != null
	bar.visible = state == "running"
	bar.ratio = IncubationManager.progress(instance.uid)
	bar.queue_redraw()
	ready_icon.visible = state == "ready"
	if state != _state:
		_state = state
		if _wobble:
			_wobble.kill()
		egg.rotation = 0.0
		if state == "running":
			_wobble = egg.create_tween().set_loops()
			_wobble.tween_property(egg, "rotation", 0.12, 0.5).set_trans(Tween.TRANS_SINE)
			_wobble.tween_property(egg, "rotation", -0.12, 0.5).set_trans(Tween.TRANS_SINE)
		elif state == "ready":
			_wobble = egg.create_tween().set_loops()
			_wobble.tween_property(egg, "rotation", 0.25, 0.08)
			_wobble.tween_property(egg, "rotation", -0.25, 0.08)
			_wobble.tween_property(egg, "rotation", 0.0, 0.08)
			_wobble.tween_interval(0.8)


## Pixel-art progress bar (frame + cropped fill sprite), drawn at 2x.
class IncubatorBar extends Node2D:
	const BG := preload("res://assets/effects/minibar_bg.png")
	const FILL := preload("res://assets/effects/minibar_fill.png")
	var ratio := 0.0

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
		draw_texture(BG, Vector2.ZERO)
		var w := roundi(FILL.get_width() * clampf(ratio, 0.0, 1.0))
		if w > 0:
			draw_texture_rect_region(FILL, Rect2(1, 1, w, FILL.get_height()), Rect2(0, 0, w, FILL.get_height()))
