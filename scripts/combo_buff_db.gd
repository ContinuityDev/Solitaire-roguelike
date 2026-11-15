class_name ComboBuffDB
extends RefCounted

## Card-specific combo buffs: condition (rank / play type / lead / last card)
## plus effect (multiply follow power, gold, retrigger). No chip grants —
## chips only come from AI knockouts.

const COMBOS: Array = [
	# --- Quad power mults ---
	{"id": "combo_quad_3", "name": "Quad Threes", "icon": "3⁴", "price": 12,
		"desc": "Four 3s: follow power ×3.",
		"kind": "combo", "currency": "gold", "max": 2, "section": "combo",
		"rank": 3, "count": 4, "effect": "mult_power", "amount": 3},
	{"id": "combo_quad_4", "name": "Quad Fours", "icon": "4⁴", "price": 14,
		"desc": "Four 4s: follow power ×4 (stacks raise the mult).",
		"kind": "combo", "currency": "gold", "max": 2, "section": "combo",
		"rank": 4, "count": 4, "effect": "mult_power", "amount": 4},
	{"id": "combo_quad_5", "name": "Quad Fives", "icon": "5⁴", "price": 14,
		"desc": "Four 5s: follow power ×3.",
		"kind": "combo", "currency": "gold", "max": 2, "section": "combo",
		"rank": 5, "count": 4, "effect": "mult_power", "amount": 3},
	{"id": "combo_quad_7", "name": "Quad Sevens", "icon": "7⁴", "price": 15,
		"desc": "Four 7s: follow power ×3.",
		"kind": "combo", "currency": "gold", "max": 2, "section": "combo",
		"rank": 7, "count": 4, "effect": "mult_power", "amount": 3},
	{"id": "combo_quad_2", "name": "Quad Bombs", "icon": "2⁴", "price": 20,
		"desc": "Four 2s: follow power ×3.",
		"kind": "combo", "currency": "gold", "max": 2, "section": "combo",
		"rank": 2, "count": 4, "effect": "mult_power", "amount": 3},
	{"id": "combo_quad_any", "name": "Quad Force", "icon": "4×", "price": 18,
		"desc": "Any four-of-a-kind: follow power ×2.",
		"kind": "combo", "currency": "gold", "max": 2, "section": "combo",
		"rank": -1, "count": 4, "effect": "mult_power", "amount": 2},
	# --- Lead power ---
	{"id": "combo_lead_k_mult", "name": "Opening Kings", "icon": "K↑×", "price": 8,
		"desc": "Lead with Kings: follow power ×2.",
		"kind": "combo", "currency": "chips", "max": 2, "section": "combo",
		"rank": 13, "count": 0, "lead": true, "effect": "mult_power", "amount": 2},
	{"id": "combo_lead_a_mult", "name": "Opening Aces ×", "icon": "A↑×", "price": 9,
		"desc": "Lead with Aces: follow power ×2.",
		"kind": "combo", "currency": "chips", "max": 2, "section": "combo",
		"rank": 1, "count": 0, "lead": true, "effect": "mult_power", "amount": 2},
	{"id": "combo_lead_q_mult", "name": "Opening Queens", "icon": "Q↑×", "price": 7,
		"desc": "Lead with Queens: follow power ×2.",
		"kind": "combo", "currency": "chips", "max": 2, "section": "combo",
		"rank": 12, "count": 0, "lead": true, "effect": "mult_power", "amount": 2},
	# --- Pair / trips gold by rank ---
	{"id": "combo_pair_3_gold", "name": "Paired Threes", "icon": "33$", "price": 8,
		"desc": "Pair of 3s: +2 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 3, "count": 2, "effect": "gold", "amount": 2},
	{"id": "combo_pair_5_gold", "name": "Paired Mint", "icon": "55$", "price": 10,
		"desc": "Pair of 5s: +3 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 5, "count": 2, "effect": "gold", "amount": 3},
	{"id": "combo_pair_6_gold", "name": "Paired Sixes", "icon": "66$", "price": 9,
		"desc": "Pair of 6s: +2 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 6, "count": 2, "effect": "gold", "amount": 2},
	{"id": "combo_pair_7_gold", "name": "Paired Sevens", "icon": "77$", "price": 10,
		"desc": "Pair of 7s: +3 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 7, "count": 2, "effect": "gold", "amount": 3},
	{"id": "combo_pair_8_gold", "name": "Paired Eights", "icon": "88$", "price": 9,
		"desc": "Pair of 8s: +2 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 8, "count": 2, "effect": "gold", "amount": 2},
	{"id": "combo_pair_9_gold", "name": "Paired Nines", "icon": "99$", "price": 10,
		"desc": "Pair of 9s: +3 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 9, "count": 2, "effect": "gold", "amount": 3},
	{"id": "combo_pair_10_gold", "name": "Paired Tens", "icon": "1010$", "price": 10,
		"desc": "Pair of 10s: +3 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 10, "count": 2, "effect": "gold", "amount": 3},
	{"id": "combo_pair_j_gold", "name": "Paired Jacks", "icon": "JJ$", "price": 11,
		"desc": "Pair of Jacks: +3 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 11, "count": 2, "effect": "gold", "amount": 3},
	{"id": "combo_pair_q_gold", "name": "Paired Queens", "icon": "QQ$", "price": 11,
		"desc": "Pair of Queens: +3 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 12, "count": 2, "effect": "gold", "amount": 3},
	{"id": "combo_pair_k_gold", "name": "Paired Kings", "icon": "KK$", "price": 12,
		"desc": "Pair of Kings: +4 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 13, "count": 2, "effect": "gold", "amount": 4},
	{"id": "combo_pair_a_gold", "name": "Paired Aces", "icon": "AA$", "price": 13,
		"desc": "Pair of Aces: +4 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 1, "count": 2, "effect": "gold", "amount": 4},
	{"id": "combo_pair_2_gold", "name": "Paired Bombs", "icon": "22$", "price": 14,
		"desc": "Pair of 2s: +5 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 2, "count": 2, "effect": "gold", "amount": 5},
	{"id": "combo_trips_3_gold", "name": "Triple Threes", "icon": "333$", "price": 10,
		"desc": "Three 3s: +3 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 3, "count": 3, "effect": "gold", "amount": 3},
	{"id": "combo_trips_4_gold", "name": "Triple Fours", "icon": "444$", "price": 11,
		"desc": "Three 4s: +3 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 4, "count": 3, "effect": "gold", "amount": 3},
	{"id": "combo_trips_5_gold", "name": "Triple Fives", "icon": "555$", "price": 12,
		"desc": "Three 5s: +4 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 5, "count": 3, "effect": "gold", "amount": 4},
	{"id": "combo_trips_7_gold", "name": "Lucky Sevens", "icon": "777$", "price": 12,
		"desc": "Three 7s: +4 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 7, "count": 3, "effect": "gold", "amount": 4},
	{"id": "combo_trips_9_gold", "name": "Triple Nines", "icon": "999$", "price": 12,
		"desc": "Three 9s: +4 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 9, "count": 3, "effect": "gold", "amount": 4},
	{"id": "combo_trips_k_gold", "name": "Triple Kings", "icon": "KKK$", "price": 14,
		"desc": "Three Kings: +5 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 13, "count": 3, "effect": "gold", "amount": 5},
	{"id": "combo_single_2_gold", "name": "Lone Bomb Pay", "icon": "2$", "price": 11,
		"desc": "Single 2: +2 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 2, "count": 1, "effect": "gold", "amount": 2},
	{"id": "combo_single_a_gold", "name": "Lone Ace Pay", "icon": "A$", "price": 10,
		"desc": "Single Ace: +2 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 1, "count": 1, "effect": "gold", "amount": 2},
	{"id": "combo_single_4_gold", "name": "Lone Four Pay", "icon": "4$", "price": 8,
		"desc": "Single 4: +1 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 4, "count": 1, "effect": "gold", "amount": 1},
	{"id": "combo_last_card_gold", "name": "Exit Bonus", "icon": "OUT$", "price": 14,
		"desc": "Emptying your hand: +5 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": -1, "count": 0, "last_card": true, "effect": "gold", "amount": 5},
	{"id": "combo_lead_ace_gold", "name": "Opening Ace $", "icon": "A↑$", "price": 9,
		"desc": "Lead with Aces: +2 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 1, "count": 0, "lead": true, "effect": "gold", "amount": 2},
	{"id": "combo_lead_k_gold", "name": "Opening King $", "icon": "K↑$", "price": 9,
		"desc": "Lead with Kings: +2 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 13, "count": 0, "lead": true, "effect": "gold", "amount": 2},
	{"id": "combo_lead_2_gold", "name": "Opening Bomb $", "icon": "2↑$", "price": 12,
		"desc": "Lead with 2s: +3 gold (per level).",
		"kind": "combo", "currency": "gold", "max": 3, "section": "combo",
		"rank": 2, "count": 0, "lead": true, "effect": "gold", "amount": 3},
	# --- Retriggers (chip-priced; scarce) ---
	{"id": "combo_retrigger_3", "name": "Three Echo", "icon": "3↻", "price": 6,
		"desc": "Playing 3s retriggers their rank buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3, "section": "combo",
		"rank": 3, "count": 0, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_5", "name": "Five Echo", "icon": "5↻", "price": 6,
		"desc": "Playing 5s retriggers their rank buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3, "section": "combo",
		"rank": 5, "count": 0, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_7", "name": "Seven Echo", "icon": "7↻", "price": 6,
		"desc": "Playing 7s retriggers their rank buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3, "section": "combo",
		"rank": 7, "count": 0, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_9", "name": "Nine Echo", "icon": "9↻", "price": 6,
		"desc": "Playing 9s retriggers their rank buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3, "section": "combo",
		"rank": 9, "count": 0, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_10", "name": "Ten Echo", "icon": "10↻", "price": 7,
		"desc": "Playing 10s retriggers their rank buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3, "section": "combo",
		"rank": 10, "count": 0, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_j", "name": "Jack Echo", "icon": "J↻", "price": 7,
		"desc": "Playing Jacks retriggers their rank buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3, "section": "combo",
		"rank": 11, "count": 0, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_q", "name": "Queen Echo", "icon": "Q↻", "price": 7,
		"desc": "Playing Queens retriggers their rank buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3, "section": "combo",
		"rank": 12, "count": 0, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_k", "name": "King Echo", "icon": "K↻", "price": 8,
		"desc": "Playing Kings retriggers their rank buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3, "section": "combo",
		"rank": 13, "count": 0, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_a", "name": "Ace Echo", "icon": "A↻", "price": 9,
		"desc": "Playing Aces retriggers their rank buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3, "section": "combo",
		"rank": 1, "count": 0, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_2", "name": "Bomb Echo", "icon": "2↻", "price": 10,
		"desc": "Playing 2s retriggers their rank buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3, "section": "combo",
		"rank": 2, "count": 0, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_pair", "name": "Pair Echo", "icon": "↻↻", "price": 8,
		"desc": "Any pair retriggers that rank’s buffs once (stacks add).",
		"kind": "combo", "currency": "chips", "max": 3, "section": "combo",
		"rank": -1, "count": 2, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_trips", "name": "Trips Echo", "icon": "↻³", "price": 9,
		"desc": "Any three-of-a-kind retriggers that rank’s buffs once.",
		"kind": "combo", "currency": "chips", "max": 2, "section": "combo",
		"rank": -1, "count": 3, "effect": "retrigger", "amount": 1},
	{"id": "combo_retrigger_last", "name": "Finale Echo", "icon": "OUT↻", "price": 10,
		"desc": "Emptying your hand retriggers that rank’s buffs twice.",
		"kind": "combo", "currency": "chips", "max": 2, "section": "combo",
		"rank": -1, "count": 0, "last_card": true, "effect": "retrigger", "amount": 2},
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
		"retrigger":
			return "%s%s↻%d" % [face, shape, base_amt * lvl]
		_:
			return "%s%s" % [face, shape]

static func target_rank_label(buff: Dictionary) -> String:
	var r: int = int(buff.get("rank", -1))
	if r <= 0:
		return "Any"
	return RankSystem.short_label(r)
