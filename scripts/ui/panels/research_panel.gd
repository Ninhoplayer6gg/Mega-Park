extends GamePanel
## Centro de Pesquisa: research projects (spend research points), the scientific team (hire and
## train specialists) and the DNA sequencer / dimensional signal from the first version.

const UNLOCK_NAMES := {
	"gene_sequencing": "Sequenciamento de genes recessivos",
	"hybrid_2": "Híbridos de 2 espécies e Laboratório Genético",
	"hybrid_3": "Híbridos de 3 espécies e Núcleo de Hibridização",
	"hybrid_4": "Quimeras de 4 espécies e Câmara Quimérica",
	"paleo": "Centro Paleontológico e Habitat Glacial",
	"mutagen": "Centro Mutagênico (mutações induzidas)",
	"evolution": "Evolução artificial",
	"alpha": "Rastreamento de espécies Alfa (chefes)",
	"team_battles": "Batalhas em equipe 3v3",
}
const EFFECT_TEXT := {
	"stability": "+%s de estabilidade genética", "mutation_chance": "+%s%% de chance de mutação",
	"purity": "+%s de pureza em restaurações", "rp_gain": "+%s%% de pontos de pesquisa",
	"photo_bonus": "+%s%% nas recompensas de fotos", "happiness": "+%s de felicidade das criaturas",
	"alien_stability": "+%s de estabilidade com espécies alienígenas", "ecosystem": "+%s%% de efeito dos ecossistemas",
	"visitors": "+%s%% de visitantes", "fossil_bonus": "+%s fragmento(s) fóssil por expedição",
}

var building: BuildingInstance
var tab := "projects"
var _tabs: HBoxContainer
var _content: VBoxContainer
var _bar: ProgressBar
var _time_label: Label
var _was_ready := false


func configure() -> void:
	title = building.data.display_name if building else "Centro de Pesquisa"
	icon_name = "research"
	desired_size = Vector2(1140, 660)


func build() -> void:
	_tabs = UIKit.hbox(8)
	body.add_child(_tabs)
	_content = UIKit.vbox(10)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	ResearchManager.research_changed.connect(_changed)
	StaffManager.staff_changed.connect(_changed)
	GameClock.tick.connect(_on_tick)
	refresh()


func _changed() -> void:
	if is_inside_tree():
		refresh()


func _on_tick() -> void:
	if not is_inside_tree() or ResearchManager.active.is_empty():
		return
	if ResearchManager.is_ready() != _was_ready:
		refresh()
	elif _bar and is_instance_valid(_bar):
		_bar.value = ResearchManager.progress()
		_time_label.text = "Tempo restante: %s" % GameEnums.format_time(ResearchManager.time_left())


func refresh() -> void:
	UIKit.clear(_tabs)
	_tabs.add_child(UIKit.tabs([["projects", "Pesquisas", "research"], ["team", "Equipe", "staff"],
		["sequencer", "Sequenciador", "dna"]], tab, func(id: String):
			tab = id
			refresh()))
	_tabs.add_child(UIKit.spacer())
	var rate := ResearchManager.PASSIVE_RP_PER_MINUTE * ParkState.count_of(&"research_center") * (1.0 + Bonuses.get_value(&"rp_gain"))
	_tabs.add_child(UIKit.label("+%s PP/min" % String.num(rate, 1), "SmallLabel"))
	_tabs.add_child(UIKit.icon_value("rp", str(int(ResearchManager.rp)), "ValueLabel", 28))
	UIKit.clear(_content)
	match tab:
		"projects":
			_build_projects()
		"team":
			_build_team()
		"sequencer":
			_build_sequencer()


static func effect_lines(effects: Dictionary) -> Array:
	var out := []
	for k in effects:
		if k == "unlock":
			out.append("Libera: " + UNLOCK_NAMES.get(str(effects[k]), str(effects[k])))
		elif EFFECT_TEXT.has(k):
			var v := float(effects[k])
			var shown := String.num(v * 100.0, 0) if k in ["mutation_chance", "rp_gain", "photo_bonus", "ecosystem", "visitors"] else String.num(v, 1).trim_suffix(".0")
			out.append(EFFECT_TEXT[k] % shown)
	return out


# ------------------------------------------------------------------ projects
func _build_projects() -> void:
	var r := ResearchManager.active_research()
	_was_ready = ResearchManager.is_ready()
	if r:
		var card := UIKit.panel("CardSelected")
		var h := UIKit.hbox(12)
		h.add_child(UIKit.icon(r.icon_name, 48))
		var v := UIKit.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(("Concluída: " if _was_ready else "Pesquisando: ") + r.display_name, "HeaderLabel"))
		if _was_ready:
			v.add_child(UIKit.label("Os resultados estão prontos para análise.", "BodyLabel", UITheme.GOOD))
		else:
			_bar = UIKit.progress("BarPurple", 18, ResearchManager.progress(), 1.0)
			_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(_bar)
			_time_label = UIKit.label("Tempo restante: %s" % GameEnums.format_time(ResearchManager.time_left()), "BodyLabel")
			v.add_child(_time_label)
		h.add_child(v)
		if _was_ready:
			var b := UIKit.button("Concluir pesquisa", "check", "ButtonGreen", Vector2(260, 64))
			b.pressed.connect(func():
				var done := ResearchManager.collect()
				if done:
					hud.show_toast("Pesquisa concluída: %s" % done.display_name, "research", "good")
				refresh())
			h.add_child(b)
		card.add_child(h)
		_content.add_child(card)
	var sc := UIKit.scroll()
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	sc.add_child(flow)
	_content.add_child(sc)
	for res in ResearchManager.list():
		flow.add_child(_project_card(res))


func _project_card(r: ResearchData) -> Control:
	var done := ResearchManager.is_done(r.id)
	var active := ResearchManager.active_research() == r
	var reason := ResearchManager.check(r)
	var p := UIKit.panel("Card")
	p.custom_minimum_size = Vector2(340, 0)
	var v := UIKit.vbox(4)
	var h := UIKit.hbox(8)
	h.add_child(UIKit.icon(r.icon_name, 34))
	var n := UIKit.label(r.display_name, "ValueLabel")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size.x = 180
	h.add_child(n)
	if done:
		h.add_child(UIKit.tag("CONCLUÍDA", UITheme.GOOD))
	elif active:
		h.add_child(UIKit.tag("EM ANDAMENTO", Color("b38cff")))
	elif reason.begins_with("Requer"):
		h.add_child(UIKit.icon("lock", 24))
	v.add_child(h)
	v.add_child(UIKit.wrap_label(r.description, "SmallLabel", 300))
	for line in effect_lines(r.effects):
		v.add_child(UIKit.wrap_label("• " + line, "SmallLabel", 300))
	if not done and not active:
		var cost := UIKit.hbox(12)
		cost.add_child(UIKit.resource_chip("rp", str(r.cost_rp), ResearchManager.rp + 0.001 >= r.cost_rp, 20))
		if r.cost_credits > 0:
			cost.add_child(UIKit.resource_chip("credits", GameEnums.format_number(r.cost_credits), Economy.can_afford(r.cost_credits), 20))
		cost.add_child(UIKit.resource_chip("time", GameEnums.format_time(r.duration), true, 20))
		v.add_child(cost)
		var b := UIKit.button("Iniciar", "research", "ButtonPurple", Vector2(0, 52))
		b.disabled = reason != ""
		b.pressed.connect(func():
			if ResearchManager.start(r):
				refresh())
		v.add_child(b)
		if reason != "":
			var rl := UIKit.wrap_label(reason, "SmallLabel", 300)
			rl.add_theme_color_override("font_color", UITheme.BAD)
			v.add_child(rl)
	p.add_child(v)
	return p


# ------------------------------------------------------------------ team
func _build_team() -> void:
	_content.add_child(UIKit.wrap_label("Especialistas dão bônus permanentes que crescem a cada nível. Treinar custa créditos e pontos de pesquisa.", "BodyLabel", 600))
	var sc := UIKit.scroll()
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	sc.add_child(flow)
	_content.add_child(sc)
	for r in StaffManager.list():
		flow.add_child(_staff_card(r))


func _staff_card(r: ResearcherData) -> Control:
	var lvl := StaffManager.level_of(r.id)
	var p := UIKit.panel("CardSelected" if lvl > 0 else "Card")
	p.custom_minimum_size = Vector2(340, 0)
	var v := UIKit.vbox(4)
	var h := UIKit.hbox(10)
	h.add_child(UIKit.texture(r.portrait, Vector2(96, 96)))
	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(r.display_name, "ValueLabel"))
	info.add_child(UIKit.label(r.specialty_name, "SmallLabel", UITheme.CYAN))
	var stars := UIKit.hbox(2)
	for i in r.max_level:
		var st := UIKit.icon("star", 20)
		st.modulate = Color.WHITE if i < lvl else Color(0.25, 0.28, 0.35)
		stars.add_child(st)
	info.add_child(stars)
	info.add_child(UIKit.label("Nível %d/%d" % [lvl, r.max_level] if lvl > 0 else "Disponível para contratar", "SmallLabel"))
	h.add_child(info)
	v.add_child(h)
	v.add_child(UIKit.wrap_label(r.description, "SmallLabel", 300))
	var per_level := effect_lines(r.bonus_per_level)
	if not per_level.is_empty():
		v.add_child(UIKit.wrap_label("Por nível: " + "; ".join(per_level), "SmallLabel", 300))
	if lvl == 0:
		var b := UIKit.button("Contratar", "staff", "ButtonGreen", Vector2(0, 52))
		b.disabled = not Economy.can_afford(r.hire_cost)
		b.pressed.connect(func():
			if StaffManager.hire(r):
				refresh())
		v.add_child(UIKit.cost_row(r.hire_cost))
		v.add_child(b)
	else:
		var reason := StaffManager.check_level_up(r)
		if lvl < r.max_level:
			var cost := StaffManager.level_up_cost(r)
			var row := UIKit.hbox(12)
			row.add_child(UIKit.resource_chip("credits", GameEnums.format_number(cost.credits), Economy.can_afford(cost.credits), 20))
			row.add_child(UIKit.resource_chip("rp", str(cost.rp), ResearchManager.rp + 0.001 >= cost.rp, 20))
			v.add_child(row)
		var b := UIKit.button("Treinar", "plus", "ButtonBlue", Vector2(0, 52))
		b.disabled = reason != ""
		b.pressed.connect(func():
			if StaffManager.level_up(r):
				hud.show_toast("%s subiu para o nível %d!" % [r.display_name, StaffManager.level_of(r.id)], "staff", "good")
				refresh())
		v.add_child(b)
		if reason != "" and reason != "Nível máximo.":
			var rl := UIKit.label(reason, "SmallLabel", UITheme.BAD)
			v.add_child(rl)
	p.add_child(v)
	return p


# ------------------------------------------------------------------ sequencer (v0.1 features)
func _build_sequencer() -> void:
	var p := building.data.params
	var cols := UIKit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var credits_cost := int(p.get("dna_exchange_credits", 200))
	var dna_amount := int(p.get("dna_exchange_amount", 15))
	var seq := _card("Sequenciador de DNA", "dna", "Converte créditos em DNA genérico para incubar novas criaturas.")
	var rate := UIKit.hbox(8)
	rate.add_child(UIKit.icon_value("credits", str(credits_cost), "ValueLabel"))
	rate.add_child(UIKit.label(">", "ValueLabel"))
	rate.add_child(UIKit.icon_value("dna", str(dna_amount), "ValueLabel"))
	seq.get_child(0).add_child(rate)
	var seq_btn := UIKit.button("Sequenciar", "research", "ButtonBlue", Vector2(240, 60))
	seq_btn.disabled = not Economy.can_afford(credits_cost)
	seq_btn.pressed.connect(func():
		var from := seq_btn.global_position + seq_btn.size * 0.5
		if Economy.spend(credits_cost):
			Economy.add(0, dna_amount)
			AudioManager.play_sfx(&"purchase")
			hud.fly_rewards(from, "dna", 4)
			refresh())
	seq.get_child(0).add_child(seq_btn)
	cols.add_child(seq)
	var species: CreatureData = DataRegistry.get_creature(StringName(p.get("research_species", "")))
	if species:
		var cost := int(p.get("research_cost", 400))
		var known := CreatureRoster.is_discovered(species.id)
		var res := _card("Sinal Dimensional", "skill", "Decodifique um sinal vindo da Cratera Estelar para obter o genoma de uma nova espécie.")
		res.get_child(0).add_child(CreaturePortrait.make(species, Vector2(200, 110), not known))
		if known:
			res.get_child(0).add_child(UIKit.label("Genoma obtido: %s" % species.display_name, "ValueLabel", UITheme.GOOD))
			res.get_child(0).add_child(UIKit.wrap_label("Incube-o na Incubadora. Ele precisa de um Habitat Alienígena.", "SmallLabel", 260))
		else:
			res.get_child(0).add_child(UIKit.cost_row(cost))
			var btn := UIKit.button("Decodificar", "research", "ButtonPurple", Vector2(240, 60))
			btn.disabled = not Economy.can_afford(cost)
			btn.pressed.connect(func():
				if Economy.spend(cost):
					CreatureRoster.discover(species.id)
					AudioManager.play_sfx(&"level_up")
					hud.show_toast("Nova espécie descoberta: %s!" % species.display_name, "research", "good")
					refresh())
			res.get_child(0).add_child(btn)
		cols.add_child(res)
	_content.add_child(cols)


func _card(title_text: String, icon_n: String, desc: String) -> PanelContainer:
	var card := UIKit.panel("Card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(10)
	var h := UIKit.hbox(8)
	h.add_child(UIKit.icon(icon_n, 32))
	h.add_child(UIKit.label(title_text, "HeaderLabel"))
	v.add_child(h)
	v.add_child(UIKit.wrap_label(desc, "BodyLabel", 260))
	card.add_child(v)
	return card
