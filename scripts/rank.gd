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

## Map a follow-power number back to a face label. 16+ is a bomb with extra
## weight (Heavier Bombs) — there is no rank above 2, so that reads "2+".
static func short_label_for_power(p: int) -> String:
	if p >= 16:
		return "2+"
	if p == 15:
		return "2"
	if p == 14:
		return "A"
	if p >= 1 and p <= 13:
		return short_label(p)
	return str(p)

## Face vs effective follow value. `power_bonus` is the seat-scoped +power bind
## (Strong Fives, Ace Authority, …). Promotions/Forge keep `origin_rank`.
## `{printed, shown, buffed}` — `printed` is the source rank (always drawn in
## suit color); `shown` is the true follow value (blue badge when buffed).
static func buff_display(card: CardData, power_bonus: int = 0) -> Dictionary:
	if card == null:
		return {"shown": "", "printed": "", "small": "", "buffed": false, "power": 0}
	var face: int = card.rank
	var origin: int = card.origin_rank if card.origin_rank > 0 else face
	var power: int = president_power(face) + maxi(0, power_bonus)
	var shown: String = short_label_for_power(power)
	var face_lab: String = short_label(face)
	var origin_lab: String = short_label(origin)
	var buffed: bool = power > president_power(origin)
	var printed: String = origin_lab if origin != face else face_lab
	var small: String = printed if buffed and printed != shown else ""
	return {"shown": shown, "printed": printed, "small": small, "buffed": buffed, "power": power}
