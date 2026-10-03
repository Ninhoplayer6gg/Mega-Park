extends Node
## Loads every script/scene in the project (with autoloads active) so parse/compile errors show up.
## Run: godot --headless res://tests/script_check.tscn

var _count := 0


func _ready() -> void:
	_scan("res://scripts")
	_scan("res://scenes")
	print("script_check: loaded %d files" % _count)
	get_tree().quit()


func _scan(path: String) -> void:
	for d in DirAccess.get_directories_at(path):
		_scan(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			var res := load(path.path_join(f))
			_count += 1
			if res == null:
				printerr("script_check: FAILED ", path.path_join(f))
