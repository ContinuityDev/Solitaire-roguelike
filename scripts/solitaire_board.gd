class_name SolitaireBoard
extends RefCounted

## Pure Klondike-style board logic (no UI). Piles are Arrays of CardData;
## the top of a pile is its last element.
##
## Prototype rules (documented deviations from strict Klondike):
##  - Tableau builds descending in alternating colours, at any rank.
##  - An empty tableau column accepts ANY card/stack (not just Kings).
##    This keeps the small A-5 starter deck playable.
##  - Foundations build ascending by suit from Ace up to the deck's max rank
##    (so they run A..K, Emperor, Empress, ... without a hard cap).
##  - Stock draws 1 card; waste recycles a limited number of times.

var tableau: Array = []          # Array[Array[CardData]]
var foundations: Dictionary = {} # suit:int -> Array[CardData]
var stock: Array = []            # Array[CardData], top = last
var waste: Array = []            # Array[CardData], top = last
var max_rank: int = 5
var redeals_left: int = 1
var wild_low: bool = false
# Wall obstacles: tableau column index -> {kind, cracks, cracks_needed, name}.
# A walled column is sealed: no card moves in or out until the wall opens.
var walls: Dictionary = {}

func setup(p_max_rank: int, rng: RandomNumberGenerator, extra_columns: int, p_redeals: int, enhancements: Dictionary = {}, wall_specs: Array = [], bury_depth: int = 0) -> void:
	max_rank = p_max_rank
	redeals_left = p_redeals
	var cards: Array = Deck.build(max_rank, rng)
	# Persistent per-card enhancements (RunManager, keyed "rank:suit").
	for c in cards:
		var card0: CardData = c
		var key: String = "%d:%d" % [card0.rank, card0.suit]
		if enhancements.has(key):
			card0.enhancement = str(enhancements[key])
	var total: int = cards.size()
	# Column count grows with deck size: 20 cards -> 4, 52 -> 7, capped at 7 (+ relics).
	var cols: int = clampi(int(ceil(float(total) / 8.0)), 4, 7) + extra_columns
	cols = mini(cols, 9)
	tableau.clear()
	foundations.clear()
	for s in range(4):
		foundations[s] = []
	stock.clear()
	waste.clear()
	var idx: int = 0
	for c in range(cols):
		var pile: Array = []
		for r in range(c + 1):
			var card: CardData = cards[idx]
			idx += 1
			card.face_up = (r == c)
			pile.append(card)
		tableau.append(pile)
	while idx < cards.size():
		var card2: CardData = cards[idx]
		idx += 1
		card2.face_up = false
		stock.append(card2)
	# Walls seal whole columns. Never wall every column: at least one
	# column (and the waste/foundations) always stays playable.
	walls.clear()
	var placed: int = 0
	for spec in wall_specs:
		if placed >= maxi(0, tableau.size() - 1):
			break
		var s: Dictionary = spec
		var ci: int = int(s.get("column", -1))
		if ci < 0:
			# No explicit column: seal columns 1, 3, 5... (never column 0,
			# so the leftmost teaching column always starts playable).
			ci = (1 + placed * 2) % maxi(1, tableau.size())
			while walls.has(ci):
				ci = (ci + 1) % maxi(1, tableau.size())
		if ci < 0 or ci >= tableau.size() or walls.has(ci) or (tableau[ci] as Array).is_empty():
			continue
		var kind: String = str(s.get("kind", "brick"))
		walls[ci] = {
			"kind": kind, "cracks": 0,
			"cracks_needed": 3 if kind == "cracked" else 1,
			"name": str(s.get("name", "The Wall")),
		}
		placed += 1
	# Mid/late Acts bury extra face-down cards under the face-up top,
	# taken from the bottom of the stock so the draw pile's top is unchanged.
	var buried: int = 0
	while buried < bury_depth and not stock.is_empty():
		var bi: int = buried % tableau.size()
		buried += 1
		if is_walled(bi):
			continue
		var bp: Array = tableau[bi]
		if bp.is_empty():
			continue
		var extra: CardData = stock.pop_front()
		extra.face_up = false
		bp.insert(bp.size() - 1, extra)

func is_walled(col: int) -> bool:
	return walls.has(col)

func wall_at(col: int) -> Dictionary:
	return walls.get(col, {})

## Which tableau column a local x falls in, or -1. Shared by taps and drags
## so the column under the pointer is geometry, not container z-order.
static func column_at_x(local_x: float, card_w: float, gap: float, cols: int) -> int:
	if local_x < 0.0 or cols <= 0 or card_w <= 0.0:
		return -1
	var stride: float = card_w + gap
	var i: int = int(local_x / stride)
	if i < 0 or i >= cols:
		return -1
	if local_x - float(i) * stride > card_w + 0.5:
		return -1
	return i

## Feed a game event to every wall. Returns opened columns:
## [{column, kind, flipped}] — curtain walls flip their top card on opening.
## One pattern/court event opens at most one sealed wall; every Cracked Wall
## still counts the same foundation play.
func register_wall_event(event: String, card: CardData = null) -> Array:
	var opened: Array = []
	var sealed_one: bool = false
	var keys: Array = walls.keys()
	keys.sort()
	for ci in keys:
		var w: Dictionary = walls[ci]
		var kind: String = str(w["kind"])
		var opens: bool = false
		match kind:
			"brick", "curtain":
				opens = event == "pattern" and not sealed_one
			"iron":
				opens = event == "foundation" and card != null and card.rank >= 11 and not sealed_one
			"cracked":
				if event == "foundation":
					w["cracks"] = int(w["cracks"]) + 1
					walls[ci] = w
					opens = int(w["cracks"]) >= int(w["cracks_needed"])
		if opens:
			opened.append({"column": ci, "kind": kind, "flipped": false})
			if kind != "cracked":
				sealed_one = true
	# Open outside the iteration above (mutating walls while iterating keys
	# is fine since keys() is a copy, but keep it clean anyway).
	for o in opened:
		var col_idx: int = int(o["column"])
		var was_curtain: bool = str(walls[col_idx]["kind"]) == "curtain"
		walls.erase(col_idx)
		if was_curtain:
			var pile: Array = tableau[col_idx]
			if not pile.is_empty() and not (pile[pile.size() - 1] as CardData).face_up:
				(pile[pile.size() - 1] as CardData).face_up = true
				o["flipped"] = true
	return opened

func foundation_pile(suit: int) -> Array:
	return foundations.get(suit, [])

func foundation_count() -> int:
	var n: int = 0
	for s in foundations.keys():
		n += (foundations[s] as Array).size()
	return n

func total_cards() -> int:
	return 4 * max_rank

func is_cleared() -> bool:
	return foundation_count() >= total_cards()

func draw_stock() -> bool:
	if stock.is_empty():
		return false
	var card: CardData = stock.pop_back()
	card.face_up = true
	waste.append(card)
	return true

func recycle_waste() -> bool:
	if not stock.is_empty() or waste.is_empty() or redeals_left <= 0:
		return false
	redeals_left -= 1
	while not waste.is_empty():
		var card: CardData = waste.pop_back()
		card.face_up = false
		stock.append(card)
	return true

func can_place_on_foundation(card: CardData) -> bool:
	var pile: Array = foundation_pile(card.suit)
	if pile.is_empty():
		return card.rank == 1
	return (pile[pile.size() - 1] as CardData).rank == card.rank - 1

func can_place_on_tableau(card: CardData, pile: Array) -> bool:
	if pile.is_empty():
		return true # prototype rule: any card may fill an empty column
	var top: CardData = pile[pile.size() - 1]
	if not top.face_up:
		return false
	if top.rank != card.rank + 1:
		return false
	if wild_low and card.rank <= 2:
		return true
	# Wild enhancement counts as any colour, moving or as the receiver.
	if card.enhancement == "wild" or top.enhancement == "wild":
		return true
	return top.is_red() != card.is_red()

## Is the face-up suffix starting at `start` a movable descending alt-colour run?
func is_movable_sequence(pile: Array, start: int) -> bool:
	if start < 0 or start >= pile.size():
		return false
	if not (pile[start] as CardData).face_up:
		return false
	for i in range(start, pile.size() - 1):
		var a: CardData = pile[i]
		var b: CardData = pile[i + 1]
		if not b.face_up:
			return false
		if a.rank != b.rank + 1:
			return false
		if a.is_red() == b.is_red():
			# A wild low card (with relic) may sit on either colour.
			if wild_low and b.rank <= 2:
				continue
			# Wild-enhanced cards count as any colour inside a stack.
			if a.enhancement == "wild" or b.enhancement == "wild":
				continue
			return false
	return true

## Generic move. source/dest are Dictionaries:
##   {"type":"waste"} {"type":"tableau","index":i,"start":k} {"type":"foundation","suit":s}
## Returns {"ok":bool, "flipped":bool, "to_foundation":bool, "card":CardData, "count":int}
func try_move(source: Dictionary, dest: Dictionary) -> Dictionary:
	var fail: Dictionary = {"ok": false, "flipped": false, "to_foundation": false, "card": null, "count": 0}
	var moving: Array = _peek_source(source)
	if moving.is_empty():
		return fail
	# Walls seal their column in both directions.
	if str(source.get("type", "")) == "tableau" and is_walled(int(source.get("index", -1))):
		return fail
	var dest_type: String = str(dest.get("type", ""))
	if dest_type == "foundation":
		if moving.size() != 1:
			return fail
		var card: CardData = moving[0]
		if int(dest.get("suit", card.suit)) != card.suit:
			return fail
		if not can_place_on_foundation(card):
			return fail
		_take_source(source, 1)
		foundation_pile(card.suit).append(card)
		var flipped: bool = _flip_exposed(source)
		return {"ok": true, "flipped": flipped, "to_foundation": true, "card": card, "count": 1, "dest_type": "foundation", "dest_index": card.suit}
	elif dest_type == "tableau":
		var di: int = int(dest.get("index", -1))
		if di < 0 or di >= tableau.size() or is_walled(di):
			return fail
		if source.get("type") == "tableau" and int(source.get("index", -2)) == di:
			return fail
		var pile: Array = tableau[di]
		var bottom: CardData = moving[0]
		if not can_place_on_tableau(bottom, pile):
			return fail
		_take_source(source, moving.size())
		for c in moving:
			pile.append(c)
		var flipped2: bool = _flip_exposed(source)
		return {"ok": true, "flipped": flipped2, "to_foundation": false, "card": bottom, "count": moving.size(), "dest_type": "tableau", "dest_index": di}
	return fail

func _peek_source(source: Dictionary) -> Array:
	match str(source.get("type", "")):
		"waste":
			if waste.is_empty():
				return []
			return [waste[waste.size() - 1]]
		"foundation":
			var pile: Array = foundation_pile(int(source.get("suit", 0)))
			if pile.is_empty():
				return []
			return [pile[pile.size() - 1]]
		"tableau":
			var i: int = int(source.get("index", -1))
			if i < 0 or i >= tableau.size():
				return []
			var pile2: Array = tableau[i]
			var start: int = int(source.get("start", pile2.size() - 1))
			if not is_movable_sequence(pile2, start):
				return []
			return pile2.slice(start)
	return []

func _take_source(source: Dictionary, count: int) -> void:
	match str(source.get("type", "")):
		"waste":
			waste.pop_back()
		"foundation":
			foundation_pile(int(source.get("suit", 0))).pop_back()
		"tableau":
			var pile: Array = tableau[int(source.get("index", 0))]
			for _i in range(count):
				pile.pop_back()

func _flip_exposed(source: Dictionary) -> bool:
	if str(source.get("type", "")) != "tableau":
		return false
	var pile: Array = tableau[int(source.get("index", 0))]
	if pile.is_empty():
		return false
	var top: CardData = pile[pile.size() - 1]
	if not top.face_up:
		top.face_up = true
		return true
	return false

## Best foundation move for a source, or {} if none. Used by double-click.
func try_auto_foundation(source: Dictionary) -> Dictionary:
	var moving: Array = _peek_source(source)
	if moving.size() != 1:
		return {"ok": false}
	var card: CardData = moving[0]
	return try_move(source, {"type": "foundation", "suit": card.suit})

## The single "most likely spot" for a source, used by double-tap and Hint.
## Priority: foundation > reveals a face-down card > frees a column >
## builds a pattern run > any legal tableau move (longest stack preferred).
## Returns {"dest": Dictionary, "reason": String} or {} if no move exists.
func find_best_move(source: Dictionary) -> Dictionary:
	var moving: Array = _peek_source(source)
	if moving.is_empty():
		return {}
	var card: CardData = moving[0]
	# 1) Foundation.
	if moving.size() == 1 and can_place_on_foundation(card):
		return {"dest": {"type": "foundation", "suit": card.suit}, "reason": "foundation"}
	var src_is_tableau: bool = str(source.get("type", "")) == "tableau"
	var src_col: int = int(source.get("index", -1))
	var src_start: int = int(source.get("start", 0))
	var best: Dictionary = {}
	var best_score: int = -1
	for di in range(tableau.size()):
		if di == src_col or is_walled(di):
			continue
		var pile: Array = tableau[di]
		if not can_place_on_tableau(card, pile):
			continue
		# Moving a whole pile into an empty column changes nothing.
		if pile.is_empty() and src_is_tableau and src_start == 0:
			continue
		var score: int = 0
		var reason: String = "tableau"
		if src_is_tableau and src_start > 0 and src_col >= 0:
			var src_pile: Array = tableau[src_col]
			if src_start - 1 < src_pile.size() and not (src_pile[src_start - 1] as CardData).face_up:
				score += 400
				reason = "reveal"
		if src_is_tableau and src_start == 0 and not pile.is_empty():
			score += 300
			reason = "free_column" if score < 400 else reason
		# Pattern value of the resulting destination pile.
		var hypo: Array = pile.duplicate()
		for c in moving:
			hypo.append(c)
		var pat: int = PatternDB.best_tableau_score(hypo)
		if pat > 0:
			score += 200 + pat
			if score < 300:
				reason = "pattern"
		score += moving.size() * 2 + hypo.size()
		if score > best_score:
			best_score = score
			best = {"dest": {"type": "tableau", "index": di}, "reason": reason}
	return best

## How many distinct things the player can do right now (draw/redeal counts
## as one). Logged per Act so scaling can be checked for forced lines.
func count_candidate_moves() -> int:
	var n: int = 0
	if not stock.is_empty() or (stock.is_empty() and not waste.is_empty() and redeals_left > 0):
		n += 1
	var sources: Array = []
	if not waste.is_empty():
		sources.append({"type": "waste"})
	for i in range(tableau.size()):
		if is_walled(i):
			continue
		var pile: Array = tableau[i]
		for start in range(pile.size()):
			if (pile[start] as CardData).face_up and is_movable_sequence(pile, start):
				sources.append({"type": "tableau", "index": i, "start": start})
	for src in sources:
		if not find_best_move(src).is_empty():
			n += 1
	return n

func has_any_legal_move() -> bool:
	if not stock.is_empty():
		return true
	if stock.is_empty() and not waste.is_empty() and redeals_left > 0:
		return true
	# Collect candidate sources: waste top, each tableau face-up suffix, foundation tops (rarely useful).
	var sources: Array = []
	if not waste.is_empty():
		sources.append({"type": "waste"})
	for i in range(tableau.size()):
		if is_walled(i):
			continue
		var pile: Array = tableau[i]
		for start in range(pile.size()):
			if (pile[start] as CardData).face_up:
				sources.append({"type": "tableau", "index": i, "start": start})
	for src in sources:
		var moving: Array = _peek_source(src)
		if moving.is_empty():
			continue
		var card: CardData = moving[0]
		if moving.size() == 1 and can_place_on_foundation(card):
			return true
		for di in range(tableau.size()):
			if is_walled(di):
				continue
			if src.get("type") == "tableau" and int(src.get("index", -1)) == di:
				continue
			# Moving a whole pile into an empty column is not progress.
			if (tableau[di] as Array).is_empty() and src.get("type") == "tableau" and int(src.get("start", 0)) == 0:
				continue
			if can_place_on_tableau(card, tableau[di]):
				return true
	return false
