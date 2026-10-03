class_name AbilityData
extends Resource
## Battle action definition. Basic actions (attack, guard, reserve) are abilities too,
## so the battle system treats every action the same way.

enum Kind { ATTACK, GUARD, RESERVE, ABILITY }

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon_name := "skill"
@export var kind: Kind = Kind.ABILITY
@export_group("Cost")
@export var energy_cost := 0
@export var cooldown := 0
@export_group("Effect")
## Damage multiplier over the attacker's attack stat. 0 = no damage.
@export var power := 0.0
## &"physical", &"electric" (ignores part of the defense) or &"cosmic".
@export var damage_type: StringName = &"physical"
## Fraction of incoming damage blocked while guarding (GUARD kind).
@export var guard_reduction := 0.0
## Extra energy granted immediately (RESERVE kind).
@export var energy_gain := 0
## Higher priority acts first regardless of speed.
@export var priority := 0
@export var effects: Array[StatusEffectData] = []
@export_group("Presentation")
@export var vfx: StringName = &"hit"
@export var sfx: StringName = &"hit"
## Multiplies how attractive the AI finds this ability.
@export var ai_weight := 1.0


func is_damaging() -> bool:
	return power > 0.0


func cost_label() -> String:
	return str(energy_cost)
