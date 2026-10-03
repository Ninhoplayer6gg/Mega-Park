class_name HabitatTypeData
extends Resource
## Visual/ruleset of a habitat family (prehistoric, alien, aquatic, glacial, volcanic...).

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Ground texture with N variants of 32x32 side by side.
@export var ground_texture: Texture2D
@export var ground_variants := 2
## 16-frame fence sheet (32x48 frames).
@export var fence_texture: Texture2D
@export var gate_texture: Texture2D
@export var feeder_texture: Texture2D
@export var decor_textures: Array[Texture2D] = []
@export var ui_color := Color.WHITE
