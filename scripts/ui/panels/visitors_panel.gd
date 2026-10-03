extends GamePanel
## Entrance: visitors, ticket income and the park's reputation style (the dominant style gives a
## permanent bonus: science, nature, hybridisation, exotic or arena).

const INTEREST_NAMES := {
	&"prehistoric": "pré-históricas", &"alien": "alienígenas", &"hybrid": "híbridos", &"giant": "gigantes",
	&"rare": "raridades", &"aquatic": "aquáticas", &"small": "pequenas", &"prototype": "protótipos",
	&"cosmic": "cósmicas", &"glacial": "glaciais",
}

var building: BuildingInstance
var _content: VBoxContainer


func configure() -> void:
	title = "Entrada e Reputação"
	icon_name = "visitors"
	desired_size = Vector2(1000, 620)


func build() -> void:
	_content = UIKit.vbox(10)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	VisitorManager.visitors_changed.connect(func():
		if is_inside_tree():
			refresh())
	refresh()


func refresh() -> void:
	UIKit.clear(_content)
	var top := UIKit.hbox(14)
	top.add_child(UIKit.icon_value("visitors", "%d visitantes no parque" % VisitorManager.visitors, "HeaderLabel", 32))
	top.add_child(UIKit.spacer())
	var pending := int(VisitorManager.pending_tickets)
	var b := UIKit.button("Coletar ingressos  %d" % pending, "credits", "ButtonAmber", Vector2(300, 60))
	b.disabled = pending <= 0
	b.pressed.connect(func():
		var got := VisitorManager.collect_tickets()
		if got > 0:
			hud.fly_rewards(b.global_position + b.size * 0.5, "credits", 6)
			AudioManager.play_sfx(&"coin"))
	top.add_child(b)
	_content.add_child(top)
	_content.add_child(UIKit.wrap_label("Visitantes vêm pelas criaturas em exibição (raridade, felicidade e interesses de cada público) e pagam ingressos que se acumulam na entrada.", "SmallLabel", 600))
	var cols := columns(380)
	_content.add_child(cols[0])
	var left: VBoxContainer = cols[1]
	left.add_child(UIKit.label("Públicos", "HeaderLabel"))
	for vt in DataRegistry.visitors.values():
		var card := UIKit.panel("Card")
		var h := UIKit.hbox(10)
		var at := AtlasTexture.new()
		at.atlas = vt.sprite
		at.region = Rect2(0, 0, 16, 24)
		h.add_child(UIKit.texture(at, Vector2(32, 48)))
		var v := UIKit.vbox(0)
		v.add_child(UIKit.label(vt.display_name, "ValueLabel"))
		var ints: Array = vt.interests.map(func(i): return INTEREST_NAMES.get(i, String(i)))
		v.add_child(UIKit.wrap_label("Gosta de: " + ", ".join(ints), "SmallLabel", 280))
		h.add_child(v)
		card.add_child(h)
		left.add_child(card)
	var right: VBoxContainer = cols[2]
	right.add_child(UIKit.label("Reputação do parque", "HeaderLabel"))
	var dom := VisitorManager.dominant_style()
	right.add_child(UIKit.wrap_label(("Estilo dominante: %s — %s" % [dom.display_name, dom.description]) if dom else "Nenhum estilo dominante ainda (é preciso 20 pontos em uma área).", "BodyLabel", 400))
	var best := 1.0
	for st in DataRegistry.reputation.values():
		best = maxf(best, VisitorManager.score(st.metric))
	for st in DataRegistry.reputation.values():
		var score := VisitorManager.score(st.metric)
		var row := UIKit.vbox(2)
		var head := UIKit.hbox(8)
		head.add_child(UIKit.icon(st.icon_name, 24))
		head.add_child(UIKit.label(st.display_name, "ValueLabel", UITheme.GOLD if dom == st else null))
		head.add_child(UIKit.spacer())
		head.add_child(UIKit.label("%d" % int(score), "ValueLabel"))
		row.add_child(head)
		var bar := UIKit.progress("BarTime" if dom == st else "BarXP", 10, score, maxf(best, 20.0))
		row.add_child(bar)
		var bonus_lines: Array = []
		for line in load("res://scripts/ui/panels/research_panel.gd").effect_lines(st.bonus):
			bonus_lines.append(line)
		if st.bonus.has("battle_credits"):
			bonus_lines.append("+%d%% de créditos em batalhas" % int(float(st.bonus.battle_credits) * 100))
		row.add_child(UIKit.label("Bônus: " + "; ".join(bonus_lines), "SmallLabel"))
		right.add_child(row)
