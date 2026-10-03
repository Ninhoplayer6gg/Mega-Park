class_name CreaturePortrait
extends Control
## Animated creature preview for UI (cycles the idle frames). Can render as a silhouette for
## undiscovered species.

var data: CreatureData
var silhouette := false
var flip := false
var anim := "idle"
var _frame := 0
var _timer: Timer
var _rect: TextureRect

const MYSTERY_BG := preload("res://assets/ui/mystery_bg.png")
const MYSTERY_ICON := preload("res://assets/ui/icons/mystery.png")


static func make(species: CreatureData, min_size := Vector2(160, 120), as_silhouette := false, animated := true) -> CreaturePortrait:
	var p := CreaturePortrait.new()
	p.data = species
	p.silhouette = as_silhouette
	p.custom_minimum_size = min_size
	p.set_meta("animated", animated)
	return p


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if silhouette:
		_build_mystery_backdrop()
	_rect = TextureRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.flip_h = flip
	if silhouette:
		_rect.modulate = Color(0.06, 0.05, 0.16, 1.0)
	add_child(_rect)
	if silhouette:
		var q := TextureRect.new()
		q.texture = MYSTERY_ICON
		q.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		q.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		q.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.anchor_left = 0.38
		q.anchor_right = 0.62
		q.anchor_top = 0.15
		q.anchor_bottom = 0.75
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(q)
		var tw := q.create_tween().set_loops()
		tw.tween_property(q, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(q, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	_show_frame()
	if get_meta("animated", true) and not silhouette:
		_timer = Timer.new()
		var spec: Array = data.anim_layout.get(anim, [0, 1, 4.0, true])
		_timer.wait_time = 1.0 / maxf(spec[2], 1.0)
		_timer.timeout.connect(_advance)
		add_child(_timer)
		_timer.start()
		visibility_changed.connect(func(): _timer.paused = not is_visible_in_tree())


## Undiscovered species: starfield/DNA backdrop + a cyan rim glow behind the dark silhouette.
func _build_mystery_backdrop() -> void:
	var bg := TextureRect.new()
	bg.texture = MYSTERY_BG
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.clip_contents = true
	add_child(bg)
	for off in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
		var rim := TextureRect.new()
		rim.name = "Rim"
		rim.set_anchors_preset(Control.PRESET_FULL_RECT)
		rim.offset_left = off.x
		rim.offset_right = off.x
		rim.offset_top = off.y
		rim.offset_bottom = off.y
		rim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rim.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rim.modulate = Color(0.37, 0.96, 1.0, 0.55)
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.flip_h = flip
		add_child(rim)


func play(anim_name: String) -> void:
	anim = anim_name
	_frame = 0
	_show_frame()


func _advance() -> void:
	var spec: Array = data.anim_layout.get(anim, [0, 1, 4.0, true])
	_frame += 1
	if _frame >= spec[1]:
		if spec[3]:
			_frame = 0
		else:
			anim = "idle"
			_frame = 0
	_show_frame()


func _show_frame() -> void:
	if data == null or _rect == null:
		return
	var spec: Array = data.anim_layout.get(anim, [0, 1, 4.0, true])
	_rect.texture = DataRegistry.frame_texture(data, spec[0], _frame % spec[1])
	if silhouette:
		for c in get_children():
			if c.name.begins_with("Rim"):
				c.texture = _rect.texture
