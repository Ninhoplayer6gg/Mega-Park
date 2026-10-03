class_name UIKit
extends RefCounted
## Small factory helpers so panels stay short and consistent.


static func icon(name: String, size := 32) -> TextureRect:
	return texture(DataRegistry.icon(name), Vector2(size, size))


static func texture(tex: Texture2D, size := Vector2(32, 32)) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func label(text: String, variation := "", color = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if color != null:
		l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, variation := "BodyLabel", min_width := 200) -> Label:
	var l := label(text, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = min_width
	return l


static func hbox(sep := 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func vbox(sep := 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func spacer(expand_h := true) -> Control:
	var c := Control.new()
	if expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func panel(variation := "Card") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


static func button(text: String, icon_name := "", variation := "ButtonGreen", min_size := Vector2(0, 60)) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = min_size
	if icon_name != "":
		b.icon = DataRegistry.icon(icon_name)
		b.expand_icon = false
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_press_feedback(b)
	return b


## Squash animation + click sound for any button.
static func add_press_feedback(b: BaseButton, sound := &"ui_click") -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func():
		if not b.is_inside_tree():
			return
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.05))
	b.button_up.connect(func():
		if not b.is_inside_tree():
			return
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.pressed.connect(func(): AudioManager.play_sfx(sound))


static func progress(variation := "BarXP", height := 14, value := 0.0, max_value := 1.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.theme_type_variation = variation
	p.custom_minimum_size = Vector2(60, height)
	p.show_percentage = false
	p.max_value = max_value
	p.value = value
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func icon_value(icon_name: String, text: String, variation := "ValueLabel", icon_size := 24) -> HBoxContainer:
	var h := hbox(6)
	h.add_child(icon(icon_name, icon_size))
	var l := label(text, variation)
	l.name = "Value"
	h.add_child(l)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func cost_row(credits: int, dna := 0, energy := 0, variation := "ValueLabel") -> HBoxContainer:
	var h := hbox(12)
	if credits > 0:
		h.add_child(icon_value("credits", GameEnums.format_number(credits), variation, 20))
	if dna > 0:
		h.add_child(icon_value("dna", str(dna), variation, 20))
	if energy > 0:
		h.add_child(icon_value("energy", str(energy), variation, 20))
	if credits <= 0 and dna <= 0 and energy <= 0:
		h.add_child(label("Grátis", variation))
	return h


static func rarity_badge(rarity: int) -> PanelContainer:
	var p := PanelContainer.new()
	var col := GameEnums.rarity_color(rarity)
	var sb := UITheme.flat(col.darkened(0.55), col, 2, 4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := label(GameEnums.rarity_name(rarity).to_upper(), "SmallLabel", col)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func tag(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UITheme.flat(Color(0, 0, 0, 0.35), color, 2, 4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, "SmallLabel", color))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func stat_row(icon_name: String, title: String, value: String, bar_ratio := -1.0, bar_variation := "BarHP") -> Control:
	var row := hbox(8)
	row.add_child(icon(icon_name, 22))
	var name_l := label(title, "BodyLabel", UITheme.TEXT_MUTED)
	name_l.custom_minimum_size.x = 110
	row.add_child(name_l)
	if bar_ratio >= 0.0:
		var bar := progress(bar_variation, 10, bar_ratio)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
	var v := label(value, "ValueLabel")
	v.custom_minimum_size.x = 64
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return row


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func scroll(vertical := true) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if vertical:
		s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	else:
		s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return s


static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.add_child(child)
	return c
