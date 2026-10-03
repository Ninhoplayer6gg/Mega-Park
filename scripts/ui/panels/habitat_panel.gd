extends GamePanel
## Habitat details: residents, production collection, adding creatures from storage, removal.

var building: BuildingInstance
var _list: VBoxContainer
var _collect: Button
var _cap_label: Label


func configure() -> void:
	title = building.data.display_name
	icon_name = "creatures"
	desired_size = Vector2(860, 600)


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
	GameClock.tick.connect(_update_collect)


func refresh() -> void:
	var residents := CreatureRoster.in_habitat(building.uid)
	_cap_label.text = "Criaturas: %d / %d" % [residents.size(), building.data.habitat_capacity]
	UIKit.clear(_list)
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
	h.add_child(CreaturePortrait.make(c.data, Vector2(110, 72)))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox(8)
	top.add_child(UIKit.label(c.display_name(), "ValueLabel"))
	top.add_child(UIKit.rarity_badge(c.data.rarity))
	v.add_child(top)
	v.add_child(UIKit.label("Nível %d · +%d créditos / %ds" % [c.level, c.income_per_cycle(), int(c.data.income_interval)], "SmallLabel"))
	h.add_child(v)
	var see := UIKit.button("Ver", "info", "ButtonBlue", Vector2(110, 56))
	see.pressed.connect(func(): hud.open_creature(c, true))
	h.add_child(see)
	card.add_child(h)
	return card


func _storage_row(c: CreatureInstance) -> Control:
	var card := UIKit.panel("CardSelected")
	var h := UIKit.hbox(12)
	h.add_child(CreaturePortrait.make(c.data, Vector2(110, 72)))
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
