class_name Fx
extends RefCounted
## Lightweight one-shot visual effects (sprite-sheet bursts and floating numbers).

const SHEETS := {
	&"sparkle": ["res://assets/effects/sparkle.png", Vector2i(16, 16), 4, 12.0],
	&"hit": ["res://assets/effects/hit.png", Vector2i(32, 32), 4, 16.0],
	&"zap": ["res://assets/effects/zap.png", Vector2i(32, 32), 4, 14.0],
	&"dust": ["res://assets/effects/dust.png", Vector2i(16, 16), 4, 10.0],
}

static var _frames := {}


static func frames_for(id: StringName) -> SpriteFrames:
	if _frames.has(id):
		return _frames[id]
	var spec: Array = SHEETS[id]
	var tex: Texture2D = load(spec[0])
	var sf := SpriteFrames.new()
	sf.set_animation_loop(&"default", false)
	sf.set_animation_speed(&"default", spec[3])
	for i in spec[2]:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(Vector2(i * spec[1].x, 0), Vector2(spec[1]))
		sf.add_frame(&"default", at)
	_frames[id] = sf
	return sf


static func burst(parent: Node, id: StringName, pos: Vector2, scale := 1.0, z := 20) -> AnimatedSprite2D:
	if not SHEETS.has(id) or parent == null:
		return null
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames_for(id)
	s.position = pos
	s.scale = Vector2(scale, scale)
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s)
	s.play(&"default")
	s.animation_finished.connect(s.queue_free)
	return s


## Several sparkles scattered around a point.
static func sparkles(parent: Node, pos: Vector2, count := 6, radius := 24.0, scale := 1.0) -> void:
	for i in count:
		var p := pos + Vector2(randf_range(-radius, radius), randf_range(-radius, radius * 0.6))
		var s := burst(parent, &"sparkle", p, scale)
		if s:
			s.speed_scale = randf_range(0.7, 1.3)


static func float_text(parent: Node, pos: Vector2, text: String, color := Color("ffd23f"), font_size := 16,
		rise := 28.0, duration := 1.0, icon_name := "") -> void:
	if parent == null:
		return
	var holder := Node2D.new()
	holder.position = pos
	holder.z_index = 60
	parent.add_child(holder)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	if icon_name != "":
		var ic := UIKit.icon(icon_name, font_size)
		box.add_child(ic)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", UITheme.OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(3, font_size / 4))
	box.add_child(l)
	holder.add_child(box)
	box.reset_size()
	box.position = -box.get_combined_minimum_size() * Vector2(0.5, 1.0)
	holder.scale = Vector2(0.6, 0.6)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "position:y", pos.y - rise, duration).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tw.tween_callback(holder.queue_free)
