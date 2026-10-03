class_name MissionData
extends Resource
## A tutorial/progression objective. Objectives are matched against EventBus events by MissionManager.

@export var id: StringName
@export var order := 0
@export var title := ""
@export_multiline var description := ""
## building_placed | creature_hatched | creature_assigned | credits_collected | creature_level |
## creature_fed | battle_won | expedition_completed | incubation_started
@export var objective: StringName
## Optional filter (building category or id, species id...). Empty = any.
@export var objective_param: StringName = &""
@export var target := 1
@export var icon_name := "missions"
@export_group("Rewards")
@export var reward_credits := 0
@export var reward_dna := 0
@export var reward_player_xp := 0
