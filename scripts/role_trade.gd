class_name RoleTrade
extends RefCounted

## Classic President tribute: Asshole gives highest cards to President,
## who returns cards of their choice. Same for VP / Vice-Asshole at 1 card.
## Dead seats are omitted. Two living seats: no trade. Three: Pres↔Asshole only.

const ROLE_PRES := "President"
const ROLE_VP := "Vice-President"
const ROLE_NEUTRAL := "Neutral"
const ROLE_VA := "Vice-Asshole"
const ROLE_SCUM := "Asshole"

static func role_for_place(place: int, n: int) -> String:
	if n <= 2:
		return ROLE_NEUTRAL
	if place == 1:
		return ROLE_PRES
	if place == n:
		return ROLE_SCUM
	if n >= 4 and place == 2:
		return ROLE_VP
	if n >= 4 and place == n - 1:
		return ROLE_VA
	return ROLE_NEUTRAL

static func short_role(role: String) -> String:
	match role:
		ROLE_PRES:
			return "Pres"
		ROLE_VP:
			return "VP"
		ROLE_VA:
			return "VA"
		ROLE_SCUM:
			return "Asshole"
		_:
			return "—"

static func roles_map(finish: Array) -> Dictionary:
	var out: Dictionary = {}
	var n: int = finish.size()
	for i in range(n):
		var seat: int = int(finish[i])
		var place: int = i + 1
		out[seat] = {"place": place, "role": role_for_place(place, n)}
	return out

static func role_of(finish: Array, seat: int) -> String:
	var m: Dictionary = roles_map(finish)
	if not m.has(seat):
		return ROLE_NEUTRAL
	return str(m[seat]["role"])

## Living finish order only. Each pair: giver (low role) sends `count` highest
## cards, then receiver (high role) returns `return_count` of their choice.
static func pairs_for(finish: Array) -> Array:
	var n: int = finish.size()
	var out: Array = []
	if n < 3:
		return out
	out.append(_pair(finish, n - 1, 0, 2, ROLE_SCUM, ROLE_PRES))
	if n >= 4:
		out.append(_pair(finish, n - 2, 1, 1, ROLE_VA, ROLE_VP))
	return out

static func _pair(finish: Array, gi: int, ri: int, count: int, g_role: String, r_role: String) -> Dictionary:
	return {
		"giver": int(finish[gi]),
		"receiver": int(finish[ri]),
		"count": count,
		"return_count": count,
		"giver_role": g_role,
		"receiver_role": r_role,
	}

static func swap_finish(finish: Array, a: int, b: int) -> bool:
	var ia: int = finish.find(a)
	var ib: int = finish.find(b)
	if ia < 0 or ib < 0 or ia == ib:
		return false
	var tmp: Variant = finish[ia]
	finish[ia] = finish[ib]
	finish[ib] = tmp
	return true

static func take_highest(hand: Array, count: int) -> Array:
	var ranked: Array = []
	for c in hand:
		var card: CardData = c
		if card.enhancement == "steel":
			continue
		ranked.append(card)
	ranked.sort_custom(func(a: CardData, b: CardData) -> bool:
		var pa: int = RankSystem.president_power(a.rank)
		var pb: int = RankSystem.president_power(b.rank)
		if pa == pb:
			return a.suit < b.suit
		return pa > pb
	)
	var out: Array = []
	for i in range(mini(count, ranked.size())):
		out.append(ranked[i])
	return out

## AI President/VP: dump junk. Keep bombs and intact pairs when possible.
static func ai_return_picks(hand: Array, count: int) -> Array:
	if count <= 0 or hand.is_empty():
		return []
	var copies: Dictionary = {}
	for c in hand:
		var r: int = (c as CardData).rank
		copies[r] = int(copies.get(r, 0)) + 1
	var ranked: Array = hand.duplicate()
	ranked.sort_custom(func(a: CardData, b: CardData) -> bool:
		return RankSystem.president_power(a.rank) < RankSystem.president_power(b.rank)
	)
	var picks: Array = []
	for c in ranked:
		if picks.size() >= count:
			break
		var card: CardData = c
		if card.rank == 2:
			continue
		if int(copies.get(card.rank, 0)) >= 2:
			# Prefer breaking a pair only if we have no singleton junk left.
			var has_single_junk: bool = false
			for c2 in ranked:
				var o: CardData = c2
				if picks.has(o):
					continue
				if o.rank != 2 and int(copies.get(o.rank, 0)) == 1:
					has_single_junk = true
					break
			if has_single_junk:
				continue
		picks.append(card)
	for c3 in ranked:
		if picks.size() >= count:
			break
		if not picks.has(c3):
			picks.append(c3)
	return picks

static func move_cards(hands: Dictionary, from_seat: int, to_seat: int, cards: Array) -> void:
	if not hands.has(from_seat):
		hands[from_seat] = []
	if not hands.has(to_seat):
		hands[to_seat] = []
	var src: Array = hands[from_seat]
	var dst: Array = hands[to_seat]
	for c in cards:
		src.erase(c)
		dst.append(c)
	Deck._sort_hand(src)
	Deck._sort_hand(dst)

static func labels_of(cards: Array) -> String:
	var bits: Array[String] = []
	for c in cards:
		bits.append((c as CardData).label())
	if bits.is_empty():
		return "(nothing)"
	return ", ".join(bits)

static func pair_is_blocked(pair: Dictionary, cancelled_givers: Array, skip_all: bool) -> bool:
	if skip_all:
		return true
	return cancelled_givers.has(int(pair.get("giver", -1)))

static func preview_lines(finish: Array, names: Array) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var pairs: Array = pairs_for(finish)
	if pairs.is_empty():
		lines.append("No tribute this deal (too few living seats).")
		return lines
	for p in pairs:
		var g: int = int(p["giver"])
		var r: int = int(p["receiver"])
		var n: int = int(p["count"])
		var gn: String = str(names[g]) if g >= 0 and g < names.size() else str(g)
		var rn: String = str(names[r]) if r >= 0 and r < names.size() else str(r)
		lines.append("%s (%s) gives %d highest → %s (%s)" % [gn, p["giver_role"], n, rn, p["receiver_role"]])
		lines.append("%s returns %d of their choice → %s" % [rn, int(p["return_count"]), gn])
	return lines
