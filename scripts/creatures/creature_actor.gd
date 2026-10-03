class_name CreatureActor
extends Node2D
## A creature living in a habitat: wanders between random points, idles, rests and looks around.
## Movement only processes while walking, and off-screen creatures skip animation and move in
## coarse steps, so dozens of creatures stay cheap.

enum State { IDLE, WALK, REST }

const OFFSCREEN_STEP := 0.25

var creature: CreatureInstance
var data: CreatureData
var bounds := Rect2()
var state := State.IDLE
var target := Vector2.ZERO
var sprite: AnimatedSprite2D
var shadow: Sprite2D
var ring: Sprite2D
var _think: Timer
var _offscreen_timer: Timer
var _on_screen := true


func setup(c: CreatureInstance, area: Rect2) -> void:
	creature = c
	data = c.data
	bounds = area
	position = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))


func _ready() -> void:
	name = creature.uid
	var fw := float(data.frame_size.x)
	shadow = Sprite2D.new()
	shadow.texture = load("res://assets/effects/shadow.png")
	shadow.scale = Vector2(fw * 0.6 / 32.0, maxf(fw * 0.6 / 32.0 * 0.5, 1.0))
	shadow.position = Vector2(0, -2)
	add_child(shadow)
	ring = Sprite2D.new()
	ring.texture = load("res://assets/effects/select_ring.png")
	ring.scale = Vector2(fw * 0.7 / 48.0, fw * 0.7 / 48.0 * 0.6)
	ring.visible = false
	add_child(ring)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = DataRegistry.sprite_frames_for(data)
	sprite.centered = false
	sprite.offset = Vector2(-data.frame_size.x * 0.5, -data.foot_y - 1)
	add_child(sprite)
	sprite.play(&"idle")
	sprite.frame = randi() % 4
	sprite.flip_h = randf() < 0.5
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-fw * 0.5, -data.foot_y, fw, data.foot_y)
	notifier.screen_entered.connect(_on_screen_entered)
	notifier.screen_exited.connect(_on_screen_exited)
	add_child(notifier)
	_think = Timer.new()
	_think.one_shot = true
	_think.timeout.connect(_decide)
	add_child(_think)
	_offscreen_timer = Timer.new()
	_offscreen_timer.wait_time = OFFSCREEN_STEP
	_offscreen_timer.timeout.connect(func(): _step(OFFSCREEN_STEP))
	add_child(_offscreen_timer)
	set_physics_process(false)
	_think.start(randf_range(0.5, 2.5))


func _decide() -> void:
	var roll := randf()
	if roll < 0.6:
		_walk_to(Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y)))
	elif roll < 0.8:
		state = State.REST
		sprite.play(&"idle")
		sprite.speed_scale = 0.4
		_think.start(randf_range(3.0, 6.0))
	else:
		state = State.IDLE
		sprite.play(&"idle")
		sprite.speed_scale = 1.0
		sprite.flip_h = not sprite.flip_h
		_hop()
		_think.start(randf_range(1.5, 3.5))


func _walk_to(p: Vector2) -> void:
	target = p
	if position.distance_to(target) < 8.0:
		_think.start(1.0)
		return
	state = State.WALK
	sprite.speed_scale = 1.0
	sprite.play(&"walk")
	sprite.flip_h = target.x < position.x
	if _on_screen:
		set_physics_process(true)
	else:
		_offscreen_timer.start()


func _physics_process(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	if state != State.WALK:
		set_physics_process(false)
		_offscreen_timer.stop()
		return
	var to := target - position
	var dist := to.length()
	var move := data.walk_speed * delta
	if dist <= move:
		position = target
		state = State.IDLE
		sprite.play(&"idle")
		set_physics_process(false)
		_offscreen_timer.stop()
		_think.start(randf_range(1.0, 3.0))
	else:
		position += to / dist * move


func _on_screen_entered() -> void:
	_on_screen = true
	sprite.play()
	if state == State.WALK:
		_offscreen_timer.stop()
		set_physics_process(true)


func _on_screen_exited() -> void:
	_on_screen = false
	sprite.pause()
	if state == State.WALK:
		set_physics_process(false)
		_offscreen_timer.start()


func _hop() -> void:
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "position:y", -4.0, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:y", 0.0, 0.15).set_ease(Tween.EASE_IN)


func set_selected(value: bool) -> void:
	ring.visible = value
	if value:
		_hop()
		AudioManager.play_sfx(data.cry_sfx, 0.08, -6.0)


func celebrate() -> void:
	_hop()
	Fx.sparkles(get_parent(), position + Vector2(0, -data.foot_y * 0.5), 8, data.frame_size.x * 0.35)
	Fx.float_text(get_parent(), position + Vector2(0, -data.foot_y), "NÍVEL %d!" % creature.level, UITheme.GOOD, 14, 34, 1.4)


## Global-space rectangle used for tap picking.
func pick_rect() -> Rect2:
	var gp := global_position
	var w := data.frame_size.x * 0.7
	var h := data.foot_y * 0.85
	return Rect2(gp + Vector2(-w * 0.5, -h), Vector2(w, h))
