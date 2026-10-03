extends Control
## Title screen with the logo, the three starter creatures and play/new-game buttons.

var _new_btn: Button


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/battle/arena_bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.1, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var v := UIKit.vbox(6)
	v.set_anchors_preset(Control.PRESET_CENTER_TOP)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.offset_top = 40
	add_child(v)
	var logo_tex: Texture2D = load("res://assets/ui/logo.png")
	var logo_scale := 2.0 if get_viewport_rect().size.x < 1500 else 3.0
	var logo := UIKit.texture(logo_tex, logo_tex.get_size() * logo_scale)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(logo)
	var sub := UIKit.label("PARQUE INTERDIMENSIONAL DE CRIATURAS", "HeaderLabel", UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_constant_override("outline_size", 6)
	v.add_child(sub)
	logo.resized.connect(func(): logo.pivot_offset = logo.size * 0.5)
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)

	var stage := Node2D.new()
	add_child(stage)
	var ids := [&"triceratopo_ancestral", &"rex_primordial", &"xenoraptor"]
	var vp := get_viewport_rect().size
	for i in ids.size():
		var data := DataRegistry.get_creature(ids[i])
		var s := AnimatedSprite2D.new()
		s.sprite_frames = DataRegistry.sprite_frames_for(data)
		s.centered = false
		s.offset = Vector2(-data.frame_size.x * 0.5, -data.foot_y)
		s.scale = Vector2(2, 2)
		s.flip_h = i == 2
		s.position = Vector2(vp.x * (0.22 + i * 0.28), vp.y * 0.66)
		stage.add_child(s)
		s.play(&"idle")
		s.frame = i
	get_viewport().size_changed.connect(func():
		var size := get_viewport_rect().size
		for i in stage.get_child_count():
			stage.get_child(i).position = Vector2(size.x * (0.22 + i * 0.28), size.y * 0.66))

	var buttons := UIKit.hbox(16)
	buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	buttons.offset_bottom = -40
	add_child(buttons)
	var play := UIKit.button("JOGAR", "creatures", "ButtonGreen", Vector2(320, 84))
	play.add_theme_font_size_override("font_size", 32)
	play.pressed.connect(func(): SceneRouter.goto(SceneRouter.PARK))
	buttons.add_child(play)
	_new_btn = UIKit.button("Novo jogo", "plus", "ButtonDark", Vector2(240, 84))
	_new_btn.pressed.connect(_on_new_game)
	buttons.add_child(_new_btn)
	var ver := UIKit.label("v%s" % ProjectSettings.get_setting("application/config/version"), "SmallLabel")
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -12
	ver.offset_bottom = -8
	add_child(ver)
	AudioManager.play_music(&"title")


func _on_new_game() -> void:
	if CreatureRoster.count() > 0 or ParkState.buildings.size() > ParkState.layout.start_paths.size() + 1:
		if not _new_btn.has_meta("armed"):
			_new_btn.set_meta("armed", true)
			_new_btn.text = "Apagar progresso?"
			return
	SaveManager.new_game()
	SceneRouter.goto(SceneRouter.PARK)
