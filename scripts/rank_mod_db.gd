class_name RankModDB
extends RefCounted

## Seat-scoped rank binders. A mod on seat 0 never changes seat 1's plays.

const MODS: Array = [
	{"id": "mod_gold_5", "name": "Gold Fives", "icon": "5$", "price": 8,
		"desc": "Your 5s pay +1 gold when you play them. Other seats' 5s do not.",
		"rank": 5, "effect": "gold_play"},
	{"id": "mod_gold_3", "name": "Gold Threes", "icon": "3$", "price": 6,
		"desc": "Your 3s pay +1 gold when you play them.",
		"rank": 3, "effect": "gold_play"},
	{"id": "mod_gold_10", "name": "Gold Tens", "icon": "10$", "price": 7,
		"desc": "Your 10s pay +1 gold when you play them.",
		"rank": 10, "effect": "gold_play"},
	{"id": "mod_power_1", "name": "Ace Authority", "icon": "A+", "price": 12,
		"desc": "Your Aces have +1 follow power. Other seats' Aces are unchanged.",
		"rank": 1, "effect": "power"},
	{"id": "mod_power_13", "name": "Kingmaker", "icon": "K+", "price": 10,
		"desc": "Your Kings have +1 follow power.",
		"rank": 13, "effect": "power"},
	{"id": "mod_power_2", "name": "Heavier Bombs", "icon": "2+", "price": 14,
		"desc": "Your 2s have +1 follow power.",
		"rank": 2, "effect": "power"},
	{"id": "mod_power_5", "name": "Strong Fives", "icon": "5+", "price": 9,
		"desc": "Your 5s have +1 follow power — they can equal a 6.",
		"rank": 5, "effect": "power"},
	{"id": "mod_legal_1", "name": "Ace Privilege", "icon": "A*", "price": 11,
		"desc": "Your Aces are always a legal follow of the matching count.",
		"rank": 1, "effect": "always_legal"},
	{"id": "mod_legal_2", "name": "Bomb Privilege", "icon": "2*", "price": 13,
		"desc": "Your 2s are always a legal follow of the matching count.",
		"rank": 2, "effect": "always_legal"},
]

## Free starter specialties for AI seats (human starts with none).
const AI_SPEC: Dictionary = {
	1: {"rank": 2, "effect": "power", "label": "2s"},
	2: {"rank": 5, "effect": "gold_play", "label": "5s"},
	3: {"rank": 1, "effect": "always_legal", "label": "As"},
	4: {"rank": 13, "effect": "power", "label": "Ks"},
	5: {"rank": 3, "effect": "gold_play", "label": "3s"},
}

static func get_by_id(id: String) -> Dictionary:
	for m in MODS:
		if str(m["id"]) == id:
			return m
	return {}

static func is_mod(id: String) -> bool:
	return id.begins_with("mod_")

static func make(rank: int, effect: String) -> Dictionary:
	return {"rank": rank, "effect": effect}

static func effect_short(effect: String) -> String:
	match effect:
		"gold_play":
			return "$"
		"power":
			return "+"
		"always_legal":
			return "*"
		_:
			return "?"
