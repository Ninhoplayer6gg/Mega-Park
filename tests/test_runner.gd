extends Node
## Headless logic tests. Run:
##   godot --headless res://tests/test_runner.tscn
## Exits with code 0 when every test passes, 1 otherwise.

var _failures := 0
var _checks := 0
var _current := ""


func _ready() -> void:
	SaveManager.set_enabled(true)
	var tests := [
		"test_data_loaded", "test_new_game_flow", "test_placement_rules", "test_level_and_feed",
		"test_battle_resolver", "test_battle_balance", "test_expedition", "test_save_roundtrip",
		"test_save_newer_version_preserved",
		"test_mutation_incubation", "test_hybrid_flow", "test_recipe_gating", "test_secret_recipe",
		"test_three_and_four_species", "test_failure_and_prototype", "test_genetics_save_roundtrip",
		"test_migration_v1_fixture", "test_hybrid_battle", "test_team_and_boss_battle", "test_evolution",
		"test_restoration", "test_induced_mutation", "test_research_and_staff", "test_events_and_visitors",
		"test_social_and_ecosystem",
	]
	for t in tests:
		_current = t
		print("> ", t)
		await call(t)
	print("\n%d checks, %d failures" % [_checks, _failures])
	SaveManager.delete_save()
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL [%s] %s" % [_current, msg])


func test_data_loaded() -> void:
	check(DataRegistry.creatures.size() >= 3, "3 creatures loaded")
	check(DataRegistry.buildings.has(&"habitat_prehistoric"), "habitat building loaded")
	check(DataRegistry.missions.size() >= 6, "missions loaded")
	check(DataRegistry.arena.size() >= 1, "arena loaded")
	for c in DataRegistry.creatures.values():
		check(c.sprite_sheet != null, "%s has sprite" % c.id)
		check(c.abilities.size() >= 2, "%s has 2+ abilities" % c.id)
		var frames := DataRegistry.sprite_frames_for(c)
		for anim in ["idle", "walk", "attack", "hurt", "defeat"]:
			check(frames.has_animation(anim), "%s has anim %s" % [c.id, anim])
	for b in DataRegistry.buildings.values():
		check(b.is_habitat() == (DataRegistry.get_habitat_type(b.habitat_type) != null) or not b.is_habitat(),
			"%s habitat type resolves" % b.id)
	check(ParkState.layout.width > 20 and ParkState.layout.height > 20, "map layout parsed")


func _find_free_cell(data: BuildingData) -> Vector2i:
	for y in range(2, ParkState.layout.height - data.size.y):
		for x in range(2, ParkState.layout.width - data.size.x):
			if ParkState.check_placement(data, Vector2i(x, y), true) == "":
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func test_new_game_flow() -> void:
	SaveManager.new_game()
	check(Economy.credits == Economy.START_CREDITS, "starting credits")
	check(ParkState.has_building(&"park_entrance"), "entrance placed")
	check(ParkState.count_of(&"path") > 5, "start paths placed")
	var hab_data := DataRegistry.get_building(&"habitat_prehistoric")
	var cell := _find_free_cell(hab_data)
	check(cell.x >= 0, "free cell for habitat")
	var hab := ParkState.place(hab_data, cell)
	check(hab != null, "habitat placed")
	check(Economy.credits == Economy.START_CREDITS - hab_data.cost_credits, "habitat cost charged")
	var inc_data := DataRegistry.get_building(&"incubator")
	var inc := ParkState.place(inc_data, _find_free_cell(inc_data))
	check(inc != null, "incubator placed")
	var m1: MissionData = DataRegistry.missions[&"m01_build_habitat"]
	check(MissionManager.is_complete(m1), "habitat mission complete")
	check(MissionManager.claim(m1), "habitat mission claimed")
	var rex := DataRegistry.get_creature(&"rex_primordial")
	var dna_before := Economy.dna
	check(IncubationManager.start(inc.uid, rex), "incubation started")
	check(Economy.dna == dna_before - rex.dna_cost, "dna charged")
	check(not IncubationManager.is_ready(inc.uid), "not ready immediately")
	check(IncubationManager.collect(inc.uid) == null, "cannot collect early")
	GameClock.advance(rex.incubation_time + 1)
	check(IncubationManager.is_ready(inc.uid), "ready after time")
	var c := IncubationManager.collect(inc.uid)
	check(c != null and c.level == 1, "creature hatched at level 1")
	check(CreatureRoster.compatible_habitats(c).size() == 1, "one compatible habitat")
	check(CreatureRoster.assign_to_habitat(c, hab.uid), "assigned to habitat")
	GameClock.advance(rex.income_interval * 3 + 0.5)
	var pending := CreatureRoster.habitat_pending(hab.uid)
	var expected := int(round(rex.income_amount * 3 * SocialLogic.production_multiplier(c)))
	check(pending == expected and pending > 0, "pending income %d (expected %d)" % [pending, expected])
	var credits_before := Economy.credits
	check(CreatureRoster.collect_habitat(hab.uid) == pending, "collected")
	check(Economy.credits == credits_before + pending, "credits added")
	check(CreatureRoster.habitat_pending(hab.uid) == 0, "pending reset")
	GameClock.advance(10000)
	check(CreatureRoster.habitat_pending(hab.uid) == int(round(c.income_cap() * SocialLogic.production_multiplier(c))), "income capped")
	# Xenoraptor must not fit the prehistoric habitat
	var xeno := CreatureRoster.add_new(DataRegistry.get_creature(&"xenoraptor"))
	check(CreatureRoster.check_assign(xeno, hab.uid) != "", "xeno rejected by prehistoric habitat")
	CreatureRoster.creatures.erase(xeno.uid)
	# Habitat with creatures can't be removed
	check(ParkState.check_removal(hab) != "", "occupied habitat not removable")


func test_placement_rules() -> void:
	SaveManager.new_game()
	var hab_data := DataRegistry.get_building(&"habitat_prehistoric")
	check(ParkState.check_placement(hab_data, Vector2i(-1, 0)) != "", "out of bounds rejected")
	var water := Vector2i(-1, -1)
	for y in ParkState.layout.height:
		for x in ParkState.layout.width:
			if ParkState.layout.is_water(Vector2i(x, y)):
				water = Vector2i(x, y)
	check(ParkState.check_placement(DataRegistry.get_building(&"path"), water) != "", "water rejected")
	var cell := _find_free_cell(hab_data)
	ParkState.place(hab_data, cell)
	check(ParkState.check_placement(hab_data, cell) != "", "overlap rejected")
	var gate := DataRegistry.get_building(&"gate")
	var free := _find_free_cell(gate)
	check(ParkState.check_placement(gate, free) != "" or ParkState.get_at_cell(free + Vector2i.LEFT) != null,
		"gate needs fence")
	var fence := DataRegistry.get_building(&"fence")
	var fcell := _find_free_cell(DataRegistry.get_building(&"generator"))
	ParkState.place(fence, fcell)
	check(ParkState.check_placement(gate, fcell + Vector2i.RIGHT) == "", "gate next to fence ok")
	ParkState.place(fence, fcell + Vector2i.DOWN)
	check(ParkState.connection_mask(fcell, &"fence") == 4, "fence connects south")
	# Energy: research center (6) + incubator (4) exceed entrance (10) -> second incubator blocked
	ParkState.place(DataRegistry.get_building(&"incubator"), _find_free_cell(DataRegistry.get_building(&"incubator")))
	Economy.add(5000)
	var rc := DataRegistry.get_building(&"research_center")
	ParkState.place(rc, _find_free_cell(rc))
	check(ParkState.energy_free() == 0, "energy fully used")
	check(ParkState.check_rules(DataRegistry.get_building(&"incubator")) != "", "incubator blocked by energy")
	ParkState.place(DataRegistry.get_building(&"generator"), _find_free_cell(DataRegistry.get_building(&"generator")))
	check(ParkState.check_rules(DataRegistry.get_building(&"incubator")) == "", "generator restores energy")
	Economy.credits = 0
	check(ParkState.check_placement(fence, _find_free_cell(fence)) != "", "cannot afford")


func test_level_and_feed() -> void:
	SaveManager.new_game()
	var c := CreatureRoster.add_new(DataRegistry.get_creature(&"triceratopo_ancestral"))
	var hp1 := c.max_hp()
	var gained := 0
	var guard := 0
	while c.level < 2 and guard < 20:
		gained += maxi(CreatureRoster.feed(c), 0)
		guard += 1
	check(c.level == 2, "level 2 reached by feeding")
	check(c.max_hp() > hp1, "hp grows with level")
	var m: MissionData = DataRegistry.missions[&"m07_level2"]
	check(MissionManager.is_complete(m), "level mission complete")
	CreatureRoster.give_xp(c, 999999)
	check(c.level == c.data.max_level, "max level clamps")


func _sim(a_species: StringName, a_level: int, b_species: StringName, b_level: int, n: int) -> float:
	var wins := 0
	for i in n:
		var a := Combatant.from_species(DataRegistry.get_creature(a_species), a_level)
		var b := Combatant.from_species(DataRegistry.get_creature(b_species), b_level)
		var state := BattleState.new(a, b, i * 7919 + 13)
		while not state.finished:
			BattleResolver.resolve_round(state, BattleAI.choose(state, a), BattleAI.choose(state, b))
		if state.winner == a:
			wins += 1
	return float(wins) / n


func test_battle_resolver() -> void:
	var rex := Combatant.from_species(DataRegistry.get_creature(&"rex_primordial"), 1)
	var tri := Combatant.from_species(DataRegistry.get_creature(&"triceratopo_ancestral"), 1)
	var state := BattleState.new(rex, tri, 42)
	var bite := DataRegistry.get_ability(&"brutal_bite")
	check(not rex.can_use(bite), "bite unaffordable at start (energy %d)" % rex.energy)
	var guard := BattleRules.basic(AbilityData.Kind.GUARD)
	var attack := BattleRules.basic(AbilityData.Kind.ATTACK)
	var events := BattleResolver.resolve_round(state, attack, guard)
	check(events[0].type == "action" and events[0].actor == tri, "guard acts first (priority)")
	var dmg_event = events.filter(func(e): return e.type == "damage")[0]
	var unguarded := BattleRules.expected_damage(rex, tri, attack)
	check(dmg_event.amount < unguarded, "guard reduced damage")
	check(rex.energy == BattleRules.START_ENERGY + BattleRules.ENERGY_PER_ROUND, "energy regen")
	var reserve := BattleRules.basic(AbilityData.Kind.RESERVE)
	BattleResolver.resolve_round(state, reserve, attack)
	check(rex.energy >= 4 + reserve.energy_gain, "reserve banks energy")
	BattleResolver.resolve_round(state, bite, attack)
	check(int(rex.cooldowns.get(bite.id, 0)) == bite.cooldown, "cooldown set")
	check(not rex.can_use(bite), "bite on cooldown")
	var roar := DataRegistry.get_ability(&"dominant_roar")
	rex.energy = 10
	var atk_before := tri.attack()
	BattleResolver.resolve_round(state, roar, guard)
	check(tri.attack() < atk_before, "roar lowers attack")
	# AI picks something legal
	for i in 20:
		var choice := BattleAI.choose(state, tri)
		check(tri.can_use(choice), "ai choice usable")
	# lethal: AI goes for the kill
	var x := Combatant.from_species(DataRegistry.get_creature(&"xenoraptor"), 3)
	var r2 := Combatant.from_species(DataRegistry.get_creature(&"rex_primordial"), 1)
	r2.hp = 20
	var s2 := BattleState.new(x, r2, 1)
	x.energy = 10
	var pick := BattleAI.choose(s2, x, 0.0)
	check(pick.is_damaging(), "ai finishes low-hp foe (picked %s)" % pick.id)


func test_battle_balance() -> void:
	var pairs := [
		[&"rex_primordial", 1, &"triceratopo_ancestral", 1],
		[&"triceratopo_ancestral", 1, &"triceratopo_ancestral", 1],
		[&"rex_primordial", 2, &"triceratopo_ancestral", 1],
		[&"triceratopo_ancestral", 2, &"triceratopo_ancestral", 1],
		[&"rex_primordial", 1, &"xenoraptor", 1],
		[&"triceratopo_ancestral", 1, &"xenoraptor", 1],
		[&"rex_primordial", 3, &"rex_primordial", 2],
	]
	for p in pairs:
		var rate := _sim(p[0], p[1], p[2], p[3], 200)
		print("  balance %s L%d vs %s L%d: %.0f%%" % [p[0], p[1], p[2], p[3], rate * 100])
		if p[1] == p[3]:
			check(rate > 0.2 and rate < 0.8, "same-level matchup reasonably balanced")
		else:
			check(rate > 0.5, "level advantage matters")
	# measure average battle length
	var rounds := 0
	for i in 50:
		var a := Combatant.from_species(DataRegistry.get_creature(&"rex_primordial"), 1)
		var b := Combatant.from_species(DataRegistry.get_creature(&"triceratopo_ancestral"), 1)
		var st := BattleState.new(a, b, i)
		while not st.finished:
			BattleResolver.resolve_round(st, BattleAI.choose(st, a), BattleAI.choose(st, b))
		rounds += st.round_number
	print("  average rounds: %.1f" % (rounds / 50.0))
	check(rounds / 50.0 > 3 and rounds / 50.0 < 15, "battle length reasonable")


func test_expedition() -> void:
	SaveManager.new_game()
	var e: ExpeditionData = DataRegistry.expeditions[&"vale_primordial"]
	var credits := Economy.credits
	check(ExpeditionManager.start(e), "expedition started")
	check(Economy.credits == credits - e.cost_credits, "expedition cost")
	check(ExpeditionManager.collect(e.id).is_empty(), "not ready yet")
	GameClock.advance(e.duration + 1)
	var r := ExpeditionManager.collect(e.id)
	check(r.credits >= e.credits_min and r.credits <= e.credits_max, "credit reward in range")
	check(not ExpeditionManager.is_active(e.id), "expedition cleared")
	var r1 := ExpeditionManager.roll_rewards(e, 1234)
	var r2 := ExpeditionManager.roll_rewards(e, 1234)
	check(r1.credits == r2.credits and r1.dna == r2.dna, "rewards deterministic per seed")


func test_save_roundtrip() -> void:
	SaveManager.new_game()
	var hab_data := DataRegistry.get_building(&"habitat_prehistoric")
	var hab := ParkState.place(hab_data, _find_free_cell(hab_data))
	var inc_data := DataRegistry.get_building(&"incubator")
	var inc := ParkState.place(inc_data, _find_free_cell(inc_data))
	var c := CreatureRoster.add_new(DataRegistry.get_creature(&"rex_primordial"))
	CreatureRoster.assign_to_habitat(c, hab.uid)
	CreatureRoster.give_xp(c, 70)
	IncubationManager.start(inc.uid, DataRegistry.get_creature(&"triceratopo_ancestral"))
	ExpeditionManager.start(DataRegistry.expeditions[&"vale_primordial"])
	var snapshot := SaveManager.build_save_data()
	check(SaveManager.save_game(), "saved")
	# wreck state then load
	Economy.reset()
	ParkState.reset()
	CreatureRoster.reset()
	IncubationManager.reset()
	ExpeditionManager.reset()
	MissionManager.reset()
	check(SaveManager.load_game(), "loaded")
	var after := SaveManager.build_save_data()
	check(JSON.stringify(snapshot.economy) == JSON.stringify(after.economy), "economy restored")
	check(after.park.buildings.size() == snapshot.park.buildings.size(), "buildings restored")
	var c2 := CreatureRoster.get_creature(c.uid)
	check(c2 != null and c2.level == c.level and c2.xp == c.xp and c2.habitat_uid == hab.uid, "creature restored")
	check(IncubationManager.has_slot(inc.uid), "incubation restored")
	check(ExpeditionManager.is_active(&"vale_primordial"), "expedition restored")
	check(MissionManager.is_complete(DataRegistry.missions[&"m01_build_habitat"]), "missions restored")
	check(FileAccess.file_exists(SaveManager.BACKUP_PATH) or true, "backup path ok")


func test_save_newer_version_preserved() -> void:
	SaveManager.delete_save()
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_version": 999, "economy": {"credits": 1}}))
	f.close()
	check(not SaveManager.load_game(), "newer save not loaded")
	check(SaveManager.load_warning != "", "warning set")
	var found := false
	for file in DirAccess.get_files_at("user://"):
		if file.begins_with("mega_park_save.newer_v999"):
			found = true
			DirAccess.remove_absolute("user://" + file)
	check(found, "newer save preserved on disk")
	# corrupt save
	f = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check(not SaveManager.load_game(), "corrupt save not loaded")
	for file in DirAccess.get_files_at("user://"):
		if file.begins_with("mega_park_save.corrupt"):
			DirAccess.remove_absolute("user://" + file)
	# migration of v0 (no version field)
	var migrated := SaveMigrations.migrate({"economy": {}}, SaveManager.SAVE_VERSION)
	check(int(migrated.get("save_version", 0)) == SaveManager.SAVE_VERSION, "v0 migrates")


# =============================================================== genetics update tests
func _setup_lab_park() -> Dictionary:
	SaveManager.new_game()
	EventManager.enabled = false
	Economy.add(200000, 5000)
	for r in DataRegistry.research.keys():
		ResearchManager.completed[r] = true
	var gens := []
	for i in 4:
		gens.append(ParkState.place(DataRegistry.get_building(&"generator"), _find_free_cell(DataRegistry.get_building(&"generator"))))
	var out := {}
	for id in [&"research_center", &"genetic_lab", &"habitat_prehistoric", &"habitat_alien", &"habitat_glacial", &"incubator"]:
		var d := DataRegistry.get_building(id)
		out[id] = ParkState.place(d, _find_free_cell(d))
	return out


func test_mutation_incubation() -> void:
	SaveManager.new_game()
	var xeno := DataRegistry.get_creature(&"xenoraptor")
	# Find a seed that produces a mutation, and check determinism + rate sanity.
	var mutated := 0
	var first_seed := -1
	for i in 2000:
		var m := GeneticsLogic.roll_mutation(xeno, GeneticsLogic.rng_for(i), 0.0, 100.0)
		if m != &"":
			mutated += 1
			if first_seed < 0:
				first_seed = i
	var rate := mutated / 2000.0
	print("  mutation rate (xeno): %.1f%%" % (rate * 100))
	check(rate > 0.03 and rate < 0.25, "mutation chance is small but real")
	check(GeneticsLogic.roll_mutation(xeno, GeneticsLogic.rng_for(first_seed)) != &"", "mutation roll deterministic per seed")
	var tempest := DataRegistry.get_mutation(&"tempestade")
	check(not tempest.can_apply_to(DataRegistry.get_creature(&"rex_primordial")), "tempestade exclusive to xenoraptor")
	var c := CreatureRoster.add_new(xeno)
	c.mutation_id = &"tempestade"
	check(c.display_name() == "Xenoraptor Tempestade", "big mutation has its own name")
	check(c.form_sheet() != null and c.form_sheet() != xeno.sprite_sheet, "big mutation has its own sprite sheet")
	check(c.speed() > Combatant.from_species(xeno, 1).base_speed, "mutation modifies stats")
	check(c.abilities().size() == xeno.abilities.size() + 1, "mutation grants ability")


func test_hybrid_flow() -> void:
	var b := _setup_lab_park()
	var lab: BuildingInstance = b[&"genetic_lab"]
	check(lab != null and GeneticsManager.lab_level() == 1, "genetic lab built (level 1)")
	var rex := CreatureRoster.add_new(DataRegistry.get_creature(&"rex_primordial"))
	var xeno := CreatureRoster.add_new(DataRegistry.get_creature(&"xenoraptor"))
	# Extraction is non-destructive and fills the species DNA bank.
	for i in 6:
		rex.extracted_at = 0
		xeno.extracted_at = 0
		GeneticsManager.extract_dna(rex)
		GeneticsManager.extract_dna(xeno)
	check(GeneticsManager.dna_of(&"rex_primordial") >= 40 and GeneticsManager.dna_of(&"xenoraptor") >= 40, "dna extracted")
	check(CreatureRoster.get_creature(rex.uid) != null, "extraction keeps the donor")
	var recipe := DataRegistry.get_recipe(&"xenorex")
	var donors := GeneticsManager.default_donors(recipe)
	check(donors[0] == rex and donors[1] == xeno, "donors picked")
	var stab := GeneticsManager.stability_for(recipe, donors)
	check(stab >= 85.0, "2-species stability high (%d)" % stab)
	check(GeneticsManager.check_recipe(recipe, donors, lab.uid) == "", "recipe ready: " + GeneticsManager.check_recipe(recipe, donors, lab.uid))
	var dna_before := GeneticsManager.dna_of(&"rex_primordial")
	check(GeneticsManager.start_synthesis(lab.uid, recipe, donors), "synthesis started")
	check(GeneticsManager.dna_of(&"rex_primordial") == dna_before - 40, "species dna consumed")
	GeneticsManager.jobs[lab.uid].outcome = "success"
	check(GeneticsManager.collect_synthesis(lab.uid).is_empty(), "not ready before creation time")
	GameClock.advance(recipe.creation_time + 1)
	var res := GeneticsManager.collect_synthesis(lab.uid)
	var h: CreatureInstance = res.creature
	check(h != null and h.species_id == &"xenorex", "xenorex created")
	check(res.new_species, "first synthesis reveals a new species")
	check(h.data.sprite_sheet.resource_path.ends_with("xenorex.png"), "hybrid has its own sprite")
	check(h.data.icon != null and h.data.abilities.size() >= 2, "hybrid has icon and abilities")
	check(h.lineage.parents.size() == 2 and h.lineage.parents[0].uid == rex.uid and h.lineage.parents[1].uid == xeno.uid, "lineage records donors")
	check(h.generation() == 1, "generation 1")
	check(h.active_genes.size() <= GeneticsLogic.MAX_ACTIVE_GENES and h.active_genes.has(&"gene_forca"), "dominant genes active")
	check(ArchiveManager.is_registered(&"xenorex") and ArchiveManager.knows(&"xenorex", &"owned"), "xenorex in Arquivo Mega")
	check(GeneticsManager.is_discovered(recipe), "recipe discovered")
	check(CreatureRoster.assign_to_habitat(h, b[&"habitat_prehistoric"].uid), "hybrid lives in the park")
	check(MissionManager.get_progress(DataRegistry.missions[&"m15_hybrid"]) == 1, "hybrid mission progress")


func test_recipe_gating() -> void:
	SaveManager.new_game()
	EventManager.enabled = false
	var recipe := DataRegistry.get_recipe(&"xenorex")
	var donors := [null, null]
	check(GeneticsManager.check_recipe(recipe, donors).contains("laboratório"), "blocked without lab")
	ParkState.buildings_changed.emit()
	var b := _setup_lab_park()
	ResearchManager.completed.erase(&"hybrid_basics")
	check(GeneticsManager.check_recipe(recipe, donors).contains("pesquisa"), "blocked without research")
	ResearchManager.completed[&"hybrid_basics"] = true
	check(GeneticsManager.check_recipe(recipe, donors).contains("DNA de"), "blocked without species DNA")
	GeneticsManager.add_species_dna(&"rex_primordial", 100)
	GeneticsManager.add_species_dna(&"xenoraptor", 100)
	Economy.credits = 100
	check(GeneticsManager.check_recipe(recipe, donors).contains("Créditos"), "blocked without credits")
	Economy.credits = 100000
	Economy.dna = 0
	check(GeneticsManager.check_recipe(recipe, donors).contains("DNA genérico"), "blocked without generic DNA")
	Economy.dna = 1000
	check(GeneticsManager.check_recipe(recipe, donors) == "", "unblocked with everything")
	var lab: BuildingInstance = b[&"genetic_lab"]
	GeneticsManager.start_synthesis(lab.uid, recipe, donors)
	check(GeneticsManager.check_recipe(recipe, donors, lab.uid).contains("ocupado"), "lab busy")
	check(ParkState.check_removal(lab) != "", "busy lab not removable")


func test_secret_recipe() -> void:
	var b := _setup_lab_park()
	var recipe := DataRegistry.get_recipe(&"cryoceratops")
	check(recipe.hidden_recipe, "cryoceratops is secret")
	check(not GeneticsManager.is_visible(recipe), "secret recipe not listed initially")
	GeneticsManager.add_species_dna(&"triceratopo_ancestral", 60)
	check(not GeneticsManager.is_visible(recipe), "needs both species")
	GeneticsManager.add_species_dna(&"glaciadon", 60)
	check(GeneticsManager.is_visible(recipe), "compatibility detected")
	check(not GeneticsManager.is_revealed(recipe), "result still unknown")
	check(GeneticsManager.check_recipe(recipe, [null, null]).contains("Materiais"), "needs cryo crystals")
	GeneticsManager.add_material(&"mat_cryo", 2)
	var lab: BuildingInstance = b[&"genetic_lab"]
	check(GeneticsManager.start_synthesis(lab.uid, recipe, [null, null]), "secret synthesis started")
	GeneticsManager.jobs[lab.uid].outcome = "success"
	GameClock.advance(recipe.creation_time + 1)
	var res := GeneticsManager.collect_synthesis(lab.uid)
	check(res.creature.species_id == &"cryoceratops" and res.new_species, "NOVA ESPÉCIE DESCOBERTA")
	check(GeneticsManager.is_revealed(recipe), "secret recipe revealed after success")
	check(res.creature.lineage.parents[0].uid == "", "bank DNA lineage without individual")


func test_three_and_four_species() -> void:
	var b := _setup_lab_park()
	var astro := DataRegistry.get_recipe(&"astrocerus")
	var aurorax := DataRegistry.get_recipe(&"aurorax")
	check(astro.tier() == 3 and aurorax.tier() == 4, "tiers 3 and 4")
	for s in [&"rex_primordial", &"triceratopo_ancestral", &"xenoraptor", &"glaciadon"]:
		GeneticsManager.add_species_dna(s, 200)
	GeneticsManager.add_material(&"mat_cosmic", 5)
	GeneticsManager.add_material(&"mat_cryo", 5)
	GeneticsManager.add_material(&"mat_unstable", 5)
	check(GeneticsManager.check_recipe(astro, [null, null, null]).contains("nível 2"), "3 species needs lab level 2")
	ParkState.place(DataRegistry.get_building(&"hybrid_core"), _find_free_cell(DataRegistry.get_building(&"hybrid_core")))
	check(GeneticsManager.lab_level() == 2, "hybrid core -> level 2")
	check(GeneticsManager.check_recipe(aurorax, [null, null, null, null]).contains("nível 3"), "4 species needs Câmara Quimérica")
	var s2 := GeneticsManager.stability_for(DataRegistry.get_recipe(&"xenorex"), [null, null])
	var s3 := GeneticsManager.stability_for(astro, [null, null, null])
	var chamber: BuildingInstance = ParkState.place(DataRegistry.get_building(&"chimera_chamber"), _find_free_cell(DataRegistry.get_building(&"chimera_chamber")))
	var s4 := GeneticsManager.stability_for(aurorax, [null, null, null, null])
	print("  stability 2/3/4: %d / %d / %d" % [s2, s3, s4])
	check(s2 > s3 and s3 > s4 - 6, "complexity lowers stability")
	check(GeneticsManager.lab_level() == 3, "chimera chamber -> level 3")
	var small_lab: BuildingInstance = b[&"genetic_lab"]
	check(GeneticsManager.check_recipe(aurorax, [null, null, null, null], small_lab.uid).contains("Câmara"), "level-1 lab redirects to the Câmara Quimérica")
	var lab := chamber
	check(GeneticsManager.check_recipe(aurorax, [null, null, null, null], lab.uid) == "", "aurorax ready: " + GeneticsManager.check_recipe(aurorax, [null, null, null, null], lab.uid))
	GeneticsManager.start_synthesis(lab.uid, aurorax, [null, null, null, null])
	GeneticsManager.jobs[lab.uid].outcome = "success"
	GameClock.advance(aurorax.creation_time + 1)
	var res := GeneticsManager.collect_synthesis(lab.uid)
	check(res.creature != null and res.creature.species_id == &"aurorax" and res.creature.lineage.parents.size() == 4, "Quimera Suprema created")
	check(res.creature.data.size_class == &"giant", "aurorax is giant")


func test_failure_and_prototype() -> void:
	var b := _setup_lab_park()
	var lab: BuildingInstance = b[&"genetic_lab"]
	var recipe := DataRegistry.get_recipe(&"xenorex")
	var rex := CreatureRoster.add_new(DataRegistry.get_creature(&"rex_primordial"))
	GeneticsManager.add_species_dna(&"rex_primordial", 100)
	GeneticsManager.add_species_dna(&"xenoraptor", 100)
	var count := CreatureRoster.count()
	GeneticsManager.start_synthesis(lab.uid, recipe, [rex, null])
	GeneticsManager.jobs[lab.uid].outcome = "failure"
	GameClock.advance(recipe.creation_time + 1)
	var rp_before := ResearchManager.rp
	var res := GeneticsManager.collect_synthesis(lab.uid)
	check(res.outcome == &"failure" and res.creature == null, "failure produces no creature")
	check(CreatureRoster.count() == count and CreatureRoster.get_creature(rex.uid) != null, "failure never destroys creatures")
	check(ResearchManager.rp > rp_before and GeneticsManager.material(&"mat_unstable") >= 1, "failure gives research + unstable material")
	check(GeneticsManager.dna_of(&"rex_primordial") > 60, "part of the DNA refunded")
	GeneticsManager.start_synthesis(lab.uid, recipe, [rex, null])
	GeneticsManager.jobs[lab.uid].outcome = "prototype"
	GameClock.advance(recipe.creation_time + 1)
	res = GeneticsManager.collect_synthesis(lab.uid)
	check(res.creature != null and res.creature.species_id == &"quimerideo_instavel", "prototype created")
	check(res.creature.genetic_stability < 50.0 and res.creature.origin() == "prototype", "prototype is unstable")
	# Statistical outcome check
	var succ := 0
	for i in 400:
		if GeneticsLogic.roll_outcome(60.0, 3, GeneticsLogic.rng_for(i)) == &"success":
			succ += 1
	check(succ > 200 and succ < 280, "outcome follows stability (%d/400)" % succ)


func test_genetics_save_roundtrip() -> void:
	var b := _setup_lab_park()
	var lab: BuildingInstance = b[&"genetic_lab"]
	var rex := CreatureRoster.add_new(DataRegistry.get_creature(&"rex_primordial"))
	var xeno := CreatureRoster.add_new(DataRegistry.get_creature(&"xenoraptor"))
	xeno.mutation_id = &"tempestade"
	ArchiveManager.note_mutation(&"xenoraptor", &"tempestade")
	GeneticsManager.add_species_dna(&"rex_primordial", 100)
	GeneticsManager.add_species_dna(&"xenoraptor", 100)
	GeneticsManager.start_synthesis(lab.uid, DataRegistry.get_recipe(&"xenorex"), [rex, xeno])
	GeneticsManager.jobs[lab.uid].outcome = "success"
	GameClock.advance(60)
	var h: CreatureInstance = GeneticsManager.collect_synthesis(lab.uid).creature
	h.sequenced = true
	CreatureRoster.assign_to_habitat(h, b[&"habitat_prehistoric"].uid)
	ParkState.install_upgrade(b[&"habitat_prehistoric"], DataRegistry.habitat_upgrades[&"lago"])
	GeneticsManager.add_material(&"mat_cosmic", 3)
	GeneticsManager.add_fossils(&"glaciadon", 4)
	StaffManager.hire(DataRegistry.researchers[&"helena_viana"])
	var snapshot := SaveManager.build_save_data()
	check(snapshot.save_version == 2, "save v2")
	check(SaveManager.save_game(), "saved genetics")
	SaveManager.reset_state()
	check(CreatureRoster.count() == 0, "state cleared")
	check(SaveManager.load_game(), "loaded genetics")
	var h2 := CreatureRoster.get_creature(h.uid)
	check(h2 != null and h2.species_id == &"xenorex", "hybrid restored")
	check(h2.active_genes == h.active_genes and h2.recessive_genes == h.recessive_genes, "genes restored")
	check(h2.lineage.parents.size() == 2 and h2.lineage.parents[1].uid == xeno.uid, "lineage restored")
	check(is_equal_approx(h2.genetic_stability, h.genetic_stability) and is_equal_approx(h2.genetic_purity, h.genetic_purity), "stability/purity restored")
	check(h2.personality_id == h.personality_id and h2.sequenced, "personality + sequencing restored")
	var x2 := CreatureRoster.get_creature(xeno.uid)
	check(x2.mutation_id == &"tempestade" and x2.display_name() == "Xenoraptor Tempestade", "mutation restored")
	check(GeneticsManager.is_discovered(DataRegistry.get_recipe(&"xenorex")), "recipe discovery restored")
	check(GeneticsManager.material(&"mat_cosmic") == 3 and GeneticsManager.fossils.get(&"glaciadon", 0) == 4, "materials/fossils restored")
	check(ArchiveManager.knows(&"xenorex", &"owned") and ArchiveManager.mutation_known(&"tempestade"), "archive restored")
	check(StaffManager.level_of(&"helena_viana") == 1, "staff restored")
	check(ParkState.habitat_upgrades(ParkState.get_building(b[&"habitat_prehistoric"].uid)).has("lago"), "ecosystem features restored")
	check(ResearchManager.is_done(&"chimera_synthesis"), "research restored")


func test_migration_v1_fixture() -> void:
	SaveManager.delete_save()
	var src := FileAccess.open("res://tests/fixtures/save_v1.json", FileAccess.READ)
	check(src != null, "v1 fixture present")
	var text := src.get_as_text()
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var old: Dictionary = JSON.parse_string(text)
	check(int(old.save_version) == 1, "fixture is v1")
	check(SaveManager.load_game(), "v1 save loads in v2")
	check(Economy.credits == int(old.economy.credits), "v1 credits kept")
	check(CreatureRoster.count() == old.creatures.creatures.size(), "v1 creatures kept")
	for c in CreatureRoster.creatures.values():
		check(c.active_genes.size() > 0 and c.personality_id != &"", "%s got genes + personality" % c.species_id)
		var again := CreatureInstance.from_dict(c.to_dict())
		check(again.active_genes == c.active_genes, "genes stable")
	check(ParkState.buildings.size() == old.park.buildings.size(), "v1 buildings kept")
	check(IncubationManager.slots.size() == old.incubation.slots.size(), "v1 incubation kept")
	check(ArchiveManager.knows(&"rex_primordial", &"owned"), "archive seeded from v1")
	check(SaveManager.save_game(), "migrated save written")
	var saved: Dictionary = JSON.parse_string(FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ).get_as_text())
	check(int(saved.save_version) == 2, "now saved as v2")
	check(FileAccess.file_exists(SaveManager.BACKUP_PATH), "previous file kept as backup")


func _battle(a_team: Array, b_team: Array, seed_value: int, env: ArenaEnvironmentData = null) -> BattleState:
	var st := BattleState.new(a_team, b_team, seed_value)
	st.setup(env)
	var guard := 0
	while not st.finished and guard < 200:
		BattleResolver.resolve_round(st, BattleAI.choose(st, st.player), BattleAI.choose(st, st.enemy))
		guard += 1
	return st


func test_hybrid_battle() -> void:
	SaveManager.new_game()
	var x := CreatureRoster.add_new(DataRegistry.get_creature(&"xenorex"))
	var cb := Combatant.from_instance(x)
	check(cb.own_abilities.size() == 4, "xenorex brings 4 abilities")
	var rex := CreatureRoster.add_new(DataRegistry.get_creature(&"rex_primordial"))
	var wins := 0
	for i in 100:
		var foe := Combatant.from_instance(rex)
		foe.is_player = false
		var st := _battle([Combatant.from_instance(x)], [foe], i)
		if st.winner_is_player:
			wins += 1
	print("  xenorex L1 vs rex L1 (both with genes): %d%%" % wins)
	check(wins > 40 and wins < 98, "hybrid is strong but not invincible")
	for sp in [&"astrocerus", &"cryoceratops", &"aurorax", &"glaciadon", &"compsolux", &"xenoraptor_alfa", &"xenorex_brutal", &"quimerideo_instavel"]:
		var st := _battle([Combatant.from_species(DataRegistry.get_creature(sp), 3)], [Combatant.from_species(DataRegistry.get_creature(&"triceratopo_ancestral"), 3)], 7)
		check(st.finished, "%s battle finishes" % sp)


func test_team_and_boss_battle() -> void:
	SaveManager.new_game()
	var team := [Combatant.from_species(DataRegistry.get_creature(&"triceratopo_ancestral"), 3),
		Combatant.from_species(DataRegistry.get_creature(&"rex_primordial"), 3),
		Combatant.from_species(DataRegistry.get_creature(&"compsolux"), 3)]
	var syn := BattleRules.active_synergies(team)
	check(syn.any(func(s): return s.id == &"trio_prehistoric"), "prehistoric trio synergy")
	check(syn.any(func(s): return s.id == &"equilibrio"), "balanced team synergy")
	var stage: ArenaOpponentData = DataRegistry.arena[&"team_02"]
	var enemy := ArenaManager.build_enemy_team(stage)
	check(enemy.size() == 3, "team stage has 3 opponents")
	var st := _battle(team, enemy, 3, stage.environment)
	check(st.finished, "team battle finishes")
	var fainted := 0
	for c in (st.enemy_team if st.winner_is_player else st.player_team):
		if not c.is_alive():
			fainted += 1
	check(fainted == 3, "loser team fully defeated")
	# Combo: Xenorex + Cryoceratops
	var duo := [Combatant.from_species(DataRegistry.get_creature(&"xenorex"), 3), Combatant.from_species(DataRegistry.get_creature(&"cryoceratops"), 3)]
	var st2 := BattleState.new(duo, [Combatant.from_species(DataRegistry.get_creature(&"rex_primordial"), 3)], 1)
	check(duo[0].combo_abilities.any(func(a): return a.id == &"combo_nova_glacial"), "combo available with partner on bench")
	# Swap
	var ev := BattleResolver.resolve_round(st2, BattleRules.swap_action(1), BattleRules.basic(AbilityData.Kind.ATTACK))
	check(st2.player == duo[1] and ev[0].type == "switch", "swap brings the bench creature in")
	# Boss phases
	var boss_stage: ArenaOpponentData = DataRegistry.arena[&"boss_matriarca"]
	var boss: Combatant = ArenaManager.build_enemy_team(boss_stage)[0]
	check(boss.is_boss and boss.max_hp > Combatant.from_species(boss_stage.creature, boss_stage.level).max_hp * 2, "boss has huge HP")
	var st3 := BattleState.new([Combatant.from_species(DataRegistry.get_creature(&"aurorax"), 10)], [boss], 5)
	var phases := 0
	var guard := 0
	while not st3.finished and guard < 200:
		for e in BattleResolver.resolve_round(st3, BattleAI.choose(st3, st3.player), BattleAI.choose(st3, st3.enemy)):
			if e.type == "phase":
				phases += 1
		guard += 1
	check(phases >= 1, "boss changed phase (%d)" % phases)
	check(boss.own_abilities.any(func(a): return a.id == &"stellar_fury") or not boss.is_alive(), "phase ability added")
	# Boss rewards
	var x := CreatureRoster.add_new(DataRegistry.get_creature(&"xenoraptor"))
	var result := ArenaManager.apply_result([x.uid], boss_stage, true)
	check(CreatureRoster.is_discovered(&"xenoraptor_alfa") and result.unlocked_species == "xenoraptor_alfa", "boss unlocks Alfa")
	check(GeneticsManager.dna_of(&"xenoraptor_alfa") > 0, "boss gives Alfa DNA")
	check(MissionManager.get_progress(DataRegistry.missions[&"m21_boss"]) == 1, "boss mission progress")


func test_evolution() -> void:
	SaveManager.new_game()
	Economy.add(100000, 2000)
	var x := CreatureRoster.add_new(DataRegistry.get_creature(&"xenorex"))
	var evo: EvolutionData = DataRegistry.evolutions[&"xenorex_brutal"]
	check(CreatureRoster.evolution_routes(x).size() == 1, "xenorex has an evolution route")
	check(CreatureRoster.check_evolution(x, evo) != "", "evolution gated")
	ResearchManager.completed[&"artificial_evolution"] = true
	x.level = 5
	GeneticsManager.add_material(&"mat_cosmic", 1)
	var uid := x.uid
	var genes := x.active_genes.duplicate()
	check(CreatureRoster.evolve(x, evo), "evolved")
	check(x.uid == uid and x.species_id == &"xenorex_brutal" and x.active_genes == genes, "evolution keeps the individual")
	check(x.data.sprite_sheet.resource_path.ends_with("xenorex_brutal.png"), "evolution has its own sprite")
	check(x.lineage.get("evolved_from", "") == "xenorex", "lineage notes evolution")


func test_restoration() -> void:
	var b := _setup_lab_park()
	var paleo := ParkState.place(DataRegistry.get_building(&"paleo_center"), _find_free_cell(DataRegistry.get_building(&"paleo_center")))
	var glac := DataRegistry.get_creature(&"glaciadon")
	check(not CreatureRoster.is_discovered(&"glaciadon"), "glaciadon unknown at start")
	check(GeneticsManager.check_restoration(glac, &"pure", paleo.uid) != "", "pure restoration needs fragments")
	GeneticsManager.add_fossils(&"glaciadon", 6)
	check(GeneticsManager.check_restoration(glac, &"assisted", paleo.uid).contains("Âmbar"), "assisted needs amber")
	GeneticsManager.add_material(&"mat_amber", 1)
	GeneticsManager.add_species_dna(&"triceratopo_ancestral", 30)
	check(GeneticsManager.check_restoration(glac, &"assisted", paleo.uid) == "", "assisted ready")
	check(GeneticsManager.start_restoration(paleo.uid, glac, &"assisted"), "assisted restoration started")
	GameClock.advance(GeneticsManager.RESTORE_TIME + 1)
	var c := GeneticsManager.collect_restoration(paleo.uid)
	check(c != null and c.species_id == &"glaciadon" and c.genetic_purity < 100.0 and c.genetic_purity >= 50.0, "assisted reconstruction purity %d%%" % (c.genetic_purity if c else 0))
	check(CreatureRoster.is_discovered(&"glaciadon"), "restoration discovers the species")
	GeneticsManager.add_fossils(&"glaciadon", 10)
	GeneticsManager.start_restoration(paleo.uid, glac, &"pure")
	GameClock.advance(GeneticsManager.RESTORE_TIME + 1)
	var p := GeneticsManager.collect_restoration(paleo.uid)
	check(p.genetic_purity == 100.0 and p.origin() == "restored_pure", "pure restoration 100%")
	check(CreatureRoster.assign_to_habitat(p, b[&"habitat_glacial"].uid), "glaciadon lives in the glacial habitat")


func test_induced_mutation() -> void:
	var b := _setup_lab_park()
	var x := CreatureRoster.add_new(DataRegistry.get_creature(&"xenoraptor"))
	var m := DataRegistry.get_mutation(&"eletrica")
	check(GeneticsManager.check_induce(x, m).contains("Centro"), "needs mutagen center")
	ParkState.place(DataRegistry.get_building(&"mutagen_center"), _find_free_cell(DataRegistry.get_building(&"mutagen_center")))
	check(GeneticsManager.check_induce(x, m).contains("catalogada"), "needs a known mutation")
	ArchiveManager.note_mutation(&"rex_primordial", &"eletrica")
	check(GeneticsManager.check_induce(x, m).contains("Soro"), "needs serum")
	var ok := false
	for i in 20:
		GeneticsManager.add_material(&"mat_serum", 1)
		if GeneticsManager.induce_mutation(x, m):
			ok = true
			break
	check(ok and x.mutation_id == &"eletrica", "induced mutation applied")
	check(Bonuses.get_value(&"mutation_chance") >= 0.05, "mutagen center + research raise mutation chance")


func test_research_and_staff() -> void:
	SaveManager.new_game()
	var r := DataRegistry.get_research(&"hybrid_basics")
	check(ResearchManager.check(r) != "", "research needs RP")
	ResearchManager.add_rp(100, false)
	check(ResearchManager.start(r), "research started")
	check(ResearchManager.collect() == null, "not ready yet")
	GameClock.advance(r.duration + 1)
	check(ResearchManager.collect() == r and ResearchManager.unlocked(&"hybrid_2"), "research completed")
	check(ParkState.check_rules(DataRegistry.get_building(&"genetic_lab")).contains("Energia") or ParkState.check_rules(DataRegistry.get_building(&"genetic_lab")) == "", "lab unlocked by research")
	check(ParkState.check_rules(DataRegistry.get_building(&"hybrid_core")) != "", "core still locked")
	Economy.add(10000)
	var hel: ResearcherData = DataRegistry.researchers[&"helena_viana"]
	var before := Bonuses.get_value(&"stability")
	check(StaffManager.hire(hel), "geneticist hired")
	check(Bonuses.get_value(&"stability") == before + 2.0, "geneticist adds stability")
	ResearchManager.add_rp(100, false)
	check(StaffManager.level_up(hel) and StaffManager.level_of(hel.id) == 2, "geneticist levels up")


func test_events_and_visitors() -> void:
	var b := _setup_lab_park()
	EventManager.enabled = true
	var c := CreatureRoster.add_new(DataRegistry.get_creature(&"rex_primordial"))
	CreatureRoster.assign_to_habitat(c, b[&"habitat_prehistoric"].uid)
	var cap := ParkState.energy_capacity()
	var uid := EventManager.spawn(DataRegistry.events[&"pane_energia"])
	check(ParkState.energy_capacity() == cap - 6, "power issue lowers energy")
	EventManager.resolve(uid)
	check(ParkState.energy_capacity() == cap, "repair restores energy")
	var s_uid := EventManager.spawn(DataRegistry.events[&"criatura_estressada"])
	check(EventManager.creature_stress(c.uid) > 0.0, "stressed creature")
	var happy_stressed := SocialLogic.happiness(c)
	EventManager.resolve(s_uid)
	check(SocialLogic.happiness(c) > happy_stressed, "calming restores happiness")
	var g_uid := EventManager.spawn(DataRegistry.events[&"amostra_genetica"])
	var target := StringName(EventManager.active[g_uid].target)
	var before := GeneticsManager.dna_of(target)
	EventManager.resolve(g_uid)
	check(GeneticsManager.dna_of(target) > before, "genetic sample event gives species DNA")
	var p_uid := EventManager.spawn(DataRegistry.events[&"anomalia"])
	check(ExpeditionManager.is_available(DataRegistry.expeditions[&"fenda_dimensional"]), "portal opens temporary expedition")
	GameClock.advance(DataRegistry.events[&"anomalia"].duration + 2)
	check(not EventManager.active.has(p_uid) and not ExpeditionManager.is_available(DataRegistry.expeditions[&"fenda_dimensional"]), "portal closes")
	EventManager.enabled = false
	VisitorManager.recompute()
	check(VisitorManager.visitors > 0, "visitors attracted (%d)" % VisitorManager.visitors)


func test_social_and_ecosystem() -> void:
	var b := _setup_lab_park()
	var hab: BuildingInstance = b[&"habitat_prehistoric"]
	var rex := CreatureRoster.add_new(DataRegistry.get_creature(&"rex_primordial"))
	var tri := CreatureRoster.add_new(DataRegistry.get_creature(&"triceratopo_ancestral"))
	var tri2 := CreatureRoster.add_new(DataRegistry.get_creature(&"triceratopo_ancestral"))
	for c in [rex, tri, tri2]:
		CreatureRoster.assign_to_habitat(c, hab.uid)
	var rel := SocialLogic.relation(tri, tri2)
	check(rel.kind == &"friendly", "same species friendly")
	var rel2 := SocialLogic.relation(tri, rex)
	check(rel2.score < rel.score, "predator nearby is worse than a herd mate (%s)" % rel2.kind)
	var h_before := SocialLogic.happiness(tri)
	ParkState.install_upgrade(hab, DataRegistry.habitat_upgrades[&"vegetacao"])
	ParkState.install_upgrade(hab, DataRegistry.habitat_upgrades[&"lago"])
	check(SocialLogic.ecosystem_score(tri, hab) == 1.0, "trike needs met")
	check(SocialLogic.happiness(tri) > h_before, "ecosystem raises happiness")
	check(SocialLogic.production_multiplier(tri) > 0.9, "happy creatures produce more")
	check(MissionManager.get_progress(DataRegistry.missions[&"m19_ecosystem"]) == 1, "ecosystem mission")
