class_name ReputationStyleData
extends Resource
## Park style (Parque Científico, Reserva Natural...). `metric` picks the score formula in
## VisitorManager; the dominant style grants `bonus` (bonus keys like research effects).

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon_name := "reputation"
@export var metric: StringName
@export var bonus := {}
