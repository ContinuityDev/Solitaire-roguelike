class_name RankSystem
extends RefCounted

## Ranks are plain integers, so the deck can escalate without limit.
## 1 = Ace, 2..10 = face value, 11 = Jack, 12 = Queen, 13 = King,
## 14+ = the "Ascended Court" (see NAMES). Any rank above 20 falls back
## to a generated name, so content never has to stop at an arbitrary cap.
##
## To add a named tier: add one entry to NAMES (and optionally SHORT).
## Nothing else in the codebase hard-codes a maximum rank except
## RunManager.PROTOTYPE_MAX_RANK, which only gates shop offers.

const NAMES: Dictionary = {
	1: "Ace",
	11: "Jack",
	12: "Queen",
	13: "King",
	14: "Emperor",
	15: "Empress",
	16: "Titan",
	17: "Leviathan",
	18: "Seraph",
	19: "Sovereign",
	20: "Deity",
}

const SHORT: Dictionary = {
	1: "A",
	11: "J",
	12: "Q",
	13: "K",
	14: "EMP",
	15: "EMS",
	16: "TTN",
	17: "LEV",
	18: "SER",
	19: "SOV",
	20: "GOD",
}

static func short_label(rank: int) -> String:
	if SHORT.has(rank):
		return str(SHORT[rank])
	return str(rank)

static func full_name(rank: int) -> String:
	if NAMES.has(rank):
		return str(NAMES[rank])
	if rank >= 2 and rank <= 10:
		return str(rank)
	if rank > 20:
		return "Transcendent %d" % (rank - 20)
	return str(rank)

static func is_face_or_higher(rank: int) -> bool:
	return rank >= 11

## Chip value scored when this card lands on a foundation.
## Linear to King, then a growing "ascension bonus" so high cards snowball.
static func chip_value(rank: int) -> int:
	var base: int = rank * 10
	if rank > 13:
		base += (rank - 13) * 15
	return base

## Display colour tier: normal / face (gold-ish) / ascended (purple).
static func tier(rank: int) -> int:
	if rank > 13:
		return 2
	if rank >= 11:
		return 1
	return 0
