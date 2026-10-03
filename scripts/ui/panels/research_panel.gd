extends GamePanel
## Research center: DNA sequencing (credits -> DNA) and dimensional signal research
## (discovers a species). Values come from BuildingData.params.

var building: BuildingInstance


func configure() -> void:
	title = building.data.display_name
	icon_name = "research"
	desired_size = Vector2(900, 560)


func build() -> void:
	refresh()
	Economy.resources_changed.connect(refresh)


func refresh() -> void:
	if not is_inside_tree() and body.get_child_count() > 0:
		return
	UIKit.clear(body)
	var p := building.data.params
	var cols := UIKit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# DNA sequencer
	var credits_cost := int(p.get("dna_exchange_credits", 200))
	var dna_amount := int(p.get("dna_exchange_amount", 15))
	var seq := _card("Sequenciador de DNA", "dna",
		"Converte créditos em DNA genérico para incubar novas criaturas.")
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
			hud.fly_rewards(from, "dna", 4))
	seq.get_child(0).add_child(seq_btn)
	cols.add_child(seq)
	# Dimensional research
	var species: CreatureData = DataRegistry.get_creature(StringName(p.get("research_species", "")))
	if species:
		var cost := int(p.get("research_cost", 400))
		var known := CreatureRoster.is_discovered(species.id)
		var res := _card("Sinal Dimensional", "skill",
			"Decodifique um sinal vindo da Cratera Estelar para obter o genoma de uma nova espécie.")
		var pic := CreaturePortrait.make(species, Vector2(200, 110), not known)
		res.get_child(0).add_child(pic)
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
	body.add_child(cols)


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
