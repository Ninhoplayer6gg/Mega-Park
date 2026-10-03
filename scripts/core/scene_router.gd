extends CanvasLayer
## Scene transitions with a fade, plus a parameter hand-off between scenes.

const PARK := "res://scenes/park/park.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const TITLE := "res://scenes/main/title.tscn"

var _params := {}
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.07, 0.1, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func goto(path: String, params := {}) -> void:
	if _busy:
		return
	_busy = true
	_params = params
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	await tw.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.3)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func take_params() -> Dictionary:
	var p := _params
	_params = {}
	return p
