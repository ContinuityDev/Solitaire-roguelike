class_name RankEffectDB
extends RefCounted

## Chip-bought rank customizations. Bind to a deal-face (`base_rank`).
## Survivor Chips are scarce — prices are high; no effect grants chips.

const EFFECTS: Array = [
	# --- Gold on play (every classic rank) ---
	{"id": "fx_gold_3", "name": "Mint Threes", "icon": "3$", "price": 4,
		"desc": "Dealt 3s: +1 gold when played (levels).",
		"rank": 3, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_4", "name": "Mint Fours", "icon": "4$", "price": 4,
		"desc": "Dealt 4s: +1 gold when played.",
		"rank": 4, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_5", "name": "Mint Fives", "icon": "5$", "price": 5,
		"desc": "Dealt 5s: +1 gold when played.",
		"rank": 5, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_6", "name": "Mint Sixes", "icon": "6$", "price": 5,
		"desc": "Dealt 6s: +1 gold when played.",
		"rank": 6, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_7", "name": "Mint Sevens", "icon": "7$", "price": 5,
		"desc": "Dealt 7s: +1 gold when played.",
		"rank": 7, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_8", "name": "Mint Eights", "icon": "8$", "price": 5,
		"desc": "Dealt 8s: +1 gold when played.",
		"rank": 8, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_9", "name": "Mint Nines", "icon": "9$", "price": 5,
		"desc": "Dealt 9s: +1 gold when played.",
		"rank": 9, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_10", "name": "Mint Tens", "icon": "10$", "price": 5,
		"desc": "Dealt 10s: +1 gold when played.",
		"rank": 10, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_11", "name": "Mint Jacks", "icon": "J$", "price": 6,
		"desc": "Dealt Jacks: +1 gold when played.",
		"rank": 11, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_12", "name": "Mint Queens", "icon": "Q$", "price": 6,
		"desc": "Dealt Queens: +1 gold when played.",
		"rank": 12, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_13", "name": "Mint Kings", "icon": "K$", "price": 6,
		"desc": "Dealt Kings: +1 gold when played.",
		"rank": 13, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_1", "name": "Mint Aces", "icon": "A$", "price": 7,
		"desc": "Dealt Aces: +1 gold when played.",
		"rank": 1, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	{"id": "fx_gold_2", "name": "Mint Bombs", "icon": "2$", "price": 8,
		"desc": "Dealt 2s: +1 gold when played.",
		"rank": 2, "effect": "gold", "kind": "rank_fx", "currency": "chips", "max": 5, "section": "rank"},
	# --- Follow power ---
	{"id": "fx_power_3", "name": "Armed Threes", "icon": "3+", "price": 5,
		"desc": "Dealt 3s: +1 follow power per level.",
		"rank": 3, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_4", "name": "Armed Fours", "icon": "4+", "price": 5,
		"desc": "Dealt 4s: +1 follow power per level.",
		"rank": 4, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_5", "name": "Armed Fives", "icon": "5+", "price": 5,
		"desc": "Dealt 5s: +1 follow power per level (can equal a 6).",
		"rank": 5, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_6", "name": "Armed Sixes", "icon": "6+", "price": 5,
		"desc": "Dealt 6s: +1 follow power per level.",
		"rank": 6, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_7", "name": "Armed Sevens", "icon": "7+", "price": 5,
		"desc": "Dealt 7s: +1 follow power per level.",
		"rank": 7, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_8", "name": "Armed Eights", "icon": "8+", "price": 5,
		"desc": "Dealt 8s: +1 follow power per level.",
		"rank": 8, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_9", "name": "Armed Nines", "icon": "9+", "price": 5,
		"desc": "Dealt 9s: +1 follow power per level.",
		"rank": 9, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_10", "name": "Armed Tens", "icon": "10+", "price": 6,
		"desc": "Dealt 10s: +1 follow power per level.",
		"rank": 10, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_11", "name": "Armed Jacks", "icon": "J+", "price": 6,
		"desc": "Dealt Jacks: +1 follow power per level.",
		"rank": 11, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_12", "name": "Armed Queens", "icon": "Q+", "price": 6,
		"desc": "Dealt Queens: +1 follow power per level.",
		"rank": 12, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_13", "name": "Armed Kings", "icon": "K+", "price": 7,
		"desc": "Dealt Kings: +1 follow power per level.",
		"rank": 13, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_1", "name": "Armed Aces", "icon": "A+", "price": 8,
		"desc": "Dealt Aces: +1 follow power per level.",
		"rank": 1, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_power_2", "name": "Armed Bombs", "icon": "2+", "price": 9,
		"desc": "Dealt 2s: +1 follow power per level.",
		"rank": 2, "effect": "power", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	# --- Damage / heal / legal / coach ---
	{"id": "fx_damage_3", "name": "Whip Threes", "icon": "3⚔", "price": 6,
		"desc": "Playing dealt 3s: +1 HP to weakest living AI.",
		"rank": 3, "effect": "damage", "kind": "rank_fx", "currency": "chips", "max": 3, "section": "rank"},
	{"id": "fx_damage_4", "name": "Whip Fours", "icon": "4⚔", "price": 6,
		"desc": "Playing dealt 4s: +1 HP to weakest living AI.",
		"rank": 4, "effect": "damage", "kind": "rank_fx", "currency": "chips", "max": 3, "section": "rank"},
	{"id": "fx_damage_7", "name": "Whip Sevens", "icon": "7⚔", "price": 7,
		"desc": "Playing dealt 7s: +1 HP to weakest living AI.",
		"rank": 7, "effect": "damage", "kind": "rank_fx", "currency": "chips", "max": 3, "section": "rank"},
	{"id": "fx_damage_8", "name": "Whip Eights", "icon": "8⚔", "price": 7,
		"desc": "Playing dealt 8s: +1 HP to weakest living AI.",
		"rank": 8, "effect": "damage", "kind": "rank_fx", "currency": "chips", "max": 3, "section": "rank"},
	{"id": "fx_damage_13", "name": "Whip Kings", "icon": "K⚔", "price": 8,
		"desc": "Playing dealt Kings: +1 HP to weakest living AI.",
		"rank": 13, "effect": "damage", "kind": "rank_fx", "currency": "chips", "max": 3, "section": "rank"},
	{"id": "fx_damage_2", "name": "Whip Bombs", "icon": "2⚔", "price": 10,
		"desc": "Playing dealt 2s: +1 HP to weakest living AI.",
		"rank": 2, "effect": "damage", "kind": "rank_fx", "currency": "chips", "max": 3, "section": "rank"},
	{"id": "fx_heal_5", "name": "Nurse Fives", "icon": "5♥", "price": 5,
		"desc": "Playing dealt 5s: heal +1 HP.",
		"rank": 5, "effect": "heal", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_heal_6", "name": "Nurse Sixes", "icon": "6♥", "price": 5,
		"desc": "Playing dealt 6s: heal +1 HP.",
		"rank": 6, "effect": "heal", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_heal_9", "name": "Nurse Nines", "icon": "9♥", "price": 5,
		"desc": "Playing dealt 9s: heal +1 HP.",
		"rank": 9, "effect": "heal", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_heal_12", "name": "Nurse Queens", "icon": "Q♥", "price": 6,
		"desc": "Playing dealt Queens: heal +1 HP.",
		"rank": 12, "effect": "heal", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_heal_1", "name": "Nurse Aces", "icon": "A♥", "price": 7,
		"desc": "Playing dealt Aces: heal +1 HP.",
		"rank": 1, "effect": "heal", "kind": "rank_fx", "currency": "chips", "max": 4, "section": "rank"},
	{"id": "fx_legal_5", "name": "Five Pass", "icon": "5*", "price": 7,
		"desc": "Dealt 5s are always a legal follow of the matching count.",
		"rank": 5, "effect": "always_legal", "kind": "rank_fx", "currency": "chips", "max": 1, "section": "rank"},
	{"id": "fx_legal_10", "name": "Ten Pass", "icon": "10*", "price": 7,
		"desc": "Dealt 10s are always a legal follow of the matching count.",
		"rank": 10, "effect": "always_legal", "kind": "rank_fx", "currency": "chips", "max": 1, "section": "rank"},
	{"id": "fx_legal_1", "name": "Ace Pass", "icon": "A*", "price": 9,
		"desc": "Dealt Aces are always a legal follow of the matching count.",
		"rank": 1, "effect": "always_legal", "kind": "rank_fx", "currency": "chips", "max": 1, "section": "rank"},
	{"id": "fx_legal_2", "name": "Bomb Pass", "icon": "2*", "price": 11,
		"desc": "Dealt 2s are always a legal follow of the matching count.",
		"rank": 2, "effect": "always_legal", "kind": "rank_fx", "currency": "chips", "max": 1, "section": "rank"},
	{"id": "fx_buff_3", "name": "Coach Threes", "icon": "3↑", "price": 6,
		"desc": "Playing dealt 3s promotes your lowest other card one rank.",
		"rank": 3, "effect": "buff_hand", "kind": "rank_fx", "currency": "chips", "max": 3, "section": "rank"},
	{"id": "fx_buff_6", "name": "Coach Sixes", "icon": "6↑", "price": 6,
		"desc": "Playing dealt 6s promotes your lowest other card one rank.",
		"rank": 6, "effect": "buff_hand", "kind": "rank_fx", "currency": "chips", "max": 3, "section": "rank"},
	{"id": "fx_buff_9", "name": "Coach Nines", "icon": "9↑", "price": 6,
		"desc": "Playing dealt 9s promotes your lowest other card one rank.",
		"rank": 9, "effect": "buff_hand", "kind": "rank_fx", "currency": "chips", "max": 3, "section": "rank"},
	{"id": "fx_buff_11", "name": "Coach Jacks", "icon": "J↑", "price": 7,
		"desc": "Playing dealt Jacks promotes your lowest other card one rank.",
		"rank": 11, "effect": "buff_hand", "kind": "rank_fx", "currency": "chips", "max": 3, "section": "rank"},
	{"id": "fx_buff_13", "name": "Coach Kings", "icon": "K↑", "price": 8,
		"desc": "Playing dealt Kings promotes your lowest other card one rank.",
		"rank": 13, "effect": "buff_hand", "kind": "rank_fx", "currency": "chips", "max": 3, "section": "rank"},
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

static func rank_label(rank: int) -> String:
	return RankSystem.short_label(rank)
