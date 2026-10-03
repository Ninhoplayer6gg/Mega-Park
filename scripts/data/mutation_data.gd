class_name MutationData
extends Resource
## A mutation modifies one existing creature (it is not a new species). Small mutations change the
## palette through a shader; big ones can replace the sprite sheet for specific species.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.RARE
## Base chance per incubation (0..1), before bonuses.
@export var base_chance := 0.01
@export_group("Visual")
@export var hue_shift := 0.0
@export var saturation := 1.0
@export var value := 1.0
@export var tint := Color.WHITE
@export_range(0.0, 1.0) var tint_amount := 0.0
## 0..1 glow pulse strength (bioluminescence, cosmic...)
@export var pulse := 0.0
## Jitter/flicker for unstable mutations.
@export var unstable := false
@export var visual_scale := 1.0
## species_id -> Texture2D sheet with the big-mutation anatomy (same layout as the species sheet).
@export var species_forms := {}
## species_id -> display name of that form (e.g. "Xenoraptor Tempestade").
@export var form_names := {}
@export_group("Rules")
@export var stat_modifiers := {}
@export var ability: AbilityData
@export var incompatible_with: Array[StringName] = []
## Empty = any category.
@export var allowed_categories: Array[StringName] = []
## If set, only these species can roll it.
@export var exclusive_species: Array[StringName] = []
@export var types_added: Array[StringName] = []


func can_apply_to(species: CreatureData) -> bool:
	if not exclusive_species.is_empty() and not exclusive_species.has(species.id):
		return false
	if not allowed_categories.is_empty() and not allowed_categories.has(species.category):
		return false
	return true


func form_sheet(species: CreatureData) -> Texture2D:
	return species_forms.get(String(species.id), species_forms.get(species.id))


func name_for(species: CreatureData) -> String:
	var n = form_names.get(String(species.id), form_names.get(species.id, ""))
	return n if n != "" else "%s %s" % [species.display_name, display_name]
