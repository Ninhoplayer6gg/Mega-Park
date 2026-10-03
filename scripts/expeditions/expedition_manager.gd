extends Node
## Timed expeditions to regions defined in data/expeditions.

signal expeditions_changed

var active := {}   # expedition_id -> {"start": float, "duration": float, "seed": int}
var completed_count := 0


func reset() -> void:
	active.clear()
	completed_count = 0
	expeditions_changed.emit()


func list() -> Array:
	return DataRegistry.sorted(DataRegistry.expeditions)


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
	if rewards.species != &"":
		rewards.new_species = CreatureRoster.discover(rewards.species)
	Economy.add(rewards.credits, rewards.dna + rewards.species_dna)
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
