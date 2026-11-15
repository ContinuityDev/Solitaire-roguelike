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

func setup(p_max_rank: int, rng: RandomNumberGenerator, extra_columns: int, p_redeals: int, enhancements: Dictionary = {}) -> void:
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
		return {"ok": true, "flipped": flipped, "to_foundation": true, "card": card, "count": 1}
	elif dest_type == "tableau":
		var di: int = int(dest.get("index", -1))
		if di < 0 or di >= tableau.size():
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
		return {"ok": true, "flipped": flipped2, "to_foundation": false, "card": bottom, "count": moving.size()}
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
			if src.get("type") == "tableau" and int(src.get("index", -1)) == di:
				continue
			# Moving a whole pile into an empty column is not progress.
			if (tableau[di] as Array).is_empty() and src.get("type") == "tableau" and int(src.get("start", 0)) == 0:
				continue
			if can_place_on_tableau(card, tableau[di]):
				return true
	return false
