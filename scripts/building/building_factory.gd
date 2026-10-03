class_name BuildingFactory
extends RefCounted
## Maps BuildingData.node_type to the node class that renders it. Register new behaviours here.

const TYPES := {
	&"generic": preload("res://scripts/building/building_node.gd"),
	&"habitat": preload("res://scripts/building/habitat_node.gd"),
	&"incubator": preload("res://scripts/building/incubator_node.gd"),
}


static func create(data: BuildingData, instance: BuildingInstance, preview := false) -> BuildingNode:
	var script: GDScript = TYPES.get(data.node_type, TYPES[&"generic"])
	var node: BuildingNode = script.new()
	node.setup(data, instance, preview)
	node.name = (instance.uid if instance else "Preview_" + String(data.id))
	return node
