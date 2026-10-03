extends Node
## Genetic economy and laboratory jobs:
## - species DNA bank, rare materials, fossil fragments, discovery clues
## - hybrid recipes (visible / secret / discovered) and timed syntheses with stability rolls
## - DNA extraction, gene sequencing, gene therapy, fossil restoration and induced mutations
## Failures never destroy creatures: they consume part of the inputs and return consolation rewards.

signal genetics_changed

const EXTRACT_COST := 60
const SEQUENCE_RP := 5
const THERAPY_RP := 15
const THERAPY_DNA := 30
const RESTORE_TIME := 45.0
const ASSISTED_DNA := 20
const INDUCE_COST := 400
const INDUCE_CHANCE := 0.65

var species_dna := {}      # species_id -> int
var materials := {}        # material_id -> int
var fossils := {}          # species_id -> fragments
var clues := {}            # species_id -> clues found
var recipe_state := {}     # recipe_id -> "detected" | "discovered"
var jobs := {}             # building_uid -> synthesis job
var restorations := {}     # building_uid -> restoration job
var syntheses_done := 0


func _ready() -> void:
	ResearchManager.research_completed_internal.connect(func(_id): refresh_detection())
	EventBus.boss_defeated.connect(func(_id): refresh_detection())


func reset() -> void:
	species_dna.clear()
	materials.clear()
	fossils.clear()
	clues.clear()
	recipe_state.clear()
	jobs.clear()
	restorations.clear()
	syntheses_done = 0
	genetics_changed.emit()


# ------------------------------------------------------------------ inventories
func dna_of(species_id: StringName) -> int:
	return int(species_dna.get(species_id, 0))


func add_species_dna(species_id: StringName, amount: int) -> void:
	if amount == 0 or DataRegistry.get_creature(species_id) == null:
		return
	species_dna[species_id] = maxi(dna_of(species_id) + amount, 0)
	refresh_detection()
	genetics_changed.emit()


func material(id: StringName) -> int:
	return int(materials.get(id, 0))


func add_material(id: StringName, amount: int) -> void:
	if DataRegistry.get_material(id) == null or amount == 0:
		return
	materials[id] = maxi(material(id) + amount, 0)
	genetics_changed.emit()


func has_materials(req: Dictionary) -> bool:
	for k in req:
		if material(StringName(k)) < int(req[k]):
			return false
	return true


func spend_materials(req: Dictionary) -> void:
	for k in req:
		materials[StringName(k)] = material(StringName(k)) - int(req[k])


func add_fossils(species_id: StringName, amount: int) -> void:
	fossils[species_id] = int(fossils.get(species_id, 0)) + amount
	genetics_changed.emit()


func add_clue(species_id: StringName, amount := 1) -> void:
	var species := DataRegistry.get_creature(species_id)
	if species == null or CreatureRoster.is_discovered(species_id):
		return
	clues[species_id] = int(clues.get(species_id, 0)) + amount
	ArchiveManager.note_clue(species_id)
	if int(clues[species_id]) >= species.clues_required:
		EventBus.toast("Pistas suficientes! Uma expedição de rastreamento foi liberada.", "clue_footprint", "good")
	genetics_changed.emit()


func clues_of(species_id: StringName) -> int:
	return int(clues.get(species_id, 0))


# ------------------------------------------------------------------ labs
func lab_level() -> int:
	var lvl := 0
	for b in ParkState.buildings.values():
		lvl = maxi(lvl, int(b.data.params.get("lab_level", 0)))
	return lvl


func lab_stability_bonus() -> float:
	var total := 0.0
	for b in ParkState.buildings.values():
		total += float(b.data.params.get("stability_bonus", 0.0))
	return total


# ------------------------------------------------------------------ recipes
func is_discovered(recipe: HybridRecipe) -> bool:
	return recipe_state.get(recipe.id, "") == "discovered"


## Whether the recipe card is listed at all (secret recipes need their detection conditions).
func is_visible(recipe: HybridRecipe) -> bool:
	if recipe_state.has(recipe.id):
		return true
	return _requirements_met(recipe.discovery_requirements)


## Whether the result (name/sprite/abilities) can be shown.
func is_revealed(recipe: HybridRecipe) -> bool:
	return not recipe.hidden_recipe or is_discovered(recipe)


func _requirements_met(req: Dictionary) -> bool:
	if req.is_empty():
		return true
	if req.has("research") and not ResearchManager.is_done(StringName(req.research)):
		return false
	for s in req.get("own_species", []):
		if not CreatureRoster.owns_species(StringName(s)):
			return false
	for s in req.get("dna_species", []):
		if dna_of(StringName(s)) <= 0 and not CreatureRoster.owns_species(StringName(s)):
			return false
	if req.has("boss") and not ArenaManager.wins.has(StringName(req.boss)):
		return false
	return true


## Marks newly detectable secret recipes ("COMPATIBILIDADE GENÉTICA DETECTADA").
func refresh_detection() -> void:
	for r in DataRegistry.recipes.values():
		if r.hidden_recipe and not recipe_state.has(r.id) and _requirements_met(r.discovery_requirements):
			recipe_state[r.id] = "detected"
			EventBus.recipe_detected.emit(r.id)
			EventBus.toast("Compatibilidade genética detectada!", "lab", "good")


## Forces detection of a recipe (boss reward, research...).
func detect_recipe(recipe_id: StringName) -> void:
	var r := DataRegistry.get_recipe(recipe_id)
	if r and not recipe_state.has(recipe_id):
		recipe_state[recipe_id] = "detected"
		EventBus.recipe_detected.emit(recipe_id)
		genetics_changed.emit()


func visible_recipes() -> Array:
	var arr := DataRegistry.recipes.values().filter(func(r): return is_visible(r))
	arr.sort_custom(func(a, b):
		if a.tier() != b.tier():
			return a.tier() < b.tier()
		return String(a.id) < String(b.id))
	return arr


func stability_bonus_points(recipe: HybridRecipe) -> float:
	var bonus := Bonuses.get_value(&"stability") + lab_stability_bonus()
	for s in recipe.required_species:
		if s.category == &"alien":
			bonus += Bonuses.get_value(&"alien_stability")
			break
	return bonus


func stability_for(recipe: HybridRecipe, donors: Array) -> float:
	return GeneticsLogic.stability_for(recipe, donors, stability_bonus_points(recipe), lab_level())


## Owned creatures that can donate genetic material for a species.
func donor_candidates(species: CreatureData) -> Array:
	var arr := CreatureRoster.creatures.values().filter(func(c): return c.species_id == species.id)
	arr.sort_custom(func(a, b): return a.genetic_purity * 10 + a.level > b.genetic_purity * 10 + b.level)
	return arr


func default_donors(recipe: HybridRecipe) -> Array:
	var out := []
	for s in recipe.required_species:
		var c := donor_candidates(s)
		out.append(c[0] if not c.is_empty() else null)
	return out


## "" when the synthesis can start, otherwise the reason shown to the player.
func check_recipe(recipe: HybridRecipe, donors: Array, lab_uid := "") -> String:
	if lab_level() < recipe.required_lab_level:
		return "Requer laboratório nível %d (%s)." % [recipe.required_lab_level, _lab_name(recipe.required_lab_level)]
	for rid in recipe.required_research:
		if not ResearchManager.is_done(rid):
			var r := DataRegistry.get_research(rid)
			return "Requer a pesquisa %s." % (r.display_name if r else String(rid))
	if lab_uid != "" and jobs.has(lab_uid):
		return "Este laboratório já está ocupado."
	for i in recipe.required_species.size():
		var s: CreatureData = recipe.required_species[i]
		var need: int = recipe.required_dna_amounts[i] if i < recipe.required_dna_amounts.size() else 0
		if dna_of(s.id) < need:
			return "DNA de %s insuficiente (%d/%d)." % [s.display_name, dna_of(s.id), need]
	if Economy.dna < recipe.generic_dna:
		return "DNA genérico insuficiente (%d/%d)." % [Economy.dna, recipe.generic_dna]
	if not has_materials(recipe.required_materials):
		return "Materiais insuficientes."
	if Economy.credits < recipe.credit_cost:
		return "Créditos insuficientes (%s)." % GameEnums.format_number(recipe.credit_cost)
	var stab := stability_for(recipe, donors)
	if stab < recipe.minimum_stability:
		return "Estabilidade %d%% abaixo do mínimo de %d%%." % [int(stab), int(recipe.minimum_stability)]
	return ""


func _lab_name(level: int) -> String:
	for b in DataRegistry.buildings.values():
		if int(b.params.get("lab_level", 0)) == level:
			return b.display_name
	return "laboratório"


func start_synthesis(lab_uid: String, recipe: HybridRecipe, donors: Array) -> bool:
	var reason := check_recipe(recipe, donors, lab_uid)
	if reason != "":
		EventBus.toast(reason, "lab", "bad")
		AudioManager.play_sfx(&"error")
		return false
	var stability := stability_for(recipe, donors)
	for i in recipe.required_species.size():
		var s: CreatureData = recipe.required_species[i]
		species_dna[s.id] = dna_of(s.id) - int(recipe.required_dna_amounts[i])
	Economy.spend(recipe.credit_cost, recipe.generic_dna)
	spend_materials(recipe.required_materials)
	var seed_value := randi()
	var outcome := GeneticsLogic.roll_outcome(stability, recipe.tier(), GeneticsLogic.rng_for(seed_value))
	jobs[lab_uid] = {
		"recipe": String(recipe.id), "start": GameClock.now(), "duration": recipe.creation_time,
		"outcome": String(outcome), "seed": seed_value, "stability": stability,
		"donors": donors.map(func(d): return d.uid if d else ""),
	}
	AudioManager.play_sfx(&"purchase")
	genetics_changed.emit()
	return true


func job(lab_uid: String) -> Dictionary:
	return jobs.get(lab_uid, {})


func job_progress(lab_uid: String) -> float:
	var j := job(lab_uid)
	if j.is_empty():
		return 0.0
	return clampf((GameClock.now() - j.start) / maxf(j.duration, 0.01), 0.0, 1.0)


func job_time_left(lab_uid: String) -> float:
	var j := job(lab_uid)
	return maxf(j.start + j.duration - GameClock.now(), 0.0) if not j.is_empty() else 0.0


func job_ready(lab_uid: String) -> bool:
	return jobs.has(lab_uid) and job_time_left(lab_uid) <= 0.0


## Finishes a synthesis. Returns {"outcome", "creature", "new_species", "recipe", "consolation"}.
func collect_synthesis(lab_uid: String) -> Dictionary:
	if not job_ready(lab_uid):
		return {}
	var j: Dictionary = jobs[lab_uid]
	jobs.erase(lab_uid)
	var recipe := DataRegistry.get_recipe(StringName(j.recipe))
	if recipe == null:
		genetics_changed.emit()
		return {}
	var rng := GeneticsLogic.rng_for(int(j.seed) + 17)
	var donors := []
	for duid in j.get("donors", []):
		donors.append(CreatureRoster.get_creature(duid) if duid != "" else null)
	var result := {"outcome": StringName(j.outcome), "recipe": recipe, "creature": null, "new_species": false,
		"consolation": {}, "stability": float(j.stability)}
	syntheses_done += 1
	match result.outcome:
		&"success":
			var c := _create_hybrid(recipe, donors, rng, float(j.stability))
			result.creature = c
			result.new_species = not is_discovered(recipe) or not CreatureRoster.is_discovered(recipe.result_species.id)
			recipe_state[recipe.id] = "discovered"
			CreatureRoster.discover(recipe.result_species.id)
			EventBus.hybrid_created.emit(c, recipe.id, result.new_species)
		&"prototype":
			result.creature = _create_prototype(recipe, donors, rng)
			result.consolation = _failure_rewards(recipe, rng, 0.5)
			EventBus.synthesis_failed.emit(recipe.id, result)
		_:
			result.consolation = _failure_rewards(recipe, rng, 1.0)
			EventBus.synthesis_failed.emit(recipe.id, result)
	genetics_changed.emit()
	return result


func _lineage_from(recipe: HybridRecipe, donors: Array) -> Dictionary:
	var parents := []
	var gen := 0
	for i in recipe.required_species.size():
		var s: CreatureData = recipe.required_species[i]
		var d: CreatureInstance = donors[i] if i < donors.size() else null
		parents.append({"species": String(s.id), "uid": d.uid if d else "", "name": d.display_name() if d else s.display_name})
		if d:
			gen = maxi(gen, d.generation())
	return {"parents": parents, "generation": gen + 1, "origin": "hybrid", "recipe": String(recipe.id)}


func _create_hybrid(recipe: HybridRecipe, donors: Array, rng: RandomNumberGenerator, stability: float) -> CreatureInstance:
	var c := CreatureInstance.create(recipe.result_species, rng)
	var genes := GeneticsLogic.inherit_genes(recipe, donors, rng)
	c.active_genes = genes.active
	c.recessive_genes = genes.recessive
	c.genetic_stability = clampf(stability + rng.randf_range(-6.0, 6.0), 10.0, 100.0)
	var purity_sum := 0.0
	var n := 0
	for d in donors:
		if d:
			purity_sum += d.genetic_purity
			n += 1
	c.genetic_purity = (purity_sum / n) if n > 0 else 100.0
	c.lineage = _lineage_from(recipe, donors)
	var mut := GeneticsLogic.roll_mutation(c.data, rng, Bonuses.get_value(&"mutation_chance") * 0.5, c.genetic_purity, 0.5)
	if mut != &"":
		c.mutation_id = mut
	CreatureRoster.adopt(c)
	return c


func _create_prototype(recipe: HybridRecipe, donors: Array, rng: RandomNumberGenerator) -> CreatureInstance:
	var species := DataRegistry.get_creature(GeneticsLogic.PROTOTYPE_SPECIES)
	if species == null:
		return null
	var c := CreatureInstance.create(species, rng)
	var genes := GeneticsLogic.inherit_genes(recipe, donors, rng)
	c.active_genes = genes.active.slice(0, 2)
	c.recessive_genes = genes.recessive
	c.genetic_stability = rng.randf_range(25.0, 45.0)
	c.lineage = _lineage_from(recipe, donors)
	c.lineage["origin"] = "prototype"
	CreatureRoster.discover(species.id)
	CreatureRoster.adopt(c)
	return c


func _failure_rewards(recipe: HybridRecipe, rng: RandomNumberGenerator, factor: float) -> Dictionary:
	var out := {"rp": int(round((10 + recipe.tier() * 5) * factor)), "unstable": rng.randi_range(1, 2), "dna_refund": {}}
	ResearchManager.add_rp(out.rp)
	add_material(&"mat_unstable", out.unstable)
	for i in recipe.required_species.size():
		var s: CreatureData = recipe.required_species[i]
		var back := int(recipe.required_dna_amounts[i] * 0.3 * factor)
		if back > 0:
			species_dna[s.id] = dna_of(s.id) + back
			out.dna_refund[String(s.id)] = back
	return out


# ------------------------------------------------------------------ extraction & genes
func check_extraction(c: CreatureInstance) -> String:
	if lab_level() < 1:
		return "Construa o Laboratório Genético."
	if c.extract_cooldown_left(GameClock.now()) > 0.0:
		return "Recarregando (%s)." % GameEnums.format_time(c.extract_cooldown_left(GameClock.now()))
	if not Economy.can_afford(EXTRACT_COST):
		return "Créditos insuficientes."
	return ""


func extraction_amount(c: CreatureInstance) -> int:
	return int(round((10 + c.level * 2) * (c.genetic_purity / 100.0)))


## Non-destructive DNA sampling from an owned creature.
func extract_dna(c: CreatureInstance) -> int:
	var reason := check_extraction(c)
	if reason != "":
		EventBus.toast(reason, "dna", "bad")
		return 0
	Economy.spend(EXTRACT_COST)
	var amount := extraction_amount(c)
	c.extracted_at = GameClock.now()
	add_species_dna(c.species_id, amount)
	EventBus.dna_extracted.emit(c, amount)
	AudioManager.play_sfx(&"purchase")
	return amount


func sequence(c: CreatureInstance) -> bool:
	if not ResearchManager.unlocked(&"gene_sequencing"):
		EventBus.toast("Pesquise Sequenciamento Genômico primeiro.", "research", "bad")
		return false
	if c.sequenced:
		return true
	if not ResearchManager.spend_rp(SEQUENCE_RP):
		EventBus.toast("Pontos de pesquisa insuficientes.", "rp", "bad")
		return false
	c.sequenced = true
	ArchiveManager.mark(c.species_id, &"sequenced")
	CreatureRoster.creature_changed.emit(c)
	return true


## Gene therapy: activates a recessive gene (swapping out the last active one when slots are full).
func activate_recessive(c: CreatureInstance, gene_id: StringName) -> bool:
	if not c.sequenced or not c.recessive_genes.has(gene_id):
		return false
	if ResearchManager.rp < THERAPY_RP or Economy.dna < THERAPY_DNA:
		EventBus.toast("Requer %d de pesquisa e %d de DNA." % [THERAPY_RP, THERAPY_DNA], "rp", "bad")
		return false
	ResearchManager.spend_rp(THERAPY_RP)
	Economy.spend(0, THERAPY_DNA)
	c.recessive_genes.erase(gene_id)
	if c.active_genes.size() >= GeneticsLogic.MAX_ACTIVE_GENES:
		c.recessive_genes.append(c.active_genes.pop_back())
	c.active_genes.append(gene_id)
	CreatureRoster.creature_changed.emit(c)
	AudioManager.play_sfx(&"level_up")
	return true


# ------------------------------------------------------------------ restoration
func restorable_species() -> Array:
	return DataRegistry.creatures.values().filter(func(s): return s.fossil_fragments_required > 0)


func assisted_purity(species: CreatureData) -> float:
	var frags := int(fossils.get(species.id, 0))
	var req := species.fossil_fragments_required
	return clampf(50.0 + 50.0 * float(frags) / req + Bonuses.get_value(&"purity") - 5.0, 50.0, 97.0)


func compatible_dna_species(species: CreatureData) -> StringName:
	var best: StringName = &""
	var best_amount := 0
	for sid in species_dna:
		var s := DataRegistry.get_creature(sid)
		if s and s.category == species.category and s.id != species.id and dna_of(sid) > best_amount:
			best = sid
			best_amount = dna_of(sid)
	return best


func check_restoration(species: CreatureData, mode: StringName, lab_uid: String) -> String:
	if restorations.has(lab_uid):
		return "O centro já está restaurando uma espécie."
	var frags := int(fossils.get(species.id, 0))
	var req := species.fossil_fragments_required
	if mode == &"pure":
		if frags < req:
			return "Fragmentos insuficientes (%d/%d)." % [frags, req]
	else:
		if frags < ceili(req / 2.0):
			return "Precisa de pelo menos %d fragmentos." % ceili(req / 2.0)
		if material(&"mat_amber") < 1:
			return "Requer 1 Âmbar Antigo."
		var comp := compatible_dna_species(species)
		if comp == &"" or dna_of(comp) < ASSISTED_DNA:
			return "Requer %d de DNA de uma espécie compatível (%s)." % [ASSISTED_DNA, species.category_name()]
	return ""


func start_restoration(lab_uid: String, species: CreatureData, mode: StringName) -> bool:
	var reason := check_restoration(species, mode, lab_uid)
	if reason != "":
		EventBus.toast(reason, "fossil", "bad")
		AudioManager.play_sfx(&"error")
		return false
	var purity := 100.0
	var frags := int(fossils.get(species.id, 0))
	if mode == &"pure":
		fossils[species.id] = frags - species.fossil_fragments_required
	else:
		purity = assisted_purity(species)
		fossils[species.id] = 0
		materials[&"mat_amber"] = material(&"mat_amber") - 1
		var comp := compatible_dna_species(species)
		species_dna[comp] = dna_of(comp) - ASSISTED_DNA
	restorations[lab_uid] = {"species": String(species.id), "mode": String(mode), "purity": purity,
		"start": GameClock.now(), "duration": RESTORE_TIME}
	AudioManager.play_sfx(&"purchase")
	genetics_changed.emit()
	return true


func restoration(lab_uid: String) -> Dictionary:
	return restorations.get(lab_uid, {})


func restoration_ready(lab_uid: String) -> bool:
	var r := restoration(lab_uid)
	return not r.is_empty() and GameClock.now() >= r.start + r.duration


func collect_restoration(lab_uid: String) -> CreatureInstance:
	if not restoration_ready(lab_uid):
		return null
	var r: Dictionary = restorations[lab_uid]
	restorations.erase(lab_uid)
	var species := DataRegistry.get_creature(StringName(r.species))
	if species == null:
		return null
	var c := CreatureInstance.create(species)
	c.genetic_purity = float(r.purity)
	c.lineage = {"parents": [], "generation": 0, "origin": "restored_%s" % r.mode}
	var mut := GeneticsLogic.roll_mutation(species, GeneticsLogic.rng_for(randi()), Bonuses.get_value(&"mutation_chance"), c.genetic_purity)
	if mut != &"":
		c.mutation_id = mut
	CreatureRoster.discover(species.id)
	CreatureRoster.adopt(c)
	EventBus.species_restored.emit(c)
	if c.mutation_id != &"":
		EventBus.mutation_found.emit(c)
	genetics_changed.emit()
	return c


# ------------------------------------------------------------------ induced mutation
func known_mutations() -> Array:
	return DataRegistry.mutations.values().filter(func(m): return ArchiveManager.mutation_known(m.id))


func check_induce(c: CreatureInstance, m: MutationData) -> String:
	if not ParkState.has_building(&"mutagen_center"):
		return "Construa o Centro Mutagênico."
	if c.mutation_id != &"":
		return "A criatura já possui uma mutação."
	if not m.can_apply_to(c.data):
		return "Mutação incompatível com esta espécie."
	if not ArchiveManager.mutation_known(m.id):
		return "Mutação ainda não catalogada."
	if material(&"mat_serum") < 1:
		return "Requer 1 Soro Mutagênico."
	if not Economy.can_afford(INDUCE_COST):
		return "Créditos insuficientes."
	return ""


## Returns true on success. Failure consumes the serum but never harms the creature.
func induce_mutation(c: CreatureInstance, m: MutationData) -> bool:
	var reason := check_induce(c, m)
	if reason != "":
		EventBus.toast(reason, "mutation", "bad")
		return false
	Economy.spend(INDUCE_COST)
	materials[&"mat_serum"] = material(&"mat_serum") - 1
	var ok := randf() < INDUCE_CHANCE + Bonuses.get_value(&"mutation_chance") * 2.0
	if ok:
		c.mutation_id = m.id
		CreatureRoster.creature_changed.emit(c)
		CreatureRoster.roster_changed.emit()
		EventBus.mutation_found.emit(c)
	else:
		ResearchManager.add_rp(5)
		EventBus.toast("A indução falhou, mas gerou dados de pesquisa (+5).", "mutation", "info")
	genetics_changed.emit()
	return ok


# ------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	return {
		"species_dna": _str_keys(species_dna), "materials": _str_keys(materials), "fossils": _str_keys(fossils),
		"clues": _str_keys(clues), "recipes": _str_keys(recipe_state), "jobs": jobs.duplicate(true),
		"restorations": restorations.duplicate(true), "syntheses": syntheses_done,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	for k in d.get("species_dna", {}):
		if DataRegistry.get_creature(StringName(k)):
			species_dna[StringName(k)] = int(d.species_dna[k])
	for k in d.get("materials", {}):
		if DataRegistry.get_material(StringName(k)):
			materials[StringName(k)] = int(d.materials[k])
	for k in d.get("fossils", {}):
		fossils[StringName(k)] = int(d.fossils[k])
	for k in d.get("clues", {}):
		clues[StringName(k)] = int(d.clues[k])
	for k in d.get("recipes", {}):
		if DataRegistry.get_recipe(StringName(k)):
			recipe_state[StringName(k)] = str(d.recipes[k])
	for uid in d.get("jobs", {}):
		if ParkState.get_building(uid) and DataRegistry.get_recipe(StringName(d.jobs[uid].get("recipe", ""))):
			jobs[uid] = d.jobs[uid]
	for uid in d.get("restorations", {}):
		if ParkState.get_building(uid):
			restorations[uid] = d.restorations[uid]
	syntheses_done = int(d.get("syntheses", 0))
	genetics_changed.emit()


static func _str_keys(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[String(k)] = src[k]
	return out
