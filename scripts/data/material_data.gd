class_name MaterialData
extends Resource
## Rare crafting/genetic material (unstable genetic material, cryo crystal, cosmic core...).

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon_name := "mat_unstable"
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.UNCOMMON
