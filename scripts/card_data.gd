class_name CardData
extends RefCounted

## One playing card. `rank` is an int (see RankSystem) and can exceed 13.
## `suit` is 0..3 = Spades, Hearts, Diamonds, Clubs.

const SUIT_GLYPHS: Array[String] = ["\u2660", "\u2665", "\u2666", "\u2663"]
const SUIT_LETTERS: Array[String] = ["s", "h", "d", "c"]
const SUIT_NAMES: Array[String] = ["Spades", "Hearts", "Diamonds", "Clubs"]

var rank: int = 1
var suit: int = 0
var face_up: bool = false
var enhancement: String = "" # EnhancementDB id, "" = none
## Printed rank when the card was dealt. Incumbent / Rally / Forge raise
## `rank` in place and leave this so the face can show the buff in blue.
var origin_rank: int = 1

func _init(p_rank: int = 1, p_suit: int = 0, p_face_up: bool = false) -> void:
	rank = p_rank
	suit = p_suit
	face_up = p_face_up
	origin_rank = p_rank

func is_red() -> bool:
	return suit == 1 or suit == 2

func suit_glyph() -> String:
	return SUIT_GLYPHS[clampi(suit, 0, 3)]

func label() -> String:
	return "%s%s" % [RankSystem.short_label(rank), SUIT_LETTERS[clampi(suit, 0, 3)]]

func display_name() -> String:
	return "%s of %s" % [RankSystem.full_name(rank), SUIT_NAMES[clampi(suit, 0, 3)]]

func pack() -> Array:
	var row: Array = [rank, suit, enhancement]
	if origin_rank > 0 and origin_rank != rank:
		row.append(origin_rank)
	return row

static func unpack(row) -> CardData:
	var a: Array = row if row is Array else []
	var c: CardData = CardData.new(
		int(a[0]) if a.size() > 0 else 1,
		int(a[1]) if a.size() > 1 else 0,
		true)
	if a.size() > 2:
		c.enhancement = str(a[2])
	if a.size() > 3:
		c.origin_rank = int(a[3])
	return c

static func pack_hand(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		if c is CardData:
			out.append((c as CardData).pack())
	return out

static func unpack_hand(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		out.append(unpack(row))
	return out

func matches_pack(row) -> bool:
	var a: Array = row if row is Array else []
	if a.size() < 2:
		return false
	if rank != int(a[0]) or suit != int(a[1]):
		return false
	if a.size() > 2 and str(a[2]) != enhancement:
		return false
	return true
