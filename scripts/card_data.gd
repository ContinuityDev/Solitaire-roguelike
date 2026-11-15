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

func _init(p_rank: int = 1, p_suit: int = 0, p_face_up: bool = false) -> void:
	rank = p_rank
	suit = p_suit
	face_up = p_face_up

func is_red() -> bool:
	return suit == 1 or suit == 2

func suit_glyph() -> String:
	return SUIT_GLYPHS[clampi(suit, 0, 3)]

func label() -> String:
	return "%s%s" % [RankSystem.short_label(rank), SUIT_LETTERS[clampi(suit, 0, 3)]]

func display_name() -> String:
	return "%s of %s" % [RankSystem.full_name(rank), SUIT_NAMES[clampi(suit, 0, 3)]]

func chip_value() -> int:
	return RankSystem.chip_value(rank)
