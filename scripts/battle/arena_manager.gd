extends Node
## Arena ladder progress and battle reward application (kept out of the UI on purpose).

signal arena_changed

var wins := {}      # stage id -> wins
var losses := 0


func reset() -> void:
	wins.clear()
	losses = 0
	arena_changed.emit()


func stages() -> Array:
	return DataRegistry.sorted(DataRegistry.arena)


func is_beaten(stage: ArenaOpponentData) -> bool:
	return int(wins.get(stage.id, 0)) > 0


func is_unlocked(stage: ArenaOpponentData) -> bool:
	var list := stages()
	var idx := list.find(stage)
	return idx <= 0 or is_beaten(list[idx - 1])


## The first stage not yet beaten (or the last one if all are beaten).
func next_stage() -> ArenaOpponentData:
	var list := stages()
	for s in list:
		if not is_beaten(s):
			return s
	return list.back() if not list.is_empty() else null


## Applies rewards for a finished battle and returns a summary for the result screen.
func apply_result(creature_uid: String, stage: ArenaOpponentData, won: bool) -> Dictionary:
	var c := CreatureRoster.get_creature(creature_uid)
	var result := {
		"won": won, "opponent_id": stage.id, "creature_uid": creature_uid,
		"credits": stage.reward_credits if won else stage.loss_credits,
		"dna": stage.reward_dna if won else 0,
		"creature_xp": stage.reward_creature_xp if won else stage.loss_creature_xp,
		"player_xp": stage.reward_player_xp if won else stage.reward_player_xp / 4,
		"levels_gained": 0, "old_level": c.level if c else 1, "old_xp": c.xp if c else 0,
		"first_win": won and not is_beaten(stage),
	}
	if won:
		wins[stage.id] = int(wins.get(stage.id, 0)) + 1
	else:
		losses += 1
	Economy.add(result.credits, result.dna)
	Economy.add_player_xp(result.player_xp)
	if c:
		result.levels_gained = CreatureRoster.give_xp(c, result.creature_xp)
		if won:
			c.battles_won += 1
	arena_changed.emit()
	EventBus.battle_finished.emit(result)
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
