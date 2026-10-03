extends GamePanel
## Generic building info (generator, fences, gates, entrance...).

var building: BuildingInstance


func configure() -> void:
	title = building.data.display_name
	icon_name = "build"
	desired_size = Vector2(720, 420)


func build() -> void:
	var data := building.data
	var h := UIKit.hbox(16)
	var stage := UIKit.panel("Inset")
	stage.add_child(UIKit.texture(BuildMenu.preview_texture(data), Vector2(160, 160)))
	h.add_child(stage)
	var v := UIKit.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.wrap_label(data.description, "BodyLabel", 300))
	if data.energy_output > 0:
		v.add_child(UIKit.icon_value("energy", "Gera +%d de energia" % data.energy_output, "ValueLabel"))
	if data.energy_use > 0:
		v.add_child(UIKit.icon_value("energy", "Consome %d de energia" % data.energy_use, "ValueLabel"))
	v.add_child(UIKit.icon_value("energy", "Energia do parque: %d livres de %d" % [ParkState.energy_free(), ParkState.energy_capacity()], "SmallLabel", 18))
	v.add_child(UIKit.label("Tamanho: %dx%d" % [data.size.x, data.size.y], "SmallLabel"))
	h.add_child(v)
	body.add_child(h)
	body.add_child(UIKit.spacer(false))
	if data.removable:
		var row := UIKit.hbox(10)
		row.add_child(UIKit.spacer())
		var refund := int(data.cost_credits * data.refund_ratio)
		var remove := UIKit.button("Remover (+%d)" % refund, "sell", "ButtonRed", Vector2(220, 56))
		remove.pressed.connect(func():
			var reason := ParkState.check_removal(building)
			if reason != "":
				EventBus.toast(reason, "lock", "bad")
				AudioManager.play_sfx(&"error")
			elif not remove.has_meta("armed"):
				remove.set_meta("armed", true)
				remove.text = "Confirmar?"
			elif ParkState.remove(building.uid):
				AudioManager.play_sfx(&"coin")
				close())
		row.add_child(remove)
		body.add_child(row)
