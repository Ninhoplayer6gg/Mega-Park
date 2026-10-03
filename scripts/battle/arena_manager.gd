extends Node
## Arena ladder progress (solo, team and boss stages) and battle reward application.

signal arena_changed

const TEAM_SIZE := 3

var wins := {}      # stage id -> wins
var losses := 0


func reset() -> void:
	wins.clear()
	losses = 0
	arena_changed.emit()


func stages(mode: StringName = &"solo") -> Array:
	return DataRegistry.sorted(DataRegistry.arena).filter(func(s): return s.mode == mode)


func is_beaten(stage: ArenaOpponentData) -> bool:
	return int(wins.get(stage.id, 0)) > 0


func is_unlocked(stage: ArenaOpponentData) -> bool:
	if stage.required_research != &"" and not ResearchManager.is_done(stage.required_research):
		return false
	if stage.mode == &"boss":
		# Bosses open once the solo ladder's 3rd stage is beaten.
		var solo := stages(&"solo")
		return solo.size() < 3 or is_beaten(solo[2])
	var list := stages(stage.mode)
	var idx := list.find(stage)
	return idx <= 0 or is_beaten(list[idx - 1])


func lock_reason(stage: ArenaOpponentData) -> String:
	if stage.required_research != &"" and not ResearchManager.is_done(stage.required_research):
		var r := DataRegistry.get_research(stage.required_research)
		return "Requer a pesquisa %s." % (r.display_name if r else String(stage.required_research))
	if stage.mode == &"boss":
		return "Vença o 3º adversário da Arena."
	return "Vença o adversário anterior."


## The first stage not yet beaten (or the last one if all are beaten).
func next_stage(mode: StringName = &"solo") -> ArenaOpponentData:
	var list := stages(mode)
	for s in list:
		if not is_beaten(s) and is_unlocked(s):
			return s
	for s in list:
		if is_unlocked(s):
			return s
	return list.back() if not list.is_empty() else null


## Opponent combatants for a stage (team stages use `team`, others the single creature).
func build_enemy_team(stage: ArenaOpponentData) -> Array:
	var out := []
	if stage.mode == &"team" and not stage.team.is_empty():
		for i in stage.team.size():
			var lvl: int = stage.team_levels[i] if i < stage.team_levels.size() else stage.level
			out.append(Combatant.from_species(stage.team[i], lvl))
	else:
		var cb := Combatant.from_species(stage.creature, stage.level)
		if stage.mode == &"boss":
			cb.is_boss = true
			cb.phases = Array(stage.phases)
			cb.apply_stat_multipliers({"health": stage.boss_hp_multiplier})
			cb.name = stage.title
		out.append(cb)
	return out


## Applies rewards for a finished battle and returns a summary for the result screen.
## creature_uids: the player's participants (1 for solo/boss, up to 3 for team).
func apply_result(creature_uids: Variant, stage: ArenaOpponentData, won: bool) -> Dictionary:
	var uids: Array = creature_uids if creature_uids is Array else [creature_uids]
	var credit_mult := 1.0 + Bonuses.get_value(&"battle_credits")
	var result := {
		"won": won, "opponent_id": stage.id, "creature_uid": uids[0] if not uids.is_empty() else "",
		"creature_uids": uids, "mode": stage.mode,
		"credits": int(round((stage.reward_credits if won else stage.loss_credits) * credit_mult)),
		"dna": stage.reward_dna if won else 0,
		"creature_xp": stage.reward_creature_xp if won else stage.loss_creature_xp,
		"player_xp": stage.reward_player_xp if won else stage.reward_player_xp / 4,
		"rp": stage.reward_rp if won else 1,
		"levels_gained": 0, "first_win": won and not is_beaten(stage),
		"species_dna": {}, "materials": {}, "unlocked_species": "", "unlocked_recipe": "",
		"species_involved": [],
	}
	var first := CreatureRoster.get_creature(result.creature_uid)
	result["old_level"] = first.level if first else 1
	result["old_xp"] = first.xp if first else 0
	if won:
		wins[stage.id] = int(wins.get(stage.id, 0)) + 1
		var opp_species: Array = stage.team if stage.mode == &"team" and not stage.team.is_empty() else [stage.creature]
		for sp in opp_species:
			var amount := 8 + stage.order * 2 if stage.mode != &"boss" else stage.reward_species_dna
			GeneticsManager.add_species_dna(sp.id, amount)
			result.species_dna[String(sp.id)] = int(result.species_dna.get(String(sp.id), 0)) + amount
		for mid in stage.reward_materials:
			GeneticsManager.add_material(StringName(mid), int(stage.reward_materials[mid]))
			result.materials[mid] = int(stage.reward_materials[mid])
		if stage.unlock_species and result.first_win:
			CreatureRoster.discover(stage.unlock_species.id)
			result.unlocked_species = String(stage.unlock_species.id)
		if stage.unlock_recipe != &"" and result.first_win:
			GeneticsManager.detect_recipe(stage.unlock_recipe)
			result.unlocked_recipe = String(stage.unlock_recipe)
	else:
		losses += 1
	Economy.add(result.credits, result.dna)
	Economy.add_player_xp(result.player_xp)
	result.rp = ResearchManager.add_rp(result.rp)
	var share: int = result.creature_xp if uids.size() <= 1 else int(result.creature_xp * 0.7)
	for uid in uids:
		var c := CreatureRoster.get_creature(uid)
		if c:
			var gained := CreatureRoster.give_xp(c, share)
			if uid == result.creature_uid:
				result.levels_gained = gained
			if won:
				c.battles_won += 1
			result.species_involved.append(String(c.species_id))
	if stage.creature:
		result.species_involved.append(String(stage.creature.id))
	for sp in stage.team:
		result.species_involved.append(String(sp.id))
	arena_changed.emit()
	EventBus.battle_finished.emit(result)
	if won and stage.mode == &"boss":
		EventBus.boss_defeated.emit(stage.id)
	if won and stage.mode == &"team":
		EventBus.team_battle_won.emit(stage.id)
	return result


func to_dict() -> Dictionary:
	var w := {}
	for k in wins:
		w[String(k)] = wins[k]
	return {"wins": w, "losses": losses}


func from_dict(d: Dictionary) -> void:
	wins.clear()
	var w: Dictionary = d.get("wins", {})
	for k in w:
		wins[StringName(k)] = int(w[k])
	losses = int(d.get("losses", 0))
	arena_changed.emit()
