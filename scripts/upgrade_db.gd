class_name UpgradeDB
extends RefCounted

## Persistent deck/run upgrades. Gold-priced by default; chip-priced economy
## pieces use currency "chips" so the desk can mix both wallets.

const UPGRADES: Array = [
	{"id": "packed", "name": "Packed Briefcase", "icon": "PAIR", "price": 12,
		"desc": "Your next deals clump more pairs and trips."},
	{"id": "favorite_2", "name": "Favorite: Twos", "icon": "2s", "price": 16,
		"desc": "Steer extra 2s (bombs) into your hand."},
	{"id": "favorite_1", "name": "Favorite: Aces", "icon": "As", "price": 14,
		"desc": "Steer extra Aces into your hand."},
	{"id": "favorite_13", "name": "Favorite: Kings", "icon": "Ks", "price": 12,
		"desc": "Steer extra Kings into your hand."},
	{"id": "pockets", "name": "Deep Pockets", "icon": "HP", "price": 14,
		"desc": "+10 max HP and heal 10 now."},
	{"id": "incumbent", "name": "Incumbent", "icon": "↑", "price": 10,
		"desc": "After each deal, promote your lowest card one rank (climbs past bombs into uncapped super ranks)."},
	{"id": "whip", "name": "Whip Count", "icon": "?", "price": 8,
		"desc": "Once per round, see whether an AI can follow the trick."},
	{"id": "lobbyist", "name": "Lobbyist", "icon": "-$", "price": 18,
		"desc": "Desk gold prices −2 (stacks)."},
	{"id": "populist", "name": "Populist Wave", "icon": "HP+", "price": 11,
		"desc": "If you were Asshole last round, heal 8 at the next deal."},
	{"id": "oval", "name": "Oval Office", "icon": "OO", "price": 15,
		"desc": "As President, incoming tribute is +1 card."},
	{"id": "majority", "name": "Majority Whip", "icon": "MW", "price": 10,
		"desc": "Whip Count is available every look, not once."},
	{"id": "safe_seat", "name": "Safe Seat", "icon": "5", "price": 16,
		"desc": "Your HP cannot fall below 5 while you still have any."},
	# --- Economy / synergy (gold) ---
	{"id": "payroll", "name": "Payroll", "icon": "$$", "price": 10, "max": 3,
		"desc": "+2 gold on every place payout (stacks). Snowballs with ante gold."},
	{"id": "interest", "name": "Compound Interest", "icon": "%", "price": 14, "max": 3,
		"desc": "When the desk opens, gain 10% of your gold (+5% per extra stack)."},
	{"id": "chip_magnet", "name": "Chip Magnet", "icon": "◈+", "price": 12, "max": 3,
		"desc": "+1 Survivor Chip whenever an AI is knocked out (stacks with the base chip)."},
	{"id": "gold_rush", "name": "Gold Rush", "icon": "×$", "price": 16, "max": 2,
		"desc": "Gold from rank customizations is multiplied by (1 + stacks)."},
	# --- Economy / synergy (chips) ---
	{"id": "war_chest", "name": "War Chest", "icon": "◈", "price": 3, "currency": "chips", "max": 5,
		"desc": "Gain 1 Survivor Chip at the start of each round (stacks)."},
	{"id": "syndicate", "name": "Syndicate", "icon": "◈$", "price": 4, "currency": "chips", "max": 3,
		"desc": "At payout, gain 1 chip per $5 gold you earned that round (stacks add another per $5)."},
	{"id": "patronage", "name": "Patronage", "icon": "-◈", "price": 5, "currency": "chips", "max": 3,
		"desc": "Rank customization chip prices −1 (stacks, min 1)."},
	{"id": "echo", "name": "Echo Chamber", "icon": "◈$", "price": 4, "currency": "chips", "max": 3,
		"desc": "When a customized rank pays gold, also gain 1 chip per stack."},
]

static func get_by_id(id: String) -> Dictionary:
	for u in UPGRADES:
		if str(u["id"]) == id:
			return u
	var m: Dictionary = RankModDB.get_by_id(id)
	if not m.is_empty():
		return m
	var fx: Dictionary = RankEffectDB.get_by_id(id)
	if not fx.is_empty():
		return fx
	var combo: Dictionary = ComboBuffDB.get_by_id(id)
	if not combo.is_empty():
		return combo
	return {}

static func currency_of(item: Dictionary) -> String:
	return str(item.get("currency", "gold"))

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
