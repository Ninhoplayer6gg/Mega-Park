extends Node
## Arquivo Mega: scientific knowledge per species, photo album, observed behaviours and mutations.
## Knowledge flags: discovered, owned, incubated, battled, photographed, sequenced, observed
## Sections unlock from those flags (see section_unlocked()).

signal archive_changed

const SECTIONS := ["identity", "biometrics", "behavior", "genetics", "habitat", "abilities"]
const MAX_PHOTOS := 40

var knowledge := {}         # species_id -> {flag: true}
var behaviors_seen := {}    # species_id -> [behavior]
var mutations_seen := {}    # species_id -> [mutation_id]
var photos: Array = []      # [{species, uid, behavior, time, file, score}]


func _ready() -> void:
	EventBus.species_discovered.connect(func(sid): mark(sid, &"discovered"))
	EventBus.creature_hatched.connect(_on_owned.bind(&"incubated"))
	EventBus.hybrid_created.connect(func(c, _r, _n): _on_owned(c, &"incubated"))
	EventBus.species_restored.connect(_on_owned.bind(&"incubated"))
	EventBus.mutation_found.connect(func(c): note_mutation(c.species_id, c.mutation_id))
	EventBus.battle_finished.connect(_on_battle)


func reset() -> void:
	knowledge.clear()
	behaviors_seen.clear()
	mutations_seen.clear()
	photos.clear()
	archive_changed.emit()


func _on_owned(c: CreatureInstance, flag: StringName) -> void:
	if c == null:
		return
	mark(c.species_id, &"discovered")
	mark(c.species_id, &"owned")
	mark(c.species_id, flag)
	if c.mutation_id != &"":
		note_mutation(c.species_id, c.mutation_id)


func _on_battle(result: Dictionary) -> void:
	for sid in result.get("species_involved", []):
		mark(StringName(sid), &"battled")


func knows(species_id: StringName, flag: StringName) -> bool:
	return knowledge.get(species_id, {}).has(flag)


func mark(species_id: StringName, flag: StringName) -> void:
	if DataRegistry.get_creature(species_id) == null:
		return
	if not knowledge.has(species_id):
		knowledge[species_id] = {}
	if knowledge[species_id].has(flag):
		return
	knowledge[species_id][flag] = true
	archive_changed.emit()
	EventBus.archive_updated.emit(species_id)


func is_registered(species_id: StringName) -> bool:
	return knows(species_id, &"discovered") or CreatureRoster.is_discovered(species_id)


func entries_count() -> int:
	var n := 0
	for s in DataRegistry.creatures.values():
		if is_registered(s.id):
			n += 1
	return n


func section_unlocked(species_id: StringName, section: String) -> bool:
	if not is_registered(species_id):
		return false
	match section:
		"identity":
			return true
		"biometrics":
			return knows(species_id, &"photographed") or knows(species_id, &"owned")
		"behavior":
			return behaviors_seen.get(species_id, []).size() >= 2 or (knows(species_id, &"owned") and ResearchManager.is_done(&"ethology"))
		"genetics":
			return knows(species_id, &"sequenced")
		"habitat":
			return knows(species_id, &"owned") or knows(species_id, &"incubated")
		"abilities":
			return knows(species_id, &"battled") or knows(species_id, &"owned")
	return false


func progress(species_id: StringName) -> float:
	var n := 0
	for s in SECTIONS:
		if section_unlocked(species_id, s):
			n += 1
	return float(n) / SECTIONS.size()


func note_behavior(species_id: StringName, behavior: StringName) -> bool:
	var arr: Array = behaviors_seen.get(species_id, [])
	if arr.has(String(behavior)):
		return false
	arr.append(String(behavior))
	behaviors_seen[species_id] = arr
	archive_changed.emit()
	return true


func note_mutation(species_id: StringName, mutation_id: StringName) -> void:
	if mutation_id == &"":
		return
	var arr: Array = mutations_seen.get(species_id, [])
	if not arr.has(String(mutation_id)):
		arr.append(String(mutation_id))
		mutations_seen[species_id] = arr
		archive_changed.emit()


func mutation_known(mutation_id: StringName) -> bool:
	for arr in mutations_seen.values():
		if arr.has(String(mutation_id)):
			return true
	return false


func note_clue(species_id: StringName) -> void:
	mark(species_id, &"clue")


func add_photo(record: Dictionary) -> void:
	photos.push_front(record)
	while photos.size() > MAX_PHOTOS:
		var old: Dictionary = photos.pop_back()
		if old.get("file", "") != "" and FileAccess.file_exists(old.file):
			DirAccess.remove_absolute(old.file)
	mark(StringName(record.species), &"photographed")
	archive_changed.emit()


func to_dict() -> Dictionary:
	var k := {}
	for sid in knowledge:
		k[String(sid)] = knowledge[sid].keys().map(func(f): return String(f))
	var b := {}
	for sid in behaviors_seen:
		b[String(sid)] = behaviors_seen[sid].duplicate()
	var m := {}
	for sid in mutations_seen:
		m[String(sid)] = mutations_seen[sid].duplicate()
	return {"knowledge": k, "behaviors": b, "mutations": m, "photos": photos.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	reset()
	var k: Dictionary = d.get("knowledge", {})
	for sid in k:
		if DataRegistry.get_creature(StringName(sid)):
			var flags := {}
			for f in k[sid]:
				flags[StringName(f)] = true
			knowledge[StringName(sid)] = flags
	var b: Dictionary = d.get("behaviors", {})
	for sid in b:
		behaviors_seen[StringName(sid)] = Array(b[sid])
	var m: Dictionary = d.get("mutations", {})
	for sid in m:
		mutations_seen[StringName(sid)] = Array(m[sid])
	photos = Array(d.get("photos", []))
	# Saves without an archive (v1): rebuild from discovered + owned creatures.
	for sid in CreatureRoster.discovered:
		if not knowledge.has(sid):
			knowledge[sid] = {&"discovered": true}
	for c in CreatureRoster.creatures.values():
		if not knowledge.has(c.species_id):
			knowledge[c.species_id] = {&"discovered": true}
		knowledge[c.species_id][&"owned"] = true
		knowledge[c.species_id][&"incubated"] = true
		if c.mutation_id != &"":
			note_mutation(c.species_id, c.mutation_id)
	archive_changed.emit()
