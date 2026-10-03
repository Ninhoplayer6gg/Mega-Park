extends Node
## Incubation slots, one per incubator building. Timers use wall-clock time so they keep
## running while the game is closed.

signal slots_changed

var slots := {}   # building_uid -> {"species": StringName, "start": float, "duration": float}


func reset() -> void:
	slots.clear()
	slots_changed.emit()


func has_slot(building_uid: String) -> bool:
	return slots.has(building_uid)


func get_slot(building_uid: String) -> Dictionary:
	return slots.get(building_uid, {})


func species_in(building_uid: String) -> CreatureData:
	var s := get_slot(building_uid)
	return DataRegistry.get_creature(s.species) if not s.is_empty() else null


func progress(building_uid: String) -> float:
	var s := get_slot(building_uid)
	if s.is_empty():
		return 0.0
	return clampf((GameClock.now() - s.start) / maxf(s.duration, 0.01), 0.0, 1.0)


func time_left(building_uid: String) -> float:
	var s := get_slot(building_uid)
	if s.is_empty():
		return 0.0
	return maxf(s.start + s.duration - GameClock.now(), 0.0)


func is_ready(building_uid: String) -> bool:
	return has_slot(building_uid) and time_left(building_uid) <= 0.0


## Why a species can't be incubated right now ("" if it can).
func check_species(species: CreatureData) -> String:
	if not CreatureRoster.is_discovered(species.id):
		return "Espécie não descoberta. Explore expedições."
	if species.required_building != &"" and not ParkState.has_building(species.required_building):
		var b := DataRegistry.get_building(species.required_building)
		return "Requer %s." % (b.display_name if b else String(species.required_building))
	if Economy.dna < species.dna_cost:
		return "DNA insuficiente."
	return ""


func start(building_uid: String, species: CreatureData) -> bool:
	if has_slot(building_uid):
		return false
	var reason := check_species(species)
	if reason != "":
		EventBus.toast(reason, "dna", "bad")
		AudioManager.play_sfx(&"error")
		return false
	Economy.spend(0, species.dna_cost)
	slots[building_uid] = {"species": species.id, "start": GameClock.now(), "duration": species.incubation_time}
	slots_changed.emit()
	EventBus.incubation_started.emit(building_uid, species.id)
	AudioManager.play_sfx(&"purchase")
	return true


## Finishes a ready incubation and returns the new creature (in storage until assigned).
func collect(building_uid: String) -> CreatureInstance:
	if not is_ready(building_uid):
		return null
	var species := species_in(building_uid)
	slots.erase(building_uid)
	slots_changed.emit()
	if species == null:
		return null
	var c := CreatureRoster.add_new(species)
	EventBus.creature_hatched.emit(c)
	AudioManager.play_sfx(&"hatch")
	return c


func to_dict() -> Dictionary:
	var out := {}
	for uid in slots:
		var s: Dictionary = slots[uid]
		out[uid] = {"species": String(s.species), "start": s.start, "duration": s.duration}
	return {"slots": out}


func from_dict(d: Dictionary) -> void:
	slots.clear()
	var saved: Dictionary = d.get("slots", {})
	for uid in saved:
		var s: Dictionary = saved[uid]
		if ParkState.get_building(uid) == null or DataRegistry.get_creature(StringName(s.get("species", ""))) == null:
			continue
		slots[uid] = {"species": StringName(s.species), "start": float(s.get("start", 0.0)),
			"duration": float(s.get("duration", 10.0))}
	slots_changed.emit()
