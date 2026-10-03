extends Node
## Player wallet (credits, DNA) and player level. Energy is a capacity derived from buildings
## and lives in ParkState.

signal resources_changed
signal player_leveled(new_level: int)

const START_CREDITS := 3000
const START_DNA := 150

var credits := START_CREDITS
var dna := START_DNA
var player_level := 1
var player_xp := 0


func reset() -> void:
	credits = START_CREDITS
	dna = START_DNA
	player_level = 1
	player_xp = 0
	resources_changed.emit()


func can_afford(credit_cost: int, dna_cost := 0) -> bool:
	return credits >= credit_cost and dna >= dna_cost


func spend(credit_cost: int, dna_cost := 0) -> bool:
	if not can_afford(credit_cost, dna_cost):
		return false
	credits -= credit_cost
	dna -= dna_cost
	resources_changed.emit()
	return true


func add(credit_amount: int, dna_amount := 0) -> void:
	credits += maxi(credit_amount, 0)
	dna += maxi(dna_amount, 0)
	resources_changed.emit()


func xp_to_next_level() -> int:
	return 100 * player_level


func add_player_xp(amount: int) -> void:
	if amount <= 0:
		return
	player_xp += amount
	while player_xp >= xp_to_next_level():
		player_xp -= xp_to_next_level()
		player_level += 1
		player_leveled.emit(player_level)
		EventBus.toast("Nível do parque %d!" % player_level, "star", "good")
	resources_changed.emit()


func to_dict() -> Dictionary:
	return {"credits": credits, "dna": dna, "player_level": player_level, "player_xp": player_xp}


func from_dict(d: Dictionary) -> void:
	credits = int(d.get("credits", START_CREDITS))
	dna = int(d.get("dna", START_DNA))
	player_level = int(d.get("player_level", 1))
	player_xp = int(d.get("player_xp", 0))
	resources_changed.emit()
