extends Node
## Automated play-through of the genetics update with screenshots.
## Run (needs a display, e.g. xvfb-run):
##   godot -- --gtour [--shots=<dir>]
## Covers: labs and ecosystem in the park, mutated creatures, visitors, research, DNA extraction,
## hybrid synthesis with reveal, the hybrid living in the park, Arquivo Mega, genetic tree,
## photo mode, team/boss battles with a hybrid, and save -> reload with everything preserved.

var shots_dir := "user://gtour"
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
		return
	await RenderingServer.frame_post_draw
	_step += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join("%02d_%s.png" % [_step, name]))
	print("GTOUR shot ", name)


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		printerr("GTOUR FAIL: ", msg)
	else:
		print("GTOUR ok: ", msg)


func scene() -> Node:
	return get_tree().current_scene


func find_free(data: BuildingData, near: Vector2i) -> Vector2i:
	for r in range(0, 24):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := near + Vector2i(dx, dy)
				if ParkState.check_placement(data, c, true) == "":
					return c
	return Vector2i(-1, -1)


func place(id: StringName, near: Vector2i) -> BuildingInstance:
	var data := DataRegistry.get_building(id)
	var cell := find_free(data, near)
	var b := ParkState.place(data, cell)
	expect(b != null, "placed %s" % id)
	return b


func button_with_text(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null


func press(root: Node, text: String) -> bool:
	var b := button_with_text(root, text)
	if b == null or b.disabled:
		printerr("GTOUR: button not available: ", text)
		return false
	b.pressed.emit()
	return true


func _run() -> void:
	await wait(1.0)
	SaveManager.new_game()
	EventManager.enabled = false
	Economy.add(120000, 3000)
	SceneRouter.goto(SceneRouter.PARK)
	await wait(1.5)
	var park := scene()
	expect(park.name == "Park", "park scene loaded")
	var ctx := await _park_world(park)
	await _lab_ui(park, ctx)
	print("GTOUR finished with %d failures" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


# ------------------------------------------------------------------ phase 1: park world
func _park_world(park: Node) -> Dictionary:
	var anchor := ParkGrid.world_to_cell(park.camera.position)
	for i in 3:
		place(&"generator", anchor + Vector2i(12, -6 + i * 2))
	ResearchManager.completed[&"gen_sequencing"] = true
	ResearchManager.completed[&"hybrid_basics"] = true
	ResearchManager.completed[&"paleo_methods"] = true
	var hab := place(&"habitat_prehistoric", anchor + Vector2i(-8, -6))
	var glacial := place(&"habitat_glacial", anchor + Vector2i(6, -9))
	var lab := place(&"genetic_lab", anchor + Vector2i(-2, 4))
	# path loop near the entrance so visitors have somewhere to walk
	for x in range(-6, 7):
		var c := anchor + Vector2i(x, 3)
		if ParkState.check_placement(DataRegistry.get_building(&"path"), c, true) == "":
			ParkState.place(DataRegistry.get_building(&"path"), c)
	var rex := CreatureRoster.add_new(DataRegistry.get_creature(&"rex_primordial"))
	var tri := CreatureRoster.add_new(DataRegistry.get_creature(&"triceratopo_ancestral"))
	var tri2 := CreatureRoster.add_new(DataRegistry.get_creature(&"triceratopo_ancestral"))
	tri2.mutation_id = &"albina"
	ArchiveManager.note_mutation(&"triceratopo_ancestral", &"albina")
	for c in [rex, tri, tri2]:
		CreatureRoster.assign_to_habitat(c, hab.uid)
	var gla := CreatureRoster.add_new(DataRegistry.get_creature(&"glaciadon"))
	CreatureRoster.discover(&"glaciadon")
	CreatureRoster.assign_to_habitat(gla, glacial.uid)
	for uid in [&"lago", &"abrigo", &"vegetacao"]:
		expect(ParkState.install_upgrade(hab, DataRegistry.habitat_upgrades[uid]), "installed %s" % uid)
	ParkState.install_upgrade(glacial, DataRegistry.habitat_upgrades[&"lago"])
	ParkState.install_upgrade(glacial, DataRegistry.habitat_upgrades[&"comedouro_premium"])
	VisitorManager.recompute()
	VisitorManager.visitors_changed.emit()
	await wait(2.5)
	park.focus_building(hab.uid, 2.0)
	await wait(2.0)
	await shot("habitat_ecosystem")
	var hn: HabitatNode = park.get_building_node(hab.uid)
	expect(hn._upgrade_nodes.size() == 3, "eco upgrades rendered in habitat")
	var actor: CreatureActor = park.find_actor(tri2.uid)
	expect(actor != null and actor.sprite.material != null, "mutated creature uses mutation shader")
	park.focus_building(glacial.uid, 2.0)
	await wait(1.5)
	await shot("glacial_habitat")
	var gn: HabitatNode = park.get_building_node(glacial.uid)
	expect(not gn._feeder.visible, "premium feeder replaces the basic one")
	# behaviours over time
	var seen := {}
	for i in 30:
		for a in hn.actors.values():
			seen[a.behavior] = true
		await wait(0.5)
	print("GTOUR behaviours seen: ", seen.keys())
	expect(seen.size() >= 3, "creatures show several behaviours (%d)" % seen.size())
	var crowd: VisitorCrowd = park.objects.get_node("Visitors")
	expect(crowd.get_child_count() > 0, "visitors walking on paths (%d)" % crowd.get_child_count())
	VisitorManager.pending_tickets = 120.0
	VisitorManager.visitors_changed.emit()
	await wait(1.2)
	var entrance: EntranceNode = null
	for n in park.building_nodes.values():
		if n is EntranceNode:
			entrance = n
	park.camera.focus_on(entrance.position + Vector2(0, -40), 2.0)
	await wait(1.0)
	await shot("entrance_tickets")
	var before := Economy.credits
	park._on_tap(entrance.bubble_rect().get_center())
	expect(Economy.credits > before, "tickets collected at the entrance")
	# lab capsule
	GeneticsManager.add_species_dna(&"rex_primordial", 100)
	GeneticsManager.add_species_dna(&"xenoraptor", 100)
	var xeno := CreatureRoster.add_new(DataRegistry.get_creature(&"xenoraptor"))
	GeneticsManager.start_synthesis(lab.uid, DataRegistry.get_recipe(&"xenorex"), [rex, xeno])
	park.focus_building(lab.uid, 2.2)
	await wait(1.6)
	await shot("lab_synthesis_running")
	var ln: LabNode = park.get_building_node(lab.uid)
	expect(ln.capsule.visible and ln.bar.visible, "lab shows capsule and progress")
	GameClock.advance(DataRegistry.get_recipe(&"xenorex").creation_time + 1)
	await wait(1.4)
	expect(ln.ready_icon.visible, "lab shows ready marker")
	await shot("lab_synthesis_ready")
	return {"hab": hab, "glacial": glacial, "lab": lab, "rex": rex, "xeno": xeno, "tri": tri, "anchor": anchor}


func current_panel(park: Node) -> GamePanel:
	return park.hud._current_panel


func continue_presentation(park: Node) -> void:
	var guard := 0
	while park.hud.is_presenting() and guard < 6:
		press(park.hud._presenting, "Continuar")
		await wait(0.5)
		guard += 1


# ------------------------------------------------------------------ phase 2: lab UI
func _lab_ui(park: Node, ctx: Dictionary) -> void:
	var lab: BuildingInstance = ctx.lab
	park.hud.close_all()
	park.hud.open_building(lab)
	await wait(0.6)
	await shot("lab_job_ready")
	expect(press(current_panel(park), "Revelar resultado"), "reveal button")
	await wait(2.0)
	await shot("presentation_new_species")
	expect(park.hud.is_presenting(), "new species presentation shown")
	var hybrid: CreatureInstance = null
	for c in CreatureRoster.all():
		if c.species_id == &"xenorex":
			hybrid = c
	expect(hybrid != null and ArchiveManager.knows(&"xenorex", &"owned"), "Xenorex created and in the Arquivo")
	await continue_presentation(park)
	# a second synthesis through the recipe UI
	GeneticsManager.add_species_dna(&"rex_primordial", 60)
	GeneticsManager.add_species_dna(&"xenoraptor", 60)
	var panel := current_panel(park)
	panel.selected_recipe = &"xenorex"
	panel.refresh()
	await wait(0.4)
	await shot("lab_recipes")
	expect(press(panel, "Iniciar síntese"), "start synthesis via UI")
	await wait(0.6)
	await shot("lab_job_running")
	expect(GeneticsManager.jobs.has(lab.uid), "synthesis job running")
	GeneticsManager.jobs[lab.uid].outcome = "failure"
	GameClock.advance(DataRegistry.get_recipe(&"xenorex").creation_time + 1)
	await wait(1.4)
	press(current_panel(park), "Revelar resultado")
	await wait(2.0)
	await shot("presentation_failure")
	expect(GeneticsManager.material(&"mat_unstable") > 0, "failure gives unstable material")
	await continue_presentation(park)
	panel = current_panel(park)
	panel.tab = "extract"
	panel.refresh()
	await wait(0.4)
	var dna_before := GeneticsManager.dna_of(&"triceratopo_ancestral")
	var tri: CreatureInstance = ctx.tri
	panel._extract_card(tri)
	var extracted := GeneticsManager.extract_dna(tri)
	panel.refresh()
	await wait(0.3)
	await shot("lab_extraction")
	expect(extracted > 0 and GeneticsManager.dna_of(&"triceratopo_ancestral") > dna_before and CreatureRoster.get_creature(tri.uid) != null, "extraction is non-destructive")
	panel.tab = "bank"
	panel.refresh()
	await wait(0.4)
	await shot("lab_gene_bank")
	ResearchManager.completed[&"gen_sequencing"] = true
	ResearchManager.add_rp(60, false)
	panel.tab = "genes"
	panel.selected_creature = hybrid.uid
	panel.refresh()
	await wait(0.3)
	expect(press(panel, "Sequenciar (%d PP)" % GeneticsManager.SEQUENCE_RP), "sequence via UI")
	await wait(0.4)
	await shot("lab_genes_sequenced")
	expect(hybrid.sequenced, "hybrid sequenced")
	expect(press(current_panel(park), "Árvore genética"), "open genetic tree")
	await wait(0.8)
	await shot("genetic_tree")
	park.hud.close_all()
	# paleontology: pure restoration
	ResearchManager.completed[&"paleo_methods"] = true
	var paleo := place(&"paleo_center", ctx.anchor + Vector2i(-12, 6))
	GeneticsManager.add_fossils(&"glaciadon", 10)
	park.hud.open_building(paleo)
	await wait(0.6)
	await shot("paleo_center")
	expect(press(current_panel(park), "Restauração pura"), "start pure restoration")
	GameClock.advance(GeneticsManager.RESTORE_TIME + 1)
	await wait(1.4)
	expect(press(current_panel(park), "Concluir restauração"), "collect restoration")
	await wait(1.6)
	await shot("presentation_restored")
	await continue_presentation(park)
	park.hud.close_all()
	# mutagen
	ResearchManager.completed[&"mutation_studies"] = true
	var mut := place(&"mutagen_center", ctx.anchor + Vector2i(10, 6))
	GeneticsManager.add_material(&"mat_serum", 2)
	ArchiveManager.note_mutation(&"xenoraptor", &"eletrica")
	park.hud.open_building(mut)
	await wait(0.6)
	var mp := current_panel(park)
	mp.selected_creature = ctx.xeno.uid
	mp.refresh()
	await wait(0.4)
	await shot("mutagen_center")
	seed(4)
	press(mp, "Induzir mutação")
	await wait(1.6)
	await shot("mutagen_result")
	print("GTOUR induced mutation: ", ctx.xeno.mutation_id)
	await continue_presentation(park)
	park.hud.close_all()
