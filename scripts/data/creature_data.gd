class_name CreatureData
extends Resource
## Species definition (shared by every creature of that species). Runtime creatures owned by the
## player are CreatureInstance objects that point at one of these.

@export var id: StringName
@export var display_name := ""
@export var species := ""
## Key of GameEnums.CATEGORIES (prehistoric, alien, mythic, aquatic, mechanical, anomalous...).
@export var category: StringName = &"prehistoric"
@export var origin := ""
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
## Key of GameEnums.ROLES.
@export var role: StringName = &"predator"
@export_multiline var description := ""
@export_multiline var lore := ""
## Elemental/biological types (biological, cosmic, glacial, electric, fire, toxic, psychic, aquatic).
@export var types: Array[StringName] = [&"biological"]
@export var icon: Texture2D

@export_group("Arquivo Mega")
## Archive code shown in the Arquivo Mega, e.g. "MG-001".
@export var archive_code := "MG-???"
## small | medium | large | giant
@export var size_class: StringName = &"large"
@export var size_text := ""
@export var diet := ""
@export_multiline var behavior_notes := ""
@export var photo_value := 30

@export_group("Genetics")
@export var default_genes: Array[GeneData] = []
@export var recessive_pool: Array[GeneData] = []
## 0 = base species, 2/3/4 = hybrid tier.
@export var hybrid_tier := 0
## "", alpha, regional, evolution, prototype
@export var variant_kind: StringName = &""
@export var variant_of: CreatureData
## How the species is first discovered: start, research, expedition, clues, restoration, hybrid, boss
@export var discovery_mode: StringName = &"start"
@export var clues_required := 0
## Fossil fragments needed for a pure restoration (0 = not restorable).
@export var fossil_fragments_required := 0
## Research needed before incubation (in addition to required_building).
@export var required_research: StringName = &""

@export_group("Ecology")
## Ecosystem needs: water, shelter, vegetation, food
@export var needs: Array[StringName] = []
## herd | pack | solitary
@export var social_style: StringName = &"solitary"

@export_group("Stats")
@export var base_health := 400
@export var base_attack := 50
@export var base_defense := 30
@export var base_speed := 100
## Fractional growth per level above 1.
@export var health_growth := 0.08
@export var attack_growth := 0.08
@export var defense_growth := 0.07
@export var speed_growth := 0.02
@export var max_level := 10
@export var abilities: Array[AbilityData] = []

@export_group("Park")
@export var habitat_type: StringName = &"prehistoric"
@export var income_amount := 20
@export var income_interval := 10.0
@export var income_cap := 200
@export var walk_speed := 26.0
@export var feed_cost := 60
@export var feed_xp := 25

@export_group("Incubation")
@export var dna_cost := 100
@export var incubation_time := 20.0
@export var start_discovered := true
## Building id that must exist in the park before this species can be incubated.
@export var required_building: StringName = &""

@export_group("Visual")
@export var sprite_sheet: Texture2D
@export var frame_size := Vector2i(64, 64)
## Y coordinate (inside a frame) where the feet touch the ground.
@export var foot_y := 60
## anim name -> [row, frame_count, fps, loop]
@export var anim_layout := {
	"idle": [0, 4, 4.0, true], "walk": [1, 6, 10.0, true], "attack": [2, 4, 10.0, false],
	"hurt": [3, 2, 8.0, false], "defeat": [4, 4, 6.0, false], "eat": [5, 4, 4.0, true],
	"sleep": [6, 2, 1.5, true], "ability": [7, 4, 8.0, false],
}
@export var battle_scale := 2.0
@export var egg_texture: Texture2D
@export var accent_color := Color.WHITE
@export var cry_sfx: StringName = &""


func stat_at_level(stat: StringName, level: int) -> int:
	var l := maxi(level - 1, 0)
	match stat:
		&"health":
			return int(round(base_health * (1.0 + health_growth * l)))
		&"attack":
			return int(round(base_attack * (1.0 + attack_growth * l)))
		&"defense":
			return int(round(base_defense * (1.0 + defense_growth * l)))
		&"speed":
			return int(round(base_speed * (1.0 + speed_growth * l)))
	return 0


func income_at_level(level: int) -> int:
	return int(round(income_amount * (1.0 + 0.12 * maxi(level - 1, 0))))


func income_cap_at_level(level: int) -> int:
	return int(round(income_cap * (1.0 + 0.12 * maxi(level - 1, 0))))


func feed_cost_at_level(level: int) -> int:
	return feed_cost * level


func is_hybrid() -> bool:
	return hybrid_tier >= 2


func base_species() -> CreatureData:
	return variant_of if variant_of else self


func type_names() -> String:
	return " / ".join(types.map(func(t): return GameEnums.type_name(t)))


func rarity_name() -> String:
	return GameEnums.rarity_name(rarity)


func category_name() -> String:
	return GameEnums.category_name(category)
