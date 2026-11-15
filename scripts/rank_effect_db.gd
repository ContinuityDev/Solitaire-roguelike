class_name RankEffectDB
extends RefCounted

## Chip-bought rank customizations. Effects bind to a deal-face (`base_rank`)
## so inflation / Incumbent still fire the same slot when that card is played.

const EFFECTS: Array = [
	{"id": "fx_gold_5", "name": "Mint Fives", "icon": "5$", "price": 3,
		"desc": "Your dealt 5s pay +1 gold when played. Buy again to level up.",
		"rank": 5, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5},
	{"id": "fx_gold_3", "name": "Mint Threes", "icon": "3$", "price": 2,
		"desc": "Your dealt 3s pay +1 gold when played.",
		"rank": 3, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5},
	{"id": "fx_gold_10", "name": "Mint Tens", "icon": "10$", "price": 3,
		"desc": "Your dealt 10s pay +1 gold when played.",
		"rank": 10, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5},
	{"id": "fx_gold_1", "name": "Mint Aces", "icon": "A$", "price": 4,
		"desc": "Your dealt Aces pay +1 gold when played.",
		"rank": 1, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5},
	{"id": "fx_gold_2", "name": "Mint Bombs", "icon": "2$", "price": 5,
		"desc": "Your dealt 2s pay +1 gold when played.",
		"rank": 2, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5},
	{"id": "fx_chip_5", "name": "Chip Fives", "icon": "5◈", "price": 4,
		"desc": "Your dealt 5s pay +1 Survivor Chip when played.",
		"rank": 5, "effect": "chips", "kind": "rank_fx", "currency": "chips", "max": 4},
	{"id": "fx_chip_7", "name": "Chip Sevens", "icon": "7◈", "price": 3,
		"desc": "Your dealt 7s pay +1 Survivor Chip when played.",
		"rank": 7, "effect": "chips", "kind": "rank_fx", "currency": "chips", "max": 4},
	{"id": "fx_chip_1", "name": "Chip Aces", "icon": "A◈", "price": 5,
		"desc": "Your dealt Aces pay +1 Survivor Chip when played.",
		"rank": 1, "effect": "chips", "kind": "rank_fx", "currency": "chips", "max": 4},
	{"id": "fx_power_5", "name": "Armed Fives", "icon": "5+", "price": 3,
		"desc": "Your dealt 5s gain +1 follow power per level.",
		"rank": 5, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4},
	{"id": "fx_power_13", "name": "Armed Kings", "icon": "K+", "price": 4,
		"desc": "Your dealt Kings gain +1 follow power per level.",
		"rank": 13, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4},
	{"id": "fx_power_2", "name": "Armed Bombs", "icon": "2+", "price": 5,
		"desc": "Your dealt 2s gain +1 follow power per level.",
		"rank": 2, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4},
	{"id": "fx_damage_4", "name": "Whip Fours", "icon": "4⚔", "price": 4,
		"desc": "Playing your dealt 4s deals +1 HP to the weakest living AI.",
		"rank": 4, "effect": "damage", "kind": "rank_fx", "currency": "chips", "max": 4},
	{"id": "fx_damage_8", "name": "Whip Eights", "icon": "8⚔", "price": 4,
		"desc": "Playing your dealt 8s deals +1 HP to the weakest living AI.",
		"rank": 8, "effect": "damage", "kind": "rank_fx", "currency": "chips", "max": 4},
	{"id": "fx_damage_2", "name": "Whip Bombs", "icon": "2⚔", "price": 6,
		"desc": "Playing your dealt 2s deals +1 HP to the weakest living AI.",
		"rank": 2, "effect": "damage", "kind": "rank_fx", "currency": "chips", "max": 4},
	{"id": "fx_heal_6", "name": "Nurse Sixes", "icon": "6♥", "price": 3,
		"desc": "Playing your dealt 6s heals +1 HP (up to max).",
		"rank": 6, "effect": "heal", "kind": "rank_fx", "currency": "chips", "max": 4},
	{"id": "fx_heal_9", "name": "Nurse Nines", "icon": "9♥", "price": 3,
		"desc": "Playing your dealt 9s heals +1 HP (up to max).",
		"rank": 9, "effect": "heal", "kind": "rank_fx", "currency": "chips", "max": 4},
	{"id": "fx_legal_1", "name": "Ace Pass", "icon": "A*", "price": 5,
		"desc": "Your dealt Aces are always a legal follow of the matching count.",
		"rank": 1, "effect": "always_legal", "kind": "rank_fx", "currency": "chips", "max": 1},
	{"id": "fx_legal_2", "name": "Bomb Pass", "icon": "2*", "price": 6,
		"desc": "Your dealt 2s are always a legal follow of the matching count.",
		"rank": 2, "effect": "always_legal", "kind": "rank_fx", "currency": "chips", "max": 1},
	{"id": "fx_buff_3", "name": "Coach Threes", "icon": "3↑", "price": 4,
		"desc": "Playing your dealt 3s promotes your lowest other card one rank.",
		"rank": 3, "effect": "buff_hand", "kind": "rank_fx", "currency": "chips", "max": 3},
	{"id": "fx_buff_j", "name": "Coach Jacks", "icon": "J↑", "price": 5,
		"desc": "Playing your dealt Jacks promotes your lowest other card one rank.",
		"rank": 11, "effect": "buff_hand", "kind": "rank_fx", "currency": "chips", "max": 3},
]

static func get_by_id(id: String) -> Dictionary:
	for e in EFFECTS:
		if str(e["id"]) == id:
			return e
	return {}

static func is_rank_fx(id: String) -> bool:
	return id.begins_with("fx_")

static func make(rank: int, effect: String, level: int = 1) -> Dictionary:
	return {"rank": rank, "effect": effect, "level": level}

static func effect_short(effect: String) -> String:
	match effect:
		"gold":
			return "$"
		"chips":
			return "◈"
		"power":
			return "+"
		"damage":
			return "⚔"
		"heal":
			return "♥"
		"always_legal":
			return "*"
		"buff_hand":
			return "↑"
		_:
			return "?"

static func effect_label(effect: String, level: int) -> String:
	var n: int = maxi(1, level)
	match effect:
		"gold":
			return "+$%d" % n
		"chips":
			return "+%d◈" % n
		"power":
			return "+%d" % n
		"damage":
			return "⚔%d" % n
		"heal":
			return "♥%d" % n
		"always_legal":
			return "*"
		"buff_hand":
			return "↑×%d" % n
		_:
			return effect_short(effect)
