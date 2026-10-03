class_name CreatureInstance
extends RefCounted
## A creature owned by the player. Stats are always derived from species data + level so balancing
## changes to the .tres files apply to existing saves.

var uid := ""
var species_id: StringName
var nickname := ""
var level := 1
var xp := 0
## Reserved for visual/genetic evolution (forms, hybrids...).
var evolution_stage := 0
## &"habitat" or &"storage"
var state: StringName = &"storage"
var habitat_uid := ""
var production_start := 0.0
var battles_won := 0
var data: CreatureData


static func create(species: CreatureData) -> CreatureInstance:
	var c := CreatureInstance.new()
	c.uid = Uid.make("cr")
	c.species_id = species.id
	c.data = species
	c.production_start = GameClock.now()
	return c


func display_name() -> String:
	return nickname if nickname != "" else data.display_name


func max_hp() -> int:
	return data.stat_at_level(&"health", level)


func attack() -> int:
	return data.stat_at_level(&"attack", level)


func defense() -> int:
	return data.stat_at_level(&"defense", level)


func speed() -> int:
	return data.stat_at_level(&"speed", level)


func stat(name: StringName) -> int:
	return data.stat_at_level(name, level)


func is_max_level() -> bool:
	return level >= data.max_level


static func xp_for_level(lvl: int) -> int:
	return int(round(40.0 * pow(lvl, 1.5)))


func xp_to_next() -> int:
	return xp_for_level(level)


## Adds XP and returns how many levels were gained.
func add_xp(amount: int) -> int:
	if is_max_level():
		return 0
	xp += amount
	var gained := 0
	while not is_max_level() and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
	if is_max_level():
		xp = 0
	return gained


func income_per_cycle() -> int:
	return data.income_at_level(level)


func income_cap() -> int:
	return data.income_cap_at_level(level)


func pending_income(now: float) -> int:
	if state != &"habitat":
		return 0
	var cycles := floori(maxf(now - production_start, 0.0) / maxf(data.income_interval, 0.1))
	return mini(cycles * income_per_cycle(), income_cap())


func to_dict() -> Dictionary:
	return {
		"uid": uid, "species": String(species_id), "nickname": nickname, "level": level, "xp": xp,
		"evolution_stage": evolution_stage, "state": String(state), "habitat_uid": habitat_uid,
		"production_start": production_start, "battles_won": battles_won,
	}


static func from_dict(d: Dictionary) -> CreatureInstance:
	var species: CreatureData = DataRegistry.get_creature(StringName(d.get("species", "")))
	if species == null:
		push_warning("Save references unknown species %s; creature skipped" % d.get("species"))
		return null
	var c := CreatureInstance.new()
	c.data = species
	c.uid = str(d.get("uid", Uid.make("cr")))
	c.species_id = species.id
	c.nickname = str(d.get("nickname", ""))
	c.level = clampi(int(d.get("level", 1)), 1, species.max_level)
	c.xp = maxi(int(d.get("xp", 0)), 0)
	c.evolution_stage = int(d.get("evolution_stage", 0))
	c.state = StringName(d.get("state", "storage"))
	c.habitat_uid = str(d.get("habitat_uid", ""))
	c.production_start = float(d.get("production_start", GameClock.now()))
	c.battles_won = int(d.get("battles_won", 0))
	return c
