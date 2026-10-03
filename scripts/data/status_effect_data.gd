class_name StatusEffectData
extends Resource
## A temporary stat modifier applied by an ability during battle.

## &"self" or &"enemy"
@export var target: StringName = &"enemy"
## &"attack", &"defense", &"speed" or &"next_attack" (one-shot damage multiplier)
@export var stat: StringName = &"attack"
@export var multiplier := 1.0
## Duration in rounds (ignored for next_attack, which is consumed by the next damaging action).
@export var duration := 2
@export var label := ""
