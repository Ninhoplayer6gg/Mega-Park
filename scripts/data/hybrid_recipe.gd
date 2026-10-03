class_name HybridRecipe
extends Resource
## Genetic recipe that produces a NEW SPECIES (with its own sprite/abilities) from 2-4 species.

@export var id: StringName
@export var display_name := ""
@export var result_species: CreatureData
@export var required_species: Array[CreatureData] = []
## Species DNA needed for each entry of required_species (same order).
@export var required_dna_amounts: Array[int] = []
## Generic DNA consumed on top of species DNA.
@export var generic_dna := 0
## material_id -> amount
@export var required_materials := {}
@export var required_lab_level := 1
@export var required_research: Array[StringName] = []
## Minimum computed stability needed to attempt the synthesis (0..100).
@export var minimum_stability := 30.0
## Overrides the tier default base stability when > 0.
@export var base_stability := 0.0
## Hidden recipes show "RESULTADO DESCONHECIDO" until synthesised once.
@export var hidden_recipe := false
## The recipe is only listed after these conditions: {"own_species": [...], "research": id,
## "boss": stage_id, "dna_species": [...]} (all must hold). Empty = always listed.
@export var discovery_requirements := {}
@export var creation_time := 30.0
@export var credit_cost := 500
@export_group("Dominant genes")
@export var primary_gene: GeneData
@export var secondary_gene: GeneData
@export var elemental_gene: GeneData
@export var special_gene: GeneData
@export_multiline var lore := ""


func tier() -> int:
	return required_species.size()


func tier_name() -> String:
	match tier():
		2:
			return "Híbrido Simples"
		3:
			return "Híbrido Avançado"
		4:
			return "Quimera Suprema"
	return "Híbrido"


func dominant_genes() -> Array[GeneData]:
	var out: Array[GeneData] = []
	for g in [primary_gene, secondary_gene, elemental_gene, special_gene]:
		if g:
			out.append(g)
	return out
