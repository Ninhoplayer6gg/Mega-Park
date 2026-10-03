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
var types: Array[StringName] = []
var own_abilities: Array[AbilityData] = []
var regen_ratio := 0.0
var form_sheet: Texture2D
var mutation: MutationData
# boss
var is_boss := false
var phases: Array = []          # Array[BossPhaseData]
var phase_index := 0
## Combo abilities usable while a partner is on the bench (set by BattleState).
var combo_abilities: Array[AbilityData] = []


static func from_instance(c: CreatureInstance) -> Combatant:
	var cb := Combatant.new()
	cb.data = c.data
	cb.name = c.display_name()
	cb.level = c.level
	cb.max_hp = c.max_hp()
	cb.hp = cb.max_hp
	cb.base_attack = c.attack()
	cb.base_defense = c.defense()
	cb.base_speed = c.speed()
	cb.energy = BattleRules.START_ENERGY
	cb.instance_uid = c.uid
	cb.is_player = true
	cb.types = c.types()
	cb.own_abilities = c.abilities()
	cb.regen_ratio = 0.03 if c.has_gene_tag(&"regen") else 0.0
	cb.form_sheet = c.form_sheet()
	cb.mutation = c.mutation()
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
	cb.types = species.types.duplicate()
	cb.own_abilities = species.abilities.duplicate()
	for g in species.default_genes:
		if g and g.behavior_tag == &"regen":
			cb.regen_ratio = 0.03
	return cb


## Multiplies base stats (synergies, environments, boss phases).
func apply_stat_multipliers(mods: Dictionary) -> void:
	for k in mods:
		var m := float(mods[k])
		match String(k):
			"health":
				var ratio := hp_ratio()
				max_hp = maxi(1, int(round(max_hp * m)))
				hp = maxi(1, int(round(max_hp * ratio)))
			"attack":
				base_attack = maxi(1, int(round(base_attack * m)))
			"defense":
				base_defense = maxi(1, int(round(base_defense * m)))
			"speed":
				base_speed = maxi(1, int(round(base_speed * m)))


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
	if a.kind == AbilityData.Kind.SWAP:
		return true
	return energy >= a.energy_cost and int(cooldowns.get(a.id, 0)) <= 0


func actions() -> Array[AbilityData]:
	var list: Array[AbilityData] = BattleRules.basic_actions()
	list.append_array(own_abilities)
	list.append_array(combo_abilities)
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
	if regen_ratio > 0.0 and is_alive():
		hp = mini(max_hp, hp + maxi(1, int(round(max_hp * regen_ratio))))
