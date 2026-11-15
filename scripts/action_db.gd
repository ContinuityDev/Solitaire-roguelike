class_name ActionDB
extends RefCounted

## One-shot action cards. `when`: turn (during a round), results (between
## rounds, before tribute), react (auto-cancels a hostile effect on you).

const ACTIONS: Array = [
	{"id": "veto", "name": "Veto", "icon": "X", "price": 10, "when": "turn",
		"desc": "Skip the next living opponent."},
	{"id": "filibuster", "name": "Filibuster", "icon": "ZZ", "price": 12, "when": "turn",
		"desc": "The next opponent must pass this trick."},
	{"id": "exec", "name": "Executive Order", "icon": "EO", "price": 16, "when": "turn",
		"desc": "Your next combo may be any rank of the required count."},
	{"id": "leak", "name": "Leak", "icon": "EYE", "price": 8, "when": "turn",
		"desc": "Peek one AI's hand until you play."},
	{"id": "tax", "name": "Tax", "icon": "$", "price": 14, "when": "turn",
		"desc": "Steal a random card from the current last-place opponent."},
	{"id": "rally", "name": "Rally", "icon": "↑↑", "price": 11, "when": "turn",
		"desc": "Promote your two lowest cards one rank each (Ace max; 2s stay)."},
	{"id": "forge", "name": "Forge Bomb", "icon": "2", "price": 10, "when": "turn",
		"desc": "Replace your lowest non-2 with a 2 of the same suit."},
	{"id": "uprising", "name": "Uprising", "icon": "UP", "price": 15, "when": "results",
		"desc": "Swap President ↔ Asshole before the next tribute."},
	{"id": "just_say_no", "name": "Just Say No", "icon": "NO", "price": 13, "when": "react",
		"desc": "Cancel one incoming tribute or one hostile action aimed at you."},
	{"id": "impeach", "name": "Impeach", "icon": "IM", "price": 12, "when": "results",
		"desc": "Swap President ↔ Vice-President for the next tribute."},
	{"id": "pardon", "name": "Pardon", "icon": "PD", "price": 14, "when": "results",
		"desc": "Skip your outgoing tribute this deal."},
	{"id": "coup", "name": "Coup", "icon": "CP", "price": 18, "when": "results",
		"desc": "Swap your role with the President before tribute."},
	{"id": "recess", "name": "Recess", "icon": "RC", "price": 16, "when": "results",
		"desc": "Cancel every tribute this deal."},
]

const HOSTILE: Array = ["tax", "filibuster", "veto", "uprising", "impeach", "coup"]

static func get_by_id(id: String) -> Dictionary:
	for a in ACTIONS:
		if str(a["id"]) == id:
			return a
	return {}

static func is_hostile(id: String) -> bool:
	return HOSTILE.has(id)

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
