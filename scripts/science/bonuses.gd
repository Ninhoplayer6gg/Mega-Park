class_name Bonuses
extends RefCounted
## Aggregates every gameplay bonus (research, staff, park style) under a single key so systems
## never need to know where a bonus comes from.
## Keys: stability, alien_stability, purity, mutation_chance, rp_gain, photo_bonus, happiness,
## ecosystem, visitors, fossil_bonus, battle_credits.

static func get_value(key: StringName) -> float:
	var total := ResearchManager.effect_sum(key) + StaffManager.bonus(key) + VisitorManager.style_bonus(key)
	if key == &"mutation_chance":
		for b in ParkState.buildings.values():
			total += float(b.data.params.get("mutation_bonus", 0.0))
	return total
