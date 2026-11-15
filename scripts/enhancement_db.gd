class_name EnhancementDB
extends RefCounted

## Run-level stamps bought at the desk. Applied per seat after each deal.

const ENHANCEMENTS: Array = [
	{"id": "steel", "name": "Steel Card", "icon": "ST", "price": 13,
		"desc": "One card in your hand is immune to tribute."},
	{"id": "gilded", "name": "Gilded Seal", "icon": "$", "price": 11,
		"desc": "+2 gold whenever you finish 1st or 2nd."},
	{"id": "union", "name": "Union Deal", "icon": "1", "price": 12,
		"desc": "Tributes that involve you are 1 card smaller."},
	{"id": "wax", "name": "Wax Seal", "icon": "WAX", "price": 10,
		"desc": "When you are President/VP, return 1 fewer card."},
	{"id": "lucky", "name": "Lucky Draw", "icon": "↔", "price": 9,
		"desc": "After each deal, swap your lowest card with a random kitty card."},
]

static func get_by_id(id: String) -> Dictionary:
	for e in ENHANCEMENTS:
		if str(e["id"]) == id:
			return e
	return {}

static func shop_offers(rng: RandomNumberGenerator, count: int = 3) -> Array:
	var pool: Array = ENHANCEMENTS.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array = []
	for e in pool:
		out.append(e)
		if out.size() >= count:
			break
	return out

static func apply_to_hand(hand: Array, owned: Array, rng: RandomNumberGenerator) -> void:
	var steel_n: int = 0
	for id in owned:
		if str(id) == "steel":
			steel_n += 1
	for _s in range(steel_n):
		if hand.is_empty():
			return
		var picks: Array = []
		for c in hand:
			if (c as CardData).enhancement == "":
				picks.append(c)
		if picks.is_empty():
			return
		var card: CardData = picks[rng.randi_range(0, picks.size() - 1)]
		card.enhancement = "steel"
