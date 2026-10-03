extends Node
## Loads every data Resource under res://data once at startup and offers lookups by id.
## Adding content = dropping a new .tres in the matching folder; no code changes required.

const FOLDERS := {
	"creatures": "res://data/creatures",
	"abilities": "res://data/abilities",
	"buildings": "res://data/buildings",
	"habitats": "res://data/habitats",
	"missions": "res://data/missions",
	"expeditions": "res://data/expeditions",
	"arena": "res://data/arena",
}

var creatures := {}
var abilities := {}
var buildings := {}
var habitats := {}
var missions := {}
var expeditions := {}
var arena := {}

var _sprite_frames_cache := {}
var _texture_cache := {}


func _ready() -> void:
	reload()


func reload() -> void:
	creatures = _load_folder(FOLDERS.creatures)
	abilities = _load_folder(FOLDERS.abilities)
	buildings = _load_folder(FOLDERS.buildings)
	habitats = _load_folder(FOLDERS.habitats)
	missions = _load_folder(FOLDERS.missions)
	expeditions = _load_folder(FOLDERS.expeditions)
	arena = _load_folder(FOLDERS.arena)


func _load_folder(path: String) -> Dictionary:
	var result := {}
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("DataRegistry: missing data folder %s" % path)
		return result
	for file in dir.get_files():
		# Exported builds may list "x.tres.remap" instead of "x.tres".
		file = file.trim_suffix(".remap")
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res := load(path.path_join(file))
		if res == null or not ("id" in res):
			push_error("DataRegistry: could not load %s" % file)
			continue
		if res.id == &"":
			push_error("DataRegistry: %s has an empty id" % file)
			continue
		if result.has(res.id):
			push_error("DataRegistry: duplicated id %s in %s" % [res.id, path])
		result[res.id] = res
	return result


func get_creature(id: StringName) -> CreatureData:
	return creatures.get(id)


func get_building(id: StringName) -> BuildingData:
	return buildings.get(id)


func get_habitat_type(id: StringName) -> HabitatTypeData:
	return habitats.get(id)


func get_ability(id: StringName) -> AbilityData:
	return abilities.get(id)


func sorted(dict: Dictionary, key := "order") -> Array:
	var arr := dict.values()
	arr.sort_custom(func(a, b): return a.get(key) < b.get(key))
	return arr


func creature_list() -> Array:
	var arr := creatures.values()
	arr.sort_custom(func(a, b):
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return a.display_name < b.display_name)
	return arr


func buildable_list() -> Array:
	var arr := buildings.values().filter(func(b): return b.buildable)
	arr.sort_custom(func(a, b): return a.sort_order < b.sort_order)
	return arr


func icon(name: String) -> Texture2D:
	var path := "res://assets/ui/icons/%s.png" % name
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		push_warning("Missing icon %s" % name)
		tex = load("res://assets/ui/icons/unknown.png")
	_texture_cache[path] = tex
	return tex


## Builds (and caches) SpriteFrames from a creature sprite sheet + anim_layout.
func sprite_frames_for(data: CreatureData) -> SpriteFrames:
	if _sprite_frames_cache.has(data.id):
		return _sprite_frames_cache[data.id]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim_name in data.anim_layout:
		var spec: Array = data.anim_layout[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, spec[2])
		frames.set_animation_loop(anim_name, spec[3])
		for i in spec[1]:
			frames.add_frame(anim_name, frame_texture(data, spec[0], i))
	_sprite_frames_cache[data.id] = frames
	return frames


func frame_texture(data: CreatureData, row: int, col: int) -> AtlasTexture:
	var key := "%s:%d:%d" % [data.id, row, col]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var atlas := AtlasTexture.new()
	atlas.atlas = data.sprite_sheet
	atlas.region = Rect2(Vector2(col * data.frame_size.x, row * data.frame_size.y), Vector2(data.frame_size))
	_texture_cache[key] = atlas
	return atlas


func portrait(data: CreatureData) -> AtlasTexture:
	return frame_texture(data, 0, 0)
