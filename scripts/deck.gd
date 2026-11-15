class_name Deck
extends RefCounted

## Standard 52-card deck plus a weighted deal for shop upgrades.

static func build_standard() -> Array:
	var cards: Array = []
	for suit in range(4):
		for rank in range(1, 14):
			cards.append(CardData.new(rank, suit, true))
	return cards

static func shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp

## Deal to living seats. Leftovers become the kitty.
## packed / favorite_rank / extra_cards only bias seat 0 (the human).
static func deal_president(living: Array, rng: RandomNumberGenerator, packed: int = 0, favorite_rank: int = 0, extra_cards: int = 0) -> Dictionary:
	var cards: Array = build_standard()
	shuffle(cards, rng)
	var n: int = living.size()
	var hands: Dictionary = {}
	for seat in living:
		hands[int(seat)] = []
	var per: int = cards.size() / n
	var idx: int = 0
	for seat3 in living:
		for _k in range(per):
			(hands[int(seat3)] as Array).append(cards[idx])
			idx += 1
	var kitty: Array = []
	while idx < cards.size():
		kitty.append(cards[idx])
		idx += 1
	_apply_packed(hands, 0, packed, rng)
	if favorite_rank >= 1 and favorite_rank <= 13:
		_apply_favorite(hands, 0, favorite_rank, rng)
	for _e in range(extra_cards):
		if kitty.is_empty():
			break
		(hands[0] as Array).append(kitty.pop_back())
	for seat4 in hands.keys():
		_sort_hand(hands[seat4])
	return {"hands": hands, "kitty": kitty}

static func _apply_packed(hands: Dictionary, seat: int, packed: int, rng: RandomNumberGenerator) -> void:
	if packed <= 0 or not hands.has(seat):
		return
	var mine: Array = hands[seat]
	for _p in range(packed):
		if mine.is_empty():
			return
		var pick: CardData = mine[rng.randi_range(0, mine.size() - 1)]
		for other in hands.keys():
			if int(other) == seat:
				continue
			var oh: Array = hands[other]
			var found: int = -1
			for j in range(oh.size()):
				if (oh[j] as CardData).rank == pick.rank:
					found = j
					break
			if found < 0:
				continue
			var stolen: CardData = oh[found]
			oh.remove_at(found)
			var swap_i: int = rng.randi_range(0, mine.size() - 1)
			oh.append(mine[swap_i])
			mine.remove_at(swap_i)
			mine.append(stolen)
			break

static func _apply_favorite(hands: Dictionary, seat: int, rank: int, rng: RandomNumberGenerator) -> void:
	var mine: Array = hands[seat]
	var stolen: int = 0
	for other in hands.keys():
		if stolen >= 2:
			break
		if int(other) == seat:
			continue
		var oh: Array = hands[other]
		for j in range(oh.size() - 1, -1, -1):
			if stolen >= 2:
				break
			if (oh[j] as CardData).rank != rank:
				continue
			var card: CardData = oh[j]
			oh.remove_at(j)
			var give_i: int = rng.randi_range(0, maxi(0, mine.size() - 1))
			oh.append(mine[give_i])
			mine.remove_at(give_i)
			mine.append(card)
			stolen += 1

static func _sort_hand(hand: Array) -> void:
	hand.sort_custom(func(a: CardData, b: CardData) -> bool:
		var pa: int = RankSystem.president_power(a.rank)
		var pb: int = RankSystem.president_power(b.rank)
		if pa == pb:
			return a.suit < b.suit
		return pa < pb
	)
