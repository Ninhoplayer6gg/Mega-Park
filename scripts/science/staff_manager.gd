extends Node
## Hired researchers (specialists) and their level-based bonuses.

signal staff_changed

var hired := {}   # researcher_id -> level


func reset() -> void:
	hired.clear()
	staff_changed.emit()


func level_of(id: StringName) -> int:
	return int(hired.get(id, 0))


func list() -> Array:
	var arr := DataRegistry.researchers.values()
	arr.sort_custom(func(a, b): return a.hire_cost < b.hire_cost)
	return arr


func bonus(key: StringName) -> float:
	var total := 0.0
	for id in hired:
		var r: ResearcherData = DataRegistry.researchers.get(id)
		if r:
			total += float(r.bonus_per_level.get(String(key), 0.0)) * level_of(id)
	return total


func has_specialty(specialty: StringName) -> bool:
	for id in hired:
		var r: ResearcherData = DataRegistry.researchers.get(id)
		if r and r.specialty == specialty:
			return true
	return false


func hire(r: ResearcherData) -> bool:
	if hired.has(r.id):
		return false
	if not Economy.spend(r.hire_cost):
		EventBus.toast("Créditos insuficientes.", "credits", "bad")
		return false
	hired[r.id] = 1
	staff_changed.emit()
	EventBus.toast("%s entrou para a equipe!" % r.display_name, "staff", "good")
	AudioManager.play_sfx(&"purchase")
	return true


func level_up_cost(r: ResearcherData) -> Dictionary:
	var lvl := level_of(r.id)
	return {"credits": r.level_cost_credits * lvl, "rp": r.level_cost_rp * lvl}


func check_level_up(r: ResearcherData) -> String:
	if not hired.has(r.id):
		return "Não contratado."
	if level_of(r.id) >= r.max_level:
		return "Nível máximo."
	var cost := level_up_cost(r)
	if not Economy.can_afford(cost.credits):
		return "Créditos insuficientes."
	if ResearchManager.rp + 0.001 < cost.rp:
		return "Pesquisa insuficiente."
	return ""


func level_up(r: ResearcherData) -> bool:
	if check_level_up(r) != "":
		return false
	var cost := level_up_cost(r)
	Economy.spend(cost.credits)
	ResearchManager.spend_rp(cost.rp)
	hired[r.id] = level_of(r.id) + 1
	staff_changed.emit()
	AudioManager.play_sfx(&"level_up")
	return true


func to_dict() -> Dictionary:
	var out := {}
	for k in hired:
		out[String(k)] = hired[k]
	return {"hired": out}


func from_dict(d: Dictionary) -> void:
	hired.clear()
	var h: Dictionary = d.get("hired", {})
	for k in h:
		if DataRegistry.researchers.has(StringName(k)):
			hired[StringName(k)] = clampi(int(h[k]), 1, 5)
	staff_changed.emit()
