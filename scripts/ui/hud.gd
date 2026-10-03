class_name Hud
extends Control
## Park HUD: resources bar, mission tracker, main menu buttons, build menu/bar, toasts, reward
## animations and the modal panel host. Panels are separate classes in scripts/ui/panels.

const PANELS := {
	"creature": preload("res://scripts/ui/panels/creature_panel.gd"),
	"habitat": preload("res://scripts/ui/panels/habitat_panel.gd"),
	"incubator": preload("res://scripts/ui/panels/incubator_panel.gd"),
	"research": preload("res://scripts/ui/panels/research_panel.gd"),
	"generic": preload("res://scripts/ui/panels/building_panel.gd"),
	"collection": preload("res://scripts/ui/panels/collection_panel.gd"),
	"arena": preload("res://scripts/ui/panels/arena_panel.gd"),
	"expeditions": preload("res://scripts/ui/panels/expedition_panel.gd"),
	"missions": preload("res://scripts/ui/panels/mission_panel.gd"),
	"settings": preload("res://scripts/ui/panels/settings_panel.gd"),
	"habitat_picker": preload("res://scripts/ui/panels/habitat_picker_panel.gd"),
	"rewards": preload("res://scripts/ui/panels/reward_panel.gd"),
	"lab": preload("res://scripts/ui/panels/lab_panel.gd"),
	"paleo": preload("res://scripts/ui/panels/paleo_panel.gd"),
	"mutagen": preload("res://scripts/ui/panels/mutagen_panel.gd"),
	"genetic_tree": preload("res://scripts/ui/panels/genetic_tree_panel.gd"),
	"archive": preload("res://scripts/ui/panels/archive_panel.gd"),
	"events": preload("res://scripts/ui/panels/events_panel.gd"),
	"visitors": preload("res://scripts/ui/panels/visitors_panel.gd"),
}

var park: Node
var safe: MarginContainer
var frame: Control
var credits_pill: Control
var dna_pill: Control
var energy_pill: Control
var level_label: Label
var xp_bar: ProgressBar
var mission_card: MissionTracker
var bottom_bar: HBoxContainer
var build_menu: BuildMenu
var build_bar: BuildBar
var toast_box: VBoxContainer
var panel_layer: Control
var mission_badge: Label
var _current_panel: GamePanel
var _panel_stack: Array = []
var presentation_layer: Control
var rp_pill: Control
var visitors_pill: Label
var side_bar: VBoxContainer
var events_badge: Label
var photo_mode: PhotoMode
var _present_queue: Array = []
var _presenting: Presentation
var _shown := {"credits": 0.0, "dna": 0.0}


func setup(park_node: Node) -> void:
	park = park_node
	theme = UITheme.get_theme()
	_build()
	Economy.resources_changed.connect(_on_resources_changed)
	ParkState.buildings_changed.connect(_update_energy)
	MissionManager.missions_changed.connect(_update_missions)
	EventBus.toast_requested.connect(show_toast)
	park.build_controller.mode_changed.connect(_on_build_mode)
	park.build_controller.preview_changed.connect(build_bar.update_preview)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_shown.credits = Economy.credits
	_shown.dna = Economy.dna
	_on_resources_changed()
	_update_energy()
	_update_missions()
	GameClock.tick.connect(_update_science)
	EventManager.events_changed.connect(_update_science)
	ResearchManager.research_changed.connect(_update_science)
	_update_science()
	EventBus.mutation_found.connect(func(c): present("mutation", {"creature": c}))
	EventBus.recipe_detected.connect(func(rid): present("detected", {"recipe": DataRegistry.get_recipe(rid)}))
	EventBus.species_restored.connect(func(c): present("restored", {"creature": c}))
	EventBus.creature_evolved.connect(func(c, from): present("evolved", {"creature": c, "from": from}))
	if SaveManager.load_warning != "":
		show_toast(SaveManager.load_warning, "save", "bad")
		SaveManager.load_warning = ""


func _build() -> void:
	safe = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	frame = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)

	# ---- top bar
	var top := UIKit.hbox(10)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(top)
	var level_pill := UIKit.panel("Pill")
	var lv := UIKit.hbox(8)
	lv.add_child(UIKit.icon("star", 30))
	var lv_col := UIKit.vbox(0)
	level_label = UIKit.label("Nv 1", "ValueLabel")
	lv_col.add_child(level_label)
	xp_bar = UIKit.progress("BarXP", 8)
	xp_bar.custom_minimum_size.x = 90
	lv_col.add_child(xp_bar)
	lv.add_child(lv_col)
	level_pill.add_child(lv)
	top.add_child(level_pill)
	top.add_child(UIKit.spacer())
	credits_pill = _resource_pill("credits", 130)
	dna_pill = _resource_pill("dna", 90)
	rp_pill = _resource_pill("rp", 70)
	energy_pill = _resource_pill("energy", 100)
	for p in [credits_pill, dna_pill, rp_pill, energy_pill]:
		top.add_child(p)
	var settings_btn := UIKit.button("", "settings", "ButtonDark", Vector2(56, 52))
	settings_btn.pressed.connect(func(): open_panel("settings"))
	top.add_child(settings_btn)

	# ---- side shortcuts (Arquivo Mega, photo mode, events, visitors)
	side_bar = UIKit.vbox(8)
	side_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side_bar.offset_right = -12
	side_bar.offset_top = 80
	frame.add_child(side_bar)
	for item in [["archive", "Arquivo Mega", func(): open_panel("archive")], ["camera", "Modo Foto", func(): start_photo_mode()],
			["event", "Eventos", func(): open_panel("events")], ["visitors", "Visitantes", func(): open_panel("visitors")]]:
		var b := UIKit.button("", item[0], "ButtonDark", Vector2(64, 60))
		b.tooltip_text = item[1]
		b.name = "Side_" + item[0]
		b.pressed.connect(item[2])
		side_bar.add_child(b)
		if item[0] == "event":
			events_badge = UIKit.label("", "SmallLabel", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			events_badge.add_theme_stylebox_override("normal", UITheme.notification_badge())
			events_badge.add_theme_constant_override("outline_size", 4)
			events_badge.custom_minimum_size = Vector2(26, 26)
			events_badge.position = Vector2(-8, -6)
			b.add_child(events_badge)
		if item[0] == "visitors":
			visitors_pill = UIKit.label("0", "SmallLabel", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			visitors_pill.add_theme_constant_override("outline_size", 4)
			visitors_pill.position = Vector2(0, 40)
			visitors_pill.custom_minimum_size = Vector2(64, 0)
			b.add_child(visitors_pill)

	# ---- mission tracker
	mission_card = MissionTracker.new()
	mission_card.hud = self
	mission_card.position = Vector2(12, 84)
	frame.add_child(mission_card)

	# ---- toasts
	toast_box = UIKit.vbox(6)
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.offset_top = 84
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	frame.add_child(toast_box)

	# ---- bottom menu
	bottom_bar = UIKit.hbox(10)
	bottom_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_bar.offset_bottom = -10
	frame.add_child(bottom_bar)
	bottom_bar.add_child(_menu_button("build", "Construir", "ButtonAmber", func(): open_build_menu()))
	bottom_bar.add_child(_menu_button("creatures", "Criaturas", "ButtonGreen", func(): open_panel("collection")))
	bottom_bar.add_child(_menu_button("battle", "Arena", "ButtonRed", func(): open_panel("arena")))
	bottom_bar.add_child(_menu_button("expedition", "Expedições", "ButtonBlue", func(): open_panel("expeditions")))
	var missions_btn := _menu_button("missions", "Missões", "ButtonPurple", func(): open_panel("missions"))
	mission_badge = UIKit.label("", "SmallLabel", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	mission_badge.add_theme_stylebox_override("normal", UITheme.notification_badge())
	mission_badge.add_theme_constant_override("outline_size", 4)
	mission_badge.custom_minimum_size = Vector2(26, 26)
	mission_badge.position = Vector2(92, -6)
	missions_btn.add_child(mission_badge)
	bottom_bar.add_child(missions_btn)

	# ---- build menu + build bar
	build_menu = BuildMenu.new()
	build_menu.hud = self
	build_menu.visible = false
	frame.add_child(build_menu)
	build_bar = BuildBar.new()
	build_bar.hud = self
	build_bar.visible = false
	frame.add_child(build_bar)

	panel_layer = Control.new()
	panel_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_layer)
	presentation_layer = Control.new()
	presentation_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	presentation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(presentation_layer)


func _resource_pill(icon_name: String, min_w: int) -> PanelContainer:
	var p := UIKit.panel("Pill")
	var h := UIKit.hbox(6)
	h.add_child(UIKit.icon(icon_name, 30))
	var l := UIKit.label("0", "ValueLabel")
	l.name = "Value"
	l.custom_minimum_size.x = min_w - 40
	h.add_child(l)
	p.add_child(h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.resized.connect(func(): p.pivot_offset = p.size * 0.5)
	return p


func _menu_button(icon_name: String, text: String, variation: String, cb: Callable) -> Button:
	var b := UIKit.button("", "", variation, Vector2(118, 88))
	var v := UIKit.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UIKit.icon(icon_name, 40)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := UIKit.label(text, "", null, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_constant_override("outline_size", 5)
	v.add_child(l)
	v.offset_bottom = -4
	b.add_child(v)
	b.pressed.connect(cb)
	return b


func _apply_safe_area() -> void:
	var win := DisplayServer.window_get_size()
	var safe_rect := DisplayServer.get_display_safe_area()
	var vp := get_viewport_rect().size
	if win.x <= 0 or win.y <= 0 or safe_rect.size.x <= 0:
		return
	var scale_f := vp / Vector2(win)
	var screen_origin := DisplayServer.window_get_position()
	var left := maxf(0.0, safe_rect.position.x - screen_origin.x) * scale_f.x
	var top := maxf(0.0, safe_rect.position.y - screen_origin.y) * scale_f.y
	var right := maxf(0.0, (screen_origin.x + win.x) - safe_rect.end.x) * scale_f.x
	var bottom := maxf(0.0, (screen_origin.y + win.y) - safe_rect.end.y) * scale_f.y
	# Desktop windows report the whole display; ignore implausible values.
	if left > vp.x * 0.2 or right > vp.x * 0.2:
		left = 0
		right = 0
	if top > vp.y * 0.2 or bottom > vp.y * 0.2:
		top = 0
		bottom = 0
	safe.add_theme_constant_override("margin_left", int(left))
	safe.add_theme_constant_override("margin_top", int(top))
	safe.add_theme_constant_override("margin_right", int(right))
	safe.add_theme_constant_override("margin_bottom", int(bottom))


# ------------------------------------------------------------------ resource display
func _on_resources_changed() -> void:
	level_label.text = "Nv %d" % Economy.player_level
	xp_bar.max_value = Economy.xp_to_next_level()
	xp_bar.value = Economy.player_xp
	for key in ["credits", "dna"]:
		var target: float = Economy.credits if key == "credits" else Economy.dna
		var pill: Control = credits_pill if key == "credits" else dna_pill
		var tw := create_tween()
		tw.tween_method(func(v: float):
			_shown[key] = v
			pill.find_child("Value", true, false).text = GameEnums.format_number(int(round(v))), _shown[key], target, 0.5)
	if mission_card:
		mission_card.refresh()


func _update_energy() -> void:
	var cap := ParkState.energy_capacity()
	var used := ParkState.energy_used()
	var l: Label = energy_pill.find_child("Value", true, false)
	l.text = "%d/%d" % [cap - used, cap]
	l.add_theme_color_override("font_color", UITheme.BAD if cap - used <= 0 else UITheme.TEXT)


func _update_science() -> void:
	rp_pill.find_child("Value", true, false).text = str(int(ResearchManager.rp))
	visitors_pill.text = str(VisitorManager.visitors)
	var n := EventManager.active.size()
	events_badge.text = str(n)
	events_badge.visible = n > 0


func _update_missions() -> void:
	var n := MissionManager.claimable_count()
	mission_badge.text = str(n)
	mission_badge.visible = n > 0
	mission_card.refresh()


func bounce(node: Control) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Small icons that fly from a screen position to the matching resource pill.
func fly_rewards(from_screen: Vector2, icon_name: String, count := 5) -> void:
	var target_pill: Control = credits_pill
	if icon_name == "dna":
		target_pill = dna_pill
	elif icon_name == "star" or icon_name == "xp":
		target_pill = level_label.get_parent().get_parent()
	var target := target_pill.global_position + target_pill.size * Vector2(0.2, 0.5)
	for i in count:
		var ic := UIKit.icon(icon_name, 28)
		ic.position = from_screen + Vector2(randf_range(-24, 24), randf_range(-16, 16)) - Vector2(14, 14)
		add_child(ic)
		var tw := ic.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(ic, "position", ic.position + Vector2(0, -24), 0.15).set_ease(Tween.EASE_OUT)
		tw.tween_property(ic, "position", target - Vector2(14, 14), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ic, "scale", Vector2(0.7, 0.7), 0.45)
		tw.tween_callback(func():
			ic.queue_free()
			bounce(target_pill))


func show_toast(text: String, icon_name := "info", kind := "info") -> void:
	var p := UIKit.panel("Pill")
	var col := UITheme.TEXT
	match kind:
		"good":
			col = UITheme.GOOD
		"bad":
			col = UITheme.BAD
	var h := UIKit.hbox(8)
	h.add_child(UIKit.icon(icon_name, 24))
	var l := UIKit.label(text, "BodyLabel", col)
	h.add_child(l)
	p.add_child(h)
	p.modulate.a = 0.0
	toast_box.add_child(p)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ presentations
## Queues a full-screen reveal (one at a time).
func present(kind: String, payload: Dictionary) -> void:
	_present_queue.append([kind, payload])
	if not is_instance_valid(_presenting):
		_next_presentation()


func _next_presentation() -> void:
	if _present_queue.is_empty():
		_presenting = null
		return
	var item: Array = _present_queue.pop_front()
	var p := Presentation.new()
	p.kind = item[0]
	p.payload = item[1]
	p.hud = self
	p.finished.connect(_next_presentation)
	_presenting = p
	presentation_layer.add_child(p)


func is_presenting() -> bool:
	return is_instance_valid(_presenting)


## Result of a hybrid synthesis (called by the lab panel after "Revelar resultado").
func show_synthesis_result(res: Dictionary) -> void:
	match res.get("outcome", &""):
		&"success":
			present("new_species" if res.new_species else "hybrid", {"creature": res.creature, "recipe": res.recipe})
		&"prototype":
			present("prototype", {"creature": res.creature, "recipe": res.recipe, "consolation": res.consolation})
		_:
			present("failure", {"recipe": res.recipe, "consolation": res.consolation})


# ------------------------------------------------------------------ build mode
func open_build_menu() -> void:
	close_panel()
	build_menu.open()
	bottom_bar.visible = false


func close_build_menu() -> void:
	build_menu.visible = false
	bottom_bar.visible = not park.build_controller.is_active()


func start_build(data: BuildingData) -> void:
	build_menu.visible = false
	park.start_build(data)


func _on_build_mode(active: bool) -> void:
	build_bar.visible = active
	bottom_bar.visible = not active and not build_menu.visible
	side_bar.visible = not active
	mission_card.visible = not active
	if not active:
		mission_card.refresh()


# ------------------------------------------------------------------ panels
func has_modal() -> bool:
	return is_instance_valid(_current_panel) or is_instance_valid(_presenting) or is_instance_valid(photo_mode)


# ------------------------------------------------------------------ photo mode
func start_photo_mode() -> void:
	if is_instance_valid(photo_mode):
		return
	close_all()
	if build_menu.visible:
		close_build_menu()
	photo_mode = PhotoMode.new()
	photo_mode.hud = self
	photo_mode.exited.connect(_on_photo_exit)
	bottom_bar.visible = false
	side_bar.visible = false
	mission_card.visible = false
	panel_layer.add_child(photo_mode)
	AudioManager.play_sfx(&"ui_open")


func _on_photo_exit() -> void:
	photo_mode = null
	bottom_bar.visible = true
	side_bar.visible = true
	mission_card.visible = true
	mission_card.refresh()


func open_panel(kind: String, args := {}) -> GamePanel:
	if build_menu.visible:
		close_build_menu()
	if park.build_controller.is_active():
		park.build_controller.stop()
	var keep_stack: bool = args.get("stack", false)
	if is_instance_valid(_current_panel):
		if keep_stack:
			_current_panel.visible = false
			_panel_stack.append(_current_panel)
		else:
			_close_all()
	var panel: GamePanel = PANELS[kind].new()
	panel.hud = self
	for k in args:
		if k != "stack" and k in panel:
			panel.set(k, args[k])
	panel.closed.connect(_on_panel_closed.bind(panel))
	_current_panel = panel
	panel_layer.add_child(panel)
	AudioManager.play_sfx(&"ui_open")
	return panel


func _on_panel_closed(panel: GamePanel) -> void:
	if panel != _current_panel:
		return
	_current_panel = null
	while not _panel_stack.is_empty():
		var prev: GamePanel = _panel_stack.pop_back()
		if is_instance_valid(prev):
			_current_panel = prev
			prev.visible = true
			prev.refresh()
			return
	if park:
		park.clear_selection()


func _close_all() -> void:
	for p in _panel_stack:
		if is_instance_valid(p):
			p.queue_free()
	_panel_stack.clear()
	if is_instance_valid(_current_panel):
		_current_panel.queue_free()
	_current_panel = null


func close_all() -> void:
	_close_all()
	if park:
		park.clear_selection()


func close_panel() -> void:
	if is_instance_valid(_current_panel):
		_current_panel.close()


func open_creature(c: CreatureInstance, stack := false) -> void:
	open_panel("creature", {"creature": c, "stack": stack})


func open_building(b: BuildingInstance) -> void:
	var kind := String(b.data.panel_type)
	if not PANELS.has(kind):
		kind = "generic"
	open_panel(kind, {"building": b})


func open_habitat_picker(c: CreatureInstance, stack := true) -> void:
	open_panel("habitat_picker", {"creature": c, "stack": stack})


func show_rewards(title_text: String, rewards: Dictionary, stack := true) -> void:
	open_panel("rewards", {"reward_title": title_text, "rewards": rewards, "stack": stack})
