extends Node
## Research points (RP), research projects and their effects. One project runs at a time.
## Research centers also generate RP passively.

signal research_changed
## Internal signal (EventBus.research_completed is the public one).
signal research_completed_internal(research_id: StringName)

const PASSIVE_RP_PER_MINUTE := 2.0

var rp := 0.0
var completed := {}        # research_id -> true
var active := {}           # {"id", "start", "duration"}
var _passive_accum := 0.0


func _ready() -> void:
	GameClock.tick.connect(_on_tick)


func reset() -> void:
	rp = 0.0
	completed.clear()
	active.clear()
	research_changed.emit()


func _on_tick() -> void:
	var centers := ParkState.count_of(&"research_center")
	if centers <= 0:
		return
	_passive_accum += PASSIVE_RP_PER_MINUTE / 60.0 * centers
	if _passive_accum >= 1.0:
		var whole := floori(_passive_accum)
		_passive_accum -= whole
		add_rp(whole, false)


func add_rp(amount: float, apply_bonus := true) -> int:
	if amount <= 0.0:
		return 0
	var value := amount * (1.0 + (Bonuses.get_value(&"rp_gain") if apply_bonus else 0.0))
	rp += value
	research_changed.emit()
	return int(round(value))


func spend_rp(amount: float) -> bool:
	if rp + 0.001 < amount:
		return false
	rp -= amount
	research_changed.emit()
	return true


func is_done(id: StringName) -> bool:
	return completed.has(id)


## True if any completed research has {"unlock": feature}.
func unlocked(feature: StringName) -> bool:
	for id in completed:
		var r := DataRegistry.get_research(id)
		if r and StringName(str(r.effects.get("unlock", ""))) == feature:
			return true
	return false


func effect_sum(key: StringName) -> float:
	var total := 0.0
	for id in completed:
		var r := DataRegistry.get_research(id)
		if r and r.effects.has(String(key)):
			var v = r.effects[String(key)]
			if v is float or v is int:
				total += float(v)
	return total


func list() -> Array:
	return DataRegistry.sorted(DataRegistry.research)


func check(r: ResearchData) -> String:
	if is_done(r.id):
		return "Concluída."
	if not active.is_empty():
		return "Outra pesquisa em andamento."
	for p in r.prerequisites:
		if not is_done(p):
			var pr := DataRegistry.get_research(p)
			return "Requer %s." % (pr.display_name if pr else String(p))
	if r.required_building != &"" and not ParkState.has_building(r.required_building):
		return "Requer construção específica."
	if rp + 0.001 < r.cost_rp:
		return "Pontos de pesquisa insuficientes (%d/%d)." % [int(rp), r.cost_rp]
	if not Economy.can_afford(r.cost_credits):
		return "Créditos insuficientes."
	return ""


func start(r: ResearchData) -> bool:
	var reason := check(r)
	if reason != "":
		EventBus.toast(reason, "research", "bad")
		AudioManager.play_sfx(&"error")
		return false
	rp -= r.cost_rp
	Economy.spend(r.cost_credits)
	active = {"id": String(r.id), "start": GameClock.now(), "duration": r.duration}
	research_changed.emit()
	AudioManager.play_sfx(&"purchase")
	return true


func active_research() -> ResearchData:
	return DataRegistry.get_research(StringName(active.get("id", ""))) if not active.is_empty() else null


func progress() -> float:
	if active.is_empty():
		return 0.0
	return clampf((GameClock.now() - active.start) / maxf(active.duration, 0.01), 0.0, 1.0)


func time_left() -> float:
	return maxf(active.start + active.duration - GameClock.now(), 0.0) if not active.is_empty() else 0.0


func is_ready() -> bool:
	return not active.is_empty() and time_left() <= 0.0


func collect() -> ResearchData:
	if not is_ready():
		return null
	var r := active_research()
	active.clear()
	if r:
		completed[r.id] = true
		research_completed_internal.emit(r.id)
		EventBus.research_completed.emit(r.id)
		EventBus.toast("Pesquisa concluída: %s" % r.display_name, "research", "good")
		AudioManager.play_sfx(&"level_up")
		if StringName(str(r.effects.get("unlock", ""))) == &"gene_sequencing":
			for c in CreatureRoster.creatures.values():
				ArchiveManager.mark(c.species_id, &"sequenced")
	research_changed.emit()
	return r


func to_dict() -> Dictionary:
	return {"rp": rp, "completed": completed.keys().map(func(k): return String(k)), "active": active.duplicate()}


func from_dict(d: Dictionary) -> void:
	reset()
	rp = float(d.get("rp", 0.0))
	for k in d.get("completed", []):
		if DataRegistry.get_research(StringName(k)):
			completed[StringName(k)] = true
	var a: Dictionary = d.get("active", {})
	if not a.is_empty() and DataRegistry.get_research(StringName(a.get("id", ""))):
		active = {"id": str(a.id), "start": float(a.get("start", 0.0)), "duration": float(a.get("duration", 30.0))}
	research_changed.emit()
