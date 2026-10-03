class_name GameEnums
extends RefCounted
## Static lookup tables shared by every system (rarities, categories, labels).

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC, ANOMALOUS }

const RARITY_NAMES := ["Comum", "Incomum", "Rara", "Épica", "Lendária", "Mítica", "Anômala"]
const RARITY_COLORS := [
	Color("c9d3dd"), Color("7ee08f"), Color("4aa8ff"), Color("b38cff"),
	Color("ffb43f"), Color("ff6ad5"), Color("5ef6ff"),
]

## Creature categories. The order defines the filter order in the bestiary.
const CATEGORIES := {
	&"prehistoric": "Pré-histórica",
	&"alien": "Alienígena",
	&"mythic": "Mítica",
	&"aquatic": "Aquática",
	&"mechanical": "Mecânica",
	&"anomalous": "Anômala",
}

const ROLES := {
	&"predator": "Predador",
	&"tank": "Tanque",
	&"striker": "Caçador Veloz",
	&"support": "Suporte",
}

const STAT_LABELS := {
	&"health": "Vida", &"attack": "Ataque", &"defense": "Defesa", &"speed": "Velocidade",
	&"next_attack": "Próximo ataque",
}


static func rarity_name(r: int) -> String:
	return RARITY_NAMES[clampi(r, 0, RARITY_NAMES.size() - 1)]


static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, RARITY_COLORS.size() - 1)]


static func category_name(c: StringName) -> String:
	return CATEGORIES.get(c, String(c).capitalize())


static func role_name(r: StringName) -> String:
	return ROLES.get(r, String(r).capitalize())


static func format_time(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%dm %02ds" % [s / 60, s % 60]
	return "%ds" % s


static func format_number(n: int) -> String:
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out
