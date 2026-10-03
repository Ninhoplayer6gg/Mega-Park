class_name GamePanel
extends Control
## Base class for modal panels: dimmed backdrop, framed window with a title ribbon and close
## button, responsive size, open/close animation. Subclasses fill `body` in build().

signal closed

var hud: Hud
var title := "Painel"
var icon_name := "info"
## Preferred size; shrinks to fit small screens.
var desired_size := Vector2(900, 560)
var dismiss_on_backdrop := true
var body: VBoxContainer
var frame: PanelContainer
var _dim: ColorRect
var _closing := false


func _ready() -> void:
	configure()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.04, 0.06, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	frame = PanelContainer.new()
	add_child(frame)
	var outer := UIKit.vbox(10)
	frame.add_child(outer)
	var header := UIKit.hbox(10)
	header.add_child(UIKit.icon(icon_name, 36))
	var t := UIKit.label(title, "TitleLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	header.add_child(t)
	var close_btn := UIKit.button("", "close", "ButtonRed", Vector2(60, 56))
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	outer.add_child(header)
	body = UIKit.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_animate_open()


## Override to set title, icon_name and desired_size (runs before the frame is built).
func configure() -> void:
	pass


## Override to create the content of `body`.
func build() -> void:
	pass


## Override to rebuild dynamic content.
func refresh() -> void:
	pass


func _layout() -> void:
	var vp := get_viewport_rect().size
	var s := Vector2(minf(desired_size.x, vp.x - 32), minf(desired_size.y, vp.y - 24))
	frame.custom_minimum_size = s
	frame.size = s
	frame.position = (vp - s) * 0.5
	frame.pivot_offset = s * 0.5


func _animate_open() -> void:
	frame.scale = Vector2(0.88, 0.88)
	frame.modulate.a = 0.0
	_dim.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(frame, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(frame, "modulate:a", 1.0, 0.12)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.15)


func _on_dim_input(event: InputEvent) -> void:
	if not dismiss_on_backdrop:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if _closing:
		return
	_closing = true
	AudioManager.play_sfx(&"ui_close")
	var tw := create_tween().set_parallel()
	tw.tween_property(frame, "scale", Vector2(0.92, 0.92), 0.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func():
		closed.emit()
		queue_free())


## Helper: a two-column content area that stacks on narrow screens.
func columns(left_min := 260.0) -> Array:
	var vp := get_viewport_rect().size
	var box: BoxContainer = HBoxContainer.new() if vp.x >= 900 else VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := UIKit.vbox(8)
	left.custom_minimum_size.x = left_min
	var right := UIKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(left)
	box.add_child(right)
	return [box, left, right]
