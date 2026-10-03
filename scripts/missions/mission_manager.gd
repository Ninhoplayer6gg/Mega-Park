extends Node
## Tracks mission progress from EventBus events. Missions are shown in order; all of them track
## progress from the start so nothing the player does early is lost.

signal missions_changed

var progress := {}   # mission_id -> int
var claimed := {}    # mission_id -> true


func _ready() -> void:
	EventBus.building_placed.connect(func(b: BuildingInstance):
		_bump(&"building_placed", [b.data.category, b.data.id]))
	EventBus.creature_hatched.connect(func(c: CreatureInstance): _bump(&"creature_hatched", [c.species_id]))
	EventBus.creature_assigned.connect(func(c: CreatureInstance, _h): _bump(&"creature_assigned", [c.species_id]))
	EventBus.credits_collected.connect(func(_amount, _pos): _bump(&"credits_collected", []))
	EventBus.creature_fed.connect(func(c: CreatureInstance): _bump(&"creature_fed", [c.species_id]))
	EventBus.creature_leveled.connect(func(_c, _l): _set_max(&"creature_level", CreatureRoster.highest_level()))
	EventBus.incubation_started.connect(func(_b, s): _bump(&"incubation_started", [s]))
	EventBus.expedition_completed.connect(func(id, _r): _bump(&"expedition_completed", [id]))
	EventBus.battle_finished.connect(func(result: Dictionary):
		if result.get("won", false):
			_bump(&"battle_won", [result.get("opponent_id", &"")]))
	EventBus.research_completed.connect(func(id): _bump(&"research_completed", [id]))
	EventBus.dna_extracted.connect(func(c, _a): _bump(&"dna_extracted", [c.species_id]))
	EventBus.hybrid_created.connect(func(c, r, _n): _bump(&"hybrid_created", [c.species_id, r]))
	EventBus.photo_taken.connect(func(rec): _bump(&"photo_taken", [StringName(rec.get("species", ""))]))
	EventBus.species_restored.connect(func(c): _bump(&"species_restored", [c.species_id]))
	EventBus.eco_upgrade_installed.connect(func(_h, u): _bump(&"eco_upgrade", [u]))
	EventBus.team_battle_won.connect(func(id): _bump(&"team_battle_won", [id]))
	EventBus.boss_defeated.connect(func(id): _bump(&"boss_defeated", [id]))
	EventBus.archive_updated.connect(func(_s): _set_max(&"archive_entries", ArchiveManager.entries_count()))
	EventBus.creature_evolved.connect(func(c, _f): _bump(&"creature_evolved", [c.species_id]))


func reset() -> void:
	progress.clear()
	claimed.clear()
	missions_changed.emit()


func ordered() -> Array:
	return DataRegistry.sorted(DataRegistry.missions)


func get_progress(m: MissionData) -> int:
	return mini(int(progress.get(m.id, 0)), m.target)


func is_complete(m: MissionData) -> bool:
	return get_progress(m) >= m.target


func is_claimed(m: MissionData) -> bool:
	return claimed.has(m.id)


## First mission not yet claimed: the one the HUD tracker shows.
func current() -> MissionData:
	for m in ordered():
		if not is_claimed(m):
			return m
	return null


## Missions visible in the panel: all claimed ones + the next few pending ones.
func visible_missions(pending_window := 3) -> Array:
	var out := []
	var pending := 0
	for m in ordered():
		if is_claimed(m):
			continue
		if pending < pending_window:
			out.append(m)
			pending += 1
	return out


func claimable_count() -> int:
	var n := 0
	for m in visible_missions():
		if is_complete(m) and not is_claimed(m):
			n += 1
	return n


func claim(m: MissionData) -> bool:
	if is_claimed(m) or not is_complete(m):
		return false
	claimed[m.id] = true
	Economy.add(m.reward_credits, m.reward_dna)
	Economy.add_player_xp(m.reward_player_xp)
	missions_changed.emit()
	EventBus.mission_claimed.emit(m.id)
	AudioManager.play_sfx(&"purchase")
	return true


func _matches(m: MissionData, params: Array) -> bool:
	return m.objective_param == &"" or params.has(m.objective_param)


func _bump(objective: StringName, params: Array, amount := 1) -> void:
	var changed := false
	for m in DataRegistry.missions.values():
		if m.objective == objective and not claimed.has(m.id) and _matches(m, params):
			if int(progress.get(m.id, 0)) < m.target:
				progress[m.id] = int(progress.get(m.id, 0)) + amount
				changed = true
				_notify_if_done(m)
	if changed:
		missions_changed.emit()


func _set_max(objective: StringName, value: int) -> void:
	var changed := false
	for m in DataRegistry.missions.values():
		if m.objective == objective and not claimed.has(m.id) and value > int(progress.get(m.id, 0)):
			progress[m.id] = value
			changed = true
			_notify_if_done(m)
	if changed:
		missions_changed.emit()


func _notify_if_done(m: MissionData) -> void:
	EventBus.mission_progressed.emit(m.id)
	if is_complete(m):
		EventBus.toast("Missão concluída: %s" % m.title, "missions", "good")


func to_dict() -> Dictionary:
	var p := {}
	for k in progress:
		p[String(k)] = progress[k]
	return {"progress": p, "claimed": claimed.keys().map(func(k): return String(k))}


func from_dict(d: Dictionary) -> void:
	progress.clear()
	claimed.clear()
	var p: Dictionary = d.get("progress", {})
	for k in p:
		progress[StringName(k)] = int(p[k])
	for k in d.get("claimed", []):
		claimed[StringName(k)] = true
	missions_changed.emit()
