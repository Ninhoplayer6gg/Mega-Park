extends GamePanel
## Genetic labs (Laboratório Genético, Núcleo de Hibridização, Câmara Quimérica).
## Tabs: Hibridização (recipes, donors, stability, synthesis and reveal), Extração (non-destructive
## DNA sampling), Banco Genético (DNA, materials, fossils, clues) and Genes (sequencing + therapy).

const CAPSULE := preload("res://assets/effects/gene_capsule.png")
const GENE_CAPTIONS := ["Gene primário", "Gene secundário", "Gene elemental", "Gene especial"]

var building: BuildingInstance
var tab := "hybrid"
var selected_recipe: StringName = &""
var selected_creature := ""
var _donors := {}              # recipe id -> Array of donor uids ("" = DNA bank only)
var _tabs: HBoxContainer
var _content: VBoxContainer
var _job_state := ""
var _bar: ProgressBar
var _time_label: Label
var _revealing := false


func configure() -> void:
	title = building.data.display_name if building else "Laboratório"
	icon_name = "lab"
	desired_size = Vector2(1140, 660)


func build() -> void:
	_tabs = UIKit.hbox(8)
	body.add_child(_tabs)
	_content = UIKit.vbox(10)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	GeneticsManager.genetics_changed.connect(_on_changed)
	ResearchManager.research_changed.connect(_on_changed)
	CreatureRoster.creature_changed.connect(func(_c): _on_changed())
	GameClock.tick.connect(_on_tick)
	refresh()


func _on_changed() -> void:
	if is_inside_tree() and not _revealing:
		refresh()


func refresh() -> void:
	if _revealing:
		return
	UIKit.clear(_tabs)
	_tabs.add_child(UIKit.tabs([["hybrid", "Hibridização", "lab"], ["extract", "Extração", "dna"],
		["bank", "Banco Genético", "archive"], ["genes", "Genes", "gene_special"]], tab, func(id: String):
			tab = id
			refresh()))
	_tabs.add_child(UIKit.spacer())
	var lvl := GeneticsManager.lab_level_of(building.uid) if building else GeneticsManager.lab_level()
	_tabs.add_child(UIKit.tag("LAB NÍVEL %d" % lvl, UITheme.CYAN))
	_tabs.add_child(UIKit.icon_value("rp", str(ResearchManager.rp), "ValueLabel", 24))
	UIKit.clear(_content)
	match tab:
		"hybrid":
			_build_hybrid()
		"extract":
			_build_extract()
		"bank":
			_build_bank()
		"genes":
			_build_genes()


func _on_tick() -> void:
	if not is_inside_tree() or tab != "hybrid" or _revealing:
		return
	var s := _current_job_state()
	if s != _job_state:
		refresh()
	elif s == "running" and _bar:
		_bar.value = GeneticsManager.job_progress(building.uid)
		_time_label.text = "Tempo restante: %s" % GameEnums.format_time(GeneticsManager.job_time_left(building.uid))


func _current_job_state() -> String:
	if building == null or not GeneticsManager.jobs.has(building.uid):
		return "idle"
	return "ready" if GeneticsManager.job_ready(building.uid) else "running"


# ------------------------------------------------------------------ hybridisation
func _build_hybrid() -> void:
	_job_state = _current_job_state()
	if _job_state != "idle":
		_build_job()
		return
	var recipes := GeneticsManager.visible_recipes()
	var cols := columns(360)
	_content.add_child(cols[0])
	var left: VBoxContainer = cols[1]
	var right: VBoxContainer = cols[2]
	var sc := UIKit.scroll()
	var list := UIKit.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	left.add_child(sc)
	if recipes.is_empty():
		list.add_child(UIKit.wrap_label("Nenhuma receita conhecida ainda. Pesquise Fundamentos de Hibridização no Centro de Pesquisa.", "BodyLabel", 300))
	if selected_recipe == &"" or not recipes.any(func(r): return r.id == selected_recipe):
		selected_recipe = recipes[0].id if not recipes.is_empty() else &""
	for r in recipes:
		list.add_child(_recipe_card(r))
	var hidden_left := DataRegistry.recipes.values().filter(func(r): return not GeneticsManager.is_visible(r)).size()
	if hidden_left > 0:
		var h := UIKit.hbox(6)
		h.add_child(UIKit.icon("mystery", 22))
		h.add_child(UIKit.wrap_label("%d combinação(ões) secreta(s) ainda não detectada(s)." % hidden_left, "SmallLabel", 260))
		left.add_child(h)
	if selected_recipe != &"":
		_recipe_detail(right, DataRegistry.get_recipe(selected_recipe))


func _recipe_card(r: HybridRecipe) -> Control:
	var revealed := GeneticsManager.is_revealed(r)
	var b := Button.new()
	b.theme_type_variation = "ButtonAmber" if r.id == selected_recipe else "ButtonDark"
	b.custom_minimum_size = Vector2(320, 112)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	UIKit.add_press_feedback(b)
	var h := UIKit.hbox(8)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.offset_top = 6
	h.offset_bottom = -12
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(CreaturePortrait.make(r.result_species, Vector2(110, 86), not revealed, false))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UIKit.label(r.result_species.display_name if revealed else "RESULTADO DESCONHECIDO", "ValueLabel")
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(n)
	var tg := UIKit.tier_tag(r.tier())
	tg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(tg)
	var parents := UIKit.hbox(2)
	for s in r.required_species:
		parents.add_child(UIKit.texture(DataRegistry.creature_icon(s), Vector2(30, 30)))
	v.add_child(parents)
	h.add_child(v)
	b.add_child(h)
	b.pressed.connect(func():
		selected_recipe = r.id
		refresh())
	return b


func donors_for(r: HybridRecipe) -> Array:
	if not _donors.has(r.id):
		_donors[r.id] = GeneticsManager.default_donors(r).map(func(d): return d.uid if d else "")
	var out := []
	for uid in _donors[r.id]:
		out.append(CreatureRoster.get_creature(uid) if uid != "" else null)
	return out


func _cycle_donor(r: HybridRecipe, index: int) -> void:
	var options := [""] + GeneticsManager.donor_candidates(r.required_species[index]).map(func(c): return c.uid)
	var current: String = _donors[r.id][index]
	var i := options.find(current)
	_donors[r.id][index] = options[(i + 1) % options.size()]
	refresh()


func _recipe_detail(parent: VBoxContainer, r: HybridRecipe) -> void:
	var revealed := GeneticsManager.is_revealed(r)
	var sc := UIKit.scroll()
	var box := UIKit.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	parent.add_child(sc)
	var head := UIKit.hbox(10)
	var title_l := UIKit.label(r.result_species.display_name if revealed else "COMPATIBILIDADE GENÉTICA DETECTADA", "HeaderLabel",
		UITheme.TEXT if revealed else UITheme.CYAN)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title_l)
	head.add_child(UIKit.tier_tag(r.tier()))
	box.add_child(head)
	if revealed:
		box.add_child(UIKit.wrap_label(r.lore if r.lore != "" else r.result_species.description, "SmallLabel", 300))
	else:
		box.add_child(UIKit.wrap_label("RESULTADO DESCONHECIDO. As amostras indicam uma espécie inédita: a forma, as habilidades e o nome só serão revelados após a primeira síntese.", "SmallLabel", 300))
	# donors / DNA per species
	box.add_child(UIKit.label("Espécies doadoras (toque para trocar o doador)", "SmallLabel"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var donors := donors_for(r)
	for i in r.required_species.size():
		flow.add_child(_donor_slot(r, i, donors[i]))
	box.add_child(flow)
	# stability
	var stab := GeneticsManager.stability_for(r, donors)
	var srow := UIKit.hbox(8)
	srow.add_child(UIKit.icon("stability", 26))
	srow.add_child(UIKit.label("Estabilidade genética", "BodyLabel"))
	var bar := UIKit.progress("BarHP" if stab >= 70 else ("BarTime" if stab >= r.minimum_stability else "BarDanger"), 16, stab, 100.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(bar)
	srow.add_child(UIKit.label("%d%%" % int(stab), "ValueLabel", UITheme.GOOD if stab >= r.minimum_stability else UITheme.BAD))
	box.add_child(srow)
	box.add_child(UIKit.wrap_label("Mínimo %d%%. Falhas devolvem material instável, pesquisa e parte do DNA (ou geram um protótipo); nenhuma criatura é ferida." % int(r.minimum_stability), "SmallLabel", 300))
	# dominant genes
	var genes := r.dominant_genes()
	if not genes.is_empty():
		box.add_child(UIKit.label("Dominância genética", "SmallLabel"))
		var gflow := HFlowContainer.new()
		gflow.add_theme_constant_override("h_separation", 8)
		gflow.add_theme_constant_override("v_separation", 6)
		var slots := [r.primary_gene, r.secondary_gene, r.elemental_gene, r.special_gene]
		for i in slots.size():
			if slots[i]:
				gflow.add_child(UIKit.gene_chip(slots[i], GENE_CAPTIONS[i], not revealed and i >= 2))
		box.add_child(gflow)
	# costs
	var costs := HFlowContainer.new()
	costs.add_theme_constant_override("h_separation", 16)
	costs.add_child(UIKit.resource_chip("credits", GameEnums.format_number(r.credit_cost), Economy.credits >= r.credit_cost))
	if r.generic_dna > 0:
		costs.add_child(UIKit.resource_chip("dna", str(r.generic_dna), Economy.dna >= r.generic_dna))
	for mid in r.required_materials:
		var m := DataRegistry.get_material(StringName(mid))
		var need := int(r.required_materials[mid])
		var have := GeneticsManager.material(StringName(mid))
		var chip := UIKit.resource_chip(m.icon_name if m else "mat_unstable", "%d/%d %s" % [have, need, m.display_name if m else String(mid)], have >= need)
		costs.add_child(chip)
	costs.add_child(UIKit.resource_chip("time", GameEnums.format_time(r.creation_time)))
	box.add_child(costs)
	var reason := GeneticsManager.check_recipe(r, donors, building.uid)
	var start := UIKit.button("Iniciar síntese", "lab", "ButtonPurple", Vector2(300, 64))
	start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	start.disabled = reason != ""
	start.pressed.connect(func():
		if GeneticsManager.start_synthesis(building.uid, r, donors):
			hud.show_toast("Síntese iniciada!", "lab", "good")
			refresh())
	parent.add_child(start)
	if reason != "":
		var rl := UIKit.wrap_label(reason, "BodyLabel", 300)
		rl.add_theme_color_override("font_color", UITheme.BAD)
		parent.add_child(rl)


func _donor_slot(r: HybridRecipe, index: int, donor: CreatureInstance) -> Control:
	var s: CreatureData = r.required_species[index]
	var need: int = r.required_dna_amounts[index] if index < r.required_dna_amounts.size() else 0
	var have := GeneticsManager.dna_of(s.id)
	var b := Button.new()
	b.theme_type_variation = "ButtonDark"
	b.custom_minimum_size = Vector2(176, 150)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	UIKit.add_press_feedback(b)
	var v := UIKit.vbox(2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 6
	v.offset_bottom = -12
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var known := CreatureRoster.is_discovered(s.id)
	var portrait: Control = CreaturePortrait.of_creature(donor, Vector2(150, 56), false) if donor else CreaturePortrait.make(s, Vector2(150, 56), not known, false)
	v.add_child(portrait)
	var n := UIKit.label(s.display_name if known else "???", "BodyLabel")
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(n)
	v.add_child(UIKit.resource_chip("dna", "%d/%d" % [have, need], have >= need, 18))
	var d := UIKit.label(("Doador: Nv %d · %d%%" % [donor.level, int(round(donor.genetic_purity))]) if donor else "Só DNA do banco", "SmallLabel",
		UITheme.GOOD if donor else UITheme.TEXT_MUTED)
	d.clip_text = true
	v.add_child(d)
	b.add_child(v)
	b.pressed.connect(_cycle_donor.bind(r, index))
	return b


func _build_job() -> void:
	var j := GeneticsManager.job(building.uid)
	var r := DataRegistry.get_recipe(StringName(j.recipe))
	var revealed := r != null and GeneticsManager.is_revealed(r)
	var center := UIKit.vbox(10)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(UIKit.label("Síntese em andamento" if _job_state == "running" else "Síntese concluída!", "TitleLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	center.add_child(UIKit.label((r.result_species.display_name if revealed else "RESULTADO DESCONHECIDO") if r else "?", "HeaderLabel",
		UITheme.TEXT if revealed else UITheme.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	var cap := _capsule_rect()
	center.add_child(UIKit.centered(cap))
	if _job_state == "running":
		_bar = UIKit.progress("BarPurple", 22, GeneticsManager.job_progress(building.uid), 1.0)
		_bar.custom_minimum_size.x = 420
		_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		center.add_child(_bar)
		_time_label = UIKit.label("Tempo restante: %s" % GameEnums.format_time(GeneticsManager.job_time_left(building.uid)), "ValueLabel", null, HORIZONTAL_ALIGNMENT_CENTER)
		center.add_child(_time_label)
		center.add_child(UIKit.label("Estabilidade da amostra: %d%% · você pode fechar esta janela." % int(j.stability), "SmallLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var btn := UIKit.button("Revelar resultado", "star", "ButtonGreen", Vector2(340, 72))
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_reveal.bind(btn, cap))
		center.add_child(btn)
	_content.add_child(center)


func _capsule_rect() -> TextureRect:
	var frames: Array[AtlasTexture] = []
	for i in 3:
		var at := AtlasTexture.new()
		at.atlas = CAPSULE
		at.region = Rect2(i * 32, 0, 32, 48)
		frames.append(at)
	var cap := UIKit.texture(frames[0], Vector2(128, 192))
	var idx := [0]
	var t := Timer.new()
	t.wait_time = 0.2
	t.autostart = true
	t.timeout.connect(func():
		idx[0] = (idx[0] + 1) % 3
		cap.texture = frames[idx[0]])
	cap.add_child(t)
	return cap


func _reveal(btn: Button, cap: TextureRect) -> void:
	btn.disabled = true
	_revealing = true
	AudioManager.play_sfx(&"buff")
	cap.pivot_offset = cap.size * 0.5
	var tw := cap.create_tween()
	for i in 3:
		tw.tween_property(cap, "rotation", 0.1, 0.06)
		tw.tween_property(cap, "rotation", -0.1, 0.06)
	tw.tween_property(cap, "rotation", 0.0, 0.05)
	tw.tween_property(cap, "modulate", Color(3, 3, 3, 1), 0.2)
	await tw.finished
	var res := GeneticsManager.collect_synthesis(building.uid)
	_revealing = false
	if res.is_empty():
		refresh()
		return
	hud.show_synthesis_result(res)
	refresh()


# ------------------------------------------------------------------ extraction
func _build_extract() -> void:
	_content.add_child(UIKit.wrap_label("A extração coleta uma pequena amostra de tecido: a criatura não é ferida nem removida. Cada criatura precisa de %s para recuperar. Custo: %d créditos." % [GameEnums.format_time(CreatureInstance.EXTRACT_COOLDOWN), GeneticsManager.EXTRACT_COST], "BodyLabel", 600))
	var sc := UIKit.scroll()
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	_content.add_child(sc)
	var list := CreatureRoster.all()
	if list.is_empty():
		grid.add_child(UIKit.label("Você ainda não tem criaturas.", "BodyLabel"))
	for c in list:
		grid.add_child(_extract_card(c))


func _extract_card(c: CreatureInstance) -> Control:
	var p := UIKit.panel("Card")
	p.custom_minimum_size = Vector2(250, 0)
	var v := UIKit.vbox(4)
	v.add_child(CreaturePortrait.of_creature(c, Vector2(220, 84), false))
	var n := UIKit.label(c.display_name(), "ValueLabel")
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(n)
	v.add_child(UIKit.label("Nv %d · Pureza %d%%" % [c.level, int(round(c.genetic_purity))], "SmallLabel"))
	v.add_child(UIKit.resource_chip("dna", "+%d DNA da espécie" % GeneticsManager.extraction_amount(c), true, 20))
	var reason := GeneticsManager.check_extraction(c)
	var b := UIKit.button("Extrair", "dna", "ButtonBlue", Vector2(0, 52))
	b.disabled = reason != ""
	b.pressed.connect(func():
		var got := GeneticsManager.extract_dna(c)
		if got > 0:
			hud.show_toast("+%d DNA de %s" % [got, c.data.display_name], "dna", "good")
			refresh())
	v.add_child(b)
	if reason != "":
		var r := UIKit.wrap_label(reason, "SmallLabel", 220)
		r.add_theme_color_override("font_color", UITheme.BAD)
		v.add_child(r)
	p.add_child(v)
	return p


# ------------------------------------------------------------------ gene bank
func _build_bank() -> void:
	var sc := UIKit.scroll()
	var box := UIKit.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	_content.add_child(sc)
	box.add_child(UIKit.label("DNA por espécie", "HeaderLabel"))
	var flow := _flow()
	var any := false
	for s in DataRegistry.creature_list():
		var amount := GeneticsManager.dna_of(s.id)
		if amount <= 0 and not CreatureRoster.is_discovered(s.id):
			continue
		any = true
		var p := UIKit.panel("Inset")
		var h := UIKit.hbox(6)
		h.add_child(UIKit.texture(DataRegistry.creature_icon(s), Vector2(36, 36)))
		var v := UIKit.vbox(0)
		v.add_child(UIKit.label(s.display_name, "SmallLabel"))
		v.add_child(UIKit.icon_value("dna", str(amount), "ValueLabel", 18))
		h.add_child(v)
		p.add_child(h)
		flow.add_child(p)
	if not any:
		flow.add_child(UIKit.label("Nenhuma amostra ainda.", "BodyLabel"))
	box.add_child(flow)
	box.add_child(UIKit.label("Materiais raros", "HeaderLabel"))
	var mflow := _flow()
	for m in DataRegistry.materials.values():
		var p := UIKit.panel("Inset")
		p.tooltip_text = m.description
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		var h := UIKit.hbox(6)
		h.add_child(UIKit.icon(m.icon_name, 32))
		var v := UIKit.vbox(0)
		v.add_child(UIKit.label(m.display_name, "SmallLabel"))
		v.add_child(UIKit.label("x%d" % GeneticsManager.material(m.id), "ValueLabel"))
		h.add_child(v)
		p.add_child(h)
		mflow.add_child(p)
	box.add_child(mflow)
	var fossil_species := GeneticsManager.restorable_species()
	if not fossil_species.is_empty():
		box.add_child(UIKit.label("Fósseis", "HeaderLabel"))
		var fflow := _flow()
		for s in fossil_species:
			var frags := int(GeneticsManager.fossils.get(s.id, 0))
			fflow.add_child(_progress_chip("fossil", s.display_name if CreatureRoster.is_discovered(s.id) or frags > 0 else "Fóssil desconhecido", frags, s.fossil_fragments_required))
		box.add_child(fflow)
	var clue_species := DataRegistry.creatures.values().filter(func(s): return s.clues_required > 0)
	if not clue_species.is_empty():
		box.add_child(UIKit.label("Pistas de campo", "HeaderLabel"))
		var cflow := _flow()
		for s in clue_species:
			var n := GeneticsManager.clues_of(s.id)
			cflow.add_child(_progress_chip("clue_footprint", s.display_name if n >= s.clues_required else "Espécie rastreada", n, s.clues_required))
		box.add_child(cflow)


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	return f


func _progress_chip(icon_name: String, text: String, have: int, need: int) -> Control:
	var p := UIKit.panel("Inset")
	p.custom_minimum_size = Vector2(230, 0)
	var h := UIKit.hbox(6)
	h.add_child(UIKit.icon(icon_name, 30))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label("%s  %d/%d" % [text, mini(have, need), need], "SmallLabel"))
	var bar := UIKit.progress("BarTime", 10, minf(have, need), maxf(need, 1))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(bar)
	h.add_child(v)
	p.add_child(h)
	return p


# ------------------------------------------------------------------ genes
func _build_genes() -> void:
	var list := CreatureRoster.all()
	if list.is_empty():
		_content.add_child(UIKit.label("Você ainda não tem criaturas.", "BodyLabel"))
		return
	if selected_creature == "" or CreatureRoster.get_creature(selected_creature) == null:
		selected_creature = list[0].uid
	var cols := columns(300)
	_content.add_child(cols[0])
	var sc := UIKit.scroll()
	var lv := UIKit.vbox(6)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	cols[1].add_child(sc)
	for c in list:
		var b := UIKit.button(UIKit.creature_line(c), "", "ButtonAmber" if c.uid == selected_creature else "ButtonDark", Vector2(0, 52))
		b.icon = DataRegistry.creature_icon(c.data)
		b.expand_icon = false
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var uid: String = c.uid
		b.pressed.connect(func():
			selected_creature = uid
			refresh())
		lv.add_child(b)
	_gene_detail(cols[2], CreatureRoster.get_creature(selected_creature))


func _gene_detail(parent: VBoxContainer, c: CreatureInstance) -> void:
	var sc := UIKit.scroll()
	var box := UIKit.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	parent.add_child(sc)
	var head := UIKit.hbox(10)
	head.add_child(CreaturePortrait.of_creature(c, Vector2(170, 100)))
	var hv := UIKit.vbox(2)
	hv.add_child(UIKit.label(c.display_name(), "HeaderLabel"))
	hv.add_child(UIKit.label("Geração %d · Pureza %d%% · Estabilidade %d%%" % [c.generation(), int(round(c.genetic_purity)), int(round(c.genetic_stability))], "SmallLabel"))
	var tree_btn := UIKit.button("Árvore genética", "tree", "ButtonBlue", Vector2(0, 48))
	tree_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tree_btn.pressed.connect(func(): hud.open_panel("genetic_tree", {"creature": c, "stack": true}))
	hv.add_child(tree_btn)
	head.add_child(hv)
	box.add_child(head)
	box.add_child(UIKit.label("Genes ativos (%d/%d)" % [c.active_genes.size(), GeneticsLogic.MAX_ACTIVE_GENES], "ValueLabel"))
	var af := _flow()
	for gid in c.active_genes:
		var g := DataRegistry.get_gene(gid)
		if g:
			af.add_child(UIKit.gene_chip(g, GameEnums.GENE_GROUPS.get(g.group, "")))
	box.add_child(af)
	for gid in c.active_genes:
		var g := DataRegistry.get_gene(gid)
		if g:
			box.add_child(UIKit.wrap_label("• %s: %s" % [g.display_name, g.description], "SmallLabel", 300))
	box.add_child(UIKit.label("Genes recessivos (%d)" % c.recessive_genes.size(), "ValueLabel"))
	if c.recessive_genes.is_empty():
		box.add_child(UIKit.label("Nenhum gene recessivo.", "SmallLabel"))
	elif not c.sequenced:
		var rf := _flow()
		for gid in c.recessive_genes:
			rf.add_child(UIKit.gene_chip(DataRegistry.get_gene(gid), "", true))
		box.add_child(rf)
		var can := ResearchManager.unlocked(&"gene_sequencing")
		var sb := UIKit.button("Sequenciar (%d PP)" % GeneticsManager.SEQUENCE_RP, "research", "ButtonPurple", Vector2(0, 56))
		sb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		sb.disabled = not can or ResearchManager.rp < GeneticsManager.SEQUENCE_RP
		sb.pressed.connect(func():
			if GeneticsManager.sequence(c):
				hud.show_toast("Genoma de %s sequenciado!" % c.display_name(), "research", "good")
				refresh())
		box.add_child(sb)
		if not can:
			box.add_child(UIKit.label("Requer a pesquisa Sequenciamento Genômico.", "SmallLabel", UITheme.BAD))
	else:
		for gid in c.recessive_genes:
			var g := DataRegistry.get_gene(gid)
			if g == null:
				continue
			var row := UIKit.hbox(8)
			row.add_child(UIKit.gene_chip(g, GameEnums.GENE_GROUPS.get(g.group, "")))
			var d := UIKit.wrap_label(g.description, "SmallLabel", 200)
			d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(d)
			var ab := UIKit.button("Ativar", "plus", "ButtonGreen", Vector2(120, 52))
			ab.tooltip_text = "Terapia gênica: %d PP + %d DNA. Com 3 genes ativos, o último volta a ser recessivo." % [GeneticsManager.THERAPY_RP, GeneticsManager.THERAPY_DNA]
			ab.disabled = ResearchManager.rp < GeneticsManager.THERAPY_RP or Economy.dna < GeneticsManager.THERAPY_DNA
			var gene_id: StringName = gid
			ab.pressed.connect(func():
				if GeneticsManager.activate_recessive(c, gene_id):
					hud.show_toast("Gene %s ativado!" % g.display_name, "gene_special", "good")
					refresh())
			row.add_child(ab)
			box.add_child(row)
		box.add_child(UIKit.label("Terapia gênica: %d PP + %d DNA por gene." % [GeneticsManager.THERAPY_RP, GeneticsManager.THERAPY_DNA], "SmallLabel"))
