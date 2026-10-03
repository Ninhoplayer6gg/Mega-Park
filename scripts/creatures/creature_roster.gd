extends Node
## Owns every CreatureInstance of the player plus the bestiary discovery state.

signal roster_changed
signal creature_changed(creature: CreatureInstance)

var creatures := {}          # uid -> CreatureInstance
var discovered := {}         # species_id -> true


func reset() -> void:
	creatures.clear()
	discovered.clear()
	for data in DataRegistry.creatures.values():
		if data.start_discovered:
			discovered[data.id] = true
	roster_changed.emit()


func get_creature(uid: String) -> CreatureInstance:
	return creatures.get(uid)


func all() -> Array:
	var arr := creatures.values()
	arr.sort_custom(func(a, b):
		if a.level != b.level:
			return a.level > b.level
		return a.data.display_name < b.data.display_name)
	return arr


func count() -> int:
	return creatures.size()


func in_habitat(habitat_uid: String) -> Array:
	return creatures.values().filter(func(c): return c.state == &"habitat" and c.habitat_uid == habitat_uid)


func in_storage() -> Array:
	return creatures.values().filter(func(c): return c.state == &"storage")


func owns_species(species_id: StringName) -> bool:
	for c in creatures.values():
		if c.species_id == species_id:
			return true
	return false


func is_discovered(species_id: StringName) -> bool:
	return discovered.has(species_id)


func discover(species_id: StringName) -> bool:
	if discovered.has(species_id):
		return false
	discovered[species_id] = true
	EventBus.species_discovered.emit(species_id)
	roster_changed.emit()
	return true


func add_new(species: CreatureData) -> CreatureInstance:
	var c := CreatureInstance.create(species)
	creatures[c.uid] = c
	discover(species.id)
	roster_changed.emit()
	return c


## Checks whether a creature may live in a habitat. Returns "" when valid, otherwise the reason.
func check_assign(c: CreatureInstance, habitat_uid: String) -> String:
	var b: BuildingInstance = ParkState.get_building(habitat_uid)
	if b == null or not b.data.is_habitat():
		return "Habitat inválido."
	if b.data.habitat_type != c.data.habitat_type:
		var ht := DataRegistry.get_habitat_type(c.data.habitat_type)
		return "%s precisa de um %s." % [c.data.display_name, ht.display_name if ht else "habitat compatível"]
	if c.habitat_uid != habitat_uid and in_habitat(habitat_uid).size() >= b.data.habitat_capacity:
		return "Habitat lotado (%d/%d)." % [b.data.habitat_capacity, b.data.habitat_capacity]
	return ""


func assign_to_habitat(c: CreatureInstance, habitat_uid: String) -> bool:
	var reason := check_assign(c, habitat_uid)
	if reason != "":
		EventBus.toast(reason, "close", "bad")
		return false
	if c.state == &"habitat" and c.habitat_uid == habitat_uid:
		return true
	c.state = &"habitat"
	c.habitat_uid = habitat_uid
	c.production_start = GameClock.now()
	creature_changed.emit(c)
	roster_changed.emit()
	EventBus.creature_assigned.emit(c, habitat_uid)
	return true


func move_to_storage(c: CreatureInstance) -> void:
	c.state = &"storage"
	c.habitat_uid = ""
	creature_changed.emit(c)
	roster_changed.emit()


func compatible_habitats(c: CreatureInstance) -> Array:
	return ParkState.habitats().filter(func(b): return check_assign(c, b.uid) == "")


func habitat_pending(habitat_uid: String) -> int:
	var now := GameClock.now()
	var total := 0
	for c in in_habitat(habitat_uid):
		total += c.pending_income(now)
	return total


## Collects every creature's production in a habitat; returns the credits gained.
func collect_habitat(habitat_uid: String, world_pos := Vector2.ZERO) -> int:
	var now := GameClock.now()
	var total := 0
	for c in in_habitat(habitat_uid):
		var amount: int = c.pending_income(now)
		if amount > 0:
			total += amount
			c.production_start = now
	if total > 0:
		Economy.add(total)
		EventBus.credits_collected.emit(total, world_pos)
		AudioManager.play_sfx(&"coin")
	return total


## Feeding costs credits and grants XP. Returns levels gained, or -1 on failure.
func feed(c: CreatureInstance) -> int:
	if c.is_max_level():
		EventBus.toast("%s já está no nível máximo." % c.display_name(), "star", "info")
		return -1
	var cost := c.data.feed_cost_at_level(c.level)
	if not Economy.spend(cost):
		EventBus.toast("Créditos insuficientes para alimentar.", "credits", "bad")
		AudioManager.play_sfx(&"error")
		return -1
	var gained := give_xp(c, c.data.feed_xp)
	EventBus.creature_fed.emit(c)
	return gained


func give_xp(c: CreatureInstance, amount: int) -> int:
	var gained := c.add_xp(amount)
	creature_changed.emit(c)
	if gained > 0:
		EventBus.creature_leveled.emit(c, c.level)
		AudioManager.play_sfx(&"level_up")
	return gained


func highest_level() -> int:
	var best := 0
	for c in creatures.values():
		best = maxi(best, c.level)
	return best


func to_dict() -> Dictionary:
	var list := []
	for c in creatures.values():
		list.append(c.to_dict())
	return {"creatures": list, "discovered": discovered.keys().map(func(k): return String(k))}


func from_dict(d: Dictionary) -> void:
	reset()
	for entry in d.get("creatures", []):
		var c := CreatureInstance.from_dict(entry)
		if c != null:
			creatures[c.uid] = c
	for s in d.get("discovered", []):
		if DataRegistry.get_creature(StringName(s)) != null:
			discovered[StringName(s)] = true
	# Repair references to habitats that no longer exist.
	for c in creatures.values():
		if c.state == &"habitat" and ParkState.get_building(c.habitat_uid) == null:
			c.state = &"storage"
			c.habitat_uid = ""
	roster_changed.emit()
