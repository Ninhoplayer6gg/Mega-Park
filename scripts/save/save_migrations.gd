class_name SaveMigrations
extends RefCounted
## Upgrades old save dictionaries step by step. To change the save format:
##   1. bump SaveManager.SAVE_VERSION
##   2. add a `_v<N>_to_v<N+1>` function here and register it in STEPS
## Never delete data a migration does not understand: copy it forward.

const STEPS := {
	# 1: "_v1_to_v2",
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
