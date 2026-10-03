extends Node
## Audio entry point. Sounds are registered by file name: any .wav/.ogg/.mp3 dropped into
## assets/audio/sfx or assets/audio/music becomes playable by id. Missing ids are ignored so the
## game stays fully functional without audio files.

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"
const SETTINGS_PATH := "user://settings.cfg"
const POOL_SIZE := 10
const UI_SOUNDS := [&"ui_click", &"ui_open", &"ui_close", &"error", &"coin", &"purchase"]

var sfx := {}
var music := {}
var music_volume := 0.7
var sfx_volume := 0.8
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx = _scan(SFX_DIR)
	music = _scan(MUSIC_DIR)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	add_child(_music_player)
	load_settings()


func _scan(path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for file in dir.get_files():
		file = file.trim_suffix(".import").trim_suffix(".remap")
		if file.get_extension() in ["wav", "ogg", "mp3"]:
			var id := StringName(file.get_basename())
			if not out.has(id):
				var stream = load(path.path_join(file))
				if stream:
					out[id] = stream
	return out


func play_sfx(id: StringName, pitch_variation := 0.0, volume_db := 0.0) -> void:
	if id == &"" or not sfx.has(id):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = sfx[id]
	p.bus = &"UI" if UI_SOUNDS.has(id) else &"SFX"
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.volume_db = volume_db
	p.play()


func play_music(id: StringName) -> void:
	if not music.has(id):
		_music_player.stop()
		return
	if _music_player.stream == music[id] and _music_player.playing:
		return
	_music_player.stream = music[id]
	_music_player.play()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	save_settings()


func _apply_volumes() -> void:
	_set_bus(&"Music", music_volume)
	_set_bus(&"SFX", sfx_volume)


func _set_bus(bus_name: StringName, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	_apply_volumes()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS_PATH)
