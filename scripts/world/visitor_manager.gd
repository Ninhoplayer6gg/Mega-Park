extends Node
## Visitors and park reputation. Visitors are attracted by habitats (rarity, size, hybrids, happiness),
## buy tickets at the entrance (collect at the entrance bubble) and have different interests.
## Reputation styles are computed from what the park is; the dominant one grants a bonus.

signal visitors_changed

const UPDATE_EVERY := 5
const TICKET_CAP := 800

var visitors := 0
var pending_tickets := 0.0
var _tick := 0
var _scores := {}
var _dominant: StringName = &""


func _ready() -> void:
	GameClock.tick.connect(_on_tick)


func reset() -> void:
	visitors = 0
	pending_tickets = 0.0
	_scores.clear()
	_dominant = &""
	visitors_changed.emit()


func _on_tick() -> void:
	_tick += 1
	if _tick % UPDATE_EVERY != 0:
		return
	recompute()
	# Ticket income per visitor per minute, accumulated every UPDATE_EVERY seconds.
	var per_min := 0.0
	for vt in DataRegistry.visitors.values():
		per_min += vt.ticket * vt.weight
	per_min /= maxf(DataRegistry.visitors.size(), 1)
	pending_tickets = minf(pending_tickets + visitors * per_min * UPDATE_EVERY / 60.0, TICKET_CAP)
	visitors_changed.emit()


## Appeal of one creature for a visitor type (interests: categories or tags).
static func creature_appeal(c: CreatureInstance, vt: VisitorTypeData) -> float:
	var base := 1.0 + c.data.rarity * 0.5
	var tags := [c.data.category]
	if c.data.is_hybrid():
		tags.append(&"hybrid")
	if c.data.size_class == &"giant" or c.data.size_class == &"large":
		tags.append(&"giant")
	if c.data.size_class == &"small":
		tags.append(&"small")
	if c.data.rarity >= GameEnums.Rarity.EPIC:
		tags.append(&"rare")
	if c.data.variant_kind == &"prototype":
		tags.append(&"prototype")
	for t in c.types():
		tags.append(t)
	var interest := 1.0
	for i in vt.interests:
		if tags.has(i):
			interest += 0.5
	return base * interest * (0.6 + SocialLogic.happiness(c) / 250.0)


func recompute() -> void:
	var appeal := 0.0
	for c in CreatureRoster.creatures.values():
		if c.state != &"habitat":
			continue
		for vt in DataRegistry.visitors.values():
			appeal += creature_appeal(c, vt) * vt.weight
	appeal /= maxf(DataRegistry.visitors.size(), 1)
	visitors = int(round(appeal * 2.0 * (1.0 + Bonuses.get_value(&"visitors"))))
	_compute_styles()


func _compute_styles() -> void:
	var hybrids := 0
	var exotic := 0
	var happy := 0.0
	var count := 0
	for c in CreatureRoster.creatures.values():
		if c.data.is_hybrid():
			hybrids += 1
		if c.data.category in [&"alien", &"mythic", &"anomalous"] or c.data.rarity >= GameEnums.Rarity.EPIC:
			exotic += 1
		if c.state == &"habitat":
			happy += SocialLogic.happiness(c)
			count += 1
	var eco := 0
	for b in ParkState.habitats():
		eco += b.extra.get("upgrades", []).size()
	var labs := ParkState.of_category(&"lab").size()
	var wins := 0
	for w in ArenaManager.wins.values():
		wins += int(w)
	_scores = {
		&"science": ResearchManager.completed.size() * 10 + labs * 15,
		&"nature": (happy / count if count > 0 else 0.0) * 0.5 + eco * 6,
		&"hybrids": hybrids * 20 + GeneticsManager.recipe_state.size() * 8,
		&"exotic": exotic * 15,
		&"arena": wins * 8,
	}
	var best := 0.0
	_dominant = &""
	for st in DataRegistry.reputation.values():
		var v: float = _scores.get(st.metric, 0.0)
		if v > best + 0.01:
			best = v
			_dominant = st.id
	if best < 20.0:
		_dominant = &""


func score(metric: StringName) -> float:
	return float(_scores.get(metric, 0.0))


func dominant_style() -> ReputationStyleData:
	return DataRegistry.reputation.get(_dominant) if _dominant != &"" else null


func style_bonus(key: StringName) -> float:
	var st := dominant_style()
	return float(st.bonus.get(String(key), 0.0)) if st else 0.0


func collect_tickets() -> int:
	var amount := int(pending_tickets)
	if amount <= 0:
		return 0
	pending_tickets -= amount
	Economy.add(amount)
	visitors_changed.emit()
	return amount


func to_dict() -> Dictionary:
	return {"pending_tickets": pending_tickets, "visitors": visitors}


func from_dict(d: Dictionary) -> void:
	pending_tickets = float(d.get("pending_tickets", 0.0))
	visitors = int(d.get("visitors", 0))
	visitors_changed.emit()
