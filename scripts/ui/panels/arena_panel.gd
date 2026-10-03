extends GamePanel
## Pick a creature and an arena stage, then start a 1v1 battle.

var selected_uid := ""
var stage: ArenaOpponentData
var _left: VBoxContainer
var _right: VBoxContainer


func configure() -> void:
	title = "Arena"
	icon_name = "battle"
	desired_size = Vector2(1120, 640)


func build() -> void:
	stage = ArenaManager.next_stage()
	var owned := CreatureRoster.all()
	if selected_uid == "" and not owned.is_empty():
		selected_uid = owned[0].uid
	if owned.is_empty():
		var msg := UIKit.vbox(12)
		msg.alignment = BoxContainer.ALIGNMENT_CENTER
		msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
		msg.add_child(UIKit.label("Você ainda não tem criaturas!", "TitleLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
		msg.add_child(UIKit.label("Construa uma Incubadora e choque um ovo para lutar na Arena.", "BodyLabel", null, HORIZONTAL_ALIGNMENT_CENTER))
		body.add_child(msg)
		return
	var cols := columns(340)
	body.add_child(cols[0])
	_left = cols[1]
	_right = cols[2]
	refresh()


func refresh() -> void:
	if _left == null:
		return
	UIKit.clear(_left)
	UIKit.clear(_right)
	_left.add_child(UIKit.label("Sua criatura", "HeaderLabel"))
	var sc := UIKit.scroll()
	var list := UIKit.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in CreatureRoster.all():
		list.add_child(_creature_row(c))
	sc.add_child(list)
	_left.add_child(sc)

	_right.add_child(UIKit.label("Adversários", "HeaderLabel"))
	var ladder := HFlowContainer.new()
	ladder.add_theme_constant_override("h_separation", 6)
	ladder.add_theme_constant_override("v_separation", 6)
	for s in ArenaManager.stages():
		var unlocked := ArenaManager.is_unlocked(s)
		var label_text := "%d" % s.order
		var b := UIKit.button(label_text, "check" if ArenaManager.is_beaten(s) else ("battle" if unlocked else "lock"), "TabButton", Vector2(86, 52))
		b.toggle_mode = true
		b.button_pressed = s == stage
		b.disabled = not unlocked
		b.pressed.connect(func():
			stage = s
			refresh())
		ladder.add_child(b)
	_right.add_child(ladder)
	if stage:
		_right.add_child(_stage_card())
	var fight := UIKit.button("LUTAR!", "battle", "ButtonRed", Vector2(300, 76))
	fight.add_theme_font_size_override("font_size", 28)
	fight.size_flags_horizontal = Control.SIZE_SHRINK_END
	fight.disabled = selected_uid == "" or stage == null
	fight.pressed.connect(_start_battle)
	_right.add_child(fight)


func _creature_row(c: CreatureInstance) -> Control:
	var b := Button.new()
	b.theme_type_variation = "TabButton"
	b.toggle_mode = true
	b.button_pressed = c.uid == selected_uid
	b.custom_minimum_size = Vector2(300, 92)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	UIKit.add_press_feedback(b)
	var h := UIKit.hbox(8)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.offset_top = 4
	h.offset_bottom = -10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(CreaturePortrait.make(c.data, Vector2(110, 76), false, false))
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(c.display_name(), "ValueLabel"))
	v.add_child(UIKit.label("Nível %d · HP %d · ATQ %d" % [c.level, c.max_hp(), c.attack()], "SmallLabel", UITheme.TEXT))
	h.add_child(v)
	b.add_child(h)
	b.pressed.connect(func():
		selected_uid = c.uid
		refresh())
	return b


func _stage_card() -> Control:
	var card := UIKit.panel("Card")
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var h := UIKit.hbox(14)
	var portrait := CreaturePortrait.make(stage.creature, Vector2(240, 160))
	portrait.flip = true
	h.add_child(portrait)
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(stage.title, "TitleLabel"))
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label("%s · Nível %d" % [stage.creature.display_name, stage.level], "ValueLabel"))
	row.add_child(UIKit.rarity_badge(stage.creature.rarity))
	v.add_child(row)
	var foe := Combatant.from_species(stage.creature, stage.level)
	v.add_child(UIKit.label("HP %d · ATQ %d · DEF %d · VEL %d" % [foe.max_hp, foe.base_attack, foe.base_defense, foe.base_speed], "SmallLabel", UITheme.TEXT))
	v.add_child(UIKit.label("Recompensa por vitória:", "SmallLabel"))
	var rw := UIKit.hbox(12)
	rw.add_child(UIKit.icon_value("credits", str(stage.reward_credits), "BodyLabel", 20))
	rw.add_child(UIKit.icon_value("dna", str(stage.reward_dna), "BodyLabel", 20))
	rw.add_child(UIKit.icon_value("xp", "%d XP" % stage.reward_creature_xp, "BodyLabel", 20))
	v.add_child(rw)
	if ArenaManager.is_beaten(stage):
		v.add_child(UIKit.label("Já derrotado — revanches valem recompensas também.", "SmallLabel", UITheme.GOOD))
	h.add_child(v)
	card.add_child(h)
	return card


func _start_battle() -> void:
	if selected_uid == "" or stage == null:
		return
	AudioManager.play_sfx(&"whoosh")
	SaveManager.save_game()
	SceneRouter.goto(SceneRouter.BATTLE, {"creature_uid": selected_uid, "stage_id": stage.id})
