class_name BattleResolver
extends RefCounted
## Resolves one round and returns a list of presentation events. Pure logic: no nodes, no UI,
## so it is fully testable headless.
##
## Event types:
##  {type:"action", actor, ability}
##  {type:"damage", actor, target, amount, crit, ability}
##  {type:"guard", actor, ability}
##  {type:"energy", actor, amount}
##  {type:"effect", target, stat, multiplier, label}
##  {type:"faint", target}
##  {type:"round_end", round}


static func resolve_round(state: BattleState, player_action: AbilityData, enemy_action: AbilityData) -> Array:
	var events: Array = []
	if state.finished:
		return events
	var order := _order(state, player_action, enemy_action)
	for entry in order:
		var actor: Combatant = entry[0]
		var ability: AbilityData = entry[1]
		if not actor.is_alive() or state.finished:
			continue
		if not actor.can_use(ability):
			ability = BattleRules.basic(AbilityData.Kind.ATTACK)
		_perform(state, actor, ability, events)
	if not state.finished:
		state.player.end_round()
		state.enemy.end_round()
		state.round_number += 1
		if state.round_number > BattleRules.MAX_ROUNDS:
			_finish_by_hp(state, events)
		events.append({"type": "round_end", "round": state.round_number})
	return events


static func _order(state: BattleState, pa: AbilityData, ea: AbilityData) -> Array:
	var p := [state.player, pa]
	var e := [state.enemy, ea]
	if pa.priority != ea.priority:
		return [p, e] if pa.priority > ea.priority else [e, p]
	var ps := state.player.speed()
	var es := state.enemy.speed()
	if is_equal_approx(ps, es):
		return [p, e] if state.rng.randf() < 0.5 else [e, p]
	return [p, e] if ps > es else [e, p]


static func _perform(state: BattleState, actor: Combatant, ability: AbilityData, events: Array) -> void:
	var target := state.opponent_of(actor)
	actor.energy -= ability.energy_cost
	actor.last_action_id = ability.id
	if ability.cooldown > 0:
		# +1 because end_round() ticks once right after this round.
		actor.cooldowns[ability.id] = ability.cooldown + 1
	events.append({"type": "action", "actor": actor, "ability": ability})
	match ability.kind:
		AbilityData.Kind.GUARD:
			actor.guard_reduction = ability.guard_reduction
			events.append({"type": "guard", "actor": actor, "ability": ability})
		AbilityData.Kind.RESERVE:
			var before := actor.energy
			actor.energy = mini(actor.energy + ability.energy_gain, BattleRules.MAX_ENERGY)
			events.append({"type": "energy", "actor": actor, "amount": actor.energy - before})
	if ability.is_damaging():
		var dmg := BattleRules.expected_damage(actor, target, ability)
		dmg *= 1.0 + state.rng.randf_range(-BattleRules.VARIANCE, BattleRules.VARIANCE)
		var crit := state.rng.randf() < BattleRules.crit_chance(actor, target)
		if crit:
			dmg *= BattleRules.CRIT_MULT
		var amount := maxi(int(round(dmg)), 1)
		actor.next_attack_mult = 1.0
		target.hp = maxi(target.hp - amount, 0)
		events.append({"type": "damage", "actor": actor, "target": target, "amount": amount, "crit": crit,
			"ability": ability})
	for eff in ability.effects:
		var who := actor if eff.target == &"self" else target
		if not who.is_alive():
			continue
		if eff.stat == &"next_attack":
			who.next_attack_mult = eff.multiplier
		else:
			# Re-applying the same stat effect refreshes it instead of stacking forever.
			who.effects = who.effects.filter(func(e): return not (e.stat == eff.stat and e.label == eff.label))
			# +1 so the effect also covers the next round after this one ends.
			who.effects.append({"stat": eff.stat, "multiplier": eff.multiplier, "turns": eff.duration + 1,
				"label": eff.label})
		events.append({"type": "effect", "target": who, "stat": eff.stat, "multiplier": eff.multiplier,
			"label": eff.label})
	if not target.is_alive():
		events.append({"type": "faint", "target": target})
		state.finished = true
		state.winner = actor


static func _finish_by_hp(state: BattleState, events: Array) -> void:
	state.finished = true
	var loser := state.enemy if state.player.hp_ratio() >= state.enemy.hp_ratio() else state.player
	state.winner = state.opponent_of(loser)
	loser.hp = 0
	events.append({"type": "faint", "target": loser})
