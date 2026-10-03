class_name VisitorTypeData
extends Resource
## Visitor archetype with interests (categories or tags: prehistoric, alien, hybrid, aquatic, giant, rare).

@export var id: StringName
@export var display_name := ""
@export var sprite: Texture2D
@export var interests: Array[StringName] = []
@export var ticket := 4
@export var weight := 1.0
