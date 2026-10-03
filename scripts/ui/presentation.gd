class_name Presentation
extends Control
## Full-screen reveal for big genetic moments: new species, mutation, prototype, unstable
## synthesis, detected compatibility, restoration and artificial evolution.

signal finished

const RAYS := preload("res://assets/effects/rays.png")

var kind := "new_species"
var payload := {}
var hud: Hud
var _rays: TextureRect
var _card: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(minf(760, get_viewport_rect().size.x - 32), minf(600, get_viewport_rect().size.y - 24))
	center.add_child(stack)
	_rays = TextureRect.new()
	_rays.texture = RAYS
	_rays.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rays.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rays.custom_minimum_size = Vector2(460, 460)
	_rays.size = Vector2(460, 460)
	_rays.position = Vector2(stack.custom_minimum_size.x * 0.5 - 230, stack.custom_minimum_size.y * 0.5 - 260)
	_rays.pivot_offset = Vector2(230, 230)
	_rays.modulate = _accent()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_rays)
	_card = UIKit.vbox(8)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(_card)
	_build_content()
	var tw := _rays.create_tween().set_loops()
	tw.tween_property(_rays, "rotation", TAU, 14.0).from(0.0)
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.7, 0.7)
	_card.pivot_offset = stack.custom_minimum_size * 0.5
	var pop := create_tween().set_parallel()
	pop.tween_property(_card, "modulate:a", 1.0, 0.25)
	pop.tween_property(_card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx(&"victory" if kind in ["new_species", "restored", "evolved", "mutation"] else &"buff")


func _accent() -> Color:
	match kind:
		"mutation":
			return Color(0.75, 0.55, 1.0, 0.8)
		"prototype", "failure":
			return Color(0.5, 1.0, 0.45, 0.55)
		"detected":
			return Color(0.37, 0.96, 1.0, 0.7)
	return Color(1.0, 0.85, 0.3, 0.85)


func _banner(text: String, color := UITheme.GOLD) -> void:
	var l := UIKit.label(text, "BigLabel", color, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 600
	if get_viewport_rect().size.x < 900:
		l.add_theme_font_size_override("font_size", 34)
	_card.add_child(l)


func _line(text: String, variation := "HeaderLabel", color = null) -> void:
	var l := UIKit.label(text, variation, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 560
	_card.add_child(l)


func _portrait(p: Control) -> void:
	_card.add_child(UIKit.centered(p))


func _build_content() -> void:
	var c: CreatureInstance = payload.get("creature")
	match kind:
		"new_species", "hybrid":
			var species: CreatureData = c.data
			_banner("NOVA ESPÉCIE DESCOBERTA!" if kind == "new_species" else "HÍBRIDO CRIADO!")
			_line("%s  ·  %s" % [species.display_name.to_upper(), species.archive_code], "TitleLabel", UITheme.TEXT)
			_portrait(CreaturePortrait.of_creature(c, Vector2(380, 230)))
			var tags := UIKit.hbox(8)
			tags.alignment = BoxContainer.ALIGNMENT_CENTER
			if species.hybrid_tier > 0:
				tags.add_child(UIKit.tier_tag(species.hybrid_tier))
			tags.add_child(UIKit.rarity_badge(species.rarity))
			_card.add_child(tags)
			_line("Estabilidade %d%% · Pureza %d%%" % [int(round(c.genetic_stability)), int(round(c.genetic_purity))], "BodyLabel")
			if kind == "new_species":
				_line("Registrada automaticamente no Arquivo Mega.", "BodyLabel", UITheme.CYAN)
		"mutation":
			var m := c.mutation()
			_banner("MUTAÇÃO DESCOBERTA")
			_line((m.name_for(c.data) if m else c.display_name()).to_upper(), "TitleLabel", UITheme.TEXT)
			_portrait(CreaturePortrait.of_creature(c, Vector2(380, 230)))
			if m:
				var tg := UIKit.rarity_badge(m.rarity)
				tg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				_card.add_child(tg)
				_line(m.description, "BodyLabel")
		"prototype":
			_banner("PROTÓTIPO GERADO", Color("8dff7a"))
			_line("A síntese de %s ficou instável e originou um protótipo vivo." % _recipe_name(), "BodyLabel")
			if c:
				_line(c.display_name().to_upper(), "TitleLabel", UITheme.TEXT)
				_portrait(CreaturePortrait.of_creature(c, Vector2(320, 200)))
			_consolation()
		"failure":
			_banner("SÍNTESE INSTÁVEL", Color("8dff7a"))
			_line("A amostra de %s não se estabilizou. Nenhuma criatura foi ferida." % _recipe_name(), "BodyLabel")
			_portrait(UIKit.icon("mat_unstable", 128))
			_consolation()
			_line("Dica: pesquisas de estabilizadores, laboratórios melhores, doadores mais puros e a Dra. Helena Viana aumentam a estabilidade.", "SmallLabel")
		"detected":
			var r: HybridRecipe = payload.get("recipe")
			_banner("COMPATIBILIDADE GENÉTICA DETECTADA", UITheme.CYAN)
			_line("RESULTADO DESCONHECIDO", "TitleLabel", UITheme.TEXT)
			if r:
				_portrait(CreaturePortrait.make(r.result_species, Vector2(300, 190), true))
				var parents := []
				for s in r.required_species:
					parents.append(s.display_name)
				_line(" + ".join(parents), "HeaderLabel")
				var tg := UIKit.tier_tag(r.tier())
				tg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				_card.add_child(tg)
			_line("Uma nova receita apareceu no Laboratório Genético.", "BodyLabel")
		"restored":
			_banner("ESPÉCIE RESTAURADA!")
			_line("%s  ·  %s" % [c.data.display_name.to_upper(), c.data.archive_code], "TitleLabel", UITheme.TEXT)
			_portrait(CreaturePortrait.of_creature(c, Vector2(380, 230)))
			_line(("Restauração pura" if c.genetic_purity >= 99.5 else "Reconstrução assistida") + " · Pureza %d%%" % int(round(c.genetic_purity)), "BodyLabel")
		"evolved":
			_banner("EVOLUÇÃO ARTIFICIAL!")
			_line(c.display_name().to_upper(), "TitleLabel", UITheme.TEXT)
			_portrait(CreaturePortrait.of_creature(c, Vector2(380, 230)))
			var from := DataRegistry.get_creature(payload.get("from", &""))
			if from:
				_line("%s evoluiu para %s." % [from.display_name, c.data.display_name], "BodyLabel")
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if kind in ["new_species", "restored", "evolved"] and c:
		var arch := UIKit.button("Ver no Arquivo", "archive", "ButtonBlue", Vector2(240, 64))
		arch.pressed.connect(func():
			_close()
			if hud:
				hud.open_panel("archive", {"selected": c.species_id}))
		row.add_child(arch)
	var ok := UIKit.button("Continuar", "check", "ButtonGreen", Vector2(240, 64))
	ok.pressed.connect(_close)
	row.add_child(ok)
	_card.add_child(row)


func _recipe_name() -> String:
	var r: HybridRecipe = payload.get("recipe")
	if r == null:
		return "híbrido"
	return r.result_species.display_name if GeneticsManager.is_revealed(r) else "espécie desconhecida"


func _consolation() -> void:
	var cons: Dictionary = payload.get("consolation", {})
	if cons.is_empty():
		return
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if int(cons.get("rp", 0)) > 0:
		row.add_child(UIKit.icon_value("rp", "+%d" % int(cons.rp)))
	if int(cons.get("unstable", 0)) > 0:
		row.add_child(UIKit.icon_value("mat_unstable", "+%d" % int(cons.unstable)))
	for sid in cons.get("dna_refund", {}):
		row.add_child(UIKit.icon_value("dna", "+%d %s" % [int(cons.dna_refund[sid]), DataRegistry.get_creature(StringName(sid)).display_name]))
	_card.add_child(row)


func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		finished.emit()
		queue_free())
