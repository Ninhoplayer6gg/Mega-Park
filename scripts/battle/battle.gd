extends Node2D
## Battle scene: builds the 1v1 from SceneRouter params, runs the round loop
## (player choice -> AI choice -> BattleResolver events -> animations) and applies rewards.

const EVENT_PAUSE := 0.25

@onready var background: Sprite2D = $Background
@onready var stage_root: Node2D = $Stage
@onready var effects: Node2D = $Effects
@onready var hud: BattleHud = $UI/BattleHud

var state: BattleState
var creature: CreatureInstance
var arena_stage: ArenaOpponentData
var player_view: BattleCreatureView
var enemy_view: BattleCreatureView
var _busy := false
## True once the result screen is up (battle over, rewards applied).
var result_shown := false
var _temp_creature := false


func _ready() -> void:
	var params := SceneRouter.take_params()
	creature = CreatureRoster.get_creature(params.get("creature_uid", ""))
	arena_stage = DataRegistry.arena.get(StringName(params.get("stage_id", "")))
	if arena_stage == null:
		arena_stage = ArenaManager.next_stage()
	if creature == null:
		# Opened directly (editor/test): use the first owned creature or a temporary one.
		var owned := CreatureRoster.all()
		if owned.is_empty():
			creature = CreatureInstance.create(DataRegistry.get_creature(&"rex_primordial"))
			_temp_creature = true
		else:
			creature = owned[0]
	state = BattleState.new(Combatant.from_instance(creature), Combatant.from_species(arena_stage.creature, arena_stage.level))
	state.enemy.name = arena_stage.creature.display_name
	player_view = BattleCreatureView.new()
	player_view.setup(creature.data, true)
	stage_root.add_child(player_view)
	enemy_view = BattleCreatureView.new()
	enemy_view.setup(arena_stage.creature, false)
	stage_root.add_child(enemy_view)
	hud.setup(self)
	hud.action_chosen.connect(_on_action)
	hud.forfeit_requested.connect(_on_forfeit)
	hud.continue_pressed.connect(_on_continue)
	get_viewport().size_changed.connect(_layout)
	_layout()
	hud.refresh(state, false)
	hud.set_actions_enabled(false)
	AudioManager.play_music(&"battle")
	_intro()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var tex := background.texture
	var s := ceilf(maxf(vp.x / tex.get_width(), vp.y / tex.get_height()))
	background.scale = Vector2(s, s)
	background.position = vp * 0.5
	var ground_y := vp.y * 0.5 + (240 - tex.get_height() * 0.5) * s
	player_view.home = Vector2(vp.x * 0.28, ground_y)
	enemy_view.home = Vector2(vp.x * 0.72, ground_y)
	if not _busy:
		player_view.position = player_view.home
		enemy_view.position = enemy_view.home


func _intro() -> void:
	_busy = true
	player_view.enter(-500)
	enemy_view.enter(500)
	await get_tree().create_timer(0.7).timeout
	hud.log_text("%s (Nv %d) desafia você!" % [arena_stage.title, arena_stage.level])
	AudioManager.play_sfx(arena_stage.creature.cry_sfx)
	var emblem: Texture2D = load("res://assets/ui/vs.png")
	var vs := UIKit.texture(emblem, emblem.get_size() * 4)
	vs.size = emblem.get_size() * 4
	vs.position = (get_viewport_rect().size - vs.size) * 0.5 + Vector2(0, -40)
	hud.add_child(vs)
	vs.pivot_offset = vs.size * 0.5
	vs.scale = Vector2(2.5, 2.5)
	var tw := vs.create_tween()
	tw.tween_property(vs, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(vs, "modulate:a", 0.0, 0.25)
	tw.tween_callback(vs.queue_free)
	await tw.finished
	hud.log_text("Escolha uma ação. Você ganha +%d de energia por rodada." % BattleRules.ENERGY_PER_ROUND)
	_busy = false
	hud.set_actions_enabled(true)


func view_of(c: Combatant) -> BattleCreatureView:
	return player_view if c == state.player else enemy_view


func _on_action(ability: AbilityData) -> void:
	if _busy or state.finished:
		return
	_busy = true
	hud.set_actions_enabled(false)
	var enemy_action := BattleAI.choose(state, state.enemy)
	var events := BattleResolver.resolve_round(state, ability, enemy_action)
	await _play_events(events)
	if state.finished:
		await _finish()
	else:
		_busy = false
		hud.set_actions_enabled(true)


func _play_events(events: Array) -> void:
	for e in events:
		match e.type:
			"action":
				var actor: Combatant = e.actor
				var ability: AbilityData = e.ability
				var view := view_of(actor)
				hud.log_text("%s usou %s!" % [actor.name, ability.display_name])
				if ability.is_damaging():
					AudioManager.play_sfx(&"whoosh", 0.1, -6.0)
					await view.attack(110.0 if ability.kind == AbilityData.Kind.ABILITY else 80.0)
				elif ability.kind == AbilityData.Kind.GUARD:
					AudioManager.play_sfx(ability.sfx)
					_float(view.top_point(), "DEFESA!", Color("92cdff"), 24, "defense")
					await view.cast(Color("92cdff"))
				elif ability.kind == AbilityData.Kind.RESERVE:
					AudioManager.play_sfx(ability.sfx)
					await view.cast(Color("ffd23f"))
				else:
					AudioManager.play_sfx(ability.sfx)
					await view.cast(actor.data.accent_color)
			"damage":
				var target: Combatant = e.target
				var tv := view_of(target)
				var ab: AbilityData = e.ability
				AudioManager.play_sfx(ab.sfx, 0.08)
				var heavy: bool = e.crit or ab.power >= 1.8
				tv.hurt(heavy)
				Fx.burst(effects, ab.vfx if Fx.SHEETS.has(ab.vfx) else &"hit", tv.center_point(), 4.0 if heavy else 3.0)
				var txt := "-%d" % e.amount
				if e.crit:
					txt = "CRÍTICO! -%d" % e.amount
				_float(tv.top_point(), txt, UITheme.GOLD if e.crit else Color.WHITE, 34 if heavy else 28)
				if heavy:
					_shake(8.0)
				hud.refresh(state)
				await get_tree().create_timer(EVENT_PAUSE + 0.15).timeout
			"energy":
				_float(view_of(e.actor).top_point(), "+%d energia" % e.amount, Color("ffd23f"), 22, "energy")
				hud.refresh(state)
				await get_tree().create_timer(EVENT_PAUSE).timeout
			"effect":
				var who: Combatant = e.target
				var good: bool = e.multiplier > 1.0
				AudioManager.play_sfx(&"buff" if good else &"debuff", 0.0, -4.0)
				_float(view_of(who).top_point() + Vector2(0, -30), e.label, UITheme.GOOD if good else UITheme.BAD, 22)
				Fx.sparkles(effects, view_of(who).center_point(), 6, 50, 2.0)
				hud.refresh(state)
				await get_tree().create_timer(EVENT_PAUSE).timeout
			"faint":
				hud.log_text("%s foi derrotado!" % e.target.name)
				await view_of(e.target).defeat()
			"round_end":
				hud.refresh(state)
		await get_tree().create_timer(0.05).timeout


func _float(world_pos: Vector2, text: String, color: Color, size := 26, icon_name := "") -> void:
	Fx.float_text(effects, world_pos, text, color, size, 50, 1.1, icon_name)


func _shake(amount: float) -> void:
	var tw := create_tween()
	for i in 5:
		tw.tween_property(stage_root, "position", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
	tw.tween_property(stage_root, "position", Vector2.ZERO, 0.04)


func _finish() -> void:
	var won := state.winner == state.player
	if won:
		player_view.celebrate()
		AudioManager.play_sfx(&"victory")
	else:
		AudioManager.play_sfx(&"defeat")
	await get_tree().create_timer(0.6).timeout
	var result := {}
	if _temp_creature:
		result = {"won": won, "credits": 0, "dna": 0, "creature_xp": 0, "player_xp": 0, "levels_gained": 0, "old_level": 1}
	else:
		result = ArenaManager.apply_result(creature.uid, arena_stage, won)
		SaveManager.save_game()
	hud.show_result(result, creature)
	result_shown = true


func _on_forfeit() -> void:
	if state.finished:
		return
	state.finished = true
	state.winner = state.enemy
	state.player.hp = 0
	hud.refresh(state)
	_busy = true
	hud.set_actions_enabled(false)
	await player_view.defeat()
	await _finish()


func _on_continue() -> void:
	SceneRouter.goto(SceneRouter.PARK, {"focus_creature": creature.uid})
