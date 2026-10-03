class_name CreatureActor
extends Node2D
## A creature living in a habitat. Behaviour is a small timer-driven state machine (no per-frame
## AI): walk, rest, sleep, eat, drink, roar, play, observe visitors, socialise or dispute territory
## with habitat mates. Personality, relations and habitat features weight the choices.
## Movement only processes while walking, and off-screen creatures skip animation and move in
## coarse steps, so dozens of creatures stay cheap.

enum State { IDLE, WALK, ACT }

const OFFSCREEN_STEP := 0.25
## Emote sprite per behaviour (sheet path, frame count).
const EMOTES := {
	&"sleep": ["res://assets/effects/zzz.png", 3],
	&"social": ["res://assets/effects/heart.png", 1],
	&"play": ["res://assets/effects/note.png", 1],
	&"dispute": ["res://assets/effects/anger.png", 1],
	&"stress": ["res://assets/effects/sweat.png", 1],
	&"rare": ["res://assets/effects/sparkle.png", 4],
}
const ROAR_COOLDOWN := 6.0

static var _emote_frames := {}
static var _last_roar_ms := -100000

var creature: CreatureInstance
var data: CreatureData
var habitat: Node2D            # HabitatNode (feeder/water/shelter points, habitat mates)
var bounds := Rect2()
var state := State.IDLE
## What the creature is doing right now (photos and the Arquivo read this).
var behavior: StringName = &"idle"
var target := Vector2.ZERO
var sprite: AnimatedSprite2D
var shadow: Sprite2D
var ring: Sprite2D
var emote: AnimatedSprite2D
var look_scale := 1.0
var look_key := ""
var _pending: StringName = &""
var _partner: CreatureActor
var _think: Timer
var _offscreen_timer: Timer
var _on_screen := true
var _act_tween: Tween
var _emote_tween: Tween


func setup(c: CreatureInstance, area: Rect2, home: Node2D = null) -> void:
	creature = c
	data = c.data
	bounds = area
	habitat = home
	look_key = look_key_of(c)
	position = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))


func _ready() -> void:
	name = creature.uid
	var mutation := creature.mutation()
	look_scale = CreatureLook.scale_for(mutation)
	var fw := float(data.frame_size.x) * look_scale
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
	sprite.sprite_frames = CreatureLook.frames_for(creature)
	sprite.centered = false
	sprite.offset = Vector2(-data.frame_size.x * 0.5, -data.foot_y - 1)
	sprite.scale = Vector2(look_scale, look_scale)
	if CreatureLook.has_palette(mutation):
		sprite.material = CreatureLook.material_for(mutation)
	add_child(sprite)
	sprite.play(&"idle")
	sprite.frame = randi() % 4
	sprite.flip_h = randf() < 0.5
	sprite.animation_finished.connect(func():
		if sprite.animation in [&"attack", &"ability", &"hurt"]:
			sprite.play(&"idle"))
	emote = AnimatedSprite2D.new()
	emote.position = Vector2(0, -data.foot_y * look_scale - 10)
	emote.scale = Vector2(2, 2)
	emote.z_index = 30
	emote.visible = false
	add_child(emote)
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-fw * 0.5, -data.foot_y * look_scale - 24, fw, data.foot_y * look_scale + 24)
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


static func look_key_of(c: CreatureInstance) -> String:
	return "%s:%s" % [c.species_id, c.mutation_id]


# ------------------------------------------------------------------ decisions
func _decide() -> void:
	_end_behavior()
	if creature.uid == EventManager.rare_behavior_target():
		_start(&"rare", 6.0)
		return
	var p := creature.personality()
	var stressed := EventManager.creature_stress(creature.uid) > 0.0
	var w := {
		&"walk": 3.0 * (p.wander if p else 1.0),
		&"rest": 1.0 * (p.rest if p else 1.0),
		&"sleep": 0.5 * (p.rest if p else 1.0),
		&"eat": 0.8,
		&"roar": 0.45 * (p.roar if p else 1.0),
		&"play": 0.5 * (p.play if p else 1.0),
		&"observe": 0.7 if VisitorManager.visitors > 0 else 0.15,
	}
	if habitat and habitat.has_method("water_point") and habitat.water_point() != Vector2.INF:
		w[&"drink"] = 0.7
	if stressed:
		w[&"rest"] += 1.5
		w[&"play"] = 0.05
	var mate := _pick_mate()
	if mate:
		var rel := SocialLogic.relation(creature, mate.creature)
		if rel.kind == &"friendly" or (rel.kind == &"neutral" and rel.score > 4):
			w[&"social"] = 0.9
		elif rel.kind in [&"territorial", &"predatory", &"incompatible"]:
			w[&"dispute"] = 0.6
	var choice := _weighted(w)
	match choice:
		&"walk":
			_walk_to(_random_point())
		&"rest", &"roar", &"play":
			_start(choice, {&"rest": randf_range(3.0, 6.0), &"roar": 1.8, &"play": 3.0}[choice])
		&"sleep":
			_go_then(&"sleep", habitat.rest_point() if habitat else _random_point())
		&"eat":
			_go_then(&"eat", habitat.feeder_point() if habitat else _random_point())
		&"drink":
			_go_then(&"drink", habitat.water_point())
		&"observe":
			_go_then(&"observe", habitat.front_point() if habitat else _random_point())
		&"social", &"dispute":
			_partner = mate
			var side := -1.0 if mate.position.x > position.x else 1.0
			_go_then(choice, mate.position + Vector2(side * data.frame_size.x * 0.45 * look_scale, 2))


func _weighted(w: Dictionary) -> StringName:
	var total := 0.0
	for k in w:
		total += w[k]
	var r := randf() * total
	for k in w:
		r -= w[k]
		if r <= 0.0:
			return k
	return &"walk"


func _pick_mate() -> CreatureActor:
	if habitat == null or not "actors" in habitat:
		return null
	var mates := []
	for a in habitat.actors.values():
		if a != self and is_instance_valid(a) and a.state != State.ACT:
			mates.append(a)
	return mates.pick_random() if not mates.is_empty() else null


func _random_point() -> Vector2:
	return Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))


func _clamp_point(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, bounds.position.x, bounds.end.x), clampf(p.y, bounds.position.y, bounds.end.y))


# ------------------------------------------------------------------ behaviours
func _go_then(kind: StringName, p: Vector2) -> void:
	_pending = kind
	_walk_to(p)


func _start(kind: StringName, duration: float, face_x := INF) -> void:
	state = State.ACT
	behavior = kind
	set_physics_process(false)
	_offscreen_timer.stop()
	sprite.speed_scale = 1.0
	if face_x != INF:
		sprite.flip_h = face_x < position.x
	match kind:
		&"rest":
			sprite.play(&"idle")
			sprite.speed_scale = 0.4
		&"sleep":
			sprite.play(&"sleep")
			duration = randf_range(7.0, 12.0)
		&"eat":
			sprite.play(&"eat")
			duration = randf_range(3.0, 5.0)
		&"drink":
			sprite.play(&"eat")
			sprite.speed_scale = 0.7
			duration = randf_range(2.5, 4.0)
		&"roar":
			sprite.play(&"ability")
			_roar_sound()
		&"play":
			sprite.play(&"walk")
			sprite.speed_scale = 1.6
			_act_tween = create_tween().set_loops(3)
			_act_tween.tween_property(sprite, "position:y", -8.0, 0.18).set_ease(Tween.EASE_OUT)
			_act_tween.tween_property(sprite, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
			_act_tween.tween_callback(func(): sprite.flip_h = not sprite.flip_h)
		&"observe":
			sprite.play(&"idle")
			duration = randf_range(3.0, 5.0)
		&"social":
			sprite.play(&"idle")
		&"dispute":
			sprite.play(&"attack")
			_act_tween = create_tween().set_loops(3)
			_act_tween.tween_interval(0.9)
			_act_tween.tween_callback(func(): sprite.play(&"attack"))
		&"rare":
			sprite.play(&"ability")
			_act_tween = create_tween().set_loops()
			_act_tween.tween_interval(0.9)
			_act_tween.tween_callback(func():
				sprite.play(&"ability")
				if _on_screen:
					Fx.sparkles(get_parent(), position + Vector2(0, -data.foot_y * 0.5), 3, data.frame_size.x * 0.3))
	var emote_kind := kind
	if EventManager.creature_stress(creature.uid) > 0.0 and kind in [&"rest", &"observe"]:
		emote_kind = &"stress"
	_show_emote(emote_kind)
	_think.start(duration)


## Called by a habitat mate that came over to socialise or dispute.
func engage(kind: StringName, other: CreatureActor, duration: float) -> void:
	if state == State.ACT:
		return
	_pending = &""
	_partner = other
	_start(kind, duration, other.position.x)


func _end_behavior() -> void:
	if _act_tween:
		_act_tween.kill()
		_act_tween = null
	sprite.position.y = 0.0
	sprite.speed_scale = 1.0
	_partner = null
	_show_emote(&"")
	behavior = &"idle"
	state = State.IDLE


func _arrived() -> void:
	var kind := _pending
	_pending = &""
	if kind == &"":
		state = State.IDLE
		behavior = &"idle"
		sprite.play(&"idle")
		_think.start(randf_range(1.0, 3.0))
		return
	if kind in [&"social", &"dispute"]:
		if not is_instance_valid(_partner) or _partner.state == State.ACT:
			_partner = null
			state = State.IDLE
			sprite.play(&"idle")
			_think.start(1.0)
			return
		var duration := randf_range(3.0, 5.0)
		_partner.engage(kind, self, duration)
		_start(kind, duration, _partner.position.x)
		return
	if kind == &"observe":
		_start(kind, 4.0)
		sprite.flip_h = position.x > bounds.get_center().x
		return
	_start(kind, 3.0)


func _roar_sound() -> void:
	if not _on_screen:
		return
	var now := Time.get_ticks_msec()
	if now - _last_roar_ms < ROAR_COOLDOWN * 1000.0:
		return
	_last_roar_ms = now
	AudioManager.play_sfx(data.cry_sfx, 0.1, -10.0)


func _show_emote(kind: StringName) -> void:
	if _emote_tween:
		_emote_tween.kill()
		_emote_tween = null
	if not EMOTES.has(kind):
		emote.visible = false
		return
	emote.sprite_frames = _emote_sheet(kind)
	emote.visible = true
	emote.position = Vector2(data.frame_size.x * 0.22 * look_scale * (-1.0 if sprite.flip_h else 1.0), -data.foot_y * look_scale - 10)
	emote.play(&"default")
	if not _on_screen:
		emote.pause()
	var base_y := emote.position.y
	_emote_tween = emote.create_tween().set_loops()
	_emote_tween.tween_property(emote, "position:y", base_y - 4.0, 0.5).set_trans(Tween.TRANS_SINE)
	_emote_tween.tween_property(emote, "position:y", base_y, 0.5).set_trans(Tween.TRANS_SINE)


static func _emote_sheet(kind: StringName) -> SpriteFrames:
	if _emote_frames.has(kind):
		return _emote_frames[kind]
	var spec: Array = EMOTES[kind]
	var tex: Texture2D = load(spec[0])
	var n: int = spec[1]
	var fw := tex.get_width() / n
	var sf := SpriteFrames.new()
	sf.set_animation_speed(&"default", 4.0)
	sf.set_animation_loop(&"default", true)
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, tex.get_height())
		sf.add_frame(&"default", at)
	_emote_frames[kind] = sf
	return sf


# ------------------------------------------------------------------ movement
func _walk_to(p: Vector2) -> void:
	target = _clamp_point(p)
	if position.distance_to(target) < 8.0:
		_arrived()
		return
	state = State.WALK
	behavior = &"walk"
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
		set_physics_process(false)
		_offscreen_timer.stop()
		_arrived()
	else:
		position += to / dist * move


func _on_screen_entered() -> void:
	_on_screen = true
	sprite.play()
	if emote.visible:
		emote.play()
	if state == State.WALK:
		_offscreen_timer.stop()
		set_physics_process(true)


func _on_screen_exited() -> void:
	_on_screen = false
	sprite.pause()
	emote.pause()
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
		if state != State.ACT:
			_hop()
		AudioManager.play_sfx(data.cry_sfx, 0.08, -6.0)
		# Watching a creature up close records what it is doing for the Arquivo Mega.
		if behavior != &"walk" and behavior != &"idle":
			ArchiveManager.note_behavior(data.id, behavior)


func behavior_name() -> String:
	return GameEnums.BEHAVIORS.get(behavior, "Parado")


func celebrate() -> void:
	_hop()
	Fx.sparkles(get_parent(), position + Vector2(0, -data.foot_y * 0.5), 8, data.frame_size.x * 0.35)
	Fx.float_text(get_parent(), position + Vector2(0, -data.foot_y), "NÍVEL %d!" % creature.level, UITheme.GOOD, 14, 34, 1.4)


## Global-space rectangle used for tap picking.
func pick_rect() -> Rect2:
	var gp := global_position
	var w := data.frame_size.x * 0.7 * look_scale
	var h := data.foot_y * 0.85 * look_scale
	return Rect2(gp + Vector2(-w * 0.5, -h), Vector2(w, h))
