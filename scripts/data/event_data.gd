class_name EventData
extends Resource
## Park event definition. `kind` selects the handler in EventManager.

@export var id: StringName
@export var title := ""
@export_multiline var description := ""
@export var icon_name := "event"
## storm | power_issue | egg_found | special_visitor | stressed_creature | fence_damaged |
## dimensional_anomaly | genetic_sample | rare_behavior
@export var kind: StringName
@export var weight := 1.0
@export var min_player_level := 1
@export var duration := 120.0
@export var resolve_cost := 0
@export var resolve_label := "Resolver"
@export var params := {}
