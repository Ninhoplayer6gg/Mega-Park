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
# --- genetics / science
signal hybrid_created(creature: CreatureInstance, recipe_id: StringName, new_species: bool)
signal synthesis_failed(recipe_id: StringName, result: Dictionary)
signal mutation_found(creature: CreatureInstance)
signal dna_extracted(creature: CreatureInstance, amount: int)
signal species_restored(creature: CreatureInstance)
signal creature_evolved(creature: CreatureInstance, from_species: StringName)
signal research_completed(research_id: StringName)
signal recipe_detected(recipe_id: StringName)
signal archive_updated(species_id: StringName)
signal photo_taken(record: Dictionary)
# --- park life
signal eco_upgrade_installed(habitat_uid: String, upgrade_id: StringName)
signal park_event_started(event_uid: String)
signal park_event_ended(event_uid: String)
signal boss_defeated(stage_id: StringName)
signal team_battle_won(stage_id: StringName)
## Ask the HUD to show a big presentation (new species / mutation / prototype...).
signal presentation_requested(kind: String, payload: Dictionary)
signal game_loaded


func toast(text: String, icon := "info", kind := "info") -> void:
	toast_requested.emit(text, icon, kind)
