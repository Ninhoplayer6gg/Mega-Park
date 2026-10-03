class_name SocialLogic
extends RefCounted
## Relations between creatures sharing a habitat, ecosystem score and happiness.

const KINDS := {
	&"friendly": "Amigável", &"neutral": "Neutra", &"territorial": "Territorial",
	&"predatory": "Predatória", &"incompatible": "Incompatível",
}
const SIZE_RANK := {&"small": 0, &"medium": 1, &"large": 2, &"giant": 3}


## Returns {"kind": StringName, "score": int} from a's point of view.
static func relation(a: CreatureInstance, b: CreatureInstance) -> Dictionary:
	var sa := a.data
	var sb := b.data
	var score := 0
	var kind: StringName = &"neutral"
	var same := sa.base_species().id == sb.base_species().id
	if same:
		kind = &"friendly"
		score = 8 if sa.social_style != &"solitary" else 2
		if sa.variant_kind == &"alpha" or sb.variant_kind == &"alpha":
			score += 6
	elif sb.role == &"predator" and sa.role != &"predator":
		var diff: int = SIZE_RANK.get(sb.size_class, 1) - SIZE_RANK.get(sa.size_class, 1)
		if diff > 0:
			kind = &"predatory"
			score = -18
		elif diff == 0:
			kind = &"territorial"
			score = -6
	elif sa.role == &"predator" and sb.role == &"predator":
		kind = &"territorial"
		score = -10
	elif sa.role == &"predator" and SIZE_RANK.get(sa.size_class, 1) > SIZE_RANK.get(sb.size_class, 1) + 1:
		kind = &"territorial"
		score = -4
	else:
		score = 2
	var pa := a.personality()
	var pb := b.personality()
	var social: int = ((pa.social if pa else 0) + (pb.social if pb else 0)) / 2
	score += social
	if kind == &"neutral" and social <= -6:
		kind = &"territorial"
	elif kind == &"territorial" and social >= 6:
		kind = &"neutral"
	if pa and pb and pa.id == &"dominante" and pb.id == &"dominante":
		kind = &"territorial"
		score -= 6
	if score <= -25:
		kind = &"incompatible"
	return {"kind": kind, "score": score}


## 0..1: how many ecosystem needs of the creature are met by the habitat features.
static func ecosystem_score(c: CreatureInstance, b: BuildingInstance) -> float:
	if b == null:
		return 0.0
	var needs := c.data.needs
	if needs.is_empty():
		return 1.0
	var installed: Array = b.extra.get("upgrades", [])
	var kinds := {}
	for uid in installed:
		var u: HabitatUpgradeData = DataRegistry.habitat_upgrades.get(StringName(uid))
		if u:
			kinds[u.kind] = true
	var met := 0
	for n in needs:
		if kinds.has(n):
			met += 1
	return float(met) / needs.size()


## Full happiness breakdown for UI and production.
static func happiness_breakdown(c: CreatureInstance) -> Dictionary:
	var out := {"base": 60.0, "personality": 0.0, "ecosystem": 0.0, "social": 0.0, "bonus": 0.0, "stress": 0.0,
		"stability": 0.0}
	var p := c.personality()
	if p:
		out.personality = float(p.happiness)
	var b := ParkState.get_building(c.habitat_uid) if c.state == &"habitat" else null
	if b:
		out.ecosystem = ecosystem_score(c, b) * 20.0 * (1.0 + Bonuses.get_value(&"ecosystem"))
		var social := 0.0
		for other in CreatureRoster.in_habitat(b.uid):
			if other != c:
				social += relation(c, other).score
		out.social = clampf(social, -30.0, 20.0)
	out.bonus = Bonuses.get_value(&"happiness")
	out.stress = -EventManager.creature_stress(c.uid)
	if c.genetic_stability < 50.0:
		out.stability = -(50.0 - c.genetic_stability) / 5.0
	return out


static func happiness(c: CreatureInstance) -> float:
	var total := 0.0
	for v in happiness_breakdown(c).values():
		total += v
	return clampf(total, 0.0, 100.0)


## Production multiplier from happiness and active park events (0.75 .. 1.2).
static func production_multiplier(c: CreatureInstance) -> float:
	var m := 0.85 + happiness(c) * 0.0035
	m *= EventManager.production_multiplier(c.habitat_uid)
	return clampf(m, 0.5, 1.25)
