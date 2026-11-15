class_name PatternDB
extends RefCounted

## Solitaire-native "patterns" — this game's answer to poker hands.
## Tableau patterns are pure functions of a pile (Array of CardData);
## foundation/reveal patterns are sequence events tracked by RunManager.
## Rewards are base Applause, scaled by Flair (and pattern Props) in
## RunManager.register_pattern.

const PATTERNS: Array = [
	{"id": "natural_run", "name": "Natural Run", "base": 60, "desc": "A descending alternating run of 4+ on the tableau."},
	{"id": "rope", "name": "Silk Rope", "base": 90, "desc": "Three or more same-suit cards descending in sequence in one stack."},
	{"id": "royal_descent", "name": "Royal Descent", "base": 100, "desc": "A run of 3+ descending from a King or higher."},
	{"id": "rainbow_run", "name": "Rainbow Run", "base": 80, "desc": "A run of 4+ holding at least two red and two black cards."},
	{"id": "book", "name": "Book of Four", "base": 120, "desc": "All four suits of one rank reach the finale piles."},
	{"id": "staircase", "name": "Grand Staircase", "base": 90, "desc": "Four finale plays in a row, each one rank higher than the last."},
	{"id": "suit_surge", "name": "Suit Surge", "base": 70, "desc": "Three finale plays in a row of the same suit."},
	{"id": "mirror_pair", "name": "Mirror Pair", "base": 50, "desc": "Same rank to the finale piles in opposite colours, back to back."},
	{"id": "excavation", "name": "Excavation", "base": 80, "desc": "Reveal three face-down cards without drawing from the stock."},
	{"id": "breakout", "name": "Breakout", "base": 70, "desc": "Free a whole tableau column."},
	{"id": "housekeeping", "name": "Full House-keeping", "base": 100, "desc": "Free a column in an Act where you already completed a Book."},
]

static func get_by_id(id: String) -> Dictionary:
	for p in PATTERNS:
		if str(p["id"]) == id:
			return p
	return {}

static func display_name(id: String) -> String:
	return str(get_by_id(id).get("name", id))

static func base_reward(id: String) -> int:
	return int(get_by_id(id).get("base", 0))

## Length of the face-up run ending at the top of the pile (0 if top is
## face-down). A run is descending-by-1; colour rules depend on the caller.
static func _suffix_from(pile: Array, start: int) -> Array:
	return pile.slice(start)

static func face_up_suffix_start(pile: Array) -> int:
	var i: int = pile.size()
	while i > 0 and (pile[i - 1] as CardData).face_up:
		i -= 1
	return i

## All tableau pattern instances in one pile. Each instance carries a
## signature (the exact cards involved) so a pattern cannot be farmed by
## moving the same stack back and forth within an Act.
static func tableau_instances(pile: Array) -> Array:
	var out: Array = []
	if pile.is_empty():
		return out
	var start: int = face_up_suffix_start(pile)
	if start >= pile.size():
		return out
	var run: Array = pile.slice(start)
	# Longest descending-by-1 suffix (any colours) anchors the run checks.
	var n: int = run.size()
	if n >= 4:
		var alt: bool = true
		for i in range(start, pile.size() - 1):
			var a: CardData = pile[i]
			var b: CardData = pile[i + 1]
			if a.rank != b.rank + 1 or a.is_red() == b.is_red():
				alt = false
				break
		if alt:
			out.append({"id": "natural_run", "signature": _sig(run)})
			var reds: int = 0
			for c in run:
				if (c as CardData).is_red():
					reds += 1
			if reds >= 2 and n - reds >= 2:
				out.append({"id": "rainbow_run", "signature": _sig(run)})
	if n >= 3 and (run[0] as CardData).rank >= 13:
		var desc: bool = true
		for i in range(start, pile.size() - 1):
			if (pile[i] as CardData).rank != (pile[i + 1] as CardData).rank + 1:
				desc = false
				break
		if desc:
			out.append({"id": "royal_descent", "signature": _sig(run)})
	# Silk Rope: 3+ same-suit descending-by-1 anywhere in the face-up run.
	var rope_len: int = 1
	var rope_start: int = start
	for i in range(start + 1, pile.size()):
		var prev: CardData = pile[i - 1]
		var cur: CardData = pile[i]
		if cur.suit == prev.suit and prev.rank == cur.rank + 1:
			rope_len += 1
			if rope_len >= 3:
				out.append({"id": "rope", "signature": _sig(pile.slice(rope_start, i + 1))})
				break
		else:
			rope_len = 1
			rope_start = i
	return out

static func _sig(cards: Array) -> String:
	var parts: Array[String] = []
	for c in cards:
		parts.append((c as CardData).label())
	return ",".join(parts)

## Heuristic pattern value of a hypothetical pile, for find_best_move.
static func best_tableau_score(pile: Array) -> int:
	var best: int = 0
	for inst in tableau_instances(pile):
		best = maxi(best, base_reward(str(inst["id"])))
	return best
