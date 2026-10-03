extends GamePanel
## Active park events. None of them is punitive: they expire on their own, and acting on them
## gives rewards or removes a small temporary penalty.

var _list: VBoxContainer


func configure() -> void:
	title = "Eventos do Parque"
	icon_name = "event"
	desired_size = Vector2(900, 560)


func build() -> void:
	var sc := UIKit.scroll()
	_list = UIKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	body.add_child(sc)
	EventManager.events_changed.connect(func():
		if is_inside_tree():
			refresh())
	GameClock.tick.connect(func():
		if is_inside_tree():
			for l in _list.find_children("TimeLeft*", "Label", true, false):
				l.text = "Termina em %s" % GameEnums.format_time(EventManager.time_left(l.get_meta("uid"))))
	refresh()


func refresh() -> void:
	UIKit.clear(_list)
	if EventManager.active.is_empty():
		_list.add_child(UIKit.wrap_label("Tudo tranquilo no parque. Eventos aparecem de tempos em tempos: tempestades, ovos encontrados, visitantes especiais, anomalias dimensionais...", "BodyLabel", 600))
		return
	for uid in EventManager.active:
		_list.add_child(_event_card(uid))


func _target_text(ev: EventData, target: String) -> String:
	match ev.kind:
		&"stressed_creature", &"rare_behavior":
			var c := CreatureRoster.get_creature(target)
			return "Criatura: %s" % c.display_name() if c else ""
		&"fence_damaged":
			var b := ParkState.get_building(target)
			return "Local: %s" % b.data.display_name if b else ""
		&"egg_found", &"genetic_sample":
			var s := DataRegistry.get_creature(StringName(target))
			return "Espécie: %s" % s.display_name if s else ""
	return ""


func _event_card(uid: String) -> Control:
	var ev := EventManager.data_of(uid)
	var e: Dictionary = EventManager.active[uid]
	var card := UIKit.panel("Card")
	var h := UIKit.hbox(12)
	h.add_child(UIKit.icon(ev.icon_name, 48))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(ev.title, "HeaderLabel"))
	v.add_child(UIKit.wrap_label(ev.description, "SmallLabel", 300))
	var t := _target_text(ev, str(e.get("target", "")))
	if t != "":
		v.add_child(UIKit.label(t, "BodyLabel", UITheme.CYAN))
	var tl := UIKit.label("Termina em %s" % GameEnums.format_time(EventManager.time_left(uid)), "SmallLabel")
	tl.name = "TimeLeft" + uid
	tl.set_meta("uid", uid)
	v.add_child(tl)
	h.add_child(v)
	var cost := ev.resolve_cost
	if ev.kind == &"stressed_creature" and StaffManager.has_specialty(&"veterinary"):
		cost = 0
	var label := ev.resolve_label + ("  %s" % GameEnums.format_number(cost) if cost > 0 else "")
	var b := UIKit.button(label, "credits" if cost > 0 else "check", "ButtonGreen", Vector2(220, 60))
	b.disabled = cost > 0 and not Economy.can_afford(cost)
	b.pressed.connect(_act.bind(uid))
	h.add_child(b)
	card.add_child(h)
	return card


func _act(uid: String) -> void:
	var ev := EventManager.data_of(uid)
	if ev == null:
		return
	var e: Dictionary = EventManager.active[uid]
	match ev.kind:
		&"dimensional_anomaly":
			hud.open_panel("expeditions")
			return
		&"rare_behavior":
			var c := CreatureRoster.get_creature(str(e.target))
			hud.close_all()
			if c and hud.park:
				hud.park.focus_creature(c.uid)
				hud.start_photo_mode()
			return
	var out := EventManager.resolve(uid)
	if out.is_empty():
		return
	var rewards := {}
	if out.has("credits"):
		rewards["credits"] = out.credits
	if out.has("dna"):
		rewards["dna"] = out.dna
	if out.has("rp"):
		rewards["rp"] = out.rp
	if out.has("species_dna"):
		var s := DataRegistry.get_creature(StringName(out.get("species", "")))
		hud.show_toast("+%d DNA de %s" % [out.species_dna, s.display_name if s else "?"], "dna", "good")
	if not rewards.is_empty():
		hud.show_rewards(ev.title, rewards)
	else:
		hud.show_toast("%s: resolvido!" % ev.title, ev.icon_name, "good")
	refresh()
