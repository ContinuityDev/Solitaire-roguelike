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
	{"id": "lobbyist", "name": "Lobbyist", "icon": "-$", "price": 15,
		"desc": "Desk prices −2 gold (stacks)."},
	{"id": "populist", "name": "Populist Wave", "icon": "HP+", "price": 9,
		"desc": "If you were Asshole last round, heal 8 at the next deal."},
	{"id": "oval", "name": "Oval Office", "icon": "OO", "price": 13,
		"desc": "As President, incoming tribute is +1 card."},
	{"id": "majority", "name": "Majority Whip", "icon": "MW", "price": 8,
		"desc": "Whip Count is available every look, not once."},
	{"id": "safe_seat", "name": "Safe Seat", "icon": "5", "price": 14,
		"desc": "Your HP cannot fall below 5 while you still have any."},
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
