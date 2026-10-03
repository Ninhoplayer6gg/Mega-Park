class_name Uid
extends RefCounted
## Short unique ids for saved runtime objects.

static var _counter := 0


static func make(prefix: String) -> String:
	_counter += 1
	return "%s_%x%04x%03x" % [prefix, int(Time.get_unix_time_from_system()) & 0xffffff, randi() & 0xffff, _counter & 0xfff]
