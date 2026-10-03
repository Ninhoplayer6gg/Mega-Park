class_name EntranceNode
extends BuildingNode
## Park entrance: a ticket bubble floats over the gate while visitor tickets wait to be collected.

var bubble: Node2D
var _label: Label


func _build_visual() -> void:
	super._build_visual()
	if preview:
		return
	var top := -float(data.sprite.get_height()) if data.sprite else -64.0
	bubble = Node2D.new()
	bubble.z_index = 40
	bubble.position = Vector2(0, top + 4)
	bubble.visible = false
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/effects/bubble.png")
	bg.scale = Vector2(2, 2)
	bg.position = Vector2(0, -26)
	bubble.add_child(bg)
	var ic := Sprite2D.new()
	ic.texture = DataRegistry.icon("visitors")
	ic.scale = Vector2(2, 2)
	ic.position = Vector2(0, -30)
	bubble.add_child(ic)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_outline_color", UITheme.OUTLINE)
	_label.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(-30, -10)
	_label.custom_minimum_size = Vector2(60, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_child(_label)
	add_child(bubble)
	var tw := bubble.create_tween().set_loops()
	tw.tween_property(bg, "position:y", -30.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ic, "position:y", -34.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bg, "position:y", -26.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ic, "position:y", -30.0, 0.6).set_trans(Tween.TRANS_SINE)


func _ready() -> void:
	super._ready()
	tick()


func tick() -> void:
	if bubble == null:
		return
	var pending := int(VisitorManager.pending_tickets)
	bubble.visible = pending >= 1
	_label.text = "+%d" % pending


func bubble_rect() -> Rect2:
	if bubble == null or not bubble.visible:
		return Rect2()
	return Rect2(position + bubble.position + Vector2(-30, -60), Vector2(60, 64))
