extends Node
## Developer tool: AI-vs-AI win rates between species at equal level.
## Run: godot --headless res://tests/balance_sim.tscn

const MATCHUPS := [
	[&"xenorex", &"rex_primordial"], [&"xenorex", &"xenoraptor"], [&"xenorex", &"triceratopo_ancestral"],
	[&"cryoceratops", &"triceratopo_ancestral"], [&"cryoceratops", &"rex_primordial"], [&"cryoceratops", &"glaciadon"],
	[&"astrocerus", &"xenorex"], [&"aurorax", &"astrocerus"], [&"xenorex_brutal", &"xenorex"],
	[&"xenoraptor_alfa", &"xenoraptor"], [&"glaciadon", &"triceratopo_ancestral"], [&"compsolux", &"xenoraptor"],
	[&"quimerideo_instavel", &"rex_primordial"], [&"rex_primordial", &"xenoraptor"], [&"rex_primordial", &"triceratopo_ancestral"],
	[&"xenoraptor", &"triceratopo_ancestral"],
]
const RUNS := 200


func _ready() -> void:
	EventManager.enabled = false
	# Optional overrides for quick tuning: -- xenorex=590,75,30,104
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		var c: CreatureData = DataRegistry.get_creature(StringName(kv[0]))
		if c and kv.size() == 2:
			var v := kv[1].split(",")
			c.base_health = int(v[0]); c.base_attack = int(v[1]); c.base_defense = int(v[2]); c.base_speed = int(v[3])
	if OS.get_cmdline_user_args().has("log"):
		_log_one(&"xenorex", &"rex_primordial")
		get_tree().quit()
		return
	for lvl in [1, 5]:
		print("== level %d ==" % lvl)
		for m in MATCHUPS:
			var a: CreatureData = DataRegistry.get_creature(m[0])
			var b: CreatureData = DataRegistry.get_creature(m[1])
			var wins := 0
			var rounds := 0
			for i in RUNS:
				var st := BattleState.new([Combatant.from_species(a, lvl)], [Combatant.from_species(b, lvl)], i)
				st.setup(null)
				var guard := 0
				while not st.finished and guard < 200:
					BattleResolver.resolve_round(st, BattleAI.choose(st, st.player), BattleAI.choose(st, st.enemy))
					guard += 1
				rounds += guard
				if st.winner_is_player:
					wins += 1
			print("  %-20s vs %-22s %3d%%  (%.1f rounds)" % [m[0], m[1], wins * 100 / RUNS, float(rounds) / RUNS])
	get_tree().quit()


func _log_one(a_id: StringName, b_id: StringName) -> void:
	var a := Combatant.from_species(DataRegistry.get_creature(a_id), 1)
	var b := Combatant.from_species(DataRegistry.get_creature(b_id), 1)
	for c in [a, b]:
		print("%s hp %d atk %d def %d spd %d" % [c.name, c.max_hp, c.attack(), c.defense(), c.speed()])
	var st := BattleState.new([a], [b], 3)
	st.setup(null)
	while not st.finished:
		var pa := BattleAI.choose(st, st.player)
		var pb := BattleAI.choose(st, st.enemy)
		var ev := BattleResolver.resolve_round(st, pa, pb)
		print("R: %s(%d en) vs %s(%d en)" % [pa.id, st.player.energy, pb.id, st.enemy.energy])
		for e in ev:
			if e.type in ["damage", "heal", "effect"]:
				print("   ", e)
		print("   hp %d / %d" % [st.player.hp, st.enemy.hp])
