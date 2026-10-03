extends Node
## Timed expeditions to regions defined in data/expeditions.

signal expeditions_changed

var active := {}   # expedition_id -> {"start": float, "duration": float, "seed": int}
var completed_count := 0


func reset() -> void:
	active.clear()
	completed_count = 0
	expeditions_changed.emit()


## Expeditions currently offered: tracking ones need enough clues, temporary ones need an open portal.
func list() -> Array:
	return DataRegistry.sorted(DataRegistry.expeditions).filter(func(e): return is_available(e) or active.has(e.id))


func is_available(e: ExpeditionData) -> bool:
	if e.temporary and not EventManager.portal_open():
		return false
	if e.tracking_species:
		var sp := e.tracking_species
		return not CreatureRoster.is_discovered(sp.id) and GeneticsManager.clues_of(sp.id) >= sp.clues_required
	return true


func is_active(id: StringName) -> bool:
	return active.has(id)


func time_left(id: StringName) -> float:
	if not active.has(id):
		return 0.0
	var a: Dictionary = active[id]
	return maxf(a.start + a.duration - GameClock.now(), 0.0)


func progress(id: StringName) -> float:
	if not active.has(id):
		return 0.0
	var a: Dictionary = active[id]
	return clampf((GameClock.now() - a.start) / maxf(a.duration, 0.01), 0.0, 1.0)


func is_ready(id: StringName) -> bool:
	return active.has(id) and time_left(id) <= 0.0


func check_start(data: ExpeditionData) -> String:
	if active.has(data.id):
		return "Expedição em andamento."
	if not is_available(data):
		return "Indisponível no momento."
	if Economy.player_level < data.unlock_player_level:
		return "Requer nível %d do parque." % data.unlock_player_level
	if not Economy.can_afford(data.cost_credits):
		return "Créditos insuficientes."
	return ""


func start(data: ExpeditionData) -> bool:
	var reason := check_start(data)
	if reason != "":
		EventBus.toast(reason, "close", "bad")
		AudioManager.play_sfx(&"error")
		return false
	Economy.spend(data.cost_credits)
	active[data.id] = {"start": GameClock.now(), "duration": data.duration, "seed": randi()}
	expeditions_changed.emit()
	EventBus.expedition_started.emit(data.id)
	AudioManager.play_sfx(&"expedition")
	return true


## Rolls rewards deterministically from the seed stored at start (no save-scumming).
func roll_rewards(data: ExpeditionData, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rewards := {
		"credits": rng.randi_range(data.credits_min, data.credits_max),
		"dna": rng.randi_range(data.dna_min, data.dna_max),
		"player_xp": data.player_xp,
		"species": &"",
		"species_dna": 0,
	}
	if not data.species_pool.is_empty() and rng.randf() < data.species_sample_chance:
		var species: CreatureData = data.species_pool[rng.randi_range(0, data.species_pool.size() - 1)]
		rewards.species = species.id
		rewards.species_dna = data.species_sample_dna
	rewards["rp"] = data.rp_reward
	var mats := {}
	for mid in data.material_rewards:
		var spec: Array = data.material_rewards[mid]
		if rng.randf() < float(spec[2]):
			mats[mid] = rng.randi_range(int(spec[0]), int(spec[1]))
	rewards["materials"] = mats
	rewards["fossils"] = 0
	if data.fossil_species:
		rewards.fossils = rng.randi_range(data.fossil_range.x, data.fossil_range.y)
		rewards["fossil_species"] = data.fossil_species.id
	rewards["clues"] = 0
	if data.clue_species and rng.randf() < data.clue_chance:
		rewards.clues = 1
		rewards["clue_species"] = data.clue_species.id
	return rewards


func collect(id: StringName) -> Dictionary:
	if not is_ready(id):
		return {}
	var data: ExpeditionData = DataRegistry.expeditions.get(id)
	var a: Dictionary = active[id]
	active.erase(id)
	if data == null:
		expeditions_changed.emit()
		return {}
	var rewards := roll_rewards(data, a.seed)
	rewards["new_species"] = false
	if data.tracking_species:
		rewards.species = data.tracking_species.id
	if rewards.species != &"":
		# Samples discover the species only for tracking expeditions or already-known regions.
		if data.tracking_species or data.temporary or CreatureRoster.is_discovered(rewards.species) \
				or DataRegistry.get_creature(rewards.species).discovery_mode in [&"expedition", &"research"]:
			rewards.new_species = CreatureRoster.discover(rewards.species)
		GeneticsManager.add_species_dna(rewards.species, rewards.species_dna)
	for mid in rewards.materials:
		GeneticsManager.add_material(StringName(mid), int(rewards.materials[mid]))
	if rewards.fossils > 0:
		rewards.fossils += int(Bonuses.get_value(&"fossil_bonus"))
		GeneticsManager.add_fossils(rewards.fossil_species, rewards.fossils)
	if rewards.clues > 0:
		GeneticsManager.add_clue(rewards.clue_species, rewards.clues)
	rewards.rp = ResearchManager.add_rp(rewards.rp)
	Economy.add(rewards.credits, rewards.dna)
	Economy.add_player_xp(rewards.player_xp)
	completed_count += 1
	expeditions_changed.emit()
	EventBus.expedition_completed.emit(id, rewards)
	return rewards


func to_dict() -> Dictionary:
	var out := {}
	for id in active:
		out[String(id)] = active[id].duplicate()
	return {"active": out, "completed": completed_count}


func from_dict(d: Dictionary) -> void:
	active.clear()
	var saved: Dictionary = d.get("active", {})
	for id in saved:
		if DataRegistry.expeditions.has(StringName(id)):
			var a: Dictionary = saved[id]
			active[StringName(id)] = {"start": float(a.get("start", 0)), "duration": float(a.get("duration", 30)),
				"seed": int(a.get("seed", 0))}
	completed_count = int(d.get("completed", 0))
	expeditions_changed.emit()
