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


static func make(species: CreatureData, min_size := Vector2(160, 120), as_silhouette := false, animated := true) -> CreaturePortrait:
	var p := CreaturePortrait.new()
	p.data = species
	p.silhouette = as_silhouette
	p.custom_minimum_size = min_size
	p.set_meta("animated", animated)
	return p


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = TextureRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.flip_h = flip
	if silhouette:
		_rect.modulate = Color(0.05, 0.07, 0.12, 0.9)
	add_child(_rect)
	_show_frame()
	if get_meta("animated", true) and not silhouette:
		_timer = Timer.new()
		var spec: Array = data.anim_layout.get(anim, [0, 1, 4.0, true])
		_timer.wait_time = 1.0 / maxf(spec[2], 1.0)
		_timer.timeout.connect(_advance)
		add_child(_timer)
		_timer.start()
		visibility_changed.connect(func(): _timer.paused = not is_visible_in_tree())


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
