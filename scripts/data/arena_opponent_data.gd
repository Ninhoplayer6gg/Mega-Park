class_name ArenaOpponentData
extends Resource
## One stage of the arena ladder.

@export var id: StringName
@export var order := 0
@export var title := ""
@export var creature: CreatureData
@export var level := 1
## solo | team | boss
@export var mode: StringName = &"solo"
@export var team: Array[CreatureData] = []
@export var team_levels: Array[int] = []
@export var environment: ArenaEnvironmentData
@export var required_research: StringName = &""
@export_multiline var intro := ""
@export_group("Boss")
@export var boss_hp_multiplier := 1.0
@export var phases: Array[BossPhaseData] = []
@export var unlock_species: CreatureData
@export var unlock_recipe: StringName = &""
@export var reward_materials := {}
@export var reward_species_dna := 0
@export_group("Rewards")
@export var reward_credits := 150
@export var reward_dna := 10
@export var reward_creature_xp := 60
@export var reward_player_xp := 30
@export var loss_creature_xp := 20
@export var loss_credits := 30
@export var reward_rp := 5


func is_boss() -> bool:
	return mode == &"boss"


func is_team() -> bool:
	return mode == &"team"
