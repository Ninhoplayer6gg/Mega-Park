class_name BuildBar
extends PanelContainer
## Confirm/cancel bar shown while placing a building.

var hud: Hud
var _name: Label
var _hint: Label
var _cost: HBoxContainer
var _confirm: Button
var _cancel: Button
var _pic: TextureRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -10
	custom_minimum_size = Vector2(620, 0)
	var h := UIKit.hbox(12)
	_pic = UIKit.texture(null, Vector2(64, 64))
	h.add_child(_pic)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = UIKit.label("", "HeaderLabel")
	v.add_child(_name)
	_cost = UIKit.hbox(8)
	v.add_child(_cost)
	_hint = UIKit.label("", "SmallLabel")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 280
	v.add_child(_hint)
	h.add_child(v)
	_cancel = UIKit.button("", "close", "ButtonRed", Vector2(76, 72))
	_cancel.pressed.connect(func(): hud.park.build_controller.stop())
	h.add_child(_cancel)
	_confirm = UIKit.button("", "check", "ButtonGreen", Vector2(76, 72))
	_confirm.pressed.connect(func(): hud.park.build_controller.confirm())
	h.add_child(_confirm)
	add_child(h)


func update_preview(data: BuildingData, reason: String) -> void:
	if data == null:
		return
	_name.text = data.display_name
	_pic.texture = BuildMenu.preview_texture(data)
	UIKit.clear(_cost)
	_cost.add_child(UIKit.cost_row(data.cost_credits, 0, data.energy_use, "BodyLabel"))
	if reason != "":
		_hint.text = reason
		_hint.add_theme_color_override("font_color", UITheme.BAD)
	elif data.connects:
		_hint.text = "Toque nas casas para construir. Arraste para mover a câmera. Botão vermelho conclui."
		_hint.add_theme_color_override("font_color", UITheme.GOOD)
	else:
		_hint.text = "Toque no mapa para posicionar e confirme no botão verde."
		_hint.add_theme_color_override("font_color", UITheme.GOOD)
	_confirm.visible = not data.connects
	_confirm.disabled = reason != ""
