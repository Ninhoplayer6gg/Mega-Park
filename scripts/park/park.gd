extends Node2D
## Park scene controller: renders ParkState, routes taps (build mode, coin bubbles, creatures,
## buildings) and connects the world to the HUD. Holds no game state of its own.

@onready var map: ParkMap = $ParkMap
@onready var objects: Node2D = $Objects
@onready var effects: Node2D = $Effects
@onready var camera: ParkCamera = $Camera
@onready var build_controller: BuildController = $BuildController
@onready var build_overlay: BuildOverlay = $BuildOverlay
@onready var hud: Hud = $UI/Hud

var building_nodes := {}      # uid -> BuildingNode
var decor_nodes := {}         # Vector2i -> Sprite2D
var selected_actor: CreatureActor


func _ready() -> void:
	var layout := ParkState.layout
	map.build(layout)
	build_overlay.map_size = Vector2i(layout.width, layout.height)
	_spawn_decor()
	_sync_buildings()
	ParkState.buildings_changed.connect(_sync_buildings)
	CreatureRoster.roster_changed.connect(_sync_creatures)
	GameClock.tick.connect(_on_tick)
	EventBus.creature_leveled.connect(_on_creature_leveled)
	EventBus.credits_collected.connect(_on_credits_collected)
	camera.setup(layout.pixel_size(), 2.0)
	camera.tapped.connect(_on_tap)
	camera.hovered.connect(_on_hover)
	camera.cancel_requested.connect(func(): build_controller.stop())
	build_controller.setup(self, build_overlay)
	hud.setup(self)
	var entrance := ParkState.of_category(&"landmark")
	camera.position = entrance[0].center_world() + Vector2(0, -200) if not entrance.is_empty() else layout.pixel_size() * 0.5
	camera.position = camera._clamped(camera.position)
	var params := SceneRouter.take_params()
	if params.has("focus_creature"):
		focus_creature(params.focus_creature)
	AudioManager.play_music(&"park")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and build_controller.is_active():
		build_controller.stop()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ world building
func _spawn_decor() -> void:
	for cell in ParkState.layout.decor:
		var ch: String = ParkState.layout.decor[cell]
		var tex: Texture2D = load(MapLayout.DECOR[ch].texture)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
		var jitter := Vector2((ParkMap._hash(cell) % 7) - 3, 0)
		s.position = ParkGrid.footprint_anchor(cell, Vector2i.ONE) + jitter - Vector2(0, 2)
		objects.add_child(s)
		decor_nodes[cell] = s


func _sync_buildings() -> void:
	var existing := {}
	for b in ParkState.buildings.values():
		existing[b.uid] = true
		if not building_nodes.has(b.uid):
			var node := BuildingFactory.create(b.data, b)
			objects.add_child(node)
			building_nodes[b.uid] = node
	for uid in building_nodes.keys():
		if not existing.has(uid):
			building_nodes[uid].queue_free()
			building_nodes.erase(uid)
	for node in building_nodes.values():
		node.refresh_connections()
	for cell in decor_nodes:
		decor_nodes[cell].visible = ParkState.get_at_cell(cell) == null


func _sync_creatures() -> void:
	for node in building_nodes.values():
		if node is HabitatNode:
			node.sync_creatures()


func _on_tick() -> void:
	for node in building_nodes.values():
		node.tick()


func get_building_node(uid: String) -> BuildingNode:
	return building_nodes.get(uid)


func find_actor(creature_uid: String) -> CreatureActor:
	for node in building_nodes.values():
		if node is HabitatNode and node.actors.has(creature_uid):
			return node.actors[creature_uid]
	return null


# ------------------------------------------------------------------ input routing
func _on_hover(world_pos: Vector2) -> void:
	if build_controller.is_active() and not build_controller.data.connects:
		build_controller.move_to_world(world_pos)


func _on_tap(world_pos: Vector2) -> void:
	if hud.has_modal():
		return
	if build_controller.is_active():
		build_controller.handle_tap(world_pos)
		return
	# 1. Coin bubbles
	for node in building_nodes.values():
		if node is HabitatNode and node.bubble_rect().has_point(world_pos):
			collect_habitat(node)
			return
	# 2. Creatures (front-most first)
	var best: CreatureActor = null
	for node in building_nodes.values():
		if node is HabitatNode:
			for actor in node.actors.values():
				if actor.pick_rect().has_point(world_pos) and (best == null or actor.global_position.y > best.global_position.y):
					best = actor
	if best:
		select_creature(best)
		return
	# 3. Buildings
	var hit: BuildingNode = null
	for node in building_nodes.values():
		if node.data.ground_layer:
			continue
		if node.pick_rect().has_point(world_pos) and (hit == null or node.position.y > hit.position.y):
			hit = node
	if hit:
		_select_building(hit)
		return
	clear_selection()


func select_creature(actor: CreatureActor) -> void:
	clear_selection()
	selected_actor = actor
	actor.set_selected(true)
	hud.open_creature(actor.creature)


func clear_selection() -> void:
	if is_instance_valid(selected_actor):
		selected_actor.set_selected(false)
	selected_actor = null


func _select_building(node: BuildingNode) -> void:
	clear_selection()
	node.set_selected(true)
	AudioManager.play_sfx(&"ui_open")
	hud.open_building(node.instance)


func collect_habitat(node: HabitatNode) -> int:
	var amount := CreatureRoster.collect_habitat(node.instance.uid, node.position + node.bubble.position)
	node.tick()
	return amount


func _on_credits_collected(amount: int, world_pos: Vector2) -> void:
	Fx.float_text(effects, world_pos + Vector2(0, -40), "+%d" % amount, UITheme.GOLD, 16, 36, 1.2, "credits")
	Fx.sparkles(effects, world_pos + Vector2(0, -30), 5, 20)
	hud.fly_rewards(camera.get_canvas_transform() * (world_pos + Vector2(0, -30)), "credits", mini(8, 2 + amount / 25))


func _on_creature_leveled(c: CreatureInstance, _level: int) -> void:
	var actor := find_actor(c.uid)
	if actor:
		actor.celebrate()


# ------------------------------------------------------------------ helpers for HUD/panels
func start_build(data: BuildingData) -> void:
	clear_selection()
	build_controller.start(data)


func focus_building(uid: String, zoom_level := -1.0) -> void:
	var b := ParkState.get_building(uid)
	if b:
		camera.focus_on(b.center_world(), zoom_level)


func focus_creature(uid: String) -> void:
	var c := CreatureRoster.get_creature(uid)
	if c and c.state == &"habitat":
		focus_building(c.habitat_uid, 2.5)
