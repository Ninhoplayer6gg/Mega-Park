extends GamePanel
## Incubator flow: choose species -> pay DNA -> timer -> hatch -> choose habitat.

var building: BuildingInstance
var _content: VBoxContainer
var _state := ""
var _time_label: Label
var _bar: ProgressBar
var _egg: TextureRect


func configure() -> void:
	title = "Incubadora"
	icon_name = "egg"
	desired_size = Vector2(980, 600)


func build() -> void:
	_content = UIKit.vbox(10)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	refresh()
	GameClock.tick.connect(_on_tick)
	IncubationManager.slots_changed.connect(refresh)


func _current_state() -> String:
	if not IncubationManager.has_slot(building.uid):
		return "idle"
	return "ready" if IncubationManager.is_ready(building.uid) else "running"


func _on_tick() -> void:
	if not is_inside_tree() or _state == "hatched":
		return
	var s := _current_state()
	if s != _state:
		refresh()
	elif s == "running":
		_bar.value = IncubationManager.progress(building.uid)
		_time_label.text = "Tempo restante: %s" % GameEnums.format_time(IncubationManager.time_left(building.uid))


func refresh() -> void:
	if _state == "hatched":
		return
	_state = _current_state()
	UIKit.clear(_content)
	match _state:
		"idle":
			_build_idle()
		"running":
			_build_running()
		"ready":
			_build_ready()


func _build_idle() -> void:
	_content.add_child(UIKit.label("Escolha uma espécie para incubar. O DNA é consumido no início.", "BodyLabel"))
	var sc := UIKit.scroll()
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for species in DataRegistry.creature_list():
		grid.add_child(_species_card(species))
	sc.add_child(grid)
	_content.add_child(sc)


func _species_card(species: CreatureData) -> Control:
	var discovered := CreatureRoster.is_discovered(species.id)
	var reason := IncubationManager.check_species(species)
	var b := Button.new()
	b.theme_type_variation = "ButtonDark"
	b.custom_minimum_size = Vector2(280, 270)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	UIKit.add_press_feedback(b)
	var v := UIKit.vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 8
	v.offset_bottom = -14
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := UIKit.hbox(6)
	top.add_child(UIKit.label(species.display_name if discovered else "???", "ValueLabel"))
	top.add_child(UIKit.spacer())
	top.add_child(UIKit.rarity_badge(species.rarity))
	v.add_child(top)
	var pic := UIKit.hbox(4)
	pic.add_child(CreaturePortrait.make(species, Vector2(190, 110), not discovered))
	if discovered and species.egg_texture:
		pic.add_child(UIKit.texture(species.egg_texture, Vector2(48, 60)))
	v.add_child(pic)
	if discovered:
		var info := UIKit.hbox(14)
		var dna := UIKit.icon_value("dna", str(species.dna_cost), "ValueLabel", 22)
		if Economy.dna < species.dna_cost:
			dna.modulate = Color(1, 0.55, 0.55)
		info.add_child(dna)
		info.add_child(UIKit.icon_value("time", GameEnums.format_time(species.incubation_time), "ValueLabel", 22))
		v.add_child(info)
		v.add_child(UIKit.label(species.category_name(), "SmallLabel"))
	else:
		v.add_child(UIKit.wrap_label("Espécie desconhecida. Descubra-a pesquisando ou em expedições.", "SmallLabel", 240))
	if reason != "" and discovered:
		var r := UIKit.wrap_label(reason, "SmallLabel", 240)
		r.add_theme_color_override("font_color", UITheme.BAD)
		v.add_child(r)
	b.add_child(v)
	b.pressed.connect(func():
		if IncubationManager.start(building.uid, species):
			hud.show_toast("Incubando %s!" % species.display_name, "egg", "good")
			refresh())
	return b


func _build_running() -> void:
	var species := IncubationManager.species_in(building.uid)
	var center := UIKit.vbox(12)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(UIKit.label("Incubando: %s" % species.display_name, "HeaderLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	_egg = UIKit.texture(species.egg_texture, Vector2(140, 170))
	center.add_child(_egg)
	_wobble(_egg, 0.08, 0.5)
	_bar = UIKit.progress("BarTime", 22, IncubationManager.progress(building.uid), 1.0)
	_bar.custom_minimum_size.x = 420
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(_bar)
	_time_label = UIKit.label("Tempo restante: %s" % GameEnums.format_time(IncubationManager.time_left(building.uid)), "ValueLabel", null, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(_time_label)
	center.add_child(UIKit.label("Você pode fechar esta janela; a incubação continua.", "SmallLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	_content.add_child(center)


func _build_ready() -> void:
	var species := IncubationManager.species_in(building.uid)
	var center := UIKit.vbox(12)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(UIKit.label("O ovo vai chocar!", "TitleLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	_egg = UIKit.texture(species.egg_texture, Vector2(140, 170))
	center.add_child(_egg)
	_wobble(_egg, 0.2, 0.09)
	var btn := UIKit.button("Chocar e coletar", "egg", "ButtonGreen", Vector2(320, 72))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_hatch.bind(btn))
	center.add_child(btn)
	_content.add_child(center)


func _wobble(node: Control, amount: float, speed: float) -> void:
	node.resized.connect(func(): node.pivot_offset = node.size * Vector2(0.5, 0.9))
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "rotation", amount, speed).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "rotation", -amount, speed).set_trans(Tween.TRANS_SINE)


func _hatch(btn: Button) -> void:
	btn.disabled = true
	var tw := _egg.create_tween()
	tw.tween_property(_egg, "scale", Vector2(1.3, 0.8), 0.12)
	tw.tween_property(_egg, "scale", Vector2(0.9, 1.25), 0.12)
	tw.tween_property(_egg, "modulate", Color(3, 3, 3, 1), 0.15)
	await tw.finished
	_state = "hatched"
	var c := IncubationManager.collect(building.uid)
	if c == null:
		_state = ""
		refresh()
		return
	UIKit.clear(_content)
	var center := UIKit.vbox(10)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(UIKit.label("Nasceu: %s!" % c.data.display_name, "TitleLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	var portrait := CreaturePortrait.make(c.data, Vector2(320, 200))
	center.add_child(portrait)
	var badge := UIKit.rarity_badge(c.data.rarity)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(badge)
	var choose := UIKit.button("Escolher habitat", "move", "ButtonGreen", Vector2(320, 72))
	choose.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	choose.pressed.connect(func(): hud.open_habitat_picker(c, false))
	center.add_child(choose)
	_content.add_child(center)
	portrait.scale = Vector2(0.2, 0.2)
	portrait.resized.connect(func(): portrait.pivot_offset = portrait.size * 0.5)
	var pop := portrait.create_tween()
	pop.tween_property(portrait, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx(c.data.cry_sfx, 0.0, -4.0)
