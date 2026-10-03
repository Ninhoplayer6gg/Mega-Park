class_name VisitorCrowd
extends Node2D
## Visitors strolling on the park paths. Purely visual: the count follows VisitorManager.visitors,
## each walker hops between neighbouring path cells with tweens (no per-frame processing).

const MAX_WALKERS := 14
const PER_WALKER := 4          # visitors represented by one walker
const STEP_TIME := 0.9

var _walkers: Array = []
var _path_cells: Array[Vector2i] = []
var _path_set := {}
var _frames := {}              # visitor type id -> SpriteFrames


func _ready() -> void:
	y_sort_enabled = true
	ParkState.buildings_changed.connect(_rebuild_paths)
	VisitorManager.visitors_changed.connect(_sync_count)
	_rebuild_paths()
	_sync_count()


func _rebuild_paths() -> void:
	_path_cells.clear()
	_path_set.clear()
	for b in ParkState.buildings.values():
		if b.data.connects and b.data.id == &"path":
			_path_cells.append(b.cell)
			_path_set[b.cell] = true
	for w in _walkers:
		if not _path_set.has(w.get_meta("cell", Vector2i(-1, -1))):
			_place(w, _random_cell())
	_sync_count()


func wanted_count() -> int:
	if _path_cells.size() < 4 or VisitorManager.visitors <= 0:
		return 0
	return clampi(ceili(VisitorManager.visitors / float(PER_WALKER)), 1, MAX_WALKERS)


func _sync_count() -> void:
	var want := wanted_count()
	while _walkers.size() > want:
		var w: AnimatedSprite2D = _walkers.pop_back()
		w.queue_free()
	while _walkers.size() < want:
		_walkers.append(_spawn())


func _spawn() -> AnimatedSprite2D:
	var vt := _pick_type()
	var w := AnimatedSprite2D.new()
	w.sprite_frames = _frames_for(vt)
	w.centered = false
	w.offset = Vector2(-8, -24)
	w.play(&"walk")
	w.frame = randi() % 4
	add_child(w)
	_place(w, _random_cell())
	_walk(w)
	return w


func _pick_type() -> VisitorTypeData:
	var types := DataRegistry.visitors.values()
	var total := 0.0
	for t in types:
		total += t.weight
	var r := randf() * total
	for t in types:
		r -= t.weight
		if r <= 0.0:
			return t
	return types[0]


func _frames_for(vt: VisitorTypeData) -> SpriteFrames:
	if _frames.has(vt.id):
		return _frames[vt.id]
	var sf := SpriteFrames.new()
	sf.add_animation(&"walk")
	sf.set_animation_speed(&"walk", 6.0)
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = vt.sprite
		at.region = Rect2(i * 16, 0, 16, 24)
		sf.add_frame(&"walk", at)
	_frames[vt.id] = sf
	return sf


func _random_cell() -> Vector2i:
	return _path_cells.pick_random() if not _path_cells.is_empty() else Vector2i.ZERO


func _cell_pos(cell: Vector2i) -> Vector2:
	var h := (cell.x * 31 + cell.y * 17) % 9 - 4
	return ParkGrid.cell_center(cell) + Vector2(h, 8)


func _place(w: AnimatedSprite2D, cell: Vector2i) -> void:
	w.set_meta("cell", cell)
	w.set_meta("prev", cell)
	w.position = _cell_pos(cell)


func _walk(w: AnimatedSprite2D) -> void:
	if not is_instance_valid(w) or _path_cells.is_empty():
		return
	var cell: Vector2i = w.get_meta("cell", _random_cell())
	var prev: Vector2i = w.get_meta("prev", cell)
	var options := []
	for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if _path_set.has(cell + d) and cell + d != prev:
			options.append(cell + d)
	if options.is_empty():
		options = [prev] if _path_set.has(prev) and prev != cell else [_random_cell()]
	var next: Vector2i = options.pick_random()
	w.set_meta("prev", cell)
	w.set_meta("cell", next)
	var to := _cell_pos(next)
	if absf(to.x - w.position.x) > 1.0:
		w.flip_h = to.x < w.position.x
	var tw := w.create_tween()
	tw.tween_property(w, "position", to, STEP_TIME * randf_range(0.9, 1.2))
	if randf() < 0.12:
		tw.tween_callback(func(): w.pause())
		tw.tween_interval(randf_range(1.0, 2.5))
		tw.tween_callback(func(): w.play(&"walk"))
	tw.tween_callback(_walk.bind(w))
