class_name MissionTracker
extends PanelContainer
## Compact "current objective" card shown on the park HUD. Teaches the game step by step.

var hud: Hud
var _icon: TextureRect
var _title: Label
var _desc: Label
var _bar: ProgressBar
var _count: Label
var _claim: Button
var _mission: MissionData
var _pulse: Tween


func _ready() -> void:
	theme_type_variation = "Card"
	custom_minimum_size = Vector2(320, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var h := UIKit.hbox(10)
	_icon = UIKit.icon("missions", 36)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(_icon)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cap := UIKit.label("OBJETIVO", "SmallLabel", UITheme.GOLD)
	v.add_child(cap)
	_title = UIKit.label("", "ValueLabel")
	v.add_child(_title)
	_desc = UIKit.wrap_label("", "SmallLabel", 240)
	_desc.add_theme_color_override("font_color", UITheme.TEXT)
	v.add_child(_desc)
	var row := UIKit.hbox(6)
	_bar = UIKit.progress("BarTime", 10)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bar)
	_count = UIKit.label("0/1", "SmallLabel")
	row.add_child(_count)
	v.add_child(row)
	_claim = UIKit.button("Resgatar", "check", "ButtonGreen", Vector2(0, 52))
	_claim.pressed.connect(_on_claim)
	v.add_child(_claim)
	h.add_child(v)
	add_child(h)
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			hud.open_panel("missions"))
	resized.connect(func(): pivot_offset = size * 0.5)
	refresh()


func refresh() -> void:
	if _title == null:
		return
	_mission = MissionManager.current()
	if _mission == null:
		_title.text = "Parque em expansão!"
		_desc.text = "Todas as missões concluídas. Continue evoluindo suas criaturas."
		_bar.visible = false
		_count.visible = false
		_claim.visible = false
		return
	_icon.texture = DataRegistry.icon(_mission.icon_name)
	_title.text = _mission.title
	_desc.text = _mission.description
	var p := MissionManager.get_progress(_mission)
	_bar.max_value = _mission.target
	_bar.value = p
	_count.text = "%d/%d" % [p, _mission.target]
	var done := MissionManager.is_complete(_mission)
	_claim.visible = done
	_bar.visible = not done
	_count.visible = not done
	if done and _pulse == null:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "scale", Vector2(1.04, 1.04), 0.4).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)
	elif not done and _pulse:
		_pulse.kill()
		_pulse = null
		scale = Vector2.ONE


func _on_claim() -> void:
	var m := _mission
	if m and MissionManager.claim(m):
		var from := _claim.global_position + _claim.size * 0.5
		if m.reward_credits > 0:
			hud.fly_rewards(from, "credits", 6)
		if m.reward_dna > 0:
			hud.fly_rewards(from, "dna", 4)
		hud.show_toast("+%d créditos  +%d DNA  +%d XP" % [m.reward_credits, m.reward_dna, m.reward_player_xp], "trophy", "good")
	refresh()
