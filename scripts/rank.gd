class_name RankSystem
extends RefCounted

## Standard French ranks. President power is 3-low through Ace, with 2s
## sitting above Ace as the bomb rank.

const NAMES: Dictionary = {
	1: "Ace",
	2: "Two",
	11: "Jack",
	12: "Queen",
	13: "King",
}

const SHORT: Dictionary = {
	1: "A",
	11: "J",
	12: "Q",
	13: "K",
}

static func short_label(rank: int) -> String:
	if SHORT.has(rank):
		return str(SHORT[rank])
	return str(rank)

static func full_name(rank: int) -> String:
	if NAMES.has(rank):
		return str(NAMES[rank])
	return str(rank)

## President shedding power. 3 is weakest, Ace is high, 2 is the bomb.
static func president_power(rank: int) -> int:
	if rank == 2:
		return 15
	if rank == 1:
		return 14
	return rank

static func is_bomb(rank: int) -> bool:
	return rank == 2
