class_name PhotoMode
extends Control
## MODO FOTO: a viewfinder over the park. The camera can still be dragged and zoomed; the shutter
## photographs the best-framed creature, stores the picture in the album and grants rewards.

signal exited

var hud: Hud
var _finder: NinePatchRect
var _subject_label: Label
var _shutter: Button
var _ui: Array[Control] = []
var _result: Control
var _scan: Timer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finder = NinePatchRect.new()
	_finder.texture = load("res://assets/ui/frames/viewfinder.png")
	_finder.patch_margin_left = 20
	_finder.patch_margin_right = 20
	_finder.patch_margin_top = 20
	_finder.patch_margin_bottom = 20
	_finder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_finder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_finder)
	var top := UIKit.vbox(2)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 76
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(UIKit.label("MODO FOTO", "TitleLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	_subject_label = UIKit.label("", "ValueLabel", null, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_subject_label)
	add_child(top)
	_ui.append(top)
	var bottom := UIKit.hbox(16)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -12
	var exit_btn := UIKit.button("Sair", "close", "ButtonRed", Vector2(150, 72))
	exit_btn.pressed.connect(close)
	bottom.add_child(exit_btn)
	_shutter = UIKit.button("Fotografar", "camera", "ButtonAmber", Vector2(260, 84))
	_shutter.pressed.connect(take_photo)
	bottom.add_child(_shutter)
	add_child(bottom)
	_ui.append(bottom)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_scan = Timer.new()
	_scan.wait_time = 0.25
	_scan.autostart = true
	_scan.timeout.connect(_update_subject)
	add_child(_scan)
	_update_subject()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var s := Vector2(vp.x * 0.62, vp.y * 0.52)
	_finder.size = s
	_finder.position = (vp - s) * 0.5 + Vector2(0, 6)


func finder_rect() -> Rect2:
	return Rect2(_finder.position, _finder.size)


## Best creature inside the viewfinder: {"actor", "framing", "size_ratio"} or {}.
func best_subject() -> Dictionary:
	if hud == null or hud.park == null:
		return {}
	var ct: Transform2D = get_viewport().get_canvas_transform()
	var fr := finder_rect()
	var center := fr.get_center()
	var best := {}
	var best_score := -1.0
	for node in hud.park.building_nodes.values():
		if not node is HabitatNode:
			continue
		for actor in node.actors.values():
			var r: Rect2 = ct * actor.pick_rect()
			if not fr.has_point(r.get_center()):
				continue
			var framing := 1.0 - clampf(r.get_center().distance_to(center) / (fr.size.length() * 0.5), 0.0, 1.0)
			var size_ratio := r.size.y / fr.size.y
			var s := framing + minf(size_ratio, 0.6)
			if s > best_score:
				best_score = s
				best = {"actor": actor, "framing": framing, "size_ratio": size_ratio}
	return best


func _update_subject() -> void:
	if _result:
		return
	var b := best_subject()
	if b.is_empty():
		_subject_label.text = "Enquadre uma criatura no visor"
		_subject_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		_shutter.disabled = true
	else:
		var a: CreatureActor = b.actor
		_subject_label.text = "%s · %s" % [a.creature.display_name(), a.behavior_name()]
		_subject_label.add_theme_color_override("font_color", UITheme.GOLD if b.framing > 0.7 else UITheme.TEXT)
		_shutter.disabled = false


func take_photo() -> void:
	var b := best_subject()
	if b.is_empty() or _result:
		return
	var actor: CreatureActor = b.actor
	var behavior := actor.behavior
	var c := actor.creature
	_shutter.disabled = true
	# Hide every UI layer for the capture.
	visible = false
	var hud_was := hud.frame.visible
	hud.frame.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	hud.frame.visible = hud_was
	visible = true
	var scale_f := Vector2(img.get_size()) / get_viewport_rect().size
	var fr := finder_rect()
	var crop_rect := Rect2i(Vector2i(fr.position * scale_f), Vector2i(fr.size * scale_f))
	var file := PhotoStore.save(img, crop_rect)
	var result := PhotoLogic.evaluate(c, behavior, b.framing, b.size_ratio)
	var record := PhotoLogic.commit(c, behavior, result, file)
	AudioManager.play_sfx(&"ui_click", 0.0, 2.0)
	_flash()
	_show_result(c, behavior, result, record, file)


func _flash() -> void:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.9)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)


func _show_result(c: CreatureInstance, behavior: StringName, result: Dictionary, record: Dictionary, file: String) -> void:
	for u in _ui:
		u.visible = false
	_finder.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_result = dim
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := UIKit.panel("Paper")
	var v := UIKit.vbox(6)
	var tex := PhotoStore.load_thumbnail(file)
	if tex:
		v.add_child(UIKit.texture(tex, Vector2(minf(480, get_viewport_rect().size.x - 80), 250)))
	v.add_child(UIKit.label(c.display_name(), "HeaderLabel", UITheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(GameEnums.BEHAVIORS.get(behavior, ""), "DarkLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
	var stars := UIKit.hbox(4)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var st := UIKit.icon("star", 32)
		st.modulate = Color.WHITE if i < int(result.stars) else Color(0.3, 0.3, 0.35)
		stars.add_child(st)
	v.add_child(stars)
	var rw := UIKit.hbox(16)
	rw.alignment = BoxContainer.ALIGNMENT_CENTER
	var cr := UIKit.icon_value("credits", "+%d" % int(result.credits), "DarkLabel", 24)
	rw.add_child(cr)
	rw.add_child(UIKit.icon_value("rp", "+%d" % int(record.get("rp_gained", 0)), "DarkLabel", 24))
	v.add_child(rw)
	if result.first:
		v.add_child(UIKit.label("Primeira foto da espécie! Biometria liberada no Arquivo.", "DarkLabel", Color("1f7a3a"), HORIZONTAL_ALIGNMENT_CENTER))
	if result.repeated:
		v.add_child(UIKit.label("Foto repetida: recompensa reduzida.", "DarkLabel", Color("a33b3b"), HORIZONTAL_ALIGNMENT_CENTER))
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := UIKit.button("Outra foto", "camera", "ButtonAmber", Vector2(220, 60))
	again.pressed.connect(func():
		_result.queue_free()
		_result = null
		for u in _ui:
			u.visible = true
		_finder.visible = true
		_update_subject())
	row.add_child(again)
	var done := UIKit.button("Sair", "check", "ButtonGreen", Vector2(180, 60))
	done.pressed.connect(close)
	row.add_child(done)
	v.add_child(row)
	card.add_child(v)
	center.add_child(card)


func close() -> void:
	exited.emit()
	queue_free()
