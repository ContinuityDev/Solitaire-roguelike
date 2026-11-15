class_name ActionDB
extends RefCounted

## One-shot action cards spent on your turn.

const ACTIONS: Array = [
	{"id": "veto", "name": "Veto", "icon": "X", "price": 8,
		"desc": "Skip the next living opponent."},
	{"id": "filibuster", "name": "Filibuster", "icon": "ZZ", "price": 10,
		"desc": "The next opponent must pass this trick."},
	{"id": "exec", "name": "Executive Order", "icon": "EO", "price": 14,
		"desc": "Your next combo may be any rank of the required count."},
	{"id": "leak", "name": "Leak", "icon": "EYE", "price": 6,
		"desc": "Peek one AI's hand until you play."},
	{"id": "tax", "name": "Tax", "icon": "$", "price": 12,
		"desc": "Steal a random card from the current last-place AI."},
	{"id": "rally", "name": "Rally", "icon": "+2", "price": 9,
		"desc": "Draw 2 from the kitty (or two Threes if it is empty)."},
]

static func get_by_id(id: String) -> Dictionary:
	for a in ACTIONS:
		if str(a["id"]) == id:
			return a
	return {}

static func shop_offers(rng: RandomNumberGenerator, count: int = 3) -> Array:
	var pool: Array = ACTIONS.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array = []
	for a in pool:
		out.append(a)
		if out.size() >= count:
			break
	return out
