class_name BuildMenu
extends PanelContainer
## Bottom sheet listing every buildable BuildingData as a card.

var hud: Hud
var _list: HBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 10
	offset_right = -10
	offset_bottom = -8
	var v := UIKit.vbox(8)
	var header := UIKit.hbox(10)
	header.add_child(UIKit.icon("build", 32))
	var t := UIKit.label("Construir", "TitleLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	var close_btn := UIKit.button("", "close", "ButtonRed", Vector2(60, 52))
	close_btn.pressed.connect(func(): hud.close_build_menu())
	header.add_child(close_btn)
	v.add_child(header)
	var sc := UIKit.scroll(false)
	sc.custom_minimum_size.y = 236
	_list = UIKit.hbox(10)
	sc.add_child(_list)
	v.add_child(sc)
	add_child(v)
	Economy.resources_changed.connect(func():
		if visible:
			_rebuild())
	ParkState.buildings_changed.connect(func():
		if visible:
			_rebuild())


func open() -> void:
	visible = true
	_rebuild()
	modulate.a = 0.0
	position.y += 40
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(self, "position:y", position.y - 40, 0.2).set_ease(Tween.EASE_OUT)


static func preview_texture(data: BuildingData) -> Texture2D:
	if data.icon:
		return data.icon
	if data.sprite == null:
		return DataRegistry.icon("build")
	if data.hframes <= 1:
		return data.sprite
	var at := AtlasTexture.new()
	at.atlas = data.sprite
	var fw := data.sprite.get_width() / data.hframes
	var frame_i: int = int(data.params.get("preview_frame", 0))
	at.region = Rect2(fw * frame_i, 0, fw, data.sprite.get_height())
	return at


func _rebuild() -> void:
	UIKit.clear(_list)
	for data in DataRegistry.buildable_list():
		_list.add_child(_card(data))


func _card(data: BuildingData) -> Control:
	var rule := ParkState.check_rules(data)
	var affordable := Economy.can_afford(data.cost_credits)
	var b := Button.new()
	b.theme_type_variation = "ButtonDark"
	b.custom_minimum_size = Vector2(176, 226)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	UIKit.add_press_feedback(b)
	var v := UIKit.vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 8
	v.offset_bottom = -14
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := UIKit.label(data.display_name, "BodyLabel", null, HORIZONTAL_ALIGNMENT_CENTER)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size.y = 44
	v.add_child(name_l)
	var pic := UIKit.texture(preview_texture(data), Vector2(150, 88))
	v.add_child(pic)
	var size_l := UIKit.label("%dx%d" % [data.size.x, data.size.y], "SmallLabel", null, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(size_l)
	var cost := UIKit.cost_row(data.cost_credits, 0, data.energy_use, "BodyLabel")
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	if not affordable:
		cost.modulate = Color(1, 0.6, 0.6)
	v.add_child(cost)
	if data.energy_output > 0:
		var out := UIKit.icon_value("energy", "+%d" % data.energy_output, "BodyLabel", 18)
		out.alignment = BoxContainer.ALIGNMENT_CENTER
		out.modulate = UITheme.GOOD
		v.add_child(out)
	if rule != "":
		var lock := UIKit.label(rule, "SmallLabel", UITheme.BAD, HORIZONTAL_ALIGNMENT_CENTER)
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lock)
		pic.modulate = Color(0.4, 0.4, 0.45)
	b.add_child(v)
	b.tooltip_text = data.description
	b.pressed.connect(func():
		if rule != "":
			EventBus.toast(rule, "lock", "bad")
			AudioManager.play_sfx(&"error")
		elif not affordable:
			EventBus.toast("Créditos insuficientes.", "credits", "bad")
			AudioManager.play_sfx(&"error")
		else:
			hud.start_build(data))
	return b
