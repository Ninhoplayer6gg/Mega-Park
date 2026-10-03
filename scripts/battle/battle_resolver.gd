class_name BattleResolver
extends RefCounted
## Resolves one round and returns a list of presentation events. Pure logic: no nodes, no UI,
## so it is fully testable headless. Works for 1v1 and team battles.
##
## Event types:
##  {type:"action", actor, ability}
##  {type:"damage", actor, target, amount, crit, ability}
##  {type:"heal", target, amount}
##  {type:"guard", actor, ability}
##  {type:"energy", actor, amount}
##  {type:"effect", target, stat, multiplier, label}
##  {type:"phase", target, phase}
##  {type:"faint", target}
##  {type:"switch", out, in, is_player}
##  {type:"round_end", round}


static func resolve_round(state: BattleState, player_action: AbilityData, enemy_action: AbilityData) -> Array:
	var events: Array = []
	if state.finished:
		return events
	var order := _order(state, player_action, enemy_action)
	var started_player := state.player
	var started_enemy := state.enemy
	for entry in order:
		var actor: Combatant = entry[0]
		var ability: AbilityData = entry[1]
		# A creature that fainted or was switched out this round loses its action.
		if not actor.is_alive() or state.finished:
			continue
		if actor != state.player and actor != state.enemy:
			continue
		if (actor == started_player or actor == started_enemy) and not actor.can_use(ability):
			ability = BattleRules.basic(AbilityData.Kind.ATTACK)
		_perform(state, actor, ability, events)
	if not state.finished:
		for team in [state.player_team, state.enemy_team]:
			for c in team:
				if c.is_alive():
					var before: int = c.hp
					c.end_round()
					if c.hp > before:
						events.append({"type": "heal", "target": c, "amount": c.hp - before})
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
	return [p, e] if state.rng.randf() < BattleRules.initiative_chance(ps, es) else [e, p]


static func _perform(state: BattleState, actor: Combatant, ability: AbilityData, events: Array) -> void:
	if ability.kind == AbilityData.Kind.SWAP:
		_swap(state, actor, int(ability.get_meta("swap_to", 0)), events)
		return
	var target := state.enemy if actor == state.player else state.player
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
		_check_phase(target, events)
	if ability.heal_ratio > 0.0 and actor.is_alive():
		var heal := mini(actor.max_hp - actor.hp, int(round(actor.max_hp * ability.heal_ratio)))
		if heal > 0:
			actor.hp += heal
			events.append({"type": "heal", "target": actor, "amount": heal})
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
		_on_faint(state, target, actor, events)


static func _check_phase(c: Combatant, events: Array) -> void:
	if not c.is_boss or not c.is_alive():
		return
	while c.phase_index < c.phases.size() and c.hp_ratio() <= c.phases[c.phase_index].hp_threshold:
		var ph: BossPhaseData = c.phases[c.phase_index]
		c.phase_index += 1
		c.apply_stat_multipliers(ph.stat_multipliers)
		for a in ph.new_abilities:
			if not c.own_abilities.has(a):
				c.own_abilities.append(a)
		if ph.heal_ratio > 0.0:
			c.hp = mini(c.max_hp, c.hp + int(round(c.max_hp * ph.heal_ratio)))
		c.energy = mini(c.energy + ph.energy_bonus, BattleRules.MAX_ENERGY)
		events.append({"type": "phase", "target": c, "phase": ph})


static func _on_faint(state: BattleState, target: Combatant, killer: Combatant, events: Array) -> void:
	events.append({"type": "faint", "target": target})
	var team := state.team_of(target)
	var next := state.next_alive(team)
	if next == null:
		state.finished = true
		state.winner = killer
		state.winner_is_player = team == state.enemy_team
		return
	_bring_in(state, target, next, events)


static func _swap(state: BattleState, actor: Combatant, index: int, events: Array) -> void:
	var team := state.team_of(actor)
	if index < 0 or index >= team.size() or not team[index].is_alive() or team[index] == actor:
		return
	_bring_in(state, actor, team[index], events)


static func _bring_in(state: BattleState, out_c: Combatant, in_c: Combatant, events: Array) -> void:
	var is_player_side := state.player_team.has(out_c)
	if is_player_side:
		state.player = in_c
	else:
		state.enemy = in_c
	out_c.guard_reduction = 0.0
	state.refresh_combos()
	events.append({"type": "switch", "out": out_c, "in": in_c, "is_player": is_player_side})


static func _finish_by_hp(state: BattleState, events: Array) -> void:
	state.finished = true
	var p_total := 0.0
	var e_total := 0.0
	for c in state.player_team:
		p_total += c.hp_ratio()
	for c in state.enemy_team:
		e_total += c.hp_ratio()
	state.winner_is_player = p_total >= e_total
	var loser := state.enemy if state.winner_is_player else state.player
	state.winner = state.player if state.winner_is_player else state.enemy
	loser.hp = 0
	events.append({"type": "faint", "target": loser})
