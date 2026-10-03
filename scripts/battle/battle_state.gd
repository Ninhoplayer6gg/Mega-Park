class_name BattleState
extends RefCounted

var player: Combatant
var enemy: Combatant
var round_number := 1
var finished := false
var winner: Combatant
var rng := RandomNumberGenerator.new()


func _init(p: Combatant, e: Combatant, seed_value := -1) -> void:
	player = p
	enemy = e
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func opponent_of(c: Combatant) -> Combatant:
	return enemy if c == player else player
