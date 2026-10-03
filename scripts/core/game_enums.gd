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

const CATEGORY_ICONS := {
	&"all": "cat_all",
	&"prehistoric": "cat_prehistoric",
	&"alien": "cat_alien",
	&"mythic": "cat_mythic",
	&"aquatic": "cat_aquatic",
	&"mechanical": "cat_mechanical",
	&"anomalous": "cat_anomalous",
}

const ROLES := {
	&"predator": "Predador",
	&"tank": "Tanque",
	&"striker": "Caçador Veloz",
	&"support": "Suporte",
}

const TYPES := {
	&"biological": ["Biológico", "type_biological"],
	&"cosmic": ["Cósmico", "type_cosmic"],
	&"glacial": ["Glacial", "type_glacial"],
	&"electric": ["Elétrico", "energy"],
	&"fire": ["Fogo", "type_fire"],
	&"toxic": ["Tóxico", "type_toxic"],
	&"psychic": ["Psíquico", "type_psychic"],
	&"aquatic": ["Aquático", "type_aquatic"],
}

const SIZE_CLASSES := {&"small": "Pequeno", &"medium": "Médio", &"large": "Grande", &"giant": "Gigante"}

const VARIANT_KINDS := {
	&"alpha": "Alfa", &"regional": "Variante regional", &"evolution": "Evolução artificial",
	&"prototype": "Protótipo genético",
}

const GENE_GROUPS := {&"physical": "Físico", &"elemental": "Elemental", &"special": "Especial"}

const BEHAVIORS := {
	&"idle": "Parado", &"walk": "Andando", &"rest": "Descansando", &"sleep": "Dormindo", &"eat": "Comendo",
	&"drink": "Bebendo", &"roar": "Rugindo", &"play": "Brincando", &"observe": "Observando visitantes",
	&"social": "Socializando", &"dispute": "Disputando território", &"rare": "Comportamento raro",
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


static func type_name(t: StringName) -> String:
	return TYPES.get(t, [String(t).capitalize()])[0]


static func type_icon(t: StringName) -> String:
	return TYPES.get(t, ["", "info"])[1]


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
