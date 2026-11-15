class_name RankSystem
extends RefCounted

## Standard French ranks. President power is 3-low through Ace, with 2s
## sitting above Ace as the bomb rank. Rank 0 is a Joker (round-ender).
## Ranks 16+ are "super" faces used by round inflation and uncapped promotes;
## their follow power equals the rank number (so they climb past bombs).

const JOKER: int = 0
## First rank id above the classic bomb (power 15). Power N (>=16) ↔ rank N.
const SUPER_MIN: int = 16

const NAMES: Dictionary = {
	0: "Joker",
	1: "Ace",
	2: "Two",
	11: "Jack",
	12: "Queen",
	13: "King",
}

const SHORT: Dictionary = {
	0: "Jk",
	1: "A",
	11: "J",
	12: "Q",
	13: "K",
}

static func is_joker(rank: int) -> bool:
	return rank == JOKER

static func is_super(rank: int) -> bool:
	return rank >= SUPER_MIN

static func short_label(rank: int) -> String:
	if SHORT.has(rank):
		return str(SHORT[rank])
	if rank >= 1000 or rank <= -1000:
		return NumFormat.compact(rank)
	return str(rank)

static func full_name(rank: int) -> String:
	if NAMES.has(rank):
		return str(NAMES[rank])
	if is_super(rank):
		return "Rank %s" % NumFormat.compact(rank)
	return str(rank)

## President shedding power. 3 is weakest, Ace is high, 2 is the bomb.
## Super ranks (16+) use their id as power so inflation can climb forever.
## Jokers are not a follow rank (they end the round); sort them last.
static func president_power(rank: int) -> int:
	if is_joker(rank):
		return 100
	if is_super(rank):
		return rank
	if rank == 2:
		return 15
	if rank == 1:
		return 14
	return rank

static func is_bomb(rank: int) -> bool:
	return rank == 2

## Map follow-power back to a face rank. 16+ stay as super ranks (not bombs).
static func rank_from_power(p: int) -> int:
	if p >= SUPER_MIN:
		return p
	if p == 15:
		return 2
	if p == 14:
		return 1
	return clampi(p, 3, 13)

static func copies_in_deck(rank: int) -> int:
	return 2 if is_joker(rank) else 4

## Map a follow-power number back to a face label. Classic 16 was "2+" for a
## single Heavier Bombs bind; once power climbs further, show the number.
static func short_label_for_power(p: int) -> String:
	if p == 16:
		return "2+"
	if p > 16:
		return NumFormat.compact(p) if p >= 1000 else str(p)
	if p == 15:
		return "2"
	if p == 14:
		return "A"
	if p >= 1 and p <= 13:
		return short_label(p)
	return NumFormat.compact(p) if absi(p) >= 1000 else str(p)

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
	# Super faces use the numeric label; classic "2+" is only for a buffed bomb
	# (power 16 from Heavier Bombs), not for an inflated rank-16 card.
	var shown: String = _shown_for(face, power)
	var face_lab: String = short_label(face)
	var origin_lab: String = short_label(origin)
	var buffed: bool = power > president_power(origin)
	var printed: String = origin_lab if origin != face else face_lab
	var small: String = printed if buffed and printed != shown else ""
	return {"shown": shown, "printed": printed, "small": small, "buffed": buffed, "power": power}

static func _shown_for(face: int, power: int) -> String:
	# Only super *faces* use raw numeric labels. A classic bomb with +power
	# (Heavier Bombs → power 16) still reads as "2+" via short_label_for_power.
	if is_super(face):
		if power >= 1000:
			return NumFormat.compact(power)
		return str(power)
	return short_label_for_power(power)

## Inflate a classic (or already-scaled) rank by adding `bonus` to its follow
## power, then mapping back to a face. Preserves relative order so N-of-a-kind
## of the same pre-inflation rank stay matched.
static func inflate_rank(rank: int, bonus: int) -> int:
	if is_joker(rank) or bonus <= 0:
		return rank
	return rank_from_power(president_power(rank) + bonus)
