class_name EnhancementDB
extends RefCounted

## Data-driven per-card enhancements. A card carries at most one enhancement
## id in CardData.enhancement ("" = none). Enhancements are granted by shop
## rewards and persist for the whole run (RunManager.enhancement_assignments,
## keyed "rank:suit", applied to each round's fresh deck).
##
## Effects (all numbers live in RunManager.score_for_event / SolitaireBoard):
##   bonus  +30 chips on foundation play
##   mult   +0.5 Mult on foundation play
##   wild   counts as any colour for tableau building (moving or receiving)
##   lucky  25% chance on foundation play: +50 chips and +0.5 Mult
##   prism  +20 chips, and counts DOUBLE towards the combo chain

const ENHANCEMENTS: Array = [
	{"id": "bonus", "name": "Gilded", "code": "+C", "desc": "+30 applause when played to a finale pile."},
	{"id": "mult", "name": "Sparkle", "code": "+M", "desc": "+0.5 Flair when played to a finale pile."},
	{"id": "wild", "name": "Wild", "code": "W", "desc": "A shapeshifter: counts as any colour for tableau building."},
	{"id": "lucky", "name": "Rabbit's Foot", "code": "L", "desc": "25% chance on a finale play: +50 applause and +0.5 Flair (something came out of the hat!)."},
	{"id": "prism", "name": "Crystal", "code": "P2", "desc": "+20 applause on a finale play; counts double for the encore chain."},
]

static func get_by_id(id: String) -> Dictionary:
	for e in ENHANCEMENTS:
		if str(e["id"]) == id:
			return e
	return {}

static func is_valid(id: String) -> bool:
	return not get_by_id(id).is_empty()

static func random_id(rng: RandomNumberGenerator) -> String:
	return str(ENHANCEMENTS[rng.randi_range(0, ENHANCEMENTS.size() - 1)]["id"])

static func short_code(id: String) -> String:
	var e: Dictionary = get_by_id(id)
	return str(e.get("code", ""))

static func display_name(id: String) -> String:
	var e: Dictionary = get_by_id(id)
	return str(e.get("name", id))

static func border_color(id: String) -> Color:
	match id:
		"bonus":
			return Color(0.90, 0.65, 0.10)
		"mult":
			return Color(0.85, 0.25, 0.55)
		"wild":
			return Color(0.20, 0.75, 0.35)
		"lucky":
			return Color(0.15, 0.60, 0.25)
		"prism":
			return Color(0.20, 0.70, 0.90)
	return Color(0.25, 0.25, 0.25)
