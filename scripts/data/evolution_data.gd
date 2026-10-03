class_name EvolutionData
extends Resource
## An artificial evolution route: turns one species into another (own sprite/abilities) while keeping
## the individual (uid, level, genes, lineage).

@export var id: StringName
@export var route_name := ""
@export_multiline var description := ""
@export var icon_name := "evolve"
@export var from_species: CreatureData
@export var to_species: CreatureData
@export var min_level := 5
@export var min_stability := 50.0
@export var required_research: Array[StringName] = []
@export var credit_cost := 1000
@export var generic_dna := 100
@export var required_materials := {}
