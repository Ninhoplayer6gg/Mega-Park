class_name SaveMigrations
extends RefCounted
## Upgrades old save dictionaries step by step. To change the save format:
##   1. bump SaveManager.SAVE_VERSION
##   2. add a `_v<N>_to_v<N+1>` function here and register it in STEPS
## Never delete data a migration does not understand: copy it forward.

const STEPS := {
	1: "_v1_to_v2",
}


## Returns the migrated dictionary, or an empty one when the save cannot be migrated.
static func migrate(data: Dictionary, target_version: int) -> Dictionary:
	var version := int(data.get("save_version", 0))
	if version == 0:
		# Pre-release saves had no version field; their layout matches v1.
		version = 1
		data["save_version"] = 1
	while version < target_version:
		if not STEPS.has(version):
			push_error("SaveMigrations: no migration from v%d" % version)
			return {}
		data = Callable(SaveMigrations, STEPS[version]).call(data)
		version += 1
		data["save_version"] = version
	return data


## v1 -> v2 (genetics update). Nothing is removed. Creatures get genetics fields filled in by
## CreatureInstance.from_dict (deterministic from their uid); buildings get an empty "extra";
## the Arquivo Mega is seeded from the old "discovered" list and owned creatures.
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var park: Dictionary = out.get("park", {})
	for b in park.get("buildings", []):
		if not b.has("extra"):
			b["extra"] = {}
	var cr: Dictionary = out.get("creatures", {})
	var knowledge := {}
	for sid in cr.get("discovered", []):
		knowledge[sid] = ["discovered"]
	for c in cr.get("creatures", []):
		var sid: String = c.get("species", "")
		if sid == "":
			continue
		var flags: Array = knowledge.get(sid, ["discovered"])
		for f in ["owned", "incubated"]:
			if not flags.has(f):
				flags.append(f)
		knowledge[sid] = flags
		if not c.has("purity"):
			c["purity"] = 100.0
		if not c.has("stability"):
			c["stability"] = 100.0
		if not c.has("lineage"):
			c["lineage"] = {"parents": [], "generation": 0, "origin": "incubated"}
	if not out.has("archive"):
		out["archive"] = {"knowledge": knowledge, "behaviors": {}, "mutations": {}, "photos": []}
	for key in ["genetics", "research", "staff", "events", "visitors"]:
		if not out.has(key):
			out[key] = {}
	out["migrated_from"] = 1
	return out
