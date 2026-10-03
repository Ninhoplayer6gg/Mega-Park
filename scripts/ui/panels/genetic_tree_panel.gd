extends GamePanel
## Genetic tree: the creature at the bottom and its ancestry above it (parents, grandparents),
## generation by generation, with connector lines. Scrolls vertically on small screens.

const MAX_DEPTH := 3
const ORIGINS := {
	"incubated": "Incubada a partir do banco de DNA", "hybrid": "Síntese híbrida",
	"prototype": "Protótipo de síntese instável", "restored_pure": "Restauração pura",
	"restored_assisted": "Reconstrução assistida", "boss_reward": "Recompensa de chefe",
}

var creature: CreatureInstance
var _tree: TreeView


func configure() -> void:
	title = "Árvore Genética"
	icon_name = "tree"
	desired_size = Vector2(1080, 660)


func build() -> void:
	var head := UIKit.hbox(10)
	head.add_child(UIKit.label(creature.display_name(), "HeaderLabel"))
	head.add_child(UIKit.tag("GERAÇÃO %d" % creature.generation(), UITheme.CYAN))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.label(ORIGINS.get(creature.origin(), creature.origin().capitalize()), "SmallLabel"))
	body.add_child(head)
	var sc := UIKit.scroll()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tree = TreeView.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_tree)
	body.add_child(sc)
	_build_levels()


## Each level is a row; level 0 = this creature (drawn at the bottom).
func _build_levels() -> void:
	var levels: Array = [[{"creature": creature, "child": -1}]]
	for depth in MAX_DEPTH:
		var next: Array = []
		var current: Array = levels[depth]
		for i in current.size():
			var node: Dictionary = current[i]
			var c: CreatureInstance = node.get("creature")
			if c == null:
				continue
			for p in c.lineage.get("parents", []):
				var pc := CreatureRoster.get_creature(str(p.get("uid", "")))
				next.append({"creature": pc, "species": StringName(p.get("species", "")), "name": str(p.get("name", "")), "child": i})
			if c.lineage.has("evolved_from"):
				next.append({"creature": null, "species": StringName(c.lineage.evolved_from), "name": "", "child": i, "evolution": true})
		if next.is_empty():
			break
		levels.append(next)
	levels.reverse()
	var rows := UIKit.vbox(36)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.add_child(rows)
	var cards := []
	for li in levels.size():
		var row := UIKit.hbox(14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var gen_cards := []
		for node in levels[li]:
			var card := _card(node, li == levels.size() - 1)
			row.add_child(card)
			gen_cards.append(card)
		rows.add_child(row)
		cards.append(gen_cards)
	if levels.size() == 1:
		var note := UIKit.wrap_label("Sem ancestrais registrados: esta criatura foi gerada a partir de DNA do banco genético, sem doadores individuais.", "BodyLabel", 400)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(note)
	# connectors: each card links to its child in the row below
	for li in range(levels.size() - 1):
		for ni in levels[li].size():
			var child_index: int = levels[li][ni].child
			_tree.links.append([cards[li][ni], cards[li + 1][child_index], levels[li][ni].get("evolution", false)])
	_tree.queue_redraw.call_deferred()


func _card(node: Dictionary, is_root: bool) -> Control:
	var c: CreatureInstance = node.get("creature")
	var species: CreatureData = c.data if c else DataRegistry.get_creature(node.get("species", &""))
	var p := UIKit.panel("CardSelected" if is_root else "Card")
	p.custom_minimum_size = Vector2(210, 0)
	var v := UIKit.vbox(2)
	if c:
		v.add_child(CreaturePortrait.of_creature(c, Vector2(180, 90), is_root))
		var n := UIKit.label(c.display_name(), "ValueLabel")
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(n)
		v.add_child(UIKit.label("Nv %d · Pureza %d%%" % [c.level, int(round(c.genetic_purity))], "SmallLabel"))
		var genes := UIKit.hbox(2)
		for gid in c.active_genes:
			var g := DataRegistry.get_gene(gid)
			if g:
				var ic := UIKit.icon(g.icon_name, 22)
				ic.tooltip_text = g.display_name
				ic.mouse_filter = Control.MOUSE_FILTER_PASS
				genes.add_child(ic)
		if c.mutation_id != &"":
			genes.add_child(UIKit.icon("mutation", 22))
		v.add_child(genes)
		if not is_root:
			var open := UIKit.button("Ver", "info", "ButtonDark", Vector2(0, 40))
			open.pressed.connect(func(): hud.open_creature(c, true))
			v.add_child(open)
	elif species:
		v.add_child(CreaturePortrait.make(species, Vector2(180, 90), false, false))
		v.add_child(UIKit.label(species.display_name, "ValueLabel"))
		var why := "Forma anterior (evolução)" if node.get("evolution", false) else "Amostra do banco de DNA"
		if node.get("name", "") != "" and not node.get("evolution", false):
			why = "Doador não está mais no parque"
		v.add_child(UIKit.label(why, "SmallLabel"))
	p.add_child(v)
	return p


## Draws connector lines between cards (parent -> child) behind the content.
class TreeView extends MarginContainer:
	var links: Array = []

	func _ready() -> void:
		sort_children.connect(func(): queue_redraw.call_deferred())
		resized.connect(queue_redraw)

	func _draw() -> void:
		var inv := get_global_transform().affine_inverse()
		for l in links:
			var a: Control = l[0]
			var b: Control = l[1]
			if not is_instance_valid(a) or not is_instance_valid(b):
				continue
			var from: Vector2 = inv * (a.get_global_transform() * Vector2(a.size.x * 0.5, a.size.y))
			var to: Vector2 = inv * (b.get_global_transform() * Vector2(b.size.x * 0.5, 0.0))
			var mid := (from.y + to.y) * 0.5
			var col := Color("b38cff") if l[2] else UITheme.CYAN
			for w in [7.0, 3.0]:
				var cc := UITheme.OUTLINE if w > 4.0 else col
				draw_line(from, Vector2(from.x, mid), cc, w)
				draw_line(Vector2(from.x, mid), Vector2(to.x, mid), cc, w)
				draw_line(Vector2(to.x, mid), to, cc, w)
