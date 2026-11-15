class_name Deck
extends RefCounted

## Standard 54-card deck (52 + 2 jokers) plus a weighted deal for shop upgrades.

static func build_standard() -> Array:
	var cards: Array = []
	for suit in range(4):
		for rank in range(1, 14):
			cards.append(CardData.new(rank, suit, true))
	cards.append(CardData.new(RankSystem.JOKER, 0, true))
	cards.append(CardData.new(RankSystem.JOKER, 1, true))
	return cards

static func shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp

## Deal to living seats. Leftovers become the kitty.
## packed / favorite_rank bias a seat when asked; extra_cards is ignored
## (item-grants became in-place promotes / kitty swaps).
static func deal_president(living: Array, rng: RandomNumberGenerator, packed: int = 0, favorite_rank: int = 0, extra_cards: int = 0, packed_seat: int = 0) -> Dictionary:
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
	var _unused_e: int = extra_cards
	_apply_packed(hands, packed_seat, packed, rng)
	if favorite_rank >= 1 and favorite_rank <= 13:
		_apply_favorite(hands, packed_seat, favorite_rank, rng)
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

## Bump every non-joker card's face by `bonus` follow-power so mid/late-run
## ranks read as large numbers while keeping relative order (and N-of-a-kind).
static func inflate_hands(hands: Dictionary, bonus: int) -> void:
	if bonus <= 0:
		return
	for seat in hands.keys():
		inflate_card_list(hands[seat], bonus)

static func inflate_card_list(cards: Array, bonus: int) -> void:
	if bonus <= 0:
		return
	for c in cards:
		inflate_card(c as CardData, bonus)

static func inflate_card(card: CardData, bonus: int) -> void:
	if card == null or bonus <= 0 or RankSystem.is_joker(card.rank):
		return
	# Keep base_rank as the classic deal-face so rank customizations still match.
	if card.base_rank <= 0:
		card.base_rank = card.rank
	var nxt: int = RankSystem.inflate_rank(card.rank, bonus)
	if nxt == card.rank:
		return
	card.rank = nxt
	card.origin_rank = nxt

static func _sort_hand(hand: Array) -> void:
	hand.sort_custom(func(a: CardData, b: CardData) -> bool:
		var pa: int = RankSystem.president_power(a.rank)
		var pb: int = RankSystem.president_power(b.rank)
		if pa == pb:
			return a.suit < b.suit
		return pa < pb
	)
