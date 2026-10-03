class_name BattleRules
extends RefCounted
## Tunable battle constants and the basic actions shared by every creature.

const START_ENERGY := 2
const ENERGY_PER_ROUND := 2
const MAX_ENERGY := 10
const DAMAGE_SCALE := 2.1
const DEFENSE_CONSTANT := 100.0
const ELECTRIC_DEFENSE_IGNORE := 0.3
const CRIT_BASE := 0.05
const CRIT_PER_SPEED := 0.004
const CRIT_MAX := 0.25
const CRIT_MULT := 1.5
const VARIANCE := 0.08
const MAX_ROUNDS := 40

const ATTACK_PATH := "res://data/abilities/basic_attack.tres"
const GUARD_PATH := "res://data/abilities/basic_guard.tres"
const RESERVE_PATH := "res://data/abilities/basic_reserve.tres"

static var _basic: Array[AbilityData] = []


static func basic_actions() -> Array[AbilityData]:
	if _basic.is_empty():
		for p in [ATTACK_PATH, GUARD_PATH, RESERVE_PATH]:
			_basic.append(load(p))
	return _basic.duplicate()


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
	var dmg := attacker.attack() * ability.power * DAMAGE_SCALE * (DEFENSE_CONSTANT / (DEFENSE_CONSTANT + def))
	dmg *= attacker.next_attack_mult
	dmg *= 1.0 - defender.guard_reduction
	return maxf(dmg, 1.0)


static func crit_chance(attacker: Combatant, defender: Combatant) -> float:
	return clampf(CRIT_BASE + maxf(attacker.speed() - defender.speed(), 0.0) * CRIT_PER_SPEED, 0.0, CRIT_MAX)
