class_name BattleRules
extends RefCounted
## Tunable battle constants and the basic actions shared by every creature.

const START_ENERGY := 2
const ENERGY_PER_ROUND := 2
const MAX_ENERGY := 10
const DAMAGE_SCALE := 2.1
const DEFENSE_CONSTANT := 100.0
const ELECTRIC_DEFENSE_IGNORE := 0.3
const COSMIC_DEFENSE_IGNORE := 0.15
const CRIT_BASE := 0.05
const CRIT_PER_SPEED := 0.004
const CRIT_MAX := 0.25
const CRIT_MULT := 1.5
const VARIANCE := 0.08
const MAX_ROUNDS := 40
## Initiative: the faster creature usually acts first, but close speeds stay contested.
const INITIATIVE_SWING := 3.0
const INITIATIVE_MAX := 0.9

const ATTACK_PATH := "res://data/abilities/basic_attack.tres"
const GUARD_PATH := "res://data/abilities/basic_guard.tres"
const RESERVE_PATH := "res://data/abilities/basic_reserve.tres"

static var _basic: Array[AbilityData] = []


static func basic_actions() -> Array[AbilityData]:
	if _basic.is_empty():
		for p in [ATTACK_PATH, GUARD_PATH, RESERVE_PATH]:
			_basic.append(load(p))
	return _basic.duplicate()


static var _swap: AbilityData


## Runtime "switch creature" action used by team battles (meta "swap_to" = team index).
static func swap_action(index: int) -> AbilityData:
	var a := AbilityData.new()
	a.id = &"swap"
	a.display_name = "Trocar"
	a.kind = AbilityData.Kind.SWAP
	a.priority = 3
	a.set_meta("swap_to", index)
	return a


static func active_synergies(team: Array) -> Array:
	var out := []
	if team.size() < 2:
		return out
	for s in DataRegistry.synergies.values():
		if synergy_applies(s, team):
			out.append(s)
	return out


static func synergy_applies(s: SynergyData, team: Array) -> bool:
	match s.condition:
		&"category_count":
			return team.filter(func(c): return c.data.category == StringName(s.params.get("category", ""))).size() >= int(s.params.get("count", 3))
		&"type_count":
			return team.filter(func(c): return c.types.has(StringName(s.params.get("type", "")))).size() >= int(s.params.get("count", 2))
		&"hybrid_count":
			return team.filter(func(c): return c.data.is_hybrid()).size() >= int(s.params.get("count", 2))
		&"role_set":
			var roles := team.map(func(c): return String(c.data.role))
			for r in s.params.get("roles", []):
				if not roles.has(String(r)):
					return false
			return true
	return false


static func basic(kind: AbilityData.Kind) -> AbilityData:
	for a in basic_actions():
		if a.kind == kind:
			return a
	return null


## Expected damage (no variance/crit), used by both the resolver and the AI.
static func expected_damage(attacker: Combatant, defender: Combatant, ability: AbilityData) -> float:
	if not ability.is_damaging():
		return 0.0
	var def := defender.defense()
	if ability.damage_type == &"electric":
		def *= 1.0 - ELECTRIC_DEFENSE_IGNORE
	elif ability.damage_type == &"cosmic":
		def *= 1.0 - COSMIC_DEFENSE_IGNORE
	var dmg := attacker.attack() * ability.power * DAMAGE_SCALE * (DEFENSE_CONSTANT / (DEFENSE_CONSTANT + def))
	dmg *= attacker.next_attack_mult
	dmg *= 1.0 - defender.guard_reduction
	return maxf(dmg, 1.0)


## Chance that a creature with speed `a` acts before one with speed `b` (same priority).
static func initiative_chance(a: float, b: float) -> float:
	if a + b <= 0.0:
		return 0.5
	return clampf(0.5 + (a - b) / (a + b) * INITIATIVE_SWING, 1.0 - INITIATIVE_MAX, INITIATIVE_MAX)


static func crit_chance(attacker: Combatant, defender: Combatant) -> float:
	return clampf(CRIT_BASE + maxf(attacker.speed() - defender.speed(), 0.0) * CRIT_PER_SPEED, 0.0, CRIT_MAX)
