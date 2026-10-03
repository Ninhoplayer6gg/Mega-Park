class_name HabitatUpgradeData
extends Resource
## Ecosystem feature installed inside a habitat (water, shelter, vegetation, food).

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## water | shelter | vegetation | food
@export var kind: StringName
@export var icon_name := "plus"
@export var cost_credits := 300
## habitat_type -> Texture2D (falls back to "default").
@export var textures := {}
## Position inside the habitat footprint (in cells, from the top-left).
@export var slot := Vector2i(1, 1)


func texture_for(habitat_type: StringName) -> Texture2D:
	return textures.get(String(habitat_type), textures.get(habitat_type, textures.get("default")))
