extends GamePanel
## Shows a list of rewards with a pop-in animation.

var reward_title := "Recompensas"
var rewards := {}


func configure() -> void:
	title = reward_title
	icon_name = "trophy"
	desired_size = Vector2(640, 480)


func build() -> void:
	var list := UIKit.vbox(10)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(list)
	var rows := []
	if int(rewards.get("credits", 0)) > 0:
		rows.append(["credits", "+%s créditos" % GameEnums.format_number(rewards.credits)])
	if int(rewards.get("dna", 0)) > 0:
		rows.append(["dna", "+%d DNA" % rewards.dna])
	if int(rewards.get("species_dna", 0)) > 0:
		rows.append(["dna", "+%d DNA da amostra genética" % rewards.species_dna])
	if int(rewards.get("rp", 0)) > 0:
		rows.append(["rp", "+%d pontos de pesquisa" % rewards.rp])
	var mats: Dictionary = rewards.get("materials", {})
	for mid in mats:
		var m := DataRegistry.get_material(StringName(mid))
		rows.append([m.icon_name if m else "mat_unstable", "+%d %s" % [int(mats[mid]), m.display_name if m else String(mid)]])
	if int(rewards.get("fossils", 0)) > 0:
		var fs := DataRegistry.get_creature(StringName(rewards.get("fossil_species", "")))
		rows.append(["fossil", "+%d fragmento(s) fóssil(eis)%s" % [rewards.fossils, (" de " + fs.display_name) if fs and CreatureRoster.is_discovered(fs.id) else ""]])
	if int(rewards.get("clues", 0)) > 0:
		var cs := DataRegistry.get_creature(StringName(rewards.get("clue_species", "")))
		var n := GeneticsManager.clues_of(cs.id) if cs else 0
		rows.append(["clue_footprint", "Pista de campo encontrada (%d/%d)" % [n, cs.clues_required if cs else 0]])
	if int(rewards.get("player_xp", 0)) > 0:
		rows.append(["star", "+%d XP do parque" % rewards.player_xp])
	var sp := StringName(rewards.get("species", ""))
	if sp != &"":
		var data := DataRegistry.get_creature(sp)
		if data:
			rows.append(["research", ("NOVA ESPÉCIE: %s!" if rewards.get("new_species", false) else "Amostra de %s") % data.display_name])
	if rows.is_empty():
		rows.append(["info", "Nada desta vez..."])
	if rows.size() > 5:
		desired_size.y = 480 + (rows.size() - 5) * 60
	for i in rows.size():
		var card := UIKit.panel("Card")
		var h := UIKit.hbox(12)
		h.add_child(UIKit.icon(rows[i][0], 36))
		h.add_child(UIKit.label(rows[i][1], "HeaderLabel"))
		card.add_child(h)
		card.modulate.a = 0.0
		list.add_child(card)
		var tw := card.create_tween()
		tw.tween_interval(0.15 + i * 0.18)
		tw.tween_property(card, "modulate:a", 1.0, 0.15)
		tw.tween_callback(func(): AudioManager.play_sfx(&"coin", 0.1, -4.0))
	var ok := UIKit.button("Continuar", "check", "ButtonGreen", Vector2(260, 64))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(close)
	body.add_child(ok)
