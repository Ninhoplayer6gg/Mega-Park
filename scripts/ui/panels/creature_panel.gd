extends GamePanel
## Details of an owned creature (or of a species when opened from the bestiary): stats, level,
## production, abilities and actions (feed, move, battle, info).

var creature: CreatureInstance
var species: CreatureData
var _portrait: CreaturePortrait
var _content: Control
var _show_info := false


func configure() -> void:
	if creature:
		species = creature.data
	title = creature.display_name() if creature else species.display_name
	icon_name = "creatures"
	desired_size = Vector2(1040, 620)


func build() -> void:
	_content = UIKit.vbox(10)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	refresh()
	if creature:
		CreatureRoster.creature_changed.connect(_on_changed)
		GameClock.tick.connect(_on_tick)


func _on_changed(c: CreatureInstance) -> void:
	if c == creature and is_inside_tree():
		refresh()


func _on_tick() -> void:
	if is_inside_tree() and visible and creature and creature.state == &"habitat":
		var l := find_child("PendingLabel", true, false)
		if l:
			l.text = "Acumulado: %d / %d" % [creature.pending_income(GameClock.now()), creature.income_cap()]


func refresh() -> void:
	UIKit.clear(_content)
	var cols := columns(300)
	_content.add_child(cols[0])
	_build_left(cols[1])
	var sc := UIKit.scroll()
	var right := UIKit.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(right)
	cols[2].add_child(sc)
	_build_right(right)
	if creature:
		_content.add_child(_build_actions())


func _level() -> int:
	return creature.level if creature else 1


func _build_left(left: VBoxContainer) -> void:
	var stage := UIKit.panel("Inset")
	stage.custom_minimum_size = Vector2(300, 200)
	_portrait = CreaturePortrait.of_creature(creature, Vector2(280, 190)) if creature else CreaturePortrait.make(species, Vector2(280, 190))
	stage.add_child(_portrait)
	left.add_child(stage)
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_theme_constant_override("v_separation", 6)
	tags.add_child(UIKit.rarity_badge(species.rarity))
	tags.add_child(UIKit.tag(species.category_name(), Color("7ee08f")))
	tags.add_child(UIKit.tag(GameEnums.role_name(species.role), Color("ffb43f")))
	if species.hybrid_tier > 0:
		tags.add_child(UIKit.tier_tag(species.hybrid_tier))
	if creature and creature.mutation():
		tags.add_child(UIKit.tag(creature.mutation().display_name.to_upper(), Color("b38cff")))
	left.add_child(tags)
	var types := UIKit.hbox(8)
	for t in (creature.types() if creature else species.types):
		types.add_child(UIKit.icon_value(GameEnums.type_icon(t), GameEnums.type_name(t), "SmallLabel", 18))
	left.add_child(types)
	if creature:
		var lvl := UIKit.hbox(8)
		lvl.add_child(UIKit.icon("star", 28))
		lvl.add_child(UIKit.label("Nível %d" % creature.level, "HeaderLabel"))
		lvl.add_child(UIKit.label("/ %d" % species.max_level, "SmallLabel"))
		left.add_child(lvl)
		var xp := UIKit.progress("BarXP", 16, creature.xp, maxf(creature.xp_to_next(), 1))
		left.add_child(xp)
		var xp_l := UIKit.label("MÁXIMO" if creature.is_max_level() else "XP %d / %d" % [creature.xp, creature.xp_to_next()], "SmallLabel")
		left.add_child(xp_l)
		var where := "No abrigo (sem habitat)"
		if creature.state == &"habitat":
			var b := ParkState.get_building(creature.habitat_uid)
			where = "Vive em: %s" % (b.data.display_name if b else "?")
		left.add_child(UIKit.label(where, "SmallLabel"))
		var actor: CreatureActor = hud.park.find_actor(creature.uid) if hud and hud.park else null
		if actor:
			left.add_child(UIKit.icon_value("happy", "Agora: %s" % actor.behavior_name(), "SmallLabel", 18))
	else:
		left.add_child(UIKit.label(species.species, "SmallLabel"))


func _build_right(right: VBoxContainer) -> void:
	var lvl := _level()
	right.add_child(UIKit.label("Atributos", "HeaderLabel"))
	var stats := [
		["health", "Vida", &"health", 1200.0, "BarHP"],
		["attack", "Ataque", &"attack", 160.0, "BarDanger"],
		["defense", "Defesa", &"defense", 120.0, "BarXP"],
		["speed", "Velocidade", &"speed", 180.0, "BarEnergy"],
	]
	for s in stats:
		var v: int = creature.stat(s[2]) if creature else species.stat_at_level(s[2], lvl)
		var text := str(v)
		if creature:
			var bonus := creature.stat_bonus(s[2])
			if absf(bonus) >= 0.005:
				text += " (%s%d%%)" % ["+" if bonus > 0 else "", int(round(bonus * 100))]
		right.add_child(UIKit.stat_row(s[0], s[1], text, clampf(v / s[3], 0.05, 1.0), s[4]))
	if creature:
		_build_genetics(right)
		if creature.state == &"habitat":
			_build_happiness(right)
	right.add_child(UIKit.label("Produção", "HeaderLabel"))
	var income := species.income_at_level(lvl)
	right.add_child(UIKit.stat_row("credits", "Renda", "+%d / %ds" % [income, int(species.income_interval)]))
	if creature and creature.state == &"habitat":
		right.add_child(UIKit.stat_row("happy", "Multiplicador", "x%s" % String.num(SocialLogic.production_multiplier(creature), 2)))
	right.add_child(UIKit.stat_row("time", "Capacidade", str(species.income_cap_at_level(lvl))))
	if creature and creature.state == &"habitat":
		var pending := UIKit.label("Acumulado: %d / %d" % [creature.pending_income(GameClock.now()), creature.income_cap()], "SmallLabel", UITheme.GOLD)
		pending.name = "PendingLabel"
		right.add_child(pending)
	right.add_child(UIKit.label("Habilidades", "HeaderLabel"))
	for a in (creature.abilities() if creature else species.abilities):
		var card := UIKit.panel("Card")
		var h := UIKit.hbox(10)
		h.add_child(UIKit.icon(a.icon_name, 32))
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := UIKit.hbox(8)
		top.add_child(UIKit.label(a.display_name, "ValueLabel"))
		top.add_child(UIKit.spacer())
		top.add_child(UIKit.icon_value("energy", str(a.energy_cost), "BodyLabel", 18))
		if a.cooldown > 0:
			top.add_child(UIKit.icon_value("time", "%dr" % a.cooldown, "BodyLabel", 18))
		v.add_child(top)
		v.add_child(UIKit.wrap_label(a.description, "SmallLabel", 300))
		h.add_child(v)
		card.add_child(h)
		right.add_child(card)
	if creature:
		_build_evolution(right)
	if _show_info or creature == null:
		right.add_child(UIKit.label("Ficha da espécie", "HeaderLabel"))
		right.add_child(UIKit.label(species.species, "BodyLabel", UITheme.CYAN))
		right.add_child(UIKit.wrap_label("Origem: " + species.origin, "SmallLabel", 300))
		right.add_child(UIKit.wrap_label(species.description, "BodyLabel", 300))
		var ht := DataRegistry.get_habitat_type(species.habitat_type)
		right.add_child(UIKit.wrap_label("Habitat: %s · Incubação: %s · DNA: %d" % [
			ht.display_name if ht else "?", GameEnums.format_time(species.incubation_time), species.dna_cost], "SmallLabel", 300))


func _build_genetics(right: VBoxContainer) -> void:
	right.add_child(UIKit.label("Genética", "HeaderLabel"))
	right.add_child(UIKit.stat_row("purity", "Pureza", "%d%%" % int(round(creature.genetic_purity)), creature.genetic_purity / 100.0, "BarXP"))
	right.add_child(UIKit.stat_row("stability", "Estabilidade", "%d%%" % int(round(creature.genetic_stability)), creature.genetic_stability / 100.0,
		"BarHP" if creature.genetic_stability >= 50 else "BarDanger"))
	var origin := {"incubated": "Incubação", "hybrid": "Síntese híbrida", "prototype": "Protótipo", "restored_pure": "Restauração pura",
		"restored_assisted": "Reconstrução assistida", "boss_reward": "Chefe da Arena"}
	right.add_child(UIKit.label("Geração %d · Origem: %s" % [creature.generation(), origin.get(creature.origin(), creature.origin())], "SmallLabel"))
	var p := creature.personality()
	if p:
		var row := UIKit.hbox(8)
		row.add_child(UIKit.icon("personality", 22))
		var pv := UIKit.vbox(0)
		pv.add_child(UIKit.label("Personalidade: %s" % p.display_name, "BodyLabel"))
		pv.add_child(UIKit.wrap_label(p.description, "SmallLabel", 260))
		row.add_child(pv)
		right.add_child(row)
	var m := creature.mutation()
	if m:
		var row := UIKit.hbox(8)
		row.add_child(UIKit.icon("mutation", 22))
		var mv := UIKit.vbox(0)
		mv.add_child(UIKit.label("Mutação: %s" % m.display_name, "BodyLabel", Color("b38cff")))
		mv.add_child(UIKit.wrap_label(m.description, "SmallLabel", 260))
		row.add_child(mv)
		right.add_child(row)
	var genes := HFlowContainer.new()
	genes.add_theme_constant_override("h_separation", 6)
	genes.add_theme_constant_override("v_separation", 6)
	for gid in creature.active_genes:
		var g := DataRegistry.get_gene(gid)
		if g:
			genes.add_child(UIKit.gene_chip(g, GameEnums.GENE_GROUPS.get(g.group, "")))
	right.add_child(genes)
	if not creature.recessive_genes.is_empty():
		right.add_child(UIKit.label("%d gene(s) recessivo(s) %s" % [creature.recessive_genes.size(), "sequenciado(s)" if creature.sequenced else "ainda ocultos"], "SmallLabel"))


func _build_happiness(right: VBoxContainer) -> void:
	var h := SocialLogic.happiness(creature)
	right.add_child(UIKit.label("Bem-estar", "HeaderLabel"))
	right.add_child(UIKit.stat_row("happy", "Felicidade", "%d" % int(round(h)), h / 100.0, "BarHP" if h >= 50 else "BarDanger"))
	var bd := SocialLogic.happiness_breakdown(creature)
	var names := {"personality": "Personalidade", "ecosystem": "Ecossistema", "social": "Convivência", "bonus": "Equipe/pesquisa",
		"stress": "Estresse", "stability": "Instabilidade"}
	var parts := []
	for k in names:
		var v := float(bd.get(k, 0.0))
		if absf(v) >= 0.5:
			parts.append("%s %s%d" % [names[k], "+" if v > 0 else "", int(round(v))])
	if not parts.is_empty():
		right.add_child(UIKit.wrap_label(" · ".join(parts), "SmallLabel", 300))
	for rel in CreatureRoster.relations_in(creature, creature.habitat_uid):
		var other: CreatureInstance = rel.creature
		var kind: StringName = rel.relation.kind
		var col := UITheme.GOOD if kind == &"friendly" else (UITheme.BAD if kind in [&"predatory", &"incompatible", &"territorial"] else UITheme.TEXT_MUTED)
		right.add_child(UIKit.label("%s: %s" % [other.display_name(), SocialLogic.KINDS.get(kind, "")], "SmallLabel", col))


func _build_evolution(right: VBoxContainer) -> void:
	var routes := CreatureRoster.evolution_routes(creature)
	if routes.is_empty():
		return
	right.add_child(UIKit.label("Evolução artificial", "HeaderLabel"))
	for evo in routes:
		var card := UIKit.panel("Card")
		var v := UIKit.vbox(6)
		var h := UIKit.hbox(10)
		var known := CreatureRoster.is_discovered(evo.to_species.id)
		h.add_child(CreaturePortrait.make(evo.to_species, Vector2(150, 90), not known))
		var info := UIKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.label(evo.route_name, "ValueLabel"))
		info.add_child(UIKit.wrap_label(evo.description, "SmallLabel", 200))
		h.add_child(info)
		v.add_child(h)
		var cost := HFlowContainer.new()
		cost.add_theme_constant_override("h_separation", 12)
		cost.add_child(UIKit.resource_chip("star", "Nv %d" % evo.min_level, creature.level >= evo.min_level, 20))
		cost.add_child(UIKit.resource_chip("credits", GameEnums.format_number(evo.credit_cost), Economy.credits >= evo.credit_cost, 20))
		cost.add_child(UIKit.resource_chip("dna", str(evo.generic_dna), Economy.dna >= evo.generic_dna, 20))
		for mid in evo.required_materials:
			var md := DataRegistry.get_material(StringName(mid))
			cost.add_child(UIKit.resource_chip(md.icon_name if md else "mat_unstable", "x%d" % int(evo.required_materials[mid]),
				GeneticsManager.material(StringName(mid)) >= int(evo.required_materials[mid]), 20))
		v.add_child(cost)
		var reason := CreatureRoster.check_evolution(creature, evo)
		var b := UIKit.button("Evoluir", "evolve", "ButtonPurple", Vector2(0, 56))
		b.disabled = reason != ""
		b.pressed.connect(func():
			if CreatureRoster.evolve(creature, evo):
				title = creature.display_name()
				refresh())
		v.add_child(b)
		if reason != "":
			var rl := UIKit.wrap_label(reason, "SmallLabel", 260)
			rl.add_theme_color_override("font_color", UITheme.BAD)
			v.add_child(rl)
		card.add_child(v)
		right.add_child(card)


func _build_actions() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	var feed_cost := species.feed_cost_at_level(creature.level)
	var feed := UIKit.button("Alimentar  %d" % feed_cost, "feed", "ButtonAmber", Vector2(190, 64))
	feed.disabled = creature.is_max_level()
	feed.pressed.connect(_on_feed)
	row.add_child(feed)
	var move := UIKit.button("Mover", "move", "ButtonBlue", Vector2(130, 64))
	move.pressed.connect(func(): hud.open_habitat_picker(creature))
	row.add_child(move)
	var fight := UIKit.button("Batalhar", "battle", "ButtonRed", Vector2(150, 64))
	fight.pressed.connect(func(): hud.open_panel("arena", {"selected_uid": creature.uid}))
	row.add_child(fight)
	var tree := UIKit.button("Árvore", "tree", "ButtonPurple", Vector2(140, 64))
	tree.pressed.connect(func(): hud.open_panel("genetic_tree", {"creature": creature, "stack": true}))
	row.add_child(tree)
	var arch := UIKit.button("Arquivo", "archive", "ButtonDark", Vector2(140, 64))
	arch.pressed.connect(func(): hud.open_panel("archive", {"selected": creature.species_id, "stack": true}))
	row.add_child(arch)
	var info := UIKit.button("", "info", "ButtonDark", Vector2(64, 64))
	info.tooltip_text = "Ficha da espécie"
	info.pressed.connect(func():
		_show_info = not _show_info
		refresh())
	row.add_child(info)
	return row


func _on_feed() -> void:
	var before_level := creature.level
	var gained := CreatureRoster.feed(creature)
	if gained < 0:
		return
	AudioManager.play_sfx(&"coin")
	if hud and hud.park:
		var actor: CreatureActor = hud.park.find_actor(creature.uid)
		if actor:
			Fx.float_text(hud.park.effects, actor.global_position + Vector2(0, -actor.data.foot_y),
				"+%d XP" % species.feed_xp, UITheme.CYAN, 14, 28, 1.0)
	refresh()
	if creature.level > before_level:
		_level_up_flash()


func _level_up_flash() -> void:
	var banner := UIKit.label("NÍVEL %d!" % creature.level, "BigLabel", UITheme.GOOD, HORIZONTAL_ALIGNMENT_CENTER)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(banner)
	banner.pivot_offset = banner.get_combined_minimum_size() * 0.5
	banner.scale = Vector2(0.3, 0.3)
	var tw := banner.create_tween()
	tw.tween_property(banner, "scale", Vector2(1.2, 1.2), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(0.8)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.tween_callback(banner.queue_free)
	if _portrait:
		var flash := _portrait.create_tween()
		flash.tween_property(_portrait, "modulate", Color(2, 2, 1.5), 0.1)
		flash.tween_property(_portrait, "modulate", Color.WHITE, 0.4)
