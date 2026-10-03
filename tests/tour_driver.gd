extends Node
## Automated play-through of the first milestone flow with screenshots.
## Run (needs a display, e.g. xvfb-run):
##   godot -- --tour [--shots=<dir>]
## Drives the real scenes/UI through: new game -> build habitat -> build incubator -> incubate ->
## hatch -> assign -> collect -> feed to level 2 -> arena battle -> rewards -> park -> save.

var shots_dir := "user://tour"
var _step := 0
var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.substr(8)
	DirAccess.make_dir_recursive_absolute(shots_dir)
	_run.call_deferred()


func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("TOUR (headless) skip shot ", name)
		return
	await RenderingServer.frame_post_draw
	_step += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join("%02d_%s.png" % [_step, name]))
	print("TOUR shot ", name)


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		printerr("TOUR FAIL: ", msg)
	else:
		print("TOUR ok: ", msg)


func scene() -> Node:
	return get_tree().current_scene


func find_free(data: BuildingData, near: Vector2i) -> Vector2i:
	for r in range(0, 20):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := near + Vector2i(dx, dy)
				if ParkState.check_placement(data, c, true) == "":
					return c
	return Vector2i(-1, -1)


func build_via_ui(park: Node, id: StringName, near: Vector2i) -> BuildingInstance:
	var data := DataRegistry.get_building(id)
	park.hud.open_build_menu()
	await wait(0.4)
	park.hud.start_build(data)
	await wait(0.3)
	var cell := find_free(data, near)
	park.build_controller.move_to_world(ParkGrid.cell_center(cell + (data.size - Vector2i.ONE) / 2))
	await wait(0.2)
	var before := ParkState.count_of(id)
	var b: BuildingInstance = park.build_controller.confirm()
	expect(b != null and ParkState.count_of(id) == before + 1, "built %s" % id)
	return b


func _run() -> void:
	await wait(1.5)
	SaveManager.new_game()
	SceneRouter.goto(SceneRouter.TITLE)
	await wait(1.2)
	await shot("title")
	SceneRouter.goto(SceneRouter.PARK)
	await wait(1.5)
	var park := scene()
	expect(park.name == "Park", "park scene loaded")
	await shot("park_start")
	park.hud.open_build_menu()
	await wait(0.6)
	await shot("build_menu")
	var hab_data := DataRegistry.get_building(&"habitat_prehistoric")
	park.hud.start_build(hab_data)
	await wait(0.4)
	var anchor := ParkGrid.world_to_cell(park.camera.position)
	var hcell := find_free(hab_data, anchor + Vector2i(-6, -3))
	park.build_controller.move_to_world(ParkGrid.cell_center(hcell + Vector2i(4, 3)))
	await wait(0.3)
	await shot("build_ghost")
	var hab: BuildingInstance = park.build_controller.confirm()
	expect(hab != null, "habitat placed via build controller")
	await wait(0.6)
	var inc := await build_via_ui(park, &"incubator", anchor + Vector2i(6, 0))
	await wait(0.4)
	# path painting
	park.hud.start_build(DataRegistry.get_building(&"path"))
	for i in 4:
		park.build_controller.handle_tap(ParkGrid.cell_center(Vector2i(24 + i, 16 + 1)))
	park.build_controller.stop()
	await wait(0.3)
	park.focus_building(hab.uid, 2.0)
	await wait(0.7)
	await shot("buildings_placed")
	park.hud.open_building(inc)
	await wait(0.6)
	await shot("incubator_choose")
	var rex := DataRegistry.get_creature(&"rex_primordial")
	expect(IncubationManager.start(inc.uid, rex), "incubation started")
	await wait(1.2)
	await shot("incubating")
	GameClock.advance(rex.incubation_time + 1)
	await wait(1.2)
	await shot("egg_ready")
	var panel = park.hud._current_panel
	var hatch_btn: Button = panel.find_children("*", "Button", true, false).filter(func(b): return b.text == "Chocar e coletar")[0]
	hatch_btn.pressed.emit()
	await wait(1.2)
	await shot("hatched")
	var creature: CreatureInstance = CreatureRoster.all()[0]
	expect(creature != null and creature.species_id == &"rex_primordial", "creature hatched")
	park.hud.open_habitat_picker(creature, false)
	await wait(0.5)
	await shot("habitat_picker")
	var picker = park.hud._current_panel
	picker._assign(hab)
	expect(creature.habitat_uid == hab.uid, "creature assigned to habitat")
	await wait(3.0)
	await shot("creature_in_habitat")
	GameClock.advance(rex.income_interval * 4 + 1)
	await wait(1.2)
	await shot("coin_bubble")
	var hn: HabitatNode = park.get_building_node(hab.uid)
	var credits_before := Economy.credits
	park._on_tap(hn.bubble_rect().get_center())
	expect(Economy.credits > credits_before, "credits collected by tapping bubble")
	await wait(0.35)
	await shot("collecting")
	await wait(0.8)
	var actor: CreatureActor = park.find_actor(creature.uid)
	park._on_tap(actor.pick_rect().get_center())
	await wait(0.6)
	await shot("creature_panel")
	panel = park.hud._current_panel
	var guard := 0
	while creature.level < 2 and guard < 10:
		panel._on_feed()
		guard += 1
		await wait(0.3)
	expect(creature.level >= 2, "creature reached level 2 by feeding")
	await wait(0.4)
	await shot("level_up")
	# claim missions so the HUD tracker advances
	for m in MissionManager.ordered():
		if MissionManager.is_complete(m) and not MissionManager.is_claimed(m):
			MissionManager.claim(m)
	park.hud.open_panel("arena", {"selected_uid": creature.uid})
	await wait(0.6)
	await shot("arena")
	panel = park.hud._current_panel
	panel._start_battle()
	await wait(3.0)
	var battle := scene()
	expect(battle.name == "Battle", "battle scene loaded")
	await shot("battle_start")
	var rounds := 0
	while not battle.state.finished and rounds < 30:
		while battle._busy and not battle.state.finished:
			await wait(0.1)
		if battle.state.finished:
			break
		var me: Combatant = battle.state.player
		var choice: AbilityData = BattleAI.choose(battle.state, me, 0.0)
		if rounds == 1:
			battle.hud._toggle_ability_menu()
			await wait(0.3)
			await shot("ability_menu")
			battle.hud.ability_menu.visible = false
		battle.hud.action_chosen.emit(choice)
		await wait(0.35)
		if rounds == 0:
			await shot("battle_action")
		rounds += 1
	var t0 := Time.get_ticks_msec()
	while not battle.result_shown and Time.get_ticks_msec() - t0 < 20000:
		await wait(0.1)
	await wait(1.2)
	await shot("battle_result")
	expect(battle.state.finished, "battle finished in %d rounds" % rounds)
	var won: bool = battle.state.winner == battle.state.player
	print("TOUR battle won: ", won)
	battle.hud.continue_pressed.emit()
	await wait(1.8)
	park = scene()
	expect(park.name == "Park", "returned to park")
	await shot("back_in_park")
	park.hud.open_panel("collection")
	await wait(0.6)
	await shot("collection")
	park.hud._current_panel.tab = "bestiary"
	park.hud._current_panel.refresh()
	await wait(0.4)
	await shot("bestiary")
	park.hud.open_panel("missions")
	await wait(0.6)
	await shot("missions")
	park.hud.open_panel("expeditions")
	await wait(0.4)
	ExpeditionManager.start(DataRegistry.expeditions[&"vale_primordial"])
	await wait(1.2)
	await shot("expedition_running")
	GameClock.advance(40)
	await wait(1.3)
	await shot("expedition_ready")
	park.hud.close_all()
	await wait(0.3)
	park.hud.open_building(hab)
	await wait(0.5)
	await shot("habitat_panel")
	park.hud.close_all()
	park.camera.focus_on(park.camera.position, 1.0)
	await wait(0.8)
	await shot("park_zoomed_out")
	expect(SaveManager.save_game(), "progress saved")
	var data := SaveManager.build_save_data()
	expect(data.creatures.creatures.size() >= 1 and data.park.buildings.size() > 3, "save contains creatures and buildings")
	print("TOUR finished with %d failures" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
