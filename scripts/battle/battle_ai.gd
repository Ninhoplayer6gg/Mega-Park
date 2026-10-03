class_name BattleAI
extends RefCounted
## Utility-based AI. Every action is scored in the same unit — "fraction of a creature's max HP
## gained or saved" — considering current HP, energy, cooldowns, active buffs/debuffs, the foe's
## threat and lethal opportunities. A little noise keeps it from being perfectly predictable.

const NOISE := 0.12


static func choose(state: BattleState, me: Combatant, noise := NOISE) -> AbilityData:
	var foe := state.opponent_of(me)
	var best: AbilityData = null
	var best_score := -INF
	for a in me.usable_actions():
		if a.kind == AbilityData.Kind.SWAP:
			continue
		var score := score_action(me, foe, a)
		score += absf(score) * state.rng.randf_range(-noise, noise)
		if score > best_score:
			best_score = score
			best = a
	return best if best else BattleRules.basic(AbilityData.Kind.ATTACK)


static func score_action(me: Combatant, foe: Combatant, a: AbilityData) -> float:
	var basic := BattleRules.basic(AbilityData.Kind.ATTACK)
	var my_basic_value := BattleRules.expected_damage(me, foe, basic) / float(foe.max_hp)
	var energy_value := my_basic_value * 0.15
	var threat_now := _max_threat(foe, me, foe.energy)
	var incoming := (BattleRules.expected_damage(foe, me, basic) + threat_now) * 0.5
	var score := 0.0
	match a.kind:
		AbilityData.Kind.GUARD:
			var foe_has_big := threat_now > BattleRules.expected_damage(foe, me, basic) * 1.2
			var p_attack := 0.8 if foe_has_big else 0.45
			var prevented := threat_now * a.guard_reduction
			score = prevented / float(me.max_hp) * p_attack
			if threat_now >= me.hp and threat_now * (1.0 - a.guard_reduction) < me.hp:
				score += 0.6
			if me.last_action_id == a.id:
				score *= 0.35
			return score - a.energy_cost * energy_value
		AbilityData.Kind.RESERVE:
			score = 0.02
			var next_energy := me.energy + BattleRules.ENERGY_PER_ROUND
			for ab in me.own_abilities:
				var cd := int(me.cooldowns.get(ab.id, 0))
				if cd <= 1 and ab.energy_cost > next_energy and ab.energy_cost <= next_energy + a.energy_gain:
					score = maxf(score, my_basic_value * 0.55)
			if threat_now >= me.hp:
				score *= 0.2
			return score
	if a.is_damaging():
		var dmg := BattleRules.expected_damage(me, foe, a)
		score += dmg / float(foe.max_hp)
		if dmg >= foe.hp:
			score += 1.0
	for eff in a.effects:
		score += _effect_value(me, foe, eff, incoming)
	if a.heal_ratio > 0.0:
		var missing := 1.0 - me.hp_ratio()
		score += minf(a.heal_ratio, missing) * (1.2 if me.hp_ratio() < 0.5 else 0.6)
	return (score - a.energy_cost * energy_value) * a.ai_weight


static func _effect_value(me: Combatant, foe: Combatant, eff: StatusEffectData, incoming: float) -> float:
	var who := me if eff.target == &"self" else foe
	var buff := eff.multiplier > 1.0
	if eff.stat == &"next_attack":
		if me.next_attack_mult > 1.0:
			return 0.0
		var best := 0.0
		for ab in me.actions():
			best = maxf(best, BattleRules.expected_damage(me, foe, ab))
		return (eff.multiplier - 1.0) * best / float(foe.max_hp) * 0.8
	if who.has_effect(eff.stat, buff):
		return -0.05
	var turns := float(eff.duration)
	match eff.stat:
		&"defense":
			if eff.target != &"self":
				var basic_dmg := BattleRules.expected_damage(me, foe, BattleRules.basic(AbilityData.Kind.ATTACK))
				return basic_dmg * (1.0 - eff.multiplier) * 0.6 * turns / float(foe.max_hp)
			var def := me.defense()
			var factor := (BattleRules.DEFENSE_CONSTANT + def) / (BattleRules.DEFENSE_CONSTANT + def * eff.multiplier)
			return incoming * (1.0 - factor) * turns / float(me.max_hp)
		&"attack":
			if eff.target == &"enemy":
				return incoming * (1.0 - eff.multiplier) * turns / float(me.max_hp)
			return BattleRules.expected_damage(me, foe, BattleRules.basic(AbilityData.Kind.ATTACK)) \
				* (eff.multiplier - 1.0) * turns / float(foe.max_hp)
		&"speed":
			return absf(eff.multiplier - 1.0) * 0.06 * turns
	return 0.0


## Strongest damage the attacker can deal right now with the given energy.
static func _max_threat(attacker: Combatant, defender: Combatant, energy: int) -> float:
	var best := 0.0
	for a in attacker.actions():
		if a.is_damaging() and energy >= a.energy_cost and int(attacker.cooldowns.get(a.id, 0)) <= 0:
			best = maxf(best, BattleRules.expected_damage(attacker, defender, a))
	return best
