extends Node
## Global signal hub so systems (missions, audio, UI feedback, saving) stay decoupled.

signal building_placed(instance: BuildingInstance)
signal building_removed(uid: String, building_id: StringName)
signal creature_hatched(creature: CreatureInstance)
signal creature_assigned(creature: CreatureInstance, habitat_uid: String)
signal creature_leveled(creature: CreatureInstance, new_level: int)
signal creature_fed(creature: CreatureInstance)
signal credits_collected(amount: int, world_position: Vector2)
signal incubation_started(building_uid: String, species_id: StringName)
signal battle_finished(result: Dictionary)
signal expedition_started(expedition_id: StringName)
signal expedition_completed(expedition_id: StringName, rewards: Dictionary)
signal species_discovered(species_id: StringName)
signal mission_progressed(mission_id: StringName)
signal mission_claimed(mission_id: StringName)
signal toast_requested(text: String, icon: String, kind: String)
signal game_loaded


func toast(text: String, icon := "info", kind := "info") -> void:
	toast_requested.emit(text, icon, kind)
