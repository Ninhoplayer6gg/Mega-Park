class_name PhotoLogic
extends RefCounted
## Photo mode scoring and rewards. A photo is worth more when the creature is well framed (centred,
## filling a good part of the viewfinder), doing something interesting, rare, or never photographed
## before. Repeated shots of the same creature and behaviour within a few minutes are worth little.

const REPEAT_WINDOW := 300.0
const BEHAVIOR_BONUS := {
	&"walk": 1.0, &"idle": 1.0, &"rest": 1.1, &"observe": 1.2, &"eat": 1.3, &"drink": 1.3, &"sleep": 1.4,
	&"play": 1.5, &"social": 1.5, &"roar": 1.6, &"dispute": 1.7, &"rare": 2.0,
}

static var _recent := {}     # "uid:behavior" -> time


static func reset_history() -> void:
	_recent.clear()


## framing: 0..1 (1 = perfectly centred); size_ratio: creature height / viewfinder height.
static func evaluate(c: CreatureInstance, behavior: StringName, framing: float, size_ratio: float) -> Dictionary:
	var base := float(c.data.photo_value)
	var size_score := 1.0 - clampf(absf(size_ratio - 0.45) / 0.45, 0.0, 0.7)
	var frame_score := lerpf(0.4, 1.0, clampf(framing, 0.0, 1.0))
	var quality := frame_score * size_score
	var mult: float = BEHAVIOR_BONUS.get(behavior, 1.0)
	mult *= EventManager.photo_multiplier(c.uid)
	if c.mutation_id != &"":
		mult *= 1.3
	var first := not ArchiveManager.knows(c.species_id, &"photographed")
	if first:
		mult *= 2.0
	var key := "%s:%s" % [c.uid, behavior]
	var repeated := _recent.has(key) and GameClock.now() - float(_recent[key]) < REPEAT_WINDOW
	if repeated:
		mult *= 0.1
	var score := int(round(base * quality * mult * (1.0 + Bonuses.get_value(&"photo_bonus"))))
	var stars := 1
	if quality >= 0.55:
		stars = 2
	if quality >= 0.8:
		stars = 3
	return {
		"score": maxi(score, 1), "credits": maxi(score, 1), "rp": maxi(score / 12, 0 if repeated else 1),
		"stars": stars, "first": first, "repeated": repeated, "quality": quality,
	}


## Grants the rewards and records the photo in the Arquivo Mega. Returns the stored record.
static func commit(c: CreatureInstance, behavior: StringName, result: Dictionary, file := "") -> Dictionary:
	Economy.add(int(result.credits))
	var rp := ResearchManager.add_rp(float(result.rp))
	var record := {
		"species": String(c.species_id), "uid": c.uid, "behavior": String(behavior), "time": GameClock.now(),
		"file": file, "score": int(result.score), "stars": int(result.stars), "mutation": String(c.mutation_id),
	}
	_recent["%s:%s" % [c.uid, behavior]] = GameClock.now()
	ArchiveManager.add_photo(record)
	if behavior != &"walk" and behavior != &"idle":
		ArchiveManager.note_behavior(c.species_id, behavior)
	EventBus.photo_taken.emit(record)
	record["rp_gained"] = rp
	return record
