class_name LabNode
extends BuildingNode
## Science buildings (labs, Núcleo de Hibridização, Câmara Quimérica, Centro Paleontológico and the
## Centro de Pesquisa). While a synthesis, restoration or research project runs, a gene capsule
## floats over the roof with a progress bar; when it is finished the capsule glows and a bouncing
## arrow asks the player to collect it.

const CAPSULE := preload("res://assets/effects/gene_capsule.png")

var capsule: AnimatedSprite2D
var bar: IncubatorNode.IncubatorBar
var ready_icon: Sprite2D
var _bob: Tween
var _state := ""


func _build_visual() -> void:
	super._build_visual()
	if preview:
		return
	var top := -float(data.sprite.get_height()) if data.sprite else -64.0
	capsule = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_speed(&"default", 5.0)
	for i in 3:
		var at := AtlasTexture.new()
		at.atlas = CAPSULE
		at.region = Rect2(i * 32, 0, 32, 48)
		sf.add_frame(&"default", at)
	capsule.sprite_frames = sf
	capsule.position = Vector2(0, top - 8)
	capsule.z_index = 30
	capsule.visible = false
	add_child(capsule)
	bar = IncubatorNode.IncubatorBar.new()
	bar.position = Vector2(-26, 4)
	bar.z_index = 30
	bar.visible = false
	add_child(bar)
	ready_icon = Sprite2D.new()
	ready_icon.texture = load("res://assets/effects/arrow_down.png")
	ready_icon.scale = Vector2(2, 2)
	ready_icon.position = Vector2(0, top - 50)
	ready_icon.z_index = 40
	ready_icon.visible = false
	add_child(ready_icon)
	var tw := ready_icon.create_tween().set_loops()
	tw.tween_property(ready_icon, "position:y", top - 58, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ready_icon, "position:y", top - 50, 0.4).set_trans(Tween.TRANS_SINE)


func _ready() -> void:
	super._ready()
	tick()


func is_restoration_lab() -> bool:
	return data.panel_type == &"paleo"


func job_state() -> String:
	if instance == null:
		return "idle"
	if data.panel_type == &"research":
		if ResearchManager.active.is_empty():
			return "idle"
		return "ready" if ResearchManager.is_ready() else "running"
	if is_restoration_lab():
		if GeneticsManager.restoration(instance.uid).is_empty():
			return "idle"
		return "ready" if GeneticsManager.restoration_ready(instance.uid) else "running"
	if not GeneticsManager.jobs.has(instance.uid):
		return "idle"
	return "ready" if GeneticsManager.job_ready(instance.uid) else "running"


func job_progress() -> float:
	if instance == null:
		return 0.0
	if data.panel_type == &"research":
		return ResearchManager.progress()
	if is_restoration_lab():
		var r := GeneticsManager.restoration(instance.uid)
		if r.is_empty():
			return 0.0
		return clampf((GameClock.now() - float(r.start)) / maxf(float(r.duration), 0.01), 0.0, 1.0)
	return GeneticsManager.job_progress(instance.uid)


func tick() -> void:
	if preview or instance == null or capsule == null:
		return
	var state := job_state()
	capsule.visible = state != "idle"
	bar.visible = state == "running"
	bar.ratio = job_progress()
	bar.queue_redraw()
	ready_icon.visible = state == "ready"
	if state == _state:
		return
	_state = state
	if _bob:
		_bob.kill()
	capsule.modulate = Color.WHITE
	if state == "running":
		capsule.play(&"default")
		var y := capsule.position.y
		_bob = capsule.create_tween().set_loops()
		_bob.tween_property(capsule, "position:y", y - 4.0, 0.7).set_trans(Tween.TRANS_SINE)
		_bob.tween_property(capsule, "position:y", y, 0.7).set_trans(Tween.TRANS_SINE)
	elif state == "ready":
		capsule.play(&"default")
		_bob = capsule.create_tween().set_loops()
		_bob.tween_property(capsule, "modulate", Color(1.5, 1.5, 1.6), 0.35)
		_bob.tween_property(capsule, "modulate", Color.WHITE, 0.35)
