extends GamePanel
## Owned creatures + bestiary with category filters. Undiscovered species show as silhouettes.

var tab := "owned"
var filter: StringName = &"all"
var _tabs: HBoxContainer
var _filters: HFlowContainer
var _grid: HFlowContainer


func configure() -> void:
	title = "Criaturas"
	icon_name = "creatures"
	desired_size = Vector2(1100, 640)


func build() -> void:
	_tabs = UIKit.hbox(8)
	body.add_child(_tabs)
	_filters = HFlowContainer.new()
	_filters.add_theme_constant_override("h_separation", 6)
	_filters.add_theme_constant_override("v_separation", 6)
	body.add_child(_filters)
	var sc := UIKit.scroll()
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(_grid)
	body.add_child(sc)
	refresh()


func refresh() -> void:
	UIKit.clear(_tabs)
	for t in [["owned", "Minhas (%d)" % CreatureRoster.count(), "creatures"], ["bestiary", "Bestiário", "research"]]:
		var b := UIKit.button(t[1], t[2], "TabButton", Vector2(0, 52))
		b.toggle_mode = true
		b.button_pressed = tab == t[0]
		b.pressed.connect(func():
			tab = t[0]
			refresh())
		_tabs.add_child(b)
	UIKit.clear(_filters)
	var cats := [[&"all", "Todas"]]
	for k in GameEnums.CATEGORIES:
		cats.append([k, GameEnums.CATEGORIES[k]])
	for c in cats:
		var b := UIKit.button(c[1], "", "TabButton", Vector2(0, 44))
		b.add_theme_font_size_override("font_size", 16)
		b.toggle_mode = true
		b.button_pressed = filter == c[0]
		b.pressed.connect(func():
			filter = c[0]
			refresh())
		_filters.add_child(b)
	UIKit.clear(_grid)
	if tab == "owned":
		var list := CreatureRoster.all().filter(func(c): return filter == &"all" or c.data.category == filter)
		if list.is_empty():
			_grid.add_child(UIKit.wrap_label("Nenhuma criatura aqui ainda. Construa uma Incubadora e incube sua primeira criatura!", "BodyLabel", 500))
		for c in list:
			_grid.add_child(_owned_card(c))
	else:
		var species_list := DataRegistry.creature_list().filter(func(d): return filter == &"all" or d.category == filter)
		if species_list.is_empty():
			_grid.add_child(UIKit.wrap_label("Nenhuma espécie desta categoria foi catalogada ainda. Novos setores do parque trarão novas criaturas.", "BodyLabel", 500))
		for d in species_list:
			_grid.add_child(_species_card(d))


func _base_card(variation := "ButtonDark") -> Array:
	var b := Button.new()
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(240, 230)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	UIKit.add_press_feedback(b)
	var v := UIKit.vbox(3)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 8
	v.offset_bottom = -14
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	return [b, v]


func _owned_card(c: CreatureInstance) -> Control:
	var parts := _base_card()
	var v: VBoxContainer = parts[1]
	v.add_child(CreaturePortrait.make(c.data, Vector2(220, 110)))
	v.add_child(UIKit.label(c.display_name(), "ValueLabel"))
	var row := UIKit.hbox(6)
	row.add_child(UIKit.icon_value("star", "Nv %d" % c.level, "BodyLabel", 18))
	row.add_child(UIKit.rarity_badge(c.data.rarity))
	v.add_child(row)
	var where := "No habitat" if c.state == &"habitat" else "No abrigo"
	v.add_child(UIKit.label("%s · %s" % [c.data.category_name(), where], "SmallLabel"))
	parts[0].pressed.connect(func(): hud.open_creature(c, true))
	return parts[0]


func _species_card(d: CreatureData) -> Control:
	var known := CreatureRoster.is_discovered(d.id)
	var parts := _base_card()
	var v: VBoxContainer = parts[1]
	v.add_child(CreaturePortrait.make(d, Vector2(220, 110), not known, known))
	v.add_child(UIKit.label(d.display_name if known else "???", "ValueLabel"))
	var row := UIKit.hbox(6)
	row.add_child(UIKit.rarity_badge(d.rarity))
	if known and CreatureRoster.owns_species(d.id):
		row.add_child(UIKit.icon("check", 20))
	v.add_child(row)
	v.add_child(UIKit.label(d.category_name() if known else "Não descoberta", "SmallLabel"))
	parts[0].pressed.connect(func():
		if known:
			hud.open_panel("creature", {"species": d, "stack": true})
		else:
			EventBus.toast("Espécie desconhecida. Pesquise ou explore para descobri-la.", "unknown", "info"))
	return parts[0]
