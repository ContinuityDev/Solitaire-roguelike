class_name UpgradeDB
extends RefCounted

## Persistent deck/run upgrades bought with gold.

const UPGRADES: Array = [
	{"id": "packed", "name": "Packed Briefcase", "icon": "PAIR", "price": 10,
		"desc": "Your next deals clump more pairs and trips."},
	{"id": "favorite_2", "name": "Favorite: Twos", "icon": "2s", "price": 14,
		"desc": "Steer extra 2s (bombs) into your hand."},
	{"id": "favorite_1", "name": "Favorite: Aces", "icon": "As", "price": 12,
		"desc": "Steer extra Aces into your hand."},
	{"id": "favorite_13", "name": "Favorite: Kings", "icon": "Ks", "price": 10,
		"desc": "Steer extra Kings into your hand."},
	{"id": "pockets", "name": "Deep Pockets", "icon": "HP", "price": 12,
		"desc": "+10 max HP and heal 10 now."},
	{"id": "incumbent", "name": "Incumbent", "icon": "+1", "price": 8,
		"desc": "Start each round with one extra card from the kitty."},
	{"id": "whip", "name": "Whip Count", "icon": "?", "price": 6,
		"desc": "Once per round, see whether an AI can follow the trick."},
]

static func get_by_id(id: String) -> Dictionary:
	for u in UPGRADES:
		if str(u["id"]) == id:
			return u
	return {}

static func shop_offers(rng: RandomNumberGenerator, count: int = 3) -> Array:
	var pool: Array = UPGRADES.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array = []
	for u in pool:
		out.append(u)
		if out.size() >= count:
			break
	return out
