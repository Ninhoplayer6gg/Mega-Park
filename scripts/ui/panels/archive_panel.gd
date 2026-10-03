extends GamePanel
## ARQUIVO MEGA: scientific catalogue. Each species has a code (MG-001...). Unknown entries show
## only "MG-???". Six sections unlock progressively (identity, biometrics, behaviour, genetics,
## habitat, abilities); plus clues, variants, observed mutations and the photo album.

const SECTION_INFO := {
	"identity": ["Identidade", "info", ""],
	"biometrics": ["Biometria", "health", "Obtenha um exemplar ou fotografe a espécie."],
	"behavior": ["Comportamento", "happy", "Observe 2 comportamentos (toque na criatura ou fotografe) ou pesquise Etologia."],
	"genetics": ["Genética", "gene_special", "Sequencie o genoma de um exemplar no Laboratório Genético."],
	"habitat": ["Habitat e ecologia", "tree", "Crie ou incube um exemplar."],
	"abilities": ["Habilidades", "skill", "Batalhe com ou contra a espécie."],
}
const NEED_NAMES := {&"water": ["Água", "type_aquatic"], &"shelter": ["Abrigo", "build"], &"vegetation": ["Vegetação", "tree"], &"food": ["Comedouro premium", "feed"]}
const SOCIAL_NAMES := {&"solitary": "Solitária", &"pair": "Vive em pares", &"herd": "Vive em manadas", &"pack": "Caça em bando"}

var tab := "species"
var selected: StringName = &""
var _tabs: HBoxContainer
var _content: VBoxContainer


func configure() -> void:
	title = "Arquivo Mega"
	icon_name = "archive"
	desired_size = Vector2(1180, 680)


func build() -> void:
	_tabs = UIKit.hbox(8)
	body.add_child(_tabs)
	_content = UIKit.vbox(8)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	refresh()


func refresh() -> void:
	UIKit.clear(_tabs)
	_tabs.add_child(UIKit.tabs([["species", "Espécies", "archive"], ["photos", "Álbum (%d)" % ArchiveManager.photos.size(), "camera"]], tab, func(id: String):
		tab = id
		refresh()))
	_tabs.add_child(UIKit.spacer())
	_tabs.add_child(UIKit.icon_value("archive", "%d/%d registros" % [ArchiveManager.entries_count(), DataRegistry.creatures.size()], "ValueLabel", 24))
	_tabs.add_child(UIKit.icon_value("mutation", "%d/%d mutações" % [GeneticsManager.known_mutations().size(), DataRegistry.mutations.size()], "ValueLabel", 24))
	UIKit.clear(_content)
	if tab == "species":
		_build_species()
	else:
		_build_photos()


# ------------------------------------------------------------------ species
func _build_species() -> void:
	var list := DataRegistry.archive_list()
	if selected == &"" or DataRegistry.get_creature(selected) == null:
		for s in list:
			if ArchiveManager.is_registered(s.id):
				selected = s.id
				break
	var cols := columns(330)
	_content.add_child(cols[0])
	var sc := UIKit.scroll()
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(grid)
	cols[1].add_child(sc)
	for s in list:
		grid.add_child(_entry_button(s))
	if selected != &"":
		_detail(cols[2], DataRegistry.get_creature(selected))


func _entry_button(s: CreatureData) -> Control:
	var known := ArchiveManager.is_registered(s.id)
	var b := Button.new()
	b.theme_type_variation = "ButtonAmber" if s.id == selected else "ButtonDark"
	b.custom_minimum_size = Vector2(100, 108)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	UIKit.add_press_feedback(b)
	var v := UIKit.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 4
	v.offset_bottom = -10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.label(s.archive_code if known else "MG-???", "SmallLabel", UITheme.CYAN if known else UITheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var pic := UIKit.texture(DataRegistry.creature_icon(s) if known else DataRegistry.icon("mystery"), Vector2(56, 48))
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	var bar := UIKit.progress("BarXP", 6, ArchiveManager.progress(s.id) if known else 0.0, 1.0)
	v.add_child(bar)
	b.add_child(v)
	b.tooltip_text = s.display_name if known else "Espécie desconhecida"
	b.pressed.connect(func():
		selected = s.id
		refresh())
	return b


func _detail(parent: VBoxContainer, s: CreatureData) -> void:
	var sc := UIKit.scroll()
	var box := UIKit.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	parent.add_child(sc)
	if not ArchiveManager.is_registered(s.id):
		_unknown(box, s)
		return
	var head := UIKit.hbox(12)
	head.add_child(CreaturePortrait.make(s, Vector2(220, 140)))
	var hv := UIKit.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.label(s.archive_code, "ValueLabel", UITheme.CYAN))
	var n := UIKit.label(s.display_name, "TitleLabel")
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size.x = 260
	hv.add_child(n)
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_child(UIKit.rarity_badge(s.rarity))
	tags.add_child(UIKit.tag(s.category_name().to_upper(), UITheme.TEXT_MUTED))
	if s.hybrid_tier > 0:
		tags.add_child(UIKit.tier_tag(s.hybrid_tier))
	if s.variant_kind != &"":
		tags.add_child(UIKit.tag(GameEnums.VARIANT_KINDS.get(s.variant_kind, "").to_upper(), Color("ff9f43")))
	hv.add_child(tags)
	var types := UIKit.hbox(8)
	for t in s.types:
		types.add_child(UIKit.icon_value(GameEnums.type_icon(t), GameEnums.type_name(t), "BodyLabel", 20))
	hv.add_child(types)
	var prog := UIKit.hbox(6)
	prog.add_child(UIKit.label("Conhecimento", "SmallLabel"))
	var pb := UIKit.progress("BarXP", 10, ArchiveManager.progress(s.id), 1.0)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog.add_child(pb)
	var done := 0
	for sec in ArchiveManager.SECTIONS:
		if ArchiveManager.section_unlocked(s.id, sec):
			done += 1
	prog.add_child(UIKit.label("%d/%d" % [done, ArchiveManager.SECTIONS.size()], "ValueLabel"))
	hv.add_child(prog)
	head.add_child(hv)
	box.add_child(head)
	for sec in ArchiveManager.SECTIONS:
		box.add_child(_section(s, sec))


func _section(s: CreatureData, sec: String) -> Control:
	var info: Array = SECTION_INFO[sec]
	var unlocked := ArchiveManager.section_unlocked(s.id, sec)
	var p := UIKit.panel("Card" if unlocked else "Inset")
	var v := UIKit.vbox(4)
	var h := UIKit.hbox(8)
	h.add_child(UIKit.icon(info[1] if unlocked else "lock", 26))
	h.add_child(UIKit.label(info[0], "HeaderLabel" if unlocked else "ValueLabel", null if unlocked else UITheme.TEXT_MUTED))
	v.add_child(h)
	if not unlocked:
		v.add_child(UIKit.wrap_label("Bloqueado. " + info[2], "SmallLabel", 300))
		p.add_child(v)
		return p
	match sec:
		"identity":
			v.add_child(UIKit.wrap_label(s.description, "BodyLabel", 300))
			if s.lore != "":
				v.add_child(UIKit.wrap_label(s.lore, "SmallLabel", 300))
			v.add_child(UIKit.label("Espécie: %s · Origem: %s" % [s.species, s.origin], "SmallLabel"))
			if s.variant_of:
				v.add_child(UIKit.label("Variante de: %s" % s.variant_of.display_name, "SmallLabel", UITheme.CYAN))
			var variants := DataRegistry.creatures.values().filter(func(x): return x.variant_of == s and ArchiveManager.is_registered(x.id))
			for x in variants:
				v.add_child(UIKit.label("Variante conhecida: %s (%s)" % [x.display_name, GameEnums.VARIANT_KINDS.get(x.variant_kind, "")], "SmallLabel", UITheme.CYAN))
			for m in DataRegistry.mutations.values():
				if not m.form_sheet(s) == null and ArchiveManager.mutations_seen.get(s.id, []).has(String(m.id)):
					v.add_child(UIKit.label("Forma mutante: %s" % m.name_for(s), "SmallLabel", Color("b38cff")))
		"biometrics":
			v.add_child(UIKit.label("Porte: %s · %s" % [GameEnums.SIZE_CLASSES.get(s.size_class, ""), s.size_text], "BodyLabel"))
			v.add_child(UIKit.label("Dieta: %s · Função: %s" % [s.diet, GameEnums.role_name(s.role)], "BodyLabel"))
			v.add_child(UIKit.stat_row("health", "Vida", str(s.base_health), s.base_health / 1000.0, "BarHP"))
			v.add_child(UIKit.stat_row("attack", "Ataque", str(s.base_attack), s.base_attack / 100.0, "BarDanger"))
			v.add_child(UIKit.stat_row("defense", "Defesa", str(s.base_defense), s.base_defense / 70.0, "BarXP"))
			v.add_child(UIKit.stat_row("speed", "Velocidade", str(s.base_speed), s.base_speed / 150.0, "BarEnergy"))
		"behavior":
			if s.behavior_notes != "":
				v.add_child(UIKit.wrap_label(s.behavior_notes, "BodyLabel", 300))
			var seen: Array = ArchiveManager.behaviors_seen.get(s.id, [])
			var names := seen.map(func(b): return GameEnums.BEHAVIORS.get(StringName(b), str(b)))
			v.add_child(UIKit.wrap_label("Comportamentos observados: " + (", ".join(names) if not names.is_empty() else "nenhum ainda"), "SmallLabel", 300))
		"genetics":
			var gflow := HFlowContainer.new()
			gflow.add_theme_constant_override("h_separation", 6)
			gflow.add_theme_constant_override("v_separation", 6)
			for g in s.default_genes:
				gflow.add_child(UIKit.gene_chip(g, "Dominante"))
			for g in s.recessive_pool:
				gflow.add_child(UIKit.gene_chip(g, "Recessivo"))
			v.add_child(gflow)
			var recipe := DataRegistry.recipe_for(s.id)
			if recipe:
				var parents := recipe.required_species.map(func(x): return x.display_name)
				v.add_child(UIKit.wrap_label("Receita: %s (%s)" % [" + ".join(parents), recipe.tier_name()], "BodyLabel", 300))
			var muts: Array = ArchiveManager.mutations_seen.get(s.id, [])
			var mnames := muts.map(func(m):
				var md := DataRegistry.get_mutation(StringName(m))
				return md.display_name if md else str(m))
			v.add_child(UIKit.wrap_label("Mutações registradas: " + (", ".join(mnames) if not mnames.is_empty() else "nenhuma"), "SmallLabel", 300))
		"habitat":
			var ht := DataRegistry.get_habitat_type(s.habitat_type)
			v.add_child(UIKit.label("Habitat: %s" % (ht.display_name if ht else String(s.habitat_type)), "BodyLabel"))
			v.add_child(UIKit.label("Vida social: %s" % SOCIAL_NAMES.get(s.social_style, ""), "BodyLabel"))
			var needs := UIKit.hbox(10)
			needs.add_child(UIKit.label("Necessidades:", "SmallLabel"))
			for need in s.needs:
				var nn: Array = NEED_NAMES.get(need, [String(need), "info"])
				needs.add_child(UIKit.icon_value(nn[1], nn[0], "SmallLabel", 20))
			if s.needs.is_empty():
				needs.add_child(UIKit.label("nenhuma especial", "SmallLabel"))
			v.add_child(needs)
		"abilities":
			for a in s.abilities:
				var row := UIKit.hbox(8)
				row.add_child(UIKit.icon(a.icon_name, 26))
				var av := UIKit.vbox(0)
				av.add_child(UIKit.label(a.display_name, "ValueLabel"))
				av.add_child(UIKit.wrap_label(a.description, "SmallLabel", 260))
				row.add_child(av)
				v.add_child(row)
	p.add_child(v)
	return p


func _unknown(box: VBoxContainer, s: CreatureData) -> void:
	var c := UIKit.vbox(10)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(UIKit.label("MG-???", "BigLabel", UITheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var ic := UIKit.icon("mystery", 128)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(ic)
	c.add_child(UIKit.label("Registro não identificado", "HeaderLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	var hint := "Nenhuma informação disponível."
	if s.clues_required > 0:
		var n := GeneticsManager.clues_of(s.id)
		hint = "Pistas de campo: %d/%d. Rastros estranhos foram vistos perto de trilhas iluminadas." % [n, s.clues_required]
	elif s.fossil_fragments_required > 0:
		var f := int(GeneticsManager.fossils.get(s.id, 0))
		hint = "Fragmentos fósseis: %d/%d. Escavações em regiões geladas podem ajudar." % [f, s.fossil_fragments_required]
	elif s.hybrid_tier > 0:
		hint = "Combinação genética ainda não descoberta."
	elif s.discovery_mode == &"boss":
		hint = "Relatos de um espécime dominante na Arena."
	elif s.variant_kind == &"evolution":
		hint = "Forma alcançável por evolução artificial."
	elif s.variant_kind == &"prototype":
		hint = "Resultado possível de sínteses instáveis."
	c.add_child(UIKit.wrap_label(hint, "BodyLabel", 400))
	box.add_child(c)


# ------------------------------------------------------------------ photos
func _build_photos() -> void:
	if ArchiveManager.photos.is_empty():
		_content.add_child(UIKit.wrap_label("Nenhuma foto ainda. Toque no botão de câmera no parque para entrar no Modo Foto: fotos de criaturas rendem créditos, pesquisa e registros no Arquivo.", "BodyLabel", 600))
		return
	var sc := UIKit.scroll()
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	sc.add_child(flow)
	_content.add_child(sc)
	for rec in ArchiveManager.photos:
		flow.add_child(_photo_card(rec))


func _photo_card(rec: Dictionary) -> Control:
	var p := UIKit.panel("Paper")
	p.custom_minimum_size = Vector2(260, 0)
	var v := UIKit.vbox(4)
	var tex := PhotoStore.load_thumbnail(str(rec.get("file", "")))
	if tex:
		v.add_child(UIKit.texture(tex, Vector2(236, 133)))
	var species := DataRegistry.get_creature(StringName(rec.get("species", "")))
	v.add_child(UIKit.label(species.display_name if species else "?", "DarkLabel"))
	var beh: String = GameEnums.BEHAVIORS.get(StringName(rec.get("behavior", "")), "")
	v.add_child(UIKit.label("%s · %d pts" % [beh, int(rec.get("score", 0))], "DarkLabel"))
	p.add_child(v)
	return p
