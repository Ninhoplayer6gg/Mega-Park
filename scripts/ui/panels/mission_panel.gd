extends GamePanel
## Mission list with progress and claim buttons.

var _list: VBoxContainer


func configure() -> void:
	title = "Missões"
	icon_name = "missions"
	desired_size = Vector2(920, 620)


func build() -> void:
	var done := 0
	for m in MissionManager.ordered():
		if MissionManager.is_claimed(m):
			done += 1
	body.add_child(UIKit.label("Concluídas: %d / %d" % [done, DataRegistry.missions.size()], "BodyLabel", UITheme.TEXT_MUTED))
	var sc := UIKit.scroll()
	_list = UIKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	body.add_child(sc)
	refresh()
	MissionManager.missions_changed.connect(refresh)


func refresh() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	UIKit.clear(_list)
	var visible_list := MissionManager.visible_missions()
	if visible_list.is_empty():
		_list.add_child(UIKit.label("Todas as missões foram concluídas!", "HeaderLabel", UITheme.GOOD))
	for i in visible_list.size():
		_list.add_child(_card(visible_list[i], i == 0))


func _card(m: MissionData, is_current: bool) -> Control:
	var card := UIKit.panel("CardSelected" if is_current else "Card")
	var h := UIKit.hbox(14)
	h.add_child(UIKit.icon(m.icon_name, 48))
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(m.title, "HeaderLabel"))
	v.add_child(UIKit.wrap_label(m.description, "SmallLabel", 360))
	var p := MissionManager.get_progress(m)
	var row := UIKit.hbox(8)
	var bar := UIKit.progress("BarTime", 12, p, m.target)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(UIKit.label("%d/%d" % [p, m.target], "BodyLabel"))
	v.add_child(row)
	var rw := UIKit.hbox(12)
	if m.reward_credits > 0:
		rw.add_child(UIKit.icon_value("credits", str(m.reward_credits), "BodyLabel", 18))
	if m.reward_dna > 0:
		rw.add_child(UIKit.icon_value("dna", str(m.reward_dna), "BodyLabel", 18))
	if m.reward_player_xp > 0:
		rw.add_child(UIKit.icon_value("star", "%d XP" % m.reward_player_xp, "BodyLabel", 18))
	v.add_child(rw)
	h.add_child(v)
	var b := UIKit.button("Resgatar", "check", "ButtonGreen", Vector2(180, 60))
	b.disabled = not MissionManager.is_complete(m)
	b.pressed.connect(func():
		var from := b.global_position + b.size * 0.5
		if MissionManager.claim(m):
			if m.reward_credits > 0:
				hud.fly_rewards(from, "credits", 6)
			if m.reward_dna > 0:
				hud.fly_rewards(from, "dna", 4))
	h.add_child(b)
	card.add_child(h)
	return card
