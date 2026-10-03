extends Node
## JSON save system with versioning, migrations, atomic writes, a rolling backup and autosave.
## Each system serialises itself (to_dict/from_dict); this node only orchestrates.

signal saved
signal loaded

const SAVE_VERSION := 1
const SAVE_PATH := "user://mega_park_save.json"
const BACKUP_PATH := "user://mega_park_save.bak.json"
const TEMP_PATH := "user://mega_park_save.tmp.json"
const AUTOSAVE_SECONDS := 20.0

var last_save_time := 0.0
## Set when an existing save could not be loaded; shown to the player once.
var load_warning := ""
var _dirty := false
var _autosave: Timer
var _enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_autosave = Timer.new()
	_autosave.wait_time = AUTOSAVE_SECONDS
	_autosave.autostart = true
	_autosave.timeout.connect(func():
		if _dirty:
			save_game())
	add_child(_autosave)
	for sig in [EventBus.building_placed, EventBus.building_removed, EventBus.creature_hatched,
			EventBus.creature_assigned, EventBus.creature_leveled, EventBus.battle_finished,
			EventBus.expedition_started, EventBus.expedition_completed, EventBus.mission_claimed,
			EventBus.incubation_started]:
		sig.connect(func(_a = null, _b = null): mark_dirty())
	Economy.resources_changed.connect(mark_dirty)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _enabled and _dirty:
			save_game()


func mark_dirty() -> void:
	_dirty = true


## Tests use this to avoid touching the player's real save.
func set_enabled(value: bool) -> void:
	_enabled = value


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


func new_game() -> void:
	Economy.reset()
	ParkState.reset()
	CreatureRoster.reset()
	IncubationManager.reset()
	ExpeditionManager.reset()
	MissionManager.reset()
	ArenaManager.reset()
	_dirty = true
	save_game()
	EventBus.game_loaded.emit()


func build_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"game_version": ProjectSettings.get_setting("application/config/version", "0"),
		"saved_at": GameClock.now(),
		"economy": Economy.to_dict(),
		"park": ParkState.to_dict(),
		"creatures": CreatureRoster.to_dict(),
		"incubation": IncubationManager.to_dict(),
		"expeditions": ExpeditionManager.to_dict(),
		"missions": MissionManager.to_dict(),
		"arena": ArenaManager.to_dict(),
	}


func save_game() -> bool:
	if not _enabled:
		return false
	var text := JSON.stringify(build_save_data(), "\t")
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write temp save (%s)" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(text)
	file.close()
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			dir.remove(BACKUP_PATH.get_file())
		dir.rename(SAVE_PATH.get_file(), BACKUP_PATH.get_file())
	var err := dir.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	if err != OK:
		push_error("SaveManager: could not finalise save (%s)" % error_string(err))
		return false
	_dirty = false
	last_save_time = GameClock.now()
	saved.emit()
	return true


## Loads the save (or backup). Returns false when there is nothing usable (caller starts a new game).
func load_game() -> bool:
	load_warning = ""
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var data := _read(path)
		if data.is_empty():
			_quarantine(path, "corrupt")
			load_warning = "O save estava danificado; uma cópia foi preservada e o backup foi usado."
			continue
		var version := int(data.get("save_version", 0))
		if version > SAVE_VERSION:
			_quarantine(path, "newer_v%d" % version)
			load_warning = "Save de uma versão mais nova do jogo (v%d). Ele foi preservado em user://." % version
			continue
		data = SaveMigrations.migrate(data, SAVE_VERSION)
		if data.is_empty():
			_quarantine(path, "unmigratable_v%d" % version)
			load_warning = "Não foi possível migrar o save v%d. Ele foi preservado em user://." % version
			continue
		_apply(data)
		loaded.emit()
		EventBus.game_loaded.emit()
		return true
	return false


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## Keeps an unusable save on disk under a new name instead of silently overwriting it.
func _quarantine(path: String, reason: String) -> void:
	var target := "mega_park_save.%s_%d.json" % [reason, int(Time.get_unix_time_from_system())]
	DirAccess.open("user://").rename(path.get_file(), target)
	push_warning("SaveManager: %s save preserved as user://%s" % [reason, target])


func _apply(data: Dictionary) -> void:
	# Order matters: creatures validate their habitats against the park.
	Economy.from_dict(data.get("economy", {}))
	ParkState.from_dict(data.get("park", {}))
	CreatureRoster.from_dict(data.get("creatures", {}))
	IncubationManager.from_dict(data.get("incubation", {}))
	ExpeditionManager.from_dict(data.get("expeditions", {}))
	MissionManager.from_dict(data.get("missions", {}))
	ArenaManager.from_dict(data.get("arena", {}))
	_dirty = false


func delete_save() -> void:
	var dir := DirAccess.open("user://")
	for path in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(path):
			dir.remove(path.get_file())
