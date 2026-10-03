class_name SynergyData
extends Resource
## Team composition bonus. condition: "category_count" (params: category, count) |
## "role_set" (params: roles) | "type_count" (params: type, count) | "species_pair" (params: species)

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var condition: StringName
@export var params := {}
@export var stat_modifiers := {}
