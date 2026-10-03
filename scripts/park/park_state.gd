extends Node
## Authoritative park model: map layout, placed buildings, occupancy grid and energy grid.
## The park scene only renders this state, so it can be rebuilt any time (e.g. after a battle).

signal buildings_changed

const MAP_PATH := "res://data/maps/park_start.txt"
const ENTRANCE_ID := &"park_entrance"
const PATH_ID := &"path"

var layout: MapLayout
var buildings := {}        # uid -> BuildingInstance
var _occupancy := {}       # Vector2i -> uid


func _ready() -> void:
	layout = MapLayout.load_file(MAP_PATH)


func reset() -> void:
	buildings.clear()
	_occupancy.clear()
	var entrance := DataRegistry.get_building(ENTRANCE_ID)
	if entrance and layout.entrance_cell.x >= 0:
		_add(entrance, layout.entrance_cell)
	var path_data := DataRegistry.get_building(PATH_ID)
	if path_data:
		for cell in layout.start_paths:
			if is_cell_free(cell):
				_add(path_data, cell)
	buildings_changed.emit()


# ------------------------------------------------------------------ queries
func get_building(uid: String) -> BuildingInstance:
	return buildings.get(uid)


func get_at_cell(cell: Vector2i) -> BuildingInstance:
	var uid: String = _occupancy.get(cell, "")
	return buildings.get(uid) if uid != "" else null


func is_cell_free(cell: Vector2i) -> bool:
	return layout.in_bounds(cell) and not layout.is_water(cell) and not layout.decor.has(cell) \
		and not _occupancy.has(cell)


func count_of(id: StringName) -> int:
	var n := 0
	for b in buildings.values():
		if b.building_id == id:
			n += 1
	return n


func has_building(id: StringName) -> bool:
	return count_of(id) > 0


func has_category(category: StringName) -> bool:
	for b in buildings.values():
		if b.data.category == category:
			return true
	return false


func habitats() -> Array:
	var arr := buildings.values().filter(func(b): return b.data.is_habitat())
	arr.sort_custom(func(a, b): return a.placed_at < b.placed_at)
	return arr


func of_category(category: StringName) -> Array:
	return buildings.values().filter(func(b): return b.data.category == category)


func energy_capacity() -> int:
	var total := 0
	for b in buildings.values():
		total += b.data.energy_output
	return maxi(total - EventManager.energy_penalty(), 0)


func energy_used() -> int:
	var total := 0
	for b in buildings.values():
		total += b.data.energy_use
	return total


func energy_free() -> int:
	return energy_capacity() - energy_used()


## 4-bit neighbour mask (N=1, E=2, S=4, W=8) of same-id buildings, used by connecting sprites.
func connection_mask(cell: Vector2i, id: StringName) -> int:
	var mask := 0
	var dirs := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i in 4:
		var other := get_at_cell(cell + dirs[i])
		if other and _connects_with(id, other.data):
			mask |= 1 << i
	return mask


func _connects_with(id: StringName, other: BuildingData) -> bool:
	if other.id == id:
		return true
	# Fences connect to gates so a gate can sit inside a fence line.
	if id == &"fence" and other.category == &"gate":
		return true
	return false


# ------------------------------------------------------------------ placement
## Returns "" if the building can be placed, otherwise a player-facing reason.
func check_placement(data: BuildingData, cell: Vector2i, ignore_cost := false) -> String:
	for y in data.size.y:
		for x in data.size.x:
			var c := cell + Vector2i(x, y)
			if not layout.in_bounds(c):
				return "Fora dos limites do parque."
			if layout.is_water(c):
				return "Não é possível construir na água."
			if layout.decor.has(c):
				return "Há vegetação ou rochas aqui."
			if _occupancy.has(c):
				return "Espaço ocupado."
	var rule := check_rules(data)
	if rule != "":
		return rule
	match data.placement_rule:
		&"adjacent_fence":
			if not _touches_category(data, cell, &"fence"):
				return "Precisa ficar ao lado de uma cerca."
		&"adjacent_path":
			if not _touches_category(data, cell, &"path"):
				return "Precisa ficar ao lado de um caminho."
	if not ignore_cost and not Economy.can_afford(data.cost_credits):
		return "Créditos insuficientes."
	return ""


## Rules that do not depend on the position (used to grey-out the build menu too).
func check_rules(data: BuildingData) -> String:
	if Economy.player_level < data.unlock_player_level:
		return "Requer nível %d do parque." % data.unlock_player_level
	if data.max_count > 0 and count_of(data.id) >= data.max_count:
		return "Limite de %d atingido." % data.max_count
	if data.required_building != &"" and not has_building(data.required_building):
		var req := DataRegistry.get_building(data.required_building)
		return "Requer %s." % (req.display_name if req else String(data.required_building))
	if data.required_research != &"" and not ResearchManager.is_done(data.required_research):
		var rs := DataRegistry.get_research(data.required_research)
		return "Requer a pesquisa %s." % (rs.display_name if rs else String(data.required_research))
	if data.energy_use > 0 and energy_free() < data.energy_use:
		return "Energia insuficiente (precisa %d). Construa um gerador." % data.energy_use
	return ""


func _touches_category(data: BuildingData, cell: Vector2i, category: StringName) -> bool:
	for y in range(-1, data.size.y + 1):
		for x in range(-1, data.size.x + 1):
			var inside := x >= 0 and y >= 0 and x < data.size.x and y < data.size.y
			var corner := (x == -1 or x == data.size.x) and (y == -1 or y == data.size.y)
			if inside or corner:
				continue
			var other := get_at_cell(cell + Vector2i(x, y))
			if other and other.data.category == category:
				return true
	return false


func place(data: BuildingData, cell: Vector2i) -> BuildingInstance:
	var reason := check_placement(data, cell)
	if reason != "":
		EventBus.toast(reason, "close", "bad")
		return null
	Economy.spend(data.cost_credits)
	var b := _add(data, cell)
	buildings_changed.emit()
	EventBus.building_placed.emit(b)
	return b


func _add(data: BuildingData, cell: Vector2i, uid := "") -> BuildingInstance:
	var b := BuildingInstance.new()
	b.uid = uid if uid != "" else Uid.make("bd")
	b.building_id = data.id
	b.data = data
	b.cell = cell
	b.placed_at = GameClock.now()
	buildings[b.uid] = b
	for c in b.rect_cells():
		_occupancy[c] = b.uid
	return b


## Returns "" if it can be removed, otherwise the reason.
func check_removal(b: BuildingInstance) -> String:
	if not b.data.removable:
		return "Esta construção não pode ser removida."
	if b.data.is_habitat() and not CreatureRoster.in_habitat(b.uid).is_empty():
		return "Retire as criaturas do habitat primeiro."
	if IncubationManager.has_slot(b.uid):
		return "A incubadora está em uso."
	if GeneticsManager.jobs.has(b.uid) or GeneticsManager.restorations.has(b.uid):
		return "O laboratório está em uso."
	if b.data.energy_output > 0 and energy_used() > energy_capacity() - b.data.energy_output:
		return "Remover deixaria o parque sem energia."
	return ""


func remove(uid: String) -> bool:
	var b := get_building(uid)
	if b == null:
		return false
	var reason := check_removal(b)
	if reason != "":
		EventBus.toast(reason, "close", "bad")
		return false
	for c in b.rect_cells():
		_occupancy.erase(c)
	buildings.erase(uid)
	Economy.add(int(b.data.cost_credits * b.data.refund_ratio))
	buildings_changed.emit()
	EventBus.building_removed.emit(uid, b.building_id)
	return true


# ------------------------------------------------------------------ ecosystem features
func habitat_upgrades(b: BuildingInstance) -> Array:
	return b.extra.get("upgrades", [])


func check_upgrade(b: BuildingInstance, u: HabitatUpgradeData) -> String:
	if not b.data.is_habitat():
		return "Somente habitats."
	if habitat_upgrades(b).has(String(u.id)):
		return "Já instalado."
	if not Economy.can_afford(u.cost_credits):
		return "Créditos insuficientes."
	return ""


func install_upgrade(b: BuildingInstance, u: HabitatUpgradeData) -> bool:
	var reason := check_upgrade(b, u)
	if reason != "":
		EventBus.toast(reason, "build", "bad")
		return false
	Economy.spend(u.cost_credits)
	var list: Array = habitat_upgrades(b).duplicate()
	list.append(String(u.id))
	b.extra["upgrades"] = list
	buildings_changed.emit()
	EventBus.eco_upgrade_installed.emit(b.uid, u.id)
	AudioManager.play_sfx(&"build")
	return true


# ------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	var list := []
	for b in buildings.values():
		list.append(b.to_dict())
	return {"buildings": list}


func from_dict(d: Dictionary) -> void:
	buildings.clear()
	_occupancy.clear()
	for entry in d.get("buildings", []):
		var b := BuildingInstance.from_dict(entry)
		if b == null:
			continue
		var blocked := false
		for c in b.rect_cells():
			if _occupancy.has(c) or not layout.in_bounds(c):
				blocked = true
		if blocked:
			push_warning("Building %s overlaps after load; skipped" % b.uid)
			continue
		buildings[b.uid] = b
		for c in b.rect_cells():
			_occupancy[c] = b.uid
	if not has_building(ENTRANCE_ID) and layout.entrance_cell.x >= 0:
		_add(DataRegistry.get_building(ENTRANCE_ID), layout.entrance_cell)
	buildings_changed.emit()
