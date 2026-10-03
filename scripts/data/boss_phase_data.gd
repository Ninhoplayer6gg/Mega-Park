class_name BossPhaseData
extends Resource
## A boss phase triggered when its HP ratio drops below `hp_threshold`.

@export var hp_threshold := 0.5
@export var title := ""
@export var stat_multipliers := {}
@export var new_abilities: Array[AbilityData] = []
@export var heal_ratio := 0.0
@export var energy_bonus := 0
