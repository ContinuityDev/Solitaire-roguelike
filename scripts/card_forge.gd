class_name CardForge
extends RefCounted

## In-place card transforms. Never grants extra shop items or extra cards.
## Promotion climbs the classic ladder (3…K → A → 2) then into uncapped
## super ranks (16, 17, …) so Incumbent / Rally can push numbers forever.

static func next_rank(rank: int) -> int:
	if RankSystem.is_joker(rank):
		return rank
	if RankSystem.is_super(rank):
		return rank + 1
	if rank == 2:
		return RankSystem.SUPER_MIN
	if rank == 1:
		return 2
	if rank == 13:
		return 1
	if rank >= 3 and rank <= 12:
		return rank + 1
	return rank + 1

static func promote_card(card: CardData) -> bool:
	if card == null:
		return false
	var nxt: int = next_rank(card.rank)
	if nxt == card.rank:
		return false
	card.rank = nxt
	return true

static func lowest_index(hand: Array, skip_bombs: bool = true) -> int:
	var best_i: int = -1
	var best_p: int = 1_000_000_000
	for i in range(hand.size()):
		var c: CardData = hand[i]
		if RankSystem.is_joker(c.rank):
			continue
		if skip_bombs and c.rank == 2:
			continue
		var p: int = RankSystem.president_power(c.rank)
		if p < best_p:
			best_p = p
			best_i = i
	if best_i < 0:
		for i2 in range(hand.size()):
			var p2: int = RankSystem.president_power((hand[i2] as CardData).rank)
			if p2 < best_p:
				best_p = p2
				best_i = i2
	return best_i

## Promote the n lowest cards one rank (jokers skipped). Super ranks allowed.
## Returns labels like "3→4" or "2→16".
static func promote_lowest(hand: Array, n: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var used: Dictionary = {}
	for _k in range(n):
		var best_i: int = -1
		var best_p: int = 1_000_000_000
		for i in range(hand.size()):
			if used.has(i):
				continue
			var c: CardData = hand[i]
			if RankSystem.is_joker(c.rank):
				continue
			var p: int = RankSystem.president_power(c.rank)
			if p < best_p:
				best_p = p
				best_i = i
		if best_i < 0:
			break
		var card: CardData = hand[best_i]
		var before: String = RankSystem.short_label(card.rank)
		if promote_card(card):
			used[best_i] = true
			out.append("%s→%s" % [before, RankSystem.short_label(card.rank)])
	return out

## Lowest non-2 becomes a 2 of the same suit.
static func forge_bomb(hand: Array) -> String:
	var i: int = lowest_index(hand, true)
	if i < 0:
		return ""
	var card: CardData = hand[i]
	if card.rank == 2:
		return ""
	var before: String = card.label()
	card.rank = 2
	return "%s→%s" % [before, card.label()]

## Swap the lowest hand card with a random kitty card. Sizes stay the same.
static func swap_lowest_with_kitty(hand: Array, kitty: Array, rng: RandomNumberGenerator) -> String:
	if hand.is_empty() or kitty.is_empty():
		return ""
	var i: int = lowest_index(hand, false)
	if i < 0:
		return ""
	var k: int = rng.randi_range(0, kitty.size() - 1)
	var a: CardData = hand[i]
	var b: CardData = kitty[k]
	hand[i] = b
	kitty[k] = a
	return "%s ↔ %s" % [a.label(), b.label()]
