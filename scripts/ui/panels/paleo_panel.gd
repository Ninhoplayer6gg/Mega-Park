extends GamePanel
## Centro Paleontológico: rebuilds extinct species from fossil fragments.
## RESTAURAÇÃO PURA (all fragments, 100% purity) or RECONSTRUÇÃO ASSISTIDA (half the fragments +
## Âmbar Antigo + DNA of a compatible species, lower purity).

var building: BuildingInstance
var _content: VBoxContainer
var _state := ""
var _bar: ProgressBar
var _time_label: Label


func configure() -> void:
	title = building.data.display_name if building else "Centro Paleontológico"
	icon_name = "paleo"
	desired_size = Vector2(1060, 620)


func build() -> void:
	_content = UIKit.vbox(10)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	GeneticsManager.genetics_changed.connect(func():
		if is_inside_tree():
			refresh())
	GameClock.tick.connect(_on_tick)
	refresh()


func _current_state() -> String:
	if GeneticsManager.restoration(building.uid).is_empty():
		return "idle"
	return "ready" if GeneticsManager.restoration_ready(building.uid) else "running"


func _on_tick() -> void:
	if not is_inside_tree():
		return
	var s := _current_state()
	if s != _state:
		refresh()
	elif s == "running" and _bar:
		var r := GeneticsManager.restoration(building.uid)
		_bar.value = clampf((GameClock.now() - float(r.start)) / float(r.duration), 0.0, 1.0)
		_time_label.text = "Tempo restante: %s" % GameEnums.format_time(maxf(float(r.start) + float(r.duration) - GameClock.now(), 0.0))


func refresh() -> void:
	_state = _current_state()
	UIKit.clear(_content)
	if _state == "idle":
		_build_list()
	else:
		_build_job()


func _build_list() -> void:
	_content.add_child(UIKit.wrap_label("Fragmentos fósseis chegam de expedições (Geleira Eterna, Vale Primordial). Com todos os fragmentos, a restauração é pura; com metade, o centro completa o genoma com Âmbar Antigo e DNA de uma espécie compatível.", "BodyLabel", 600))
	var sc := UIKit.scroll()
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	sc.add_child(flow)
	_content.add_child(sc)
	for s in GeneticsManager.restorable_species():
		flow.add_child(_species_card(s))


func _species_card(s: CreatureData) -> Control:
	var frags := int(GeneticsManager.fossils.get(s.id, 0))
	var known := CreatureRoster.is_discovered(s.id) or frags > 0
	var p := UIKit.panel("Card")
	p.custom_minimum_size = Vector2(460, 0)
	var v := UIKit.vbox(6)
	var h := UIKit.hbox(10)
	h.add_child(CreaturePortrait.make(s, Vector2(190, 120), not CreatureRoster.is_discovered(s.id)))
	var info := UIKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(s.display_name if known else "Fóssil desconhecido", "ValueLabel"))
	info.add_child(UIKit.label(s.archive_code, "SmallLabel"))
	var fr := UIKit.hbox(6)
	fr.add_child(UIKit.icon("fossil", 24))
	var bar := UIKit.progress("BarTime", 12, minf(frags, s.fossil_fragments_required), s.fossil_fragments_required)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fr.add_child(bar)
	fr.add_child(UIKit.label("%d/%d" % [frags, s.fossil_fragments_required], "ValueLabel"))
	info.add_child(fr)
	h.add_child(info)
	v.add_child(h)
	var row := UIKit.hbox(8)
	for mode in [&"pure", &"assisted"]:
		var reason := GeneticsManager.check_restoration(s, mode, building.uid)
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var text := "Restauração pura" if mode == &"pure" else "Reconstrução assistida"
		var b := UIKit.button(text, "fossil" if mode == &"pure" else "mat_amber", "ButtonGreen" if mode == &"pure" else "ButtonBlue", Vector2(0, 56))
		b.disabled = reason != ""
		var m: StringName = mode
		b.pressed.connect(func():
			if GeneticsManager.start_restoration(building.uid, s, m):
				hud.show_toast("Restauração iniciada!", "fossil", "good")
				refresh())
		col.add_child(b)
		var detail := "Pureza 100%" if mode == &"pure" else "Pureza ~%d%% · 1 Âmbar + %d DNA compatível" % [int(GeneticsManager.assisted_purity(s)), GeneticsManager.ASSISTED_DNA]
		col.add_child(UIKit.wrap_label(detail, "SmallLabel", 180))
		if reason != "":
			var rl := UIKit.wrap_label(reason, "SmallLabel", 180)
			rl.add_theme_color_override("font_color", UITheme.BAD)
			col.add_child(rl)
		row.add_child(col)
	v.add_child(row)
	p.add_child(v)
	return p


func _build_job() -> void:
	var r := GeneticsManager.restoration(building.uid)
	var s := DataRegistry.get_creature(StringName(r.species))
	var center := UIKit.vbox(10)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(UIKit.label("Restaurando %s" % s.display_name if _state == "running" else "Genoma reconstruído!", "TitleLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	var portrait := CreaturePortrait.make(s, Vector2(360, 200), _state == "running")
	center.add_child(UIKit.centered(portrait))
	center.add_child(UIKit.label(("Restauração pura" if r.mode == "pure" else "Reconstrução assistida") + " · Pureza %d%%" % int(round(float(r.purity))), "BodyLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	if _state == "running":
		_bar = UIKit.progress("BarTime", 22, 0.0, 1.0)
		_bar.custom_minimum_size.x = 420
		_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		center.add_child(_bar)
		_time_label = UIKit.label("", "ValueLabel", null, HORIZONTAL_ALIGNMENT_CENTER)
		center.add_child(_time_label)
		_on_tick()
	else:
		var btn := UIKit.button("Concluir restauração", "fossil", "ButtonGreen", Vector2(360, 72))
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func():
			btn.disabled = true
			var c := GeneticsManager.collect_restoration(building.uid)
			if c:
				hud.close_all()
				hud.open_habitat_picker(c, false))
		center.add_child(btn)
	_content.add_child(center)
