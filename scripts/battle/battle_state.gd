class_name BattleState
extends RefCounted
## Teams of combatants (1 for classic 1v1, up to 3 for team battles). `player` / `enemy` are the
## active combatants; when one faints the next standing team member enters.

var player_team: Array = []
var enemy_team: Array = []
var player: Combatant
var enemy: Combatant
var round_number := 1
var finished := false
var winner: Combatant
var winner_is_player := false
var rng := RandomNumberGenerator.new()
var environment: ArenaEnvironmentData
var synergies_player: Array = []
var synergies_enemy: Array = []


func _init(p, e, seed_value := -1) -> void:
	player_team = p if p is Array else [p]
	enemy_team = e if e is Array else [e]
	player = player_team[0]
	enemy = enemy_team[0]
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	refresh_combos()


func opponent_of(c: Combatant) -> Combatant:
	return enemy if player_team.has(c) else player


func team_of(c: Combatant) -> Array:
	return player_team if player_team.has(c) else enemy_team


func bench(team: Array, active: Combatant) -> Array:
	return team.filter(func(m): return m != active and m.is_alive())


func next_alive(team: Array) -> Combatant:
	for m in team:
		if m.is_alive():
			return m
	return null


func is_team_battle() -> bool:
	return player_team.size() > 1 or enemy_team.size() > 1


## Applies arena environment and team synergies to every combatant (call once before round 1).
func setup(env: ArenaEnvironmentData) -> void:
	environment = env
	for team in [player_team, enemy_team]:
		for c in team:
			if env:
				for t in c.types:
					if env.type_modifiers.has(String(t)):
						c.apply_stat_multipliers(env.type_modifiers[String(t)])
	synergies_player = BattleRules.active_synergies(player_team)
	synergies_enemy = BattleRules.active_synergies(enemy_team)
	for s in synergies_player:
		for c in player_team:
			c.apply_stat_multipliers(s.stat_modifiers)
	for s in synergies_enemy:
		for c in enemy_team:
			c.apply_stat_multipliers(s.stat_modifiers)
	refresh_combos()


## Combo abilities are available when a compatible partner is alive on the bench.
func refresh_combos() -> void:
	for team in [player_team, enemy_team]:
		for c in team:
			c.combo_abilities.clear()
			for a in DataRegistry.abilities.values():
				if a.combo_partners.is_empty() or not a.combo_partners.has(c.data.base_species().id):
					continue
				for m in team:
					if m != c and m.is_alive() and a.combo_partners.has(m.data.base_species().id) \
							and m.data.base_species().id != c.data.base_species().id:
						c.combo_abilities.append(a)
						break
