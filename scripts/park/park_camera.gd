class_name ParkCamera
extends Camera2D
## Touch + mouse camera: one-finger/left-drag pans (with inertia), pinch/scroll zooms, a short
## press without movement is reported as a tap. WASD/arrows pan on PC.

signal tapped(world_pos: Vector2)
signal hovered(world_pos: Vector2)
signal cancel_requested

const MIN_ZOOM_CAP := 0.75
const MAX_ZOOM := 4.0
const DRAG_THRESHOLD := 14.0
const KEY_SPEED := 700.0

var map_size := Vector2(1024, 1024)
var velocity := Vector2.ZERO
var input_enabled := true
var _touches := {}
var _press_pos := Vector2.ZERO
var _moved := false
var _pinch_dist := 0.0
var _pinch_zoom := 1.0
var _mouse_down := false
var _focus_tween: Tween


func setup(size_px: Vector2, start_zoom := 2.0) -> void:
	map_size = size_px
	zoom = Vector2.ONE * start_zoom
	get_viewport().size_changed.connect(_clamp_all)
	_clamp_all()


func min_zoom() -> float:
	var vp := get_viewport_rect().size
	return clampf(maxf(vp.x / map_size.x, vp.y / map_size.y), MIN_ZOOM_CAP, MAX_ZOOM)


func _clamp_all() -> void:
	zoom = Vector2.ONE * clampf(zoom.x, min_zoom(), MAX_ZOOM)
	position = _clamped(position)


func _clamped(p: Vector2) -> Vector2:
	var half := get_viewport_rect().size / (2.0 * zoom.x)
	var out := p
	out.x = map_size.x * 0.5 if half.x * 2.0 >= map_size.x else clampf(p.x, half.x, map_size.x - half.x)
	out.y = map_size.y * 0.5 if half.y * 2.0 >= map_size.y else clampf(p.y, half.y, map_size.y - half.y)
	return out


func screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func zoom_at(screen_pos: Vector2, new_zoom: float) -> void:
	var before := screen_to_world(screen_pos)
	zoom = Vector2.ONE * clampf(new_zoom, min_zoom(), MAX_ZOOM)
	force_update_scroll()
	var after := get_canvas_transform().affine_inverse() * screen_pos
	position = _clamped(position + (before - after))


func focus_on(world_pos: Vector2, target_zoom := -1.0, duration := 0.45) -> void:
	if _focus_tween:
		_focus_tween.kill()
	velocity = Vector2.ZERO
	_focus_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var z := zoom.x if target_zoom <= 0.0 else clampf(target_zoom, min_zoom(), MAX_ZOOM)
	var old_zoom := zoom
	zoom = Vector2.ONE * z
	var dest := _clamped(world_pos)
	zoom = old_zoom
	_focus_tween.tween_property(self, "position", dest, duration)
	_focus_tween.tween_property(self, "zoom", Vector2.ONE * z, duration)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _mouse_down:
			_pan(event.relative, event.position, event.velocity)
		else:
			hovered.emit(screen_to_world(event.position))
	elif event is InputEventMagnifyGesture:
		zoom_at(event.position, zoom.x * event.factor)
	elif event is InputEventPanGesture:
		position = _clamped(position + event.delta * 12.0 / zoom.x)


func _handle_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_touches[e.index] = e.position
		if _touches.size() == 1:
			_press_pos = e.position
			_moved = false
			velocity = Vector2.ZERO
		elif _touches.size() == 2:
			_moved = true
			var pts: Array = _touches.values()
			_pinch_dist = maxf((pts[0] as Vector2).distance_to(pts[1]), 1.0)
			_pinch_zoom = zoom.x
	else:
		_touches.erase(e.index)
		if _touches.is_empty():
			if not _moved:
				tapped.emit(screen_to_world(e.position))
		elif _touches.size() == 1:
			velocity = Vector2.ZERO
	get_viewport().set_input_as_handled()


func _handle_drag(e: InputEventScreenDrag) -> void:
	_touches[e.index] = e.position
	if _touches.size() == 1:
		_pan(e.relative, e.position, e.velocity)
	elif _touches.size() >= 2:
		var pts: Array = _touches.values()
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[1]
		var dist := maxf(a.distance_to(b), 1.0)
		zoom_at((a + b) * 0.5, _pinch_zoom * dist / _pinch_dist)
	get_viewport().set_input_as_handled()


func _pan(relative: Vector2, pos: Vector2, vel: Vector2) -> void:
	if not _moved and pos.distance_to(_press_pos) > DRAG_THRESHOLD:
		_moved = true
	if _moved:
		position = _clamped(position - relative / zoom.x)
		velocity = -vel / zoom.x


func _handle_mouse_button(e: InputEventMouseButton) -> void:
	match e.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if e.pressed:
				zoom_at(e.position, zoom.x * 1.15)
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				zoom_at(e.position, zoom.x / 1.15)
		MOUSE_BUTTON_LEFT:
			if e.pressed:
				_mouse_down = true
				_press_pos = e.position
				_moved = false
				velocity = Vector2.ZERO
			else:
				_mouse_down = false
				if not _moved:
					tapped.emit(screen_to_world(e.position))
		MOUSE_BUTTON_RIGHT:
			if e.pressed:
				cancel_requested.emit()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var dir := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if dir != Vector2.ZERO:
		position = _clamped(position + dir * KEY_SPEED * delta / zoom.x)
	if _touches.is_empty() and not _mouse_down and velocity.length_squared() > 4.0:
		position = _clamped(position + velocity * delta)
		velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
