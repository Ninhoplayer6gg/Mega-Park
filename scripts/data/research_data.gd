class_name ResearchData
extends Resource
## A research project run at the Research Center with research points (RP).
## effects keys: "unlock": StringName | "stability": float | "mutation_chance": float |
## "purity": float | "rp_gain": float | "photo_bonus": float | "happiness": float

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon_name := "research"
@export var order := 0
@export var cost_rp := 20
@export var cost_credits := 0
@export var duration := 30.0
@export var prerequisites: Array[StringName] = []
@export var required_building: StringName = &""
@export var effects := {}
