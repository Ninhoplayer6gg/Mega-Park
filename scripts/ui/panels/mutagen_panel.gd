extends GamePanel
## Centro Mutagênico: induces an already catalogued mutation on a creature that has none.
## Uses Soro Mutagênico + credits; failures never harm the creature (they give research data).

var building: BuildingInstance
var selected_creature := ""
var selected_mutation: StringName = &""
var _content: VBoxContainer


func configure() -> void:
	title = building.data.display_name if building else "Centro Mutagênico"
	icon_name = "mutation"
	desired_size = Vector2(1100, 640)


func build() -> void:
	_content = UIKit.vbox(10)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	GeneticsManager.genetics_changed.connect(func():
		if is_inside_tree():
			refresh())
	refresh()


func refresh() -> void:
	UIKit.clear(_content)
	var head := UIKit.hbox(14)
	head.add_child(UIKit.wrap_label("Induz uma mutação já catalogada no Arquivo Mega. Chance base %d%% (+ bônus de pesquisa). Em caso de falha, a criatura não sofre nada e você recebe dados de pesquisa." % int(GeneticsManager.INDUCE_CHANCE * 100), "BodyLabel", 520))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.icon_value("mat_serum", "x%d" % GeneticsManager.material(&"mat_serum"), "ValueLabel", 28))
	head.add_child(UIKit.icon_value("mutation", "%d/%d" % [GeneticsManager.known_mutations().size(), DataRegistry.mutations.size()], "ValueLabel", 28))
	_content.add_child(head)
	var list := CreatureRoster.all()
	if list.is_empty():
		_content.add_child(UIKit.label("Você ainda não tem criaturas.", "BodyLabel"))
		return
	if selected_creature == "" or CreatureRoster.get_creature(selected_creature) == null:
		var free := list.filter(func(c): return c.mutation_id == &"")
		selected_creature = (free[0] if not free.is_empty() else list[0]).uid
	var c := CreatureRoster.get_creature(selected_creature)
	var cols := columns(300)
	_content.add_child(cols[0])
	var sc := UIKit.scroll()
	var lv := UIKit.vbox(6)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	cols[1].add_child(sc)
	for x in list:
		var b := UIKit.button(UIKit.creature_line(x), "", "ButtonAmber" if x.uid == selected_creature else "ButtonDark", Vector2(0, 52))
		b.icon = DataRegistry.creature_icon(x.data)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var uid: String = x.uid
		b.pressed.connect(func():
			selected_creature = uid
			refresh())
		lv.add_child(b)
	var right: VBoxContainer = cols[2]
	if c.mutation_id != &"":
		right.add_child(UIKit.label(c.display_name(), "HeaderLabel"))
		right.add_child(UIKit.centered(CreaturePortrait.of_creature(c, Vector2(300, 180))))
		right.add_child(UIKit.label("Esta criatura já possui uma mutação.", "BodyLabel", UITheme.TEXT_MUTED))
		return
	var known := GeneticsManager.known_mutations().filter(func(m): return m.can_apply_to(c.data))
	if known.is_empty():
		right.add_child(UIKit.wrap_label("Nenhuma mutação compatível catalogada ainda. Mutações aparecem naturalmente ao incubar; cada uma descoberta passa a poder ser induzida aqui.", "BodyLabel", 400))
		return
	if selected_mutation == &"" or not known.any(func(m): return m.id == selected_mutation):
		selected_mutation = known[0].id
	var m: MutationData = DataRegistry.get_mutation(selected_mutation)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for k in known:
		var kb := UIKit.button(k.display_name, "mutation", "ButtonAmber" if k.id == selected_mutation else "ButtonDark", Vector2(0, 48))
		var kid: StringName = k.id
		kb.pressed.connect(func():
			selected_mutation = kid
			refresh())
		flow.add_child(kb)
	right.add_child(flow)
	var preview := CreaturePortrait.make(c.data, Vector2(320, 180))
	preview.sheet = m.form_sheet(c.data)
	preview.mutation = m
	right.add_child(UIKit.centered(preview))
	right.add_child(UIKit.label("Prévia: %s" % m.name_for(c.data), "ValueLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	right.add_child(UIKit.wrap_label(m.description, "SmallLabel", 400))
	var cost := UIKit.hbox(14)
	cost.add_child(UIKit.resource_chip("credits", GameEnums.format_number(GeneticsManager.INDUCE_COST), Economy.credits >= GeneticsManager.INDUCE_COST))
	cost.add_child(UIKit.resource_chip("mat_serum", "1 Soro Mutagênico", GeneticsManager.material(&"mat_serum") >= 1))
	right.add_child(cost)
	var reason := GeneticsManager.check_induce(c, m)
	var btn := UIKit.button("Induzir mutação", "mutation", "ButtonPurple", Vector2(300, 64))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.disabled = reason != ""
	btn.pressed.connect(func():
		if GeneticsManager.induce_mutation(c, m):
			hud.close_all()
		else:
			refresh())
	right.add_child(btn)
	if reason != "":
		var rl := UIKit.wrap_label(reason, "BodyLabel", 400)
		rl.add_theme_color_override("font_color", UITheme.BAD)
		right.add_child(rl)
