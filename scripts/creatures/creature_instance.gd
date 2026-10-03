class_name CreatureInstance
extends RefCounted
## A creature owned by the player. Stats are always derived from species data + level + genes +
## mutation + purity + personality, so balancing changes to the .tres files apply to old saves.

const EXTRACT_COOLDOWN := 90.0

var uid := ""
var species_id: StringName
var nickname := ""
var level := 1
var xp := 0
## Kept for save compatibility; visual evolution now changes species_id (see EvolutionData).
var evolution_stage := 0
## &"habitat" or &"storage"
var state: StringName = &"storage"
var habitat_uid := ""
var production_start := 0.0
var battles_won := 0
var data: CreatureData

# --- genetics
var active_genes: Array[StringName] = []
var recessive_genes: Array[StringName] = []
var mutation_id: StringName = &""
var personality_id: StringName = &""
var genetic_purity := 100.0
var genetic_stability := 100.0
## {"parents": [{"species", "uid", "name"}], "generation": int, "origin": String, "evolved_from": String}
var lineage := {"parents": [], "generation": 0, "origin": "incubated"}
var sequenced := false
var extracted_at := 0.0
var born_at := 0.0


static func create(species: CreatureData, rng: RandomNumberGenerator = null) -> CreatureInstance:
	var c := CreatureInstance.new()
	c.uid = Uid.make("cr")
	c.species_id = species.id
	c.data = species
	c.production_start = GameClock.now()
	c.born_at = GameClock.now()
	if rng == null:
		rng = GeneticsLogic.rng_for(GeneticsLogic.hash_seed(c.uid))
	var g := GeneticsLogic.initial_genes(species, rng)
	c.active_genes = g.active
	c.recessive_genes = g.recessive
	c.personality_id = GeneticsLogic.pick_personality(rng.randi())
	return c


func mutation() -> MutationData:
	return DataRegistry.get_mutation(mutation_id) if mutation_id != &"" else null


func personality() -> PersonalityData:
	return DataRegistry.get_personality(personality_id) if personality_id != &"" else null


## Sprite sheet override for big mutations (e.g. Xenoraptor Tempestade), or null.
func form_sheet() -> Texture2D:
	var m := mutation()
	return m.form_sheet(data) if m else null


func display_name() -> String:
	if nickname != "":
		return nickname
	var m := mutation()
	if m and m.form_sheet(data):
		return m.name_for(data)
	return data.display_name


func types() -> Array[StringName]:
	var out: Array[StringName] = data.types.duplicate()
	var m := mutation()
	if m:
		for t in m.types_added:
			if not out.has(t):
				out.append(t)
	for gid in active_genes:
		var g: GeneData = DataRegistry.get_gene(gid)
		if g and g.element != &"" and not out.has(g.element):
			out.append(g.element)
	return out


func abilities() -> Array[AbilityData]:
	var out: Array[AbilityData] = data.abilities.duplicate()
	var m := mutation()
	if m and m.ability and not out.has(m.ability):
		out.append(m.ability)
	return out


func has_gene_tag(tag: StringName) -> bool:
	for gid in active_genes:
		var g: GeneData = DataRegistry.get_gene(gid)
		if g and g.behavior_tag == tag:
			return true
	return false


## Fractional modifier of a stat from genes + mutation + personality.
func stat_bonus(stat: StringName) -> float:
	var total := GeneticsLogic.gene_modifier(active_genes, stat)
	var m := mutation()
	if m:
		total += float(m.stat_modifiers.get(String(stat), m.stat_modifiers.get(stat, 0.0)))
	var p := personality()
	if p:
		total += float(p.stat_modifiers.get(String(stat), p.stat_modifiers.get(stat, 0.0)))
	return total


func stat(name: StringName) -> int:
	var base := float(data.stat_at_level(name, level))
	return maxi(1, int(round(base * (1.0 + stat_bonus(name)) * GeneticsLogic.purity_factor(genetic_purity))))


func max_hp() -> int:
	return stat(&"health")


func attack() -> int:
	return stat(&"attack")


func defense() -> int:
	return stat(&"defense")


func speed() -> int:
	return stat(&"speed")


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
	var raw := mini(cycles * income_per_cycle(), income_cap())
	return int(round(raw * SocialLogic.production_multiplier(self)))


func extract_cooldown_left(now: float) -> float:
	return maxf(0.0, extracted_at + EXTRACT_COOLDOWN - now)


func generation() -> int:
	return int(lineage.get("generation", 0))


func origin() -> String:
	return str(lineage.get("origin", "incubated"))


func to_dict() -> Dictionary:
	return {
		"uid": uid, "species": String(species_id), "nickname": nickname, "level": level, "xp": xp,
		"evolution_stage": evolution_stage, "state": String(state), "habitat_uid": habitat_uid,
		"production_start": production_start, "battles_won": battles_won,
		"active_genes": active_genes.map(func(g): return String(g)),
		"recessive_genes": recessive_genes.map(func(g): return String(g)),
		"mutation": String(mutation_id), "personality": String(personality_id),
		"purity": genetic_purity, "stability": genetic_stability, "lineage": lineage.duplicate(true),
		"sequenced": sequenced, "extracted_at": extracted_at, "born_at": born_at,
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
	# Genetics (absent in v1 saves): deterministic defaults from the uid so reloads are stable.
	var rng := GeneticsLogic.rng_for(GeneticsLogic.hash_seed(c.uid))
	if d.has("active_genes"):
		for g in d.active_genes:
			if DataRegistry.get_gene(StringName(g)):
				c.active_genes.append(StringName(g))
		for g in d.get("recessive_genes", []):
			if DataRegistry.get_gene(StringName(g)):
				c.recessive_genes.append(StringName(g))
	else:
		var genes := GeneticsLogic.initial_genes(species, rng)
		c.active_genes = genes.active
		c.recessive_genes = genes.recessive
	var mut := StringName(d.get("mutation", ""))
	c.mutation_id = mut if DataRegistry.get_mutation(mut) else &""
	var pers := StringName(d.get("personality", ""))
	c.personality_id = pers if DataRegistry.get_personality(pers) else GeneticsLogic.pick_personality(rng.randi())
	c.genetic_purity = clampf(float(d.get("purity", 100.0)), 1.0, 100.0)
	c.genetic_stability = clampf(float(d.get("stability", 100.0)), 1.0, 100.0)
	var lin = d.get("lineage", {})
	c.lineage = lin if lin is Dictionary and not lin.is_empty() else {"parents": [], "generation": 0, "origin": "incubated"}
	c.sequenced = bool(d.get("sequenced", false))
	c.extracted_at = float(d.get("extracted_at", 0.0))
	c.born_at = float(d.get("born_at", c.production_start))
	return c
