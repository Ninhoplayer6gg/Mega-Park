class_name Combatant
extends RefCounted
## Battle-time snapshot of a creature (player's or AI's).

var name := ""
var data: CreatureData
var level := 1
var max_hp := 1
var hp := 1
var base_attack := 1
var base_defense := 1
var base_speed := 1
var energy := 0
var cooldowns := {}            # ability id -> rounds remaining
var effects: Array = []        # [{stat, multiplier, turns, label}]
var next_attack_mult := 1.0
var guard_reduction := 0.0
var is_player := false
var last_action_id: StringName = &""
var instance_uid := ""


static func from_instance(c: CreatureInstance) -> Combatant:
	var cb := from_species(c.data, c.level)
	cb.name = c.display_name()
	cb.instance_uid = c.uid
	cb.is_player = true
	return cb


static func from_species(species: CreatureData, lvl: int) -> Combatant:
	var cb := Combatant.new()
	cb.data = species
	cb.name = species.display_name
	cb.level = lvl
	cb.max_hp = species.stat_at_level(&"health", lvl)
	cb.hp = cb.max_hp
	cb.base_attack = species.stat_at_level(&"attack", lvl)
	cb.base_defense = species.stat_at_level(&"defense", lvl)
	cb.base_speed = species.stat_at_level(&"speed", lvl)
	cb.energy = BattleRules.START_ENERGY
	return cb


func is_alive() -> bool:
	return hp > 0


func hp_ratio() -> float:
	return float(hp) / float(max_hp)


func stat_multiplier(stat: StringName) -> float:
	var m := 1.0
	for e in effects:
		if e.stat == stat:
			m *= e.multiplier
	return m


func attack() -> float:
	return base_attack * stat_multiplier(&"attack")


func defense() -> float:
	return base_defense * stat_multiplier(&"defense")


func speed() -> float:
	return base_speed * stat_multiplier(&"speed")


func has_effect(stat: StringName, buff: bool) -> bool:
	for e in effects:
		if e.stat == stat and ((e.multiplier > 1.0) == buff):
			return true
	return false


func can_use(a: AbilityData) -> bool:
	return energy >= a.energy_cost and int(cooldowns.get(a.id, 0)) <= 0


func actions() -> Array[AbilityData]:
	var list: Array[AbilityData] = BattleRules.basic_actions()
	list.append_array(data.abilities)
	return list


func usable_actions() -> Array[AbilityData]:
	var list: Array[AbilityData] = []
	for a in actions():
		if can_use(a):
			list.append(a)
	return list


func end_round() -> void:
	for id in cooldowns.keys():
		cooldowns[id] = maxi(int(cooldowns[id]) - 1, 0)
	var keep: Array = []
	for e in effects:
		e.turns -= 1
		if e.turns > 0:
			keep.append(e)
	effects = keep
	guard_reduction = 0.0
	energy = mini(energy + BattleRules.ENERGY_PER_ROUND, BattleRules.MAX_ENERGY)
