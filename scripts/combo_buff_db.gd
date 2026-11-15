class_name ComboBuffDB
extends RefCounted

## Card-specific combo buffs: condition (rank / play type / lead / last card)
## plus effect (multiply follow power, gold, chips, retrigger rank buffs).
## Bought at the desk; stacks level the amount / retrigger count.

const COMBOS: Array = [
	{"id": "combo_quad_4", "name": "Quad Fours", "icon": "4⁴", "price": 14,
		"desc": "Play four 4s: that play’s follow power ×4 (stacks raise the mult).",
		"kind": "combo", "currency": "gold", "max": 2,
		"rank": 4, "count": 4, "effect": "mult_power", "amount": 4},
	{"id": "combo_quad_any", "name": "Quad Force", "icon": "4×", "price": 16,
		"desc": "Any four-of-a-kind: follow power ×2.",
		"kind": "combo", "currency": "gold", "max": 2,
		"rank": -1, "count": 4, "effect": "mult_power", "amount": 2},
	{"id": "combo_pair_5_gold", "name": "Paired Mint", "icon": "55$", "price": 10,
		"desc": "Play a pair of 5s: +3 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3,
		"rank": 5, "count": 2, "effect": "gold", "amount": 3},
	{"id": "combo_trips_3_chip", "name": "Triple Chips", "icon": "333◈", "price": 4,
		"desc": "Play three 3s: +2 Survivor Chips (per level).",
		"kind": "combo", "currency": "chips", "max": 3,
		"rank": 3, "count": 3, "effect": "chips", "amount": 2},
	{"id": "combo_single_2_gold", "name": "Lone Bomb Pay", "icon": "2$", "price": 11,
		"desc": "Play a single 2: +2 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3,
		"rank": 2, "count": 1, "effect": "gold", "amount": 2},
	{"id": "combo_last_card_gold", "name": "Exit Bonus", "icon": "OUT$", "price": 12,
		"desc": "Emptying your hand with any play: +5 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3,
		"rank": -1, "count": 0, "last_card": true, "effect": "gold", "amount": 5},
	{"id": "combo_lead_ace_gold", "name": "Opening Ace", "icon": "A↑$", "price": 9,
		"desc": "Lead with Aces: +2 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3,
		"rank": 1, "count": 0, "lead": true, "effect": "gold", "amount": 2},
	{"id": "combo_retrigger_5", "name": "Five Echo", "icon": "5↻", "price": 5,
		"desc": "Playing your 5s retriggers their rank buffs once more (stacks add retriggers).",
		"kind": "combo", "currency": "chips", "max": 3,
		"rank": 5, "count": 0, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_pair", "name": "Pair Echo", "icon": "↻↻", "price": 6,
		"desc": "Any pair retriggers that rank’s buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3,
		"rank": -1, "count": 2, "effect": "retrigger", "amount": 1},
	{"id": "combo_trips_7_gold", "name": "Lucky Sevens", "icon": "777$", "price": 10,
		"desc": "Play three 7s: +4 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3,
		"rank": 7, "count": 3, "effect": "gold", "amount": 4},
	{"id": "combo_pair_10_chip", "name": "Ten-Spot", "icon": "1010◈", "price": 4,
		"desc": "Play a pair of 10s: +1 Survivor Chip (per level).",
		"kind": "combo", "currency": "chips", "max": 4,
		"rank": 10, "count": 2, "effect": "chips", "amount": 1},
	{"id": "combo_retrigger_last", "name": "Finale Echo", "icon": "OUT↻", "price": 7,
		"desc": "Emptying your hand retriggers that rank’s buffs twice (stacks add).",
		"kind": "combo", "currency": "chips", "max": 2,
		"rank": -1, "count": 0, "last_card": true, "effect": "retrigger", "amount": 2},
	{"id": "combo_quad_2_mult", "name": "Quad Bombs", "icon": "2⁴", "price": 18,
		"desc": "Play four 2s: follow power ×3.",
		"kind": "combo", "currency": "gold", "max": 2,
		"rank": 2, "count": 4, "effect": "mult_power", "amount": 3},
	{"id": "combo_single_any_chip", "name": "Singles Tax", "icon": "1◈", "price": 5,
		"desc": "Any single (non-joker) play: +1 Survivor Chip (per level).",
		"kind": "combo", "currency": "chips", "max": 3,
		"rank": -1, "count": 1, "effect": "chips", "amount": 1},
]

static func get_by_id(id: String) -> Dictionary:
	for c in COMBOS:
		if str(c["id"]) == id:
			return c
	return {}

static func is_combo(id: String) -> bool:
	return id.begins_with("combo_")

static func matches(buff: Dictionary, base_rank: int, count: int, is_lead: bool, last_card: bool) -> bool:
	var need_rank: int = int(buff.get("rank", -1))
	if need_rank > 0 and need_rank != base_rank:
		return false
	var need_count: int = int(buff.get("count", 0))
	if need_count > 0 and need_count != count:
		return false
	if bool(buff.get("lead", false)) and not is_lead:
		return false
	if bool(buff.get("last_card", false)) and not last_card:
		return false
	return true

static func short_label(buff: Dictionary, level: int = 1) -> String:
	var r: int = int(buff.get("rank", -1))
	var face: String = "*" if r <= 0 else RankSystem.short_label(r)
	var cnt: int = int(buff.get("count", 0))
	var shape: String = ""
	if bool(buff.get("last_card", false)):
		shape = "OUT"
	elif bool(buff.get("lead", false)):
		shape = "LEAD"
	elif cnt == 1:
		shape = "1×"
	elif cnt == 2:
		shape = "2×"
	elif cnt == 3:
		shape = "3×"
	elif cnt == 4:
		shape = "4×"
	else:
		shape = "any"
	var eff: String = str(buff.get("effect", ""))
	var base_amt: int = int(buff.get("amount", 1))
	var lvl: int = maxi(1, level)
	match eff:
		"mult_power":
			return "%s%s×%d" % [face, shape, base_amt + (lvl - 1)]
		"gold":
			return "%s%s+$%d" % [face, shape, base_amt * lvl]
		"chips":
			return "%s%s+◈%d" % [face, shape, base_amt * lvl]
		"retrigger":
			return "%s%s↻%d" % [face, shape, base_amt * lvl]
		_:
			return "%s%s" % [face, shape]
