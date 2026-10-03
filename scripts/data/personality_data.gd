class_name PersonalityData
extends Resource
## Individual temperament. Effects are deliberately small.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Multipliers used by the park behaviour AI.
@export var wander := 1.0
@export var rest := 1.0
@export var play := 1.0
@export var roar := 1.0
## Added to social relation scores (+ friendlier, - more conflict).
@export var social := 0
@export var happiness := 0
## Tiny battle stat bonus, e.g. {"attack": 0.03}
@export var stat_modifiers := {}
