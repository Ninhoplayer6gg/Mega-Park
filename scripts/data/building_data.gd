class_name BuildingData
extends Resource
## Data-driven building definition. New buildings are added by creating a .tres in data/buildings/.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Category used by missions and menus: path, fence, gate, habitat, incubator, research, generator, landmark.
@export var category: StringName = &"decor"
## Runtime node behaviour: generic, habitat, incubator (see BuildingFactory).
@export var node_type: StringName = &"generic"
## UI panel opened when tapped: generic, habitat, incubator, research.
@export var panel_type: StringName = &"generic"
@export var sort_order := 0

@export_group("Visual")
@export var icon: Texture2D
@export var sprite: Texture2D
@export var hframes := 1
@export var anim_fps := 0.0
@export var overlay_texture: Texture2D
## 16-frame neighbour-mask sheet (N=1, E=2, S=4, W=8) like paths and fences.
@export var connects := false
## Drawn flat on the ground (under creatures and buildings).
@export var ground_layer := false

@export_group("Placement")
@export var size := Vector2i.ONE
## land | adjacent_fence | adjacent_path
@export var placement_rule: StringName = &"land"
@export var buildable := true
@export var removable := true
@export var walkable := false
@export var max_count := 0
@export var unlock_player_level := 1
@export var required_building: StringName = &""
@export var required_research: StringName = &""

@export_group("Economy")
@export var cost_credits := 100
@export var energy_use := 0
@export var energy_output := 0
@export_range(0.0, 1.0) var refund_ratio := 0.5

@export_group("Habitat")
@export var habitat_type: StringName = &""
@export var habitat_capacity := 0

@export_group("Extra")
## Free-form parameters for specialised panels (e.g. research exchange rates).
@export var params := {}


func is_habitat() -> bool:
	return habitat_type != &""


func footprint_pixels() -> Vector2:
	return Vector2(size) * ParkGrid.TILE
