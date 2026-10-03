extends GamePanel
## Expedition destinations: start, follow progress, collect rewards.

var _list: VBoxContainer


func configure() -> void:
	title = "Expedições"
	icon_name = "expedition"
	desired_size = Vector2(1000, 620)


func build() -> void:
	body.add_child(UIKit.wrap_label("Envie equipes de campo para regiões distantes em busca de créditos, DNA e amostras genéticas.", "BodyLabel", 500))
	var sc := UIKit.scroll()
	_list = UIKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	body.add_child(sc)
	refresh()
	GameClock.tick.connect(_on_tick)
	ExpeditionManager.expeditions_changed.connect(refresh)


func _on_tick() -> void:
	if not is_inside_tree():
		return
	for e in ExpeditionManager.list():
		var row := _list.find_child(String(e.id), false, false)
		if row == null:
			continue
		if ExpeditionManager.is_active(e.id):
			var bar: ProgressBar = row.find_child("Bar", true, false)
			var t: Label = row.find_child("Time", true, false)
			if ExpeditionManager.is_ready(e.id) and row.get_meta("state", "") != "ready":
				refresh()
				return
			if bar:
				bar.value = ExpeditionManager.progress(e.id)
			if t:
				t.text = GameEnums.format_time(ExpeditionManager.time_left(e.id))


func refresh() -> void:
	if _list == null:
		return
	UIKit.clear(_list)
	for e in ExpeditionManager.list():
		_list.add_child(_card(e))


func _card(e: ExpeditionData) -> Control:
	var card := UIKit.panel("Card")
	card.name = String(e.id)
	var h := UIKit.hbox(14)
	var banner := ColorRect.new()
	banner.color = e.banner_color
	banner.custom_minimum_size = Vector2(110, 110)
	var ic := UIKit.icon(e.icon_name, 64)
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.position = Vector2(23, 23)
	banner.add_child(ic)
	h.add_child(banner)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(e.display_name, "HeaderLabel"))
	v.add_child(UIKit.wrap_label(e.description, "SmallLabel", 360))
	var rw := UIKit.hbox(14)
	rw.add_child(UIKit.icon_value("credits", "%d-%d" % [e.credits_min, e.credits_max], "BodyLabel", 18))
	rw.add_child(UIKit.icon_value("dna", "%d-%d" % [e.dna_min, e.dna_max], "BodyLabel", 18))
	rw.add_child(UIKit.icon_value("research", "%d%% amostra" % int(e.species_sample_chance * 100), "BodyLabel", 18))
	rw.add_child(UIKit.icon_value("time", GameEnums.format_time(e.duration), "BodyLabel", 18))
	v.add_child(rw)
	h.add_child(v)
	var side := UIKit.vbox(6)
	side.custom_minimum_size.x = 230
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	if ExpeditionManager.is_ready(e.id):
		card.set_meta("state", "ready")
		var b := UIKit.button("Coletar", "trophy", "ButtonGreen", Vector2(220, 64))
		b.pressed.connect(func():
			var from := b.global_position + b.size * 0.5
			var r := ExpeditionManager.collect(e.id)
			if not r.is_empty():
				hud.fly_rewards(from, "credits", 5)
				hud.fly_rewards(from, "dna", 3)
				hud.show_rewards("Expedição concluída!", r))
		side.add_child(b)
	elif ExpeditionManager.is_active(e.id):
		card.set_meta("state", "running")
		side.add_child(UIKit.label("Em andamento", "BodyLabel", UITheme.GOLD))
		var bar := UIKit.progress("BarTime", 18, ExpeditionManager.progress(e.id), 1.0)
		bar.name = "Bar"
		side.add_child(bar)
		var t := UIKit.label(GameEnums.format_time(ExpeditionManager.time_left(e.id)), "ValueLabel")
		t.name = "Time"
		side.add_child(t)
	else:
		var reason := ExpeditionManager.check_start(e)
		var locked := Economy.player_level < e.unlock_player_level
		var b := UIKit.button("Iniciar  %d" % e.cost_credits, "lock" if locked else "expedition", "ButtonBlue", Vector2(220, 64))
		b.disabled = reason != ""
		b.pressed.connect(func():
			if ExpeditionManager.start(e):
				hud.show_toast("Equipe enviada para %s!" % e.display_name, "expedition", "good"))
		side.add_child(b)
		if reason != "":
			var r := UIKit.wrap_label(reason, "SmallLabel", 200)
			r.add_theme_color_override("font_color", UITheme.BAD)
			side.add_child(r)
	h.add_child(side)
	card.add_child(h)
	return card
