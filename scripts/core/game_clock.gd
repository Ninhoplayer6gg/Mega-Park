extends Node
## Single source of wall-clock time for timers that must survive saves (incubation, production,
## expeditions). Also emits one shared `tick` per second so UI does not need per-node _process.

signal tick

## Debug/testing offset added to the real clock (lets tests "fast-forward" time).
var offset_seconds := 0.0
var _timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.autostart = true
	_timer.timeout.connect(func(): tick.emit())
	add_child(_timer)


func now() -> float:
	return Time.get_unix_time_from_system() + offset_seconds


func advance(seconds: float) -> void:
	offset_seconds += seconds
	tick.emit()
