extends GamePanel
## Habitat details: residents (happiness and relations), ecosystem features, production
## collection, adding creatures from storage, removal.

var building: BuildingInstance
var tab := "residents"
var _tabs: HBoxContainer
var _list: VBoxContainer
var _collect: Button
var _cap_label: Label


func configure() -> void:
	title = building.data.display_name
	icon_name = "creatures"
	desired_size = Vector2(980, 620)


func build() -> void:
	var top := UIKit.hbox(12)
	_cap_label = UIKit.label("", "HeaderLabel")
	top.add_child(_cap_label)
	top.add_child(UIKit.spacer())
	_collect = UIKit.button("Coletar", "credits", "ButtonAmber", Vector2(220, 60))
	_collect.pressed.connect(_on_collect)
	top.add_child(_collect)
	body.add_child(top)
	var ht := DataRegistry.get_habitat_type(building.data.habitat_type)
	if ht:
		body.add_child(UIKit.wrap_label(ht.description, "SmallLabel", 400))
	_tabs = UIKit.hbox(8)
	body.add_child(_tabs)
	var sc := UIKit.scroll()
	_list = UIKit.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	body.add_child(sc)
	var bottom := UIKit.hbox(10)
	bottom.add_child(UIKit.spacer())
	var remove := UIKit.button("Remover", "sell", "ButtonRed", Vector2(170, 56))
	remove.pressed.connect(_on_remove.bind(remove))
	bottom.add_child(remove)
	body.add_child(bottom)
	refresh()
	CreatureRoster.roster_changed.connect(refresh)
	ParkState.buildings_changed.connect(func():
		if is_inside_tree():
			refresh())
	GameClock.tick.connect(_update_collect)


func refresh() -> void:
	var residents := CreatureRoster.in_habitat(building.uid)
	_cap_label.text = "Criaturas: %d / %d" % [residents.size(), building.data.habitat_capacity]
	UIKit.clear(_tabs)
	_tabs.add_child(UIKit.tabs([["residents", "Residentes", "creatures"], ["eco", "Ecossistema (%d/%d)" % [ParkState.habitat_upgrades(building).size(), DataRegistry.habitat_upgrades.size()], "tree"]],
		tab, func(id: String):
			tab = id
			refresh(), 48))
	UIKit.clear(_list)
	if tab == "eco":
		_build_eco(residents)
		_update_collect()
		return
	for c in residents:
		_list.add_child(_resident_row(c))
	var free := building.data.habitat_capacity - residents.size()
	if free > 0:
		var candidates := CreatureRoster.in_storage().filter(func(c): return c.data.habitat_type == building.data.habitat_type)
		for c in candidates:
			_list.add_child(_storage_row(c))
		for i in free:
			var empty := UIKit.panel("Inset")
			var h := UIKit.hbox(10)
			h.add_child(UIKit.icon("plus", 28))
			h.add_child(UIKit.label("Vaga livre — incube uma criatura compatível na Incubadora.", "SmallLabel"))
			empty.add_child(h)
			_list.add_child(empty)
	_update_collect()


func _update_collect() -> void:
	var pending := CreatureRoster.habitat_pending(building.uid)
	_collect.text = "Coletar %d" % pending
	_collect.disabled = pending <= 0


func _resident_row(c: CreatureInstance) -> Control:
	var card := UIKit.panel("Card")
	var h := UIKit.hbox(12)
	h.add_child(CreaturePortrait.of_creature(c, Vector2(110, 72)))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox(8)
	top.add_child(UIKit.label(c.display_name(), "ValueLabel"))
	top.add_child(UIKit.rarity_badge(c.data.rarity))
	v.add_child(top)
	v.add_child(UIKit.label("Nível %d · +%d créditos / %ds" % [c.level, c.income_per_cycle(), int(c.data.income_interval)], "SmallLabel"))
	var mood := UIKit.hbox(10)
	var h_val := SocialLogic.happiness(c)
	mood.add_child(UIKit.resource_chip("happy" if h_val >= 50 else "stress", "Felicidade %d" % int(round(h_val)), h_val >= 40, 18))
	mood.add_child(UIKit.label("x%s produção" % String.num(SocialLogic.production_multiplier(c), 2), "SmallLabel"))
	var tense := CreatureRoster.relations_in(c, building.uid).filter(func(r): return r.relation.kind in [&"predatory", &"territorial", &"incompatible"])
	if not tense.is_empty():
		mood.add_child(UIKit.label("Tensão com %s" % tense[0].creature.display_name(), "SmallLabel", UITheme.BAD))
	v.add_child(mood)
	h.add_child(v)
	var see := UIKit.button("Ver", "info", "ButtonBlue", Vector2(110, 56))
	see.pressed.connect(func(): hud.open_creature(c, true))
	h.add_child(see)
	card.add_child(h)
	return card


func _storage_row(c: CreatureInstance) -> Control:
	var card := UIKit.panel("CardSelected")
	var h := UIKit.hbox(12)
	h.add_child(CreaturePortrait.of_creature(c, Vector2(110, 72)))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(c.display_name(), "ValueLabel"))
	v.add_child(UIKit.label("No abrigo · Nível %d" % c.level, "SmallLabel"))
	h.add_child(v)
	var add := UIKit.button("Adicionar", "plus", "ButtonGreen", Vector2(160, 56))
	add.pressed.connect(func():
		if CreatureRoster.assign_to_habitat(c, building.uid):
			AudioManager.play_sfx(&"purchase"))
	h.add_child(add)
	card.add_child(h)
	return card


func _build_eco(residents: Array) -> void:
	var needs := {}
	for c in residents:
		for n in c.data.needs:
			needs[n] = true
	var installed: Array = ParkState.habitat_upgrades(building)
	var info := "Recursos do ecossistema deixam as criaturas mais felizes, e criaturas felizes produzem mais."
	if not needs.is_empty():
		var kinds := {}
		for uid in installed:
			var u: HabitatUpgradeData = DataRegistry.habitat_upgrades.get(StringName(uid))
			if u:
				kinds[u.kind] = true
		var missing := needs.keys().filter(func(n): return not kinds.has(n))
		info += " Necessidades dos residentes atendidas: %d/%d." % [needs.size() - missing.size(), needs.size()]
	_list.add_child(UIKit.wrap_label(info, "BodyLabel", 500))
	for u in DataRegistry.habitat_upgrades.values():
		var have := installed.has(String(u.id))
		var card := UIKit.panel("CardSelected" if have else "Card")
		var h := UIKit.hbox(12)
		var tex: Texture2D = u.texture_for(building.data.habitat_type)
		h.add_child(UIKit.texture(tex, Vector2(96, 64)) if tex else UIKit.icon(u.icon_name, 48))
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_row := UIKit.hbox(8)
		title_row.add_child(UIKit.label(u.display_name, "ValueLabel"))
		if needs.has(u.kind):
			title_row.add_child(UIKit.tag("NECESSÁRIO", UITheme.GOLD))
		v.add_child(title_row)
		v.add_child(UIKit.wrap_label(u.description, "SmallLabel", 300))
		h.add_child(v)
		if have:
			h.add_child(UIKit.tag("INSTALADO", UITheme.GOOD))
		else:
			var reason := ParkState.check_upgrade(building, u)
			var b := UIKit.button("Instalar  %s" % GameEnums.format_number(u.cost_credits), "build", "ButtonGreen", Vector2(220, 56))
			b.disabled = reason != ""
			b.pressed.connect(func():
				if ParkState.install_upgrade(building, u):
					hud.show_toast("%s instalado!" % u.display_name, "tree", "good")
					refresh())
			h.add_child(b)
		card.add_child(h)
		_list.add_child(card)


func _on_collect() -> void:
	var node: HabitatNode = hud.park.get_building_node(building.uid)
	var amount := 0
	if node:
		amount = hud.park.collect_habitat(node)
	else:
		amount = CreatureRoster.collect_habitat(building.uid)
	if amount > 0:
		hud.fly_rewards(_collect.global_position + _collect.size * 0.5, "credits", 6)
	_update_collect()


func _on_remove(btn: Button) -> void:
	var reason := ParkState.check_removal(building)
	if reason != "":
		EventBus.toast(reason, "lock", "bad")
		AudioManager.play_sfx(&"error")
		return
	if not btn.has_meta("armed"):
		btn.set_meta("armed", true)
		btn.text = "Confirmar?"
		return
	if ParkState.remove(building.uid):
		close()
