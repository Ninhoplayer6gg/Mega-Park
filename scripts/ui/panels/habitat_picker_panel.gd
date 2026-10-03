extends GamePanel
## Choose where a creature lives (or send it to storage).

var creature: CreatureInstance


func configure() -> void:
	title = "Escolher habitat"
	icon_name = "move"
	desired_size = Vector2(820, 560)


func build() -> void:
	var head := UIKit.hbox(12)
	head.add_child(CreaturePortrait.make(creature.data, Vector2(130, 90)))
	var v := UIKit.vbox(2)
	v.add_child(UIKit.label(creature.display_name(), "HeaderLabel"))
	var ht := DataRegistry.get_habitat_type(creature.data.habitat_type)
	v.add_child(UIKit.label("Precisa de: %s" % (ht.display_name if ht else "?"), "BodyLabel", UITheme.GOLD))
	head.add_child(v)
	body.add_child(head)
	var sc := UIKit.scroll()
	var list := UIKit.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	body.add_child(sc)
	var habitats := ParkState.habitats()
	var any := false
	for b in habitats:
		var reason := CreatureRoster.check_assign(creature, b.uid)
		var here: bool = creature.state == &"habitat" and creature.habitat_uid == b.uid
		if b.data.habitat_type != creature.data.habitat_type:
			continue
		any = true
		var card := UIKit.panel("Card")
		var h := UIKit.hbox(12)
		h.add_child(UIKit.texture(BuildMenu.preview_texture(b.data), Vector2(64, 64)))
		var info := UIKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.label(b.data.display_name, "ValueLabel"))
		var count := CreatureRoster.in_habitat(b.uid).size()
		info.add_child(UIKit.label("Ocupação %d / %d" % [count, b.data.habitat_capacity], "SmallLabel"))
		h.add_child(info)
		var btn := UIKit.button("Aqui" if not here else "Atual", "check", "ButtonGreen", Vector2(150, 56))
		btn.disabled = here or reason != ""
		btn.pressed.connect(_assign.bind(b))
		h.add_child(btn)
		card.add_child(h)
		list.add_child(card)
	if not any:
		var msg := UIKit.wrap_label("Nenhum %s construído ainda. Construa um para abrigar esta criatura — ela fica guardada no abrigo até lá." % (ht.display_name if ht else "habitat"), "BodyLabel", 500)
		list.add_child(msg)
		var build_btn := UIKit.button("Construir habitat", "build", "ButtonAmber", Vector2(280, 60))
		build_btn.pressed.connect(func():
			hud.close_panel()
			hud.open_build_menu())
		list.add_child(build_btn)
	var bottom := UIKit.hbox(10)
	bottom.add_child(UIKit.spacer())
	var store := UIKit.button("Guardar no abrigo", "save", "ButtonDark", Vector2(260, 56))
	store.disabled = creature.state == &"storage"
	store.pressed.connect(func():
		CreatureRoster.move_to_storage(creature)
		close())
	bottom.add_child(store)
	body.add_child(bottom)


func _assign(b: BuildingInstance) -> void:
	if CreatureRoster.assign_to_habitat(creature, b.uid):
		AudioManager.play_sfx(&"purchase")
		hud.show_toast("%s agora vive no %s!" % [creature.display_name(), b.data.display_name], "creatures", "good")
		hud.close_all()
		hud.park.focus_building(b.uid, 2.5)
