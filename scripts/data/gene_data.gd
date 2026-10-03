class_name GeneData
extends Resource
## A gene. Creatures carry a limited set of active genes (stats/behaviour) plus recessive genes that
## only show up through hybridisation or gene therapy.

## physical | elemental | special
@export var group: StringName = &"physical"
@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon_name := "gene_physical"
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
## Fractional stat modifiers, e.g. {"attack": 0.06}
@export var stat_modifiers := {}
## Element granted by the gene (fire, ice, electric, toxic, cosmic, psychic) — used by types/arenas.
@export var element: StringName = &""
## Behaviour hint used by the park AI (e.g. "nocturnal", "aquatic", "camouflage").
@export var behavior_tag: StringName = &""
