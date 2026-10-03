class_name ArenaOpponentData
extends Resource
## One stage of the arena ladder.

@export var id: StringName
@export var order := 0
@export var title := ""
@export var creature: CreatureData
@export var level := 1
@export_group("Rewards")
@export var reward_credits := 150
@export var reward_dna := 10
@export var reward_creature_xp := 60
@export var reward_player_xp := 30
@export var loss_creature_xp := 20
@export var loss_credits := 30
