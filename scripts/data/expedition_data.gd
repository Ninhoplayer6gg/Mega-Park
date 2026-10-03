class_name ExpeditionData
extends Resource
## An expedition destination. Future regions (planets, dimensions, oceans, ruins) are just new .tres files.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## fossil_site | planet | dimension | ocean | ruins ... (used for visuals/filters later)
@export var region_type: StringName = &"fossil_site"
@export var order := 0
@export var duration := 30.0
@export var cost_credits := 100
@export var unlock_player_level := 1
@export var banner_color := Color("3f9a6a")
@export var icon_name := "expedition"
## Pixel-art illustration of the region shown on the expedition card.
@export var banner_texture: Texture2D
@export_group("Rewards")
@export var credits_min := 50
@export var credits_max := 150
@export var dna_min := 5
@export var dna_max := 20
@export var player_xp := 15
## Chance of bringing back a genetic sample of a species from the pool (discovers it + bonus DNA).
@export_range(0.0, 1.0) var species_sample_chance := 0.3
@export var species_sample_dna := 25
@export var species_pool: Array[CreatureData] = []
@export var rp_reward := 5
## material_id -> [min, max, chance]
@export var material_rewards := {}
## Fossil fragments brought back (restoration).
@export var fossil_species: CreatureData
@export var fossil_range := Vector2i(0, 0)
## Clues (footprints/signals) for species discovered through tracking.
@export var clue_species: CreatureData
@export_range(0.0, 1.0) var clue_chance := 0.0
## Tracking expeditions: listed only when enough clues exist; completion discovers the species.
@export var tracking_species: CreatureData
## Temporary expeditions only exist while a dimensional portal event is active.
@export var temporary := false
