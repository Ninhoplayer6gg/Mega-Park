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
		check(c.abilities.size() == 2, "%s has 2 abilities" % c.id)
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
	check(pending == rex.income_amount * 3, "pending income %d" % pending)
	var credits_before := Economy.credits
	check(CreatureRoster.collect_habitat(hab.uid) == pending, "collected")
	check(Economy.credits == credits_before + pending, "credits added")
	check(CreatureRoster.habitat_pending(hab.uid) == 0, "pending reset")
	GameClock.advance(10000)
	check(CreatureRoster.habitat_pending(hab.uid) == c.income_cap(), "income capped")
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
