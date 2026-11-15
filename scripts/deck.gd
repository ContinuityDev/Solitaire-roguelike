class_name Deck
extends RefCounted

## Builds the run's deck for a given maximum rank: 4 suits x ranks 1..max_rank.
## Starting a run at max_rank = 5 therefore gives a 20-card deck.

static func build(max_rank: int, rng: RandomNumberGenerator) -> Array:
	var cards: Array = []
	for suit in range(4):
		for rank in range(1, max_rank + 1):
			cards.append(CardData.new(rank, suit, false))
	# Fisher-Yates with the run's seeded RNG so runs are reproducible in tests.
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
	return cards

static func card_count(max_rank: int) -> int:
	return 4 * max_rank
