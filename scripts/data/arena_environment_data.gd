class_name ArenaEnvironmentData
extends Resource
## Battle environment: background + moderate type modifiers.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var background: Texture2D
## type -> {stat: multiplier}, e.g. {"glacial": {"defense": 1.1}, "fire": {"speed": 0.95}}
@export var type_modifiers := {}
