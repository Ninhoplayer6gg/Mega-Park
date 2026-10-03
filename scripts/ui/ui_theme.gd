class_name UITheme
extends RefCounted
## Builds the game's Theme from the pixel-art 9-slice frames in assets/ui/frames.
## Applied once to the root window, so every Control inherits it.

const FONT_PATH := "res://assets/fonts/PixelifySans.ttf"
const FRAMES := "res://assets/ui/frames/"
const TEXT := Color("f6f1e4")
const TEXT_MUTED := Color("a9b7c6")
const TEXT_DARK := Color("1b1b2a")
const OUTLINE := Color("0b1218")
const GOLD := Color("ffd23f")
const GOOD := Color("7ee08f")
const BAD := Color("ff7a7a")
const CYAN := Color("5ef6ff")

static var _theme: Theme
static var _font: FontFile


static func font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH)
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func frame(name: String, margin := 9, bottom := 12, content := Vector4(14, 10, 14, 14)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(FRAMES + name + ".png")
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = bottom
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


static func flat(color: Color, border := Color.TRANSPARENT, border_w := 0, radius := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = false
	return sb


static func _button_styles(t: Theme, type_name: String, color: String) -> void:
	var normal := frame("btn_" + color, 9, 12, Vector4(16, 8, 16, 14))
	var pressed := frame("btn_" + color + "_pressed", 9, 9, Vector4(16, 12, 16, 10))
	var disabled := frame("btn_disabled", 9, 12, Vector4(16, 8, 16, 14))
	t.set_stylebox("normal", type_name, normal)
	t.set_stylebox("hover", type_name, normal)
	t.set_stylebox("pressed", type_name, pressed)
	t.set_stylebox("hover_pressed", type_name, pressed)
	t.set_stylebox("disabled", type_name, disabled)
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type_name, TEXT)
	t.set_color("font_disabled_color", type_name, Color("c9d0d8"))
	t.set_color("font_outline_color", type_name, OUTLINE)
	t.set_constant("outline_size", type_name, 5)
	t.set_constant("h_separation", type_name, 8)
	t.set_constant("icon_max_width", type_name, 32)


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 20

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_constant("outline_size", "Label", 0)

	_button_styles(t, "Button", "dark")
	for v in [["ButtonGreen", "green"], ["ButtonAmber", "amber"], ["ButtonBlue", "blue"], ["ButtonRed", "red"],
			["ButtonPurple", "purple"], ["ButtonDark", "dark"]]:
		t.set_type_variation(v[0], "Button")
		_button_styles(t, v[0], v[1])
	# Toggle-able tab look
	t.set_type_variation("TabButton", "Button")
	_button_styles(t, "TabButton", "dark")
	t.set_stylebox("pressed", "TabButton", frame("btn_amber", 9, 12, Vector4(14, 8, 14, 14)))
	t.set_stylebox("hover_pressed", "TabButton", frame("btn_amber", 9, 12, Vector4(14, 8, 14, 14)))

	t.set_stylebox("panel", "PanelContainer", frame("panel", 9, 9, Vector4(18, 16, 18, 18)))
	t.set_stylebox("panel", "Panel", frame("panel", 9, 9))
	for v in [["Card", "card", Vector4(12, 10, 12, 12)], ["CardSelected", "card_selected", Vector4(12, 10, 12, 12)],
			["Paper", "paper", Vector4(14, 12, 14, 14)], ["Inset", "inset", Vector4(10, 8, 10, 8)],
			["Ribbon", "ribbon", Vector4(18, 8, 18, 8)]]:
		t.set_type_variation(v[0], "PanelContainer")
		t.set_stylebox("panel", v[0], frame(v[1], 9, 9, v[2]))
	t.set_type_variation("Pill", "PanelContainer")
	t.set_stylebox("panel", "Pill", _pill())

	for v in [["TitleLabel", 32, 6, GOLD], ["HeaderLabel", 24, 5, TEXT], ["ValueLabel", 22, 5, TEXT],
			["SmallLabel", 16, 0, TEXT_MUTED], ["BodyLabel", 18, 0, TEXT], ["DarkLabel", 18, 0, TEXT_DARK],
			["BigLabel", 48, 8, GOLD]]:
		t.set_type_variation(v[0], "Label")
		t.set_font_size("font_size", v[0], v[1])
		t.set_constant("outline_size", v[0], v[2])
		t.set_color("font_color", v[0], v[3])
		t.set_color("font_outline_color", v[0], OUTLINE)

	t.set_stylebox("background", "ProgressBar", flat(Color("101820"), Color("0b1218"), 2))
	t.set_stylebox("fill", "ProgressBar", flat(Color("4cc265"), Color("0b1218"), 2))
	t.set_font_size("font_size", "ProgressBar", 14)
	for v in [["BarXP", "3f95e8"], ["BarHP", "4cc265"], ["BarEnergy", "ffd23f"], ["BarTime", "f0a142"],
			["BarDanger", "e04848"], ["BarPurple", "8f6be0"]]:
		t.set_type_variation(v[0], "ProgressBar")
		t.set_stylebox("fill", v[0], flat(Color(v[1]), Color("0b1218"), 2))

	t.set_stylebox("slider", "HSlider", flat(Color("101820"), Color("0b1218"), 2))
	t.set_stylebox("grabber_area", "HSlider", flat(Color("f0a142"), Color("0b1218"), 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(Color("ffd28a"), Color("0b1218"), 2))
	t.set_icon("grabber", "HSlider", load("res://assets/ui/icons/star.png"))
	t.set_icon("grabber_highlight", "HSlider", load("res://assets/ui/icons/star.png"))

	var bar := flat(Color(1, 1, 1, 0.25), Color.TRANSPARENT, 0, 2)
	bar.content_margin_left = 6
	bar.content_margin_right = 6
	for sb_name in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_name, flat(Color(0, 0, 0, 0.15)))
		t.set_stylebox("grabber", sb_name, bar)
		t.set_stylebox("grabber_highlight", sb_name, bar)
		t.set_stylebox("grabber_pressed", sb_name, bar)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TooltipPanel", frame("panel", 9, 9))
	return t


static func _pill() -> StyleBoxFlat:
	var sb := flat(Color(0.05, 0.08, 0.11, 0.78), Color("0b1218"), 3, 6)
	sb.content_margin_left = 10
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb
