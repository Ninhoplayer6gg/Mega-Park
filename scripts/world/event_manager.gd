extends Node
## Park events (storms, power issues, eggs found, VIPs, stress, damaged fences, dimensional portals,
## genetic samples, rare behaviour). Light-touch by design: at most 2 at a time, spaced out, and none
## of them destroys progress. Events expire on their own; resolving them is optional but rewarding.

signal events_changed

const FIRST_DELAY := 180.0
const MIN_INTERVAL := 240.0
const MAX_INTERVAL := 480.0
const MAX_ACTIVE := 2

var active := {}          # event_uid -> {"id", "start", "duration", "target"}
var next_time := 0.0
var history := 0
var enabled := true


func _ready() -> void:
	GameClock.tick.connect(_on_tick)


func reset() -> void:
	active.clear()
	history = 0
	next_time = GameClock.now() + FIRST_DELAY
	events_changed.emit()


func _on_tick() -> void:
	var now := GameClock.now()
	for uid in active.keys():
		var e: Dictionary = active[uid]
		if now >= e.start + e.duration:
			_end(uid, false)
	if not enabled or next_time <= 0.0:
		return
	if now >= next_time and active.size() < MAX_ACTIVE:
		spawn_random()
		next_time = now + randf_range(MIN_INTERVAL, MAX_INTERVAL)


func data_of(uid: String) -> EventData:
	return DataRegistry.events.get(StringName(active.get(uid, {}).get("id", ""))) if active.has(uid) else null


func eligible() -> Array:
	return DataRegistry.events.values().filter(func(ev):
		if Economy.player_level < ev.min_player_level:
			return false
		for e in active.values():
			if e.id == String(ev.id):
				return false
		match ev.kind:
			&"stressed_creature", &"rare_behavior":
				return not _habitat_creatures().is_empty()
			&"fence_damaged":
				return not ParkState.habitats().is_empty()
			&"egg_found", &"genetic_sample":
				return CreatureRoster.discovered.size() > 0
		return true)


func spawn_random() -> String:
	var list := eligible()
	if list.is_empty():
		return ""
	var total := 0.0
	for ev in list:
		total += ev.weight
	var roll := randf() * total
	for ev in list:
		roll -= ev.weight
		if roll <= 0.0:
			return spawn(ev)
	return spawn(list.back())


func spawn(ev: EventData) -> String:
	var uid := Uid.make("ev")
	var target := ""
	match ev.kind:
		&"stressed_creature", &"rare_behavior":
			var cs := _habitat_creatures()
			target = cs[randi() % cs.size()].uid if not cs.is_empty() else ""
		&"fence_damaged":
			var hs := ParkState.habitats()
			target = hs[randi() % hs.size()].uid if not hs.is_empty() else ""
		&"egg_found", &"genetic_sample":
			var ids := CreatureRoster.discovered.keys().filter(func(s):
				var d := DataRegistry.get_creature(s)
				return d and d.hybrid_tier == 0 and d.variant_kind == &"")
			target = String(ids[randi() % ids.size()]) if not ids.is_empty() else ""
	active[uid] = {"id": String(ev.id), "start": GameClock.now(), "duration": ev.duration, "target": target}
	history += 1
	EventBus.park_event_started.emit(uid)
	EventBus.toast("Evento: %s" % ev.title, ev.icon_name, "info")
	events_changed.emit()
	return uid


func _habitat_creatures() -> Array:
	return CreatureRoster.creatures.values().filter(func(c): return c.state == &"habitat")


## Optional resolution: pays the cost (if any) and grants the event reward. Returns a summary.
func resolve(uid: String) -> Dictionary:
	var ev := data_of(uid)
	if ev == null:
		return {}
	var e: Dictionary = active[uid]
	var cost := ev.resolve_cost
	if ev.kind == &"stressed_creature" and StaffManager.has_specialty(&"veterinary"):
		cost = 0
	if cost > 0 and not Economy.spend(cost):
		EventBus.toast("Créditos insuficientes.", "credits", "bad")
		return {}
	var out := {"title": ev.title}
	match ev.kind:
		&"egg_found":
			Economy.add(0, int(ev.params.get("dna", 20)))
			GeneticsManager.add_species_dna(StringName(e.target), int(ev.params.get("species_dna", 20)))
			out = {"dna": int(ev.params.get("dna", 20)), "species_dna": int(ev.params.get("species_dna", 20)), "species": e.target}
		&"genetic_sample":
			GeneticsManager.add_species_dna(StringName(e.target), int(ev.params.get("species_dna", 30)))
			out = {"species_dna": int(ev.params.get("species_dna", 30)), "species": e.target}
		&"special_visitor":
			var rare := 0
			for c in CreatureRoster.creatures.values():
				if c.data.rarity >= GameEnums.Rarity.RARE or c.data.is_hybrid():
					rare += 1
			var credits: int = int(ev.params.get("base", 200)) + rare * int(ev.params.get("credits_per_rare", 100))
			Economy.add(credits)
			out = {"credits": credits}
		&"storm":
			out = {"rp": ResearchManager.add_rp(float(ev.params.get("rp_on_end", 10)))}
	_end(uid, true)
	AudioManager.play_sfx(&"purchase")
	return out


func _end(uid: String, resolved: bool) -> void:
	var ev := data_of(uid)
	if ev and not resolved and ev.kind == &"storm":
		ResearchManager.add_rp(float(ev.params.get("rp_on_end", 10)))
	active.erase(uid)
	EventBus.park_event_ended.emit(uid)
	events_changed.emit()


func time_left(uid: String) -> float:
	if not active.has(uid):
		return 0.0
	return maxf(active[uid].start + active[uid].duration - GameClock.now(), 0.0)


func has_kind(kind: StringName) -> bool:
	for uid in active:
		var ev := data_of(uid)
		if ev and ev.kind == kind:
			return true
	return false


func uid_of_kind(kind: StringName) -> String:
	for uid in active:
		var ev := data_of(uid)
		if ev and ev.kind == kind:
			return uid
	return ""


func portal_open() -> bool:
	return has_kind(&"dimensional_anomaly")


## Production multiplier for a habitat (storm, damaged fence).
func production_multiplier(habitat_uid: String) -> float:
	var m := 1.0
	for uid in active:
		var ev := data_of(uid)
		if ev == null:
			continue
		if ev.kind == &"storm":
			m *= 0.9
		elif ev.kind == &"fence_damaged" and active[uid].target == habitat_uid:
			m *= float(ev.params.get("production", 0.85))
	return m


func energy_penalty() -> int:
	var total := 0
	for uid in active:
		var ev := data_of(uid)
		if ev and ev.kind == &"power_issue":
			total += int(ev.params.get("energy", 6))
	return total


func creature_stress(creature_uid: String) -> float:
	for uid in active:
		var ev := data_of(uid)
		if ev and ev.kind == &"stressed_creature" and active[uid].target == creature_uid:
			return absf(float(ev.params.get("happiness", -25)))
	return 0.0


func rare_behavior_target() -> String:
	var uid := uid_of_kind(&"rare_behavior")
	return active[uid].target if uid != "" else ""


func photo_multiplier(creature_uid: String) -> float:
	var uid := uid_of_kind(&"rare_behavior")
	if uid != "" and active[uid].target == creature_uid:
		return float(data_of(uid).params.get("photo_mult", 3.0))
	return 1.0


func to_dict() -> Dictionary:
	return {"active": active.duplicate(true), "next_time": next_time, "history": history}


func from_dict(d: Dictionary) -> void:
	active.clear()
	var a: Dictionary = d.get("active", {})
	for uid in a:
		if DataRegistry.events.has(StringName(a[uid].get("id", ""))):
			active[uid] = a[uid]
	next_time = float(d.get("next_time", GameClock.now() + FIRST_DELAY))
	history = int(d.get("history", 0))
	events_changed.emit()
