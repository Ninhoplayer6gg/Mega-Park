class_name BattleHud
extends Control
## Battle UI: HP cards, round counter, energy pips, the four action buttons (+ ability menu),
## combat log and the result screen.

signal action_chosen(ability: AbilityData)
signal forfeit_requested
signal continue_pressed

var battle: Node
var player_card: CombatantCard
var enemy_card: CombatantCard
var round_label: Label
var log_label: Label
var energy_label: Label
var energy_pips: HBoxContainer
var actions_row: HBoxContainer
var ability_menu: PanelContainer
var bottom: VBoxContainer
var _buttons := {}


func setup(battle_node: Node) -> void:
	battle = battle_node
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := UIKit.hbox(12)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	player_card = CombatantCard.new()
	top.add_child(player_card)
	var mid := UIKit.vbox(4)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_BEGIN
	round_label = UIKit.label("RODADA 1", "TitleLabel", null, HORIZONTAL_ALIGNMENT_CENTER)
	mid.add_child(round_label)
	var forfeit := UIKit.button("Desistir", "close", "ButtonDark", Vector2(150, 48))
	forfeit.add_theme_font_size_override("font_size", 16)
	forfeit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	forfeit.pressed.connect(func():
		if not forfeit.has_meta("armed"):
			forfeit.set_meta("armed", true)
			forfeit.text = "Confirmar?"
			return
		forfeit_requested.emit())
	mid.add_child(forfeit)
	top.add_child(mid)
	enemy_card = CombatantCard.new()
	enemy_card.mirrored = true
	top.add_child(enemy_card)

	bottom = UIKit.vbox(8)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_bottom = -10
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var log_panel := UIKit.panel("Pill")
	log_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	log_label = UIKit.label("", "BodyLabel", null, HORIZONTAL_ALIGNMENT_CENTER)
	log_label.custom_minimum_size.x = 520
	log_panel.add_child(log_label)
	bottom.add_child(log_panel)
	var energy_row := UIKit.hbox(8)
	energy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	energy_row.add_child(UIKit.icon("energy", 30))
	energy_pips = UIKit.hbox(4)
	for i in BattleRules.MAX_ENERGY:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(26, 20)
		pip.color = Color("26323e")
		energy_pips.add_child(pip)
	energy_row.add_child(energy_pips)
	energy_label = UIKit.label("0/10", "ValueLabel")
	energy_row.add_child(energy_label)
	bottom.add_child(energy_row)
	actions_row = UIKit.hbox(10)
	actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(actions_row)
	_add_action(&"attack", "ATAQUE", "attack", "ButtonRed", BattleRules.basic(AbilityData.Kind.ATTACK))
	_add_action(&"guard", "DEFESA", "defense", "ButtonBlue", BattleRules.basic(AbilityData.Kind.GUARD))
	_add_action(&"skill", "HABILIDADE", "skill", "ButtonPurple", null)
	_add_action(&"reserve", "RESERVAR", "reserve", "ButtonAmber", BattleRules.basic(AbilityData.Kind.RESERVE))
	ability_menu = PanelContainer.new()
	ability_menu.visible = false
	ability_menu.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ability_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ability_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ability_menu.offset_bottom = -150
	add_child(ability_menu)


func _add_action(key: StringName, text: String, icon_name: String, variation: String, ability: AbilityData) -> void:
	var b := UIKit.button("", "", variation, Vector2(200, 84))
	var v := UIKit.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_bottom = -6
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UIKit.hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(UIKit.icon(icon_name, 32))
	var l := UIKit.label(text, "ValueLabel")
	h.add_child(l)
	v.add_child(h)
	var cost := UIKit.label("", "SmallLabel", UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	cost.name = "Cost"
	if ability:
		cost.text = "Energia %d" % ability.energy_cost if ability.energy_cost > 0 else ("+%d energia" % ability.energy_gain if ability.energy_gain > 0 else "Grátis")
	else:
		cost.text = "Especiais"
	v.add_child(cost)
	b.add_child(v)
	if ability:
		b.pressed.connect(func(): _choose(ability))
	else:
		b.pressed.connect(_toggle_ability_menu)
	actions_row.add_child(b)
	_buttons[key] = [b, ability]


func _choose(ability: AbilityData) -> void:
	ability_menu.visible = false
	action_chosen.emit(ability)


func _toggle_ability_menu() -> void:
	if ability_menu.visible:
		ability_menu.visible = false
		return
	UIKit.clear(ability_menu)
	var v := UIKit.vbox(8)
	v.add_child(UIKit.label("Habilidades", "HeaderLabel"))
	var me: Combatant = battle.state.player
	for a in me.data.abilities:
		var cd := int(me.cooldowns.get(a.id, 0))
		var b := UIKit.button("", "", "ButtonPurple", Vector2(560, 76))
		var row := UIKit.hbox(10)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 14
		row.offset_right = -14
		row.offset_bottom = -8
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UIKit.icon(a.icon_name, 32))
		var info := UIKit.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_child(UIKit.label(a.display_name, "ValueLabel"))
		var d := UIKit.label(a.description, "SmallLabel", UITheme.TEXT)
		d.clip_text = true
		d.custom_minimum_size.x = 380
		info.add_child(d)
		row.add_child(info)
		var side := UIKit.vbox(0)
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		side.add_child(UIKit.icon_value("energy", str(a.energy_cost), "ValueLabel", 22))
		if cd > 0:
			side.add_child(UIKit.label("Recarga %d" % cd, "SmallLabel", UITheme.BAD))
		row.add_child(side)
		b.add_child(row)
		b.disabled = not me.can_use(a)
		b.pressed.connect(func(): _choose(a))
		v.add_child(b)
	ability_menu.add_child(v)
	ability_menu.visible = true


func set_actions_enabled(enabled: bool) -> void:
	actions_row.modulate.a = 1.0 if enabled else 0.55
	var me: Combatant = battle.state.player
	for key in _buttons:
		var b: Button = _buttons[key][0]
		var ab: AbilityData = _buttons[key][1]
		if not enabled:
			b.disabled = true
		elif ab:
			b.disabled = not me.can_use(ab)
		else:
			var any := false
			for a in me.data.abilities:
				any = any or me.can_use(a)
			b.disabled = not any
	if not enabled:
		ability_menu.visible = false


func refresh(state: BattleState, animate := true) -> void:
	player_card.update_from(state.player, animate)
	enemy_card.update_from(state.enemy, animate)
	round_label.text = "RODADA %d" % state.round_number
	var e := state.player.energy
	energy_label.text = "%d/%d" % [e, BattleRules.MAX_ENERGY]
	for i in energy_pips.get_child_count():
		var pip: ColorRect = energy_pips.get_child(i)
		pip.color = Color("ffd23f") if i < e else Color("26323e")


func log_text(text: String) -> void:
	log_label.text = text
	log_label.modulate.a = 0.0
	var tw := log_label.create_tween()
	tw.tween_property(log_label, "modulate:a", 1.0, 0.12)


func set_battle_controls_visible(v: bool) -> void:
	bottom.visible = v


## Result screen shown over the arena.
func show_result(result: Dictionary, creature: CreatureInstance) -> void:
	set_battle_controls_visible(false)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(minf(760, get_viewport_rect().size.x - 40), 0)
	add_child(panel)
	var v := UIKit.vbox(12)
	panel.add_child(v)
	var won: bool = result.won
	var banner := UIKit.label("VITÓRIA!" if won else "DERROTA", "BigLabel", UITheme.GOLD if won else UITheme.BAD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(banner)
	var h := UIKit.hbox(16)
	var pc := UIKit.panel("Inset")
	pc.add_child(CreaturePortrait.make(creature.data, Vector2(220, 150)))
	h.add_child(pc)
	var info := UIKit.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(creature.display_name(), "HeaderLabel"))
	var lvl_text := "Nível %d" % creature.level
	if result.levels_gained > 0:
		lvl_text = "Nível %d  >  %d  SUBIU!" % [result.old_level, creature.level]
	info.add_child(UIKit.label(lvl_text, "ValueLabel", UITheme.GOOD if result.levels_gained > 0 else UITheme.TEXT))
	var xp := UIKit.progress("BarXP", 16, 0.0, maxf(creature.xp_to_next(), 1))
	info.add_child(xp)
	info.add_child(UIKit.label("+%d XP para a criatura" % result.creature_xp, "SmallLabel", UITheme.CYAN))
	var rw := UIKit.hbox(14)
	rw.add_child(UIKit.icon_value("credits", "+%d" % result.credits, "ValueLabel"))
	if result.dna > 0:
		rw.add_child(UIKit.icon_value("dna", "+%d" % result.dna, "ValueLabel"))
	rw.add_child(UIKit.icon_value("star", "+%d XP parque" % result.player_xp, "ValueLabel"))
	info.add_child(rw)
	h.add_child(info)
	v.add_child(h)
	var cont := UIKit.button("Continuar", "check", "ButtonGreen", Vector2(300, 70))
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.pressed.connect(func(): continue_pressed.emit())
	v.add_child(cont)
	panel.pivot_offset = panel.get_combined_minimum_size() * 0.5
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.chain().tween_property(xp, "value", float(creature.xp), 0.8)
	banner.pivot_offset = banner.get_combined_minimum_size() * 0.5


class CombatantCard extends PanelContainer:
	var mirrored := false
	var _name: Label
	var _level: Label
	var _hp_bar: ProgressBar
	var _hp_label: Label
	var _effects: HBoxContainer
	var _shown_hp := -1.0

	func _ready() -> void:
		theme_type_variation = "Card"
		custom_minimum_size = Vector2(380, 0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := UIKit.vbox(4)
		var top := UIKit.hbox(8)
		_name = UIKit.label("", "HeaderLabel")
		_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_level = UIKit.label("", "ValueLabel", UITheme.GOLD)
		if mirrored:
			top.add_child(_level)
			top.add_child(_name)
			_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			top.add_child(_name)
			top.add_child(_level)
		v.add_child(top)
		var hp_row := UIKit.hbox(6)
		hp_row.add_child(UIKit.icon("health", 22))
		_hp_bar = UIKit.progress("BarHP", 20)
		_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hp_row.add_child(_hp_bar)
		v.add_child(hp_row)
		var bottom_row := UIKit.hbox(6)
		_hp_label = UIKit.label("", "BodyLabel")
		bottom_row.add_child(_hp_label)
		bottom_row.add_child(UIKit.spacer())
		_effects = UIKit.hbox(4)
		bottom_row.add_child(_effects)
		v.add_child(bottom_row)
		add_child(v)

	func update_from(c: Combatant, animate: bool) -> void:
		_name.text = c.name
		_level.text = "Nv %d" % c.level
		_hp_bar.max_value = c.max_hp
		if _shown_hp < 0 or not animate:
			_hp_bar.value = c.hp
		else:
			var tw := create_tween()
			tw.tween_property(_hp_bar, "value", float(c.hp), 0.4).set_ease(Tween.EASE_OUT)
		_shown_hp = c.hp
		var ratio := c.hp_ratio()
		_hp_bar.theme_type_variation = "BarHP" if ratio > 0.5 else ("BarEnergy" if ratio > 0.25 else "BarDanger")
		_hp_label.text = "%d / %d" % [c.hp, c.max_hp]
		UIKit.clear(_effects)
		for e in c.effects:
			_effects.add_child(UIKit.tag(e.label, UITheme.GOOD if e.multiplier > 1.0 else UITheme.BAD))
		if c.next_attack_mult > 1.0:
			_effects.add_child(UIKit.tag("Carregado", UITheme.CYAN))
		if c.guard_reduction > 0.0:
			_effects.add_child(UIKit.tag("Defendendo", Color("92cdff")))
