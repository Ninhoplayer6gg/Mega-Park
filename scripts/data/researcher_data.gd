class_name ResearcherData
extends Resource
## A specialist the player can hire. bonus_per_level keys are the same bonus keys used by research.

@export var id: StringName
@export var display_name := ""
## genetics | paleontology | xenobiology | veterinary | ecology
@export var specialty: StringName
@export var specialty_name := ""
@export_multiline var description := ""
@export var portrait: Texture2D
@export var hire_cost := 800
@export var level_cost_credits := 600
@export var level_cost_rp := 15
@export var max_level := 5
@export var bonus_per_level := {}
