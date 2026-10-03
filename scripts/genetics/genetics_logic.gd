class_name GeneticsLogic
extends RefCounted
## Pure genetics rules (no nodes, no autoload state): gene sets, inheritance, mutation rolls,
## hybrid stability and outcomes. Everything takes an RNG so it is deterministic and testable.

const MAX_ACTIVE_GENES := 3
const MAX_RECESSIVE_GENES := 4
const RECESSIVE_SURFACE_CHANCE := 0.15
## Base stability by number of species in the recipe.
const TIER_STABILITY := {2: 85.0, 3: 65.0, 4: 45.0}
const PROTOTYPE_BASE_CHANCE := 0.10
const PROTOTYPE_SPECIES := &"quimerideo_instavel"


static func rng_for(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func hash_seed(text: String) -> int:
	return absi(hash(text))


## Genes for a freshly incubated creature: species defaults active + 1-2 recessive from the pool.
static func initial_genes(species: CreatureData, rng: RandomNumberGenerator) -> Dictionary:
	var active: Array[StringName] = []
	for g in species.default_genes:
		if g and active.size() < MAX_ACTIVE_GENES and not active.has(g.id):
			active.append(g.id)
	var pool: Array = species.recessive_pool.filter(func(g): return g and not active.has(g.id))
	var recessive: Array[StringName] = []
	var count := 1 + (1 if rng.randf() < 0.5 else 0)
	while recessive.size() < count and not pool.is_empty():
		var g: GeneData = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		recessive.append(g.id)
	return {"active": active, "recessive": recessive}


## Hybrid genes: recipe dominant genes become active, donor genes feed the recessive set and can
## occasionally surface as active genes.
static func inherit_genes(recipe: HybridRecipe, donors: Array, rng: RandomNumberGenerator) -> Dictionary:
	var active: Array[StringName] = []
	for g in [recipe.primary_gene, recipe.secondary_gene, recipe.elemental_gene]:
		if g and active.size() < MAX_ACTIVE_GENES and not active.has(g.id):
			active.append(g.id)
	var candidates: Array[StringName] = []
	if recipe.special_gene:
		candidates.append(recipe.special_gene.id)
	for d in donors:
		if d == null:
			continue
		for gid in d.active_genes + d.recessive_genes:
			if not active.has(gid) and not candidates.has(gid):
				candidates.append(gid)
	# Species defaults also leave traces when no individual donor was used.
	for s in recipe.required_species:
		for g in s.default_genes + s.recessive_pool:
			if g and not active.has(g.id) and not candidates.has(g.id) and rng.randf() < 0.35:
				candidates.append(g.id)
	var surfaced: StringName = &""
	if not candidates.is_empty() and rng.randf() < RECESSIVE_SURFACE_CHANCE:
		surfaced = candidates[rng.randi_range(0, candidates.size() - 1)]
		candidates.erase(surfaced)
		if active.size() >= MAX_ACTIVE_GENES:
			candidates.append(active.pop_back())
		active.append(surfaced)
	var recessive: Array[StringName] = []
	while recessive.size() < MAX_RECESSIVE_GENES and not candidates.is_empty():
		recessive.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	return {"active": active, "recessive": recessive, "surfaced": surfaced}


## Sum of a stat modifier over gene ids.
static func gene_modifier(gene_ids: Array, stat: StringName) -> float:
	var total := 0.0
	for gid in gene_ids:
		var g: GeneData = DataRegistry.get_gene(gid)
		if g:
			total += float(g.stat_modifiers.get(String(stat), g.stat_modifiers.get(stat, 0.0)))
	return total


## Picks a mutation for an incubation (or &"" for none).
static func roll_mutation(species: CreatureData, rng: RandomNumberGenerator, extra_chance := 0.0, purity := 100.0,
		chance_multiplier := 1.0) -> StringName:
	var eligible: Array = DataRegistry.mutations.values().filter(func(m): return m.can_apply_to(species))
	if eligible.is_empty():
		return &""
	var total := 0.0
	for m in eligible:
		total += m.base_chance
	# Lower purity = more genetic noise = more mutations.
	var purity_bonus := clampf((100.0 - purity) / 100.0 * 0.08, 0.0, 0.06)
	var p := clampf(total * chance_multiplier + extra_chance + purity_bonus, 0.0, 0.9)
	if rng.randf() >= p:
		return &""
	var roll := rng.randf() * total
	for m in eligible:
		roll -= m.base_chance
		if roll <= 0.0:
			return m.id
	return eligible.back().id


## Stability (0..100) of a synthesis. donors: CreatureInstance or null per required species.
static func stability_for(recipe: HybridRecipe, donors: Array, bonus_points: float, lab_level: int) -> float:
	var base: float = recipe.base_stability if recipe.base_stability > 0.0 else TIER_STABILITY.get(recipe.tier(), 40.0)
	var value := base + bonus_points
	value += maxf(0.0, lab_level - recipe.required_lab_level) * 5.0
	var purity_sum := 0.0
	var count := 0
	for d in donors:
		if d:
			purity_sum += d.genetic_purity
			value -= maxf(0.0, 60.0 - d.genetic_stability) * 0.25
			count += 1
	if count > 0:
		value += (purity_sum / count - 90.0) * 0.3
	return clampf(value, 5.0, 98.0)


## success | failure | prototype
static func roll_outcome(stability: float, tier: int, rng: RandomNumberGenerator) -> StringName:
	if rng.randf() * 100.0 < stability:
		return &"success"
	if rng.randf() < PROTOTYPE_BASE_CHANCE + tier * 0.03:
		return &"prototype"
	return &"failure"


## Small stat factor from purity: pure creatures are slightly stronger, impure ones slightly weaker
## (but they mutate more often and carry more recessive genes).
static func purity_factor(purity: float) -> float:
	return 1.0 + clampf((purity - 90.0) / 500.0, -0.03, 0.02)


static func pick_personality(seed_value: int) -> StringName:
	var keys := DataRegistry.personalities.keys()
	keys.sort()
	if keys.is_empty():
		return &""
	return keys[seed_value % keys.size()]
