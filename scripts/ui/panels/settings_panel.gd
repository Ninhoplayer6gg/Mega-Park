extends GamePanel
## Audio volumes, manual save, new game.

func configure() -> void:
	title = "Configurações"
	icon_name = "settings"
	desired_size = Vector2(700, 520)


func build() -> void:
	body.add_child(_slider_row("Música", AudioManager.music_volume, AudioManager.set_music_volume))
	body.add_child(_slider_row("Efeitos", AudioManager.sfx_volume, AudioManager.set_sfx_volume))
	var row := UIKit.hbox(10)
	var save_btn := UIKit.button("Salvar agora", "save", "ButtonBlue", Vector2(240, 60))
	save_btn.pressed.connect(func():
		if SaveManager.save_game():
			hud.show_toast("Jogo salvo!", "save", "good"))
	row.add_child(save_btn)
	var reset_btn := UIKit.button("Novo jogo", "sell", "ButtonRed", Vector2(240, 60))
	reset_btn.pressed.connect(func():
		if not reset_btn.has_meta("armed"):
			reset_btn.set_meta("armed", true)
			reset_btn.text = "Apagar tudo?"
			hud.show_toast("Toque novamente para apagar o progresso.", "sell", "bad")
			return
		SaveManager.new_game()
		SceneRouter.goto(SceneRouter.PARK))
	row.add_child(reset_btn)
	body.add_child(row)
	body.add_child(UIKit.spacer(false))
	var last := "nunca"
	if SaveManager.last_save_time > 0:
		last = Time.get_datetime_string_from_unix_time(int(SaveManager.last_save_time), true)
	body.add_child(UIKit.label("Salvamento automático ativo · último save: %s" % last, "SmallLabel"))
	body.add_child(UIKit.label("Mega Park v%s · Godot %s" % [ProjectSettings.get_setting("application/config/version"), Engine.get_version_info().string], "SmallLabel"))
	body.add_child(UIKit.label("Fonte Pixelify Sans (SIL OFL). Arte e sons originais gerados para o projeto.", "SmallLabel"))


func _slider_row(text: String, value: float, setter: Callable) -> Control:
	var h := UIKit.hbox(12)
	h.add_child(UIKit.icon("sound", 28))
	var l := UIKit.label(text, "ValueLabel")
	l.custom_minimum_size.x = 120
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(300, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(setter)
	h.add_child(s)
	return h
