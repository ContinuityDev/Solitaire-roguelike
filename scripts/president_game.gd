class_name PresidentGame
extends RefCounted

## One round of President. Seat 0 is the human. Combos are N-of-a-kind
## of equal rank. 2s are the highest rank (bombs). Pass is always legal;
## when every living un-finished player passes, the last player to play leads.

const SEATS: int = 6

var hands: Dictionary = {} # seat:int -> Array[CardData]
var kitty: Array = []
var living: Array = [] # seats still in the RUN (HP > 0)
var finished: Array = [] # seats that emptied this round, in order
var current_player: int = 0
var lead: bool = true
var trick_rank: int = 0
var trick_count: int = 0
var trick_player: int = -1
var passes: int = 0
var last_play_label: Dictionary = {} # seat -> String
var skip_seat: int = -1
var must_pass_seat: int = -1
var exec_order: bool = false
var peek_seat: int = -1
var round_over: bool = false
var history: Array = []

func setup(p_living: Array, rng: RandomNumberGenerator, packed: int = 0, favorite_rank: int = 0, extra_cards: int = 0, lead_seat: int = 0) -> void:
	living = p_living.duplicate()
	finished.clear()
	last_play_label.clear()
	history.clear()
	skip_seat = -1
	must_pass_seat = -1
	exec_order = false
	peek_seat = -1
	round_over = false
	lead = true
	trick_rank = 0
	trick_count = 0
	trick_player = -1
	passes = 0
	var dealt: Dictionary = Deck.deal_president(living, rng, packed, favorite_rank, extra_cards)
	hands = dealt["hands"]
	kitty = dealt["kitty"]
	current_player = int(living[0])
	if living.has(lead_seat):
		current_player = lead_seat
	elif living.has(0):
		current_player = 0

func rank_is_legal(seat: int, rank: int) -> bool:
	var n: int = count_of_rank(seat, rank)
	if n <= 0:
		return false
	if lead:
		return true
	if n < trick_count:
		return false
	return is_legal_combo({"rank": rank, "count": trick_count})

## How many cards of a legal rank a tap should select.
func auto_select_count() -> int:
	if lead:
		return 1
	return trick_count

func active_seats() -> Array:
	var out: Array = []
	for s in living:
		if not finished.has(int(s)):
			out.append(int(s))
	return out

func hand_of(seat: int) -> Array:
	return hands.get(seat, [])

func count_of_rank(seat: int, rank: int) -> int:
	var n: int = 0
	for c in hand_of(seat):
		if (c as CardData).rank == rank:
			n += 1
	return n

func combos_in_hand(seat: int) -> Array:
	var counts: Dictionary = {}
	for c in hand_of(seat):
		var r: int = (c as CardData).rank
		counts[r] = int(counts.get(r, 0)) + 1
	var out: Array = []
	for r in counts.keys():
		var n: int = int(counts[r])
		for k in range(1, n + 1):
			out.append({"rank": int(r), "count": k})
	return out

func is_legal_combo(combo: Dictionary) -> bool:
	var rank: int = int(combo.get("rank", 0))
	var count: int = int(combo.get("count", 0))
	if rank < 1 or rank > 13 or count < 1:
		return false
	if lead:
		return true
	if count != trick_count:
		return false
	if exec_order:
		return true
	return RankSystem.president_power(rank) >= RankSystem.president_power(trick_rank)

func legal_combos(seat: int) -> Array:
	var out: Array = []
	for combo in combos_in_hand(seat):
		if is_legal_combo(combo):
			out.append(combo)
	return out

func _take_cards(seat: int, rank: int, count: int) -> Array:
	var taken: Array = []
	var hand: Array = hands[seat]
	for i in range(hand.size() - 1, -1, -1):
		if taken.size() >= count:
			break
		if (hand[i] as CardData).rank == rank:
			taken.append(hand[i])
			hand.remove_at(i)
	taken.reverse()
	return taken

func play(seat: int, combo: Dictionary) -> Dictionary:
	if round_over or seat != current_player:
		return {"ok": false, "reason": "not your turn"}
	if must_pass_seat == seat:
		return {"ok": false, "reason": "filibustered"}
	if not is_legal_combo(combo):
		return {"ok": false, "reason": "illegal"}
	var rank: int = int(combo["rank"])
	var count: int = int(combo["count"])
	if count_of_rank(seat, rank) < count:
		return {"ok": false, "reason": "not in hand"}
	_take_cards(seat, rank, count)
	exec_order = false
	must_pass_seat = -1
	trick_rank = rank
	trick_count = count
	trick_player = seat
	lead = false
	passes = 0
	var label: String = "%dx %s" % [count, RankSystem.short_label(rank)]
	last_play_label[seat] = label
	history.append({"seat": seat, "rank": rank, "count": count})
	if hand_of(seat).is_empty() and not finished.has(seat):
		finished.append(seat)
		last_play_label[seat] = "OUT %d%s" % [finished.size(), _ord(finished.size())]
	_advance_after_play()
	return {"ok": true, "label": label, "finished": finished.has(seat)}

func pass_turn(seat: int) -> Dictionary:
	if round_over or seat != current_player:
		return {"ok": false}
	last_play_label[seat] = "pass"
	passes += 1
	exec_order = false
	must_pass_seat = -1
	_advance_after_pass()
	return {"ok": true}

func _living_unfinished() -> Array:
	return active_seats()

func _advance_after_play() -> void:
	_check_round_over()
	if round_over:
		return
	_next_player()

func _advance_after_pass() -> void:
	var remain: Array = _living_unfinished()
	if remain.size() <= 1:
		_check_round_over()
		return
	# Everyone except the trick winner has passed.
	if passes >= remain.size() - 1 and trick_player >= 0:
		lead = true
		trick_rank = 0
		trick_count = 0
		passes = 0
		current_player = trick_player
		if finished.has(current_player):
			_next_player()
		_check_round_over()
		return
	_next_player()
	_check_round_over()

func _next_player() -> void:
	var remain: Array = _living_unfinished()
	if remain.is_empty():
		return
	var idx: int = remain.find(current_player)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + 1) % remain.size()
	current_player = int(remain[idx])
	if skip_seat == current_player:
		skip_seat = -1
		var si: int = remain.find(current_player)
		idx = (si + 1) % remain.size()
		current_player = int(remain[idx])

func _check_round_over() -> void:
	var remain: Array = _living_unfinished()
	if remain.size() <= 1:
		for s in remain:
			if not finished.has(int(s)):
				finished.append(int(s))
		round_over = true

func _ord(n: int) -> String:
	if n == 1:
		return "st"
	if n == 2:
		return "nd"
	if n == 3:
		return "rd"
	return "th"

func place_of(seat: int) -> int:
	var i: int = finished.find(seat)
	return i + 1 if i >= 0 else 0
