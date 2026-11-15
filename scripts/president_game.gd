class_name PresidentGame
extends RefCounted

## One round of President. Seat 0 is the human. Combos are N-of-a-kind
## of equal rank. 2s are the highest rank (bombs). Pass is always legal;
## once a seat passes they are locked out of the current pile. When every
## other living un-finished player has passed, the pile ends and the last
## player to play leads. A joker clears the pile the same way (does not end
## the round).

const SEATS: int = 6

var hands: Dictionary = {} # seat:int -> Array[CardData]
var kitty: Array = []
var living: Array = [] # seats still in the RUN (HP > 0)
var finished: Array = [] # seats that emptied this round, in order
var current_player: int = 0
var lead: bool = true
var trick_rank: int = 0 ## effective follow rank (blue 6 if a 5 played as 6)
var trick_printed: int = 0 ## face rank of the cards that hit the table
var trick_power: int = 0 ## numeric follow power; 0 = no trick
var trick_count: int = 0
var trick_player: int = -1
var passes: int = 0 ## count of seats in passed_seats (compat / HUD)
var passed_seats: Array = [] ## seats locked out of the current pile
var last_play_label: Dictionary = {} # seat -> String
var skip_seat: int = -1
var must_pass_seat: int = -1
var exec_order: bool = false
var peek_seat: int = -1
var round_over: bool = false
var history: Array = []
var mods: RunManager = null ## optional; seat-scoped rank power / gold / always-legal

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
	trick_printed = 0
	trick_power = 0
	trick_count = 0
	trick_player = -1
	passes = 0
	passed_seats.clear()
	mods = null
	# packed / favorite / extra_cards are applied per-seat after deal by RunManager.
	# Keep the args so older call sites still compile; they no longer grant cards.
	var _unused_p: int = packed
	var _unused_f: int = favorite_rank
	var _unused_e: int = extra_cards
	var dealt: Dictionary = Deck.deal_president(living, rng)
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
	if RankSystem.is_joker(rank):
		return true
	if lead:
		return true
	if n < trick_count:
		return false
	return is_legal_combo({"rank": rank, "count": trick_count}, seat)

## How many cards of a legal rank a tap should select.
func auto_select_count() -> int:
	if lead:
		return 1
	return trick_count

func auto_select_count_for(rank: int) -> int:
	if RankSystem.is_joker(rank):
		return 1
	return auto_select_count()

func trick_need_power() -> int:
	if trick_power > 0:
		return trick_power
	if trick_rank <= 0:
		return 0
	return RankSystem.president_power(trick_rank)

func trick_follow_label() -> String:
	if trick_power > 0:
		return RankSystem.short_label_for_power(trick_power)
	return RankSystem.short_label(trick_rank)

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

## Deal-face for customization matching (survives inflation / promote).
func base_of_rank(seat: int, rank: int) -> int:
	for c in hand_of(seat):
		var card: CardData = c as CardData
		if card.rank == rank:
			return card.base_rank if card.base_rank > 0 else rank
	return rank

func play_power(seat: int, rank: int) -> int:
	var bonus: int = 0
	if mods != null:
		bonus = mods.rank_power_bonus(seat, base_of_rank(seat, rank))
	return RankSystem.president_power(rank) + bonus

func is_always_legal_rank(seat: int, rank: int) -> bool:
	if mods == null:
		return false
	return mods.rank_always_legal(seat, base_of_rank(seat, rank))

func is_legal_combo(combo: Dictionary, seat: int = -1) -> bool:
	var rank: int = int(combo.get("rank", 0))
	var count: int = int(combo.get("count", 0))
	if RankSystem.is_joker(rank):
		return count == 1
	# Ranks may exceed 13 after round inflation / uncapped promotes.
	if rank < 1 or count < 1:
		return false
	if seat < 0:
		seat = current_player
	if lead:
		return true
	if count != trick_count:
		return false
	if exec_order:
		return true
	if is_always_legal_rank(seat, rank):
		return true
	return play_power(seat, rank) >= trick_need_power()

func legal_combos(seat: int) -> Array:
	var out: Array = []
	for combo in combos_in_hand(seat):
		if is_legal_combo(combo, seat):
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

func has_passed(seat: int) -> bool:
	return passed_seats.has(seat)

## Start a new pile with `leader` on lead. Clears pass lockouts.
func _begin_new_pile(leader: int) -> void:
	lead = true
	trick_rank = 0
	trick_printed = 0
	trick_power = 0
	trick_count = 0
	trick_player = -1
	passes = 0
	passed_seats.clear()
	current_player = leader

func _all_others_passed() -> bool:
	if trick_player < 0:
		return false
	var remain: Array = _living_unfinished()
	if remain.size() <= 1:
		return true
	for s in remain:
		if int(s) == trick_player:
			continue
		if not passed_seats.has(int(s)):
			return false
	return true

func _mark_passed(seat: int) -> void:
	if not passed_seats.has(seat):
		passed_seats.append(seat)
	passes = passed_seats.size()

func play(seat: int, combo: Dictionary) -> Dictionary:
	if round_over or seat != current_player:
		return {"ok": false, "reason": "not your turn"}
	if has_passed(seat):
		return {"ok": false, "reason": "already passed this pile"}
	if must_pass_seat == seat:
		return {"ok": false, "reason": "filibustered"}
	if not is_legal_combo(combo, seat):
		return {"ok": false, "reason": "illegal"}
	var rank: int = int(combo["rank"])
	var count: int = int(combo["count"])
	if count_of_rank(seat, rank) < count:
		return {"ok": false, "reason": "not in hand"}
	# Snapshot base + power before taking cards (inflation / binds need the face in-hand).
	var base_rank: int = base_of_rank(seat, rank)
	var base_power: int = 0 if RankSystem.is_joker(rank) else play_power(seat, rank)
	var was_lead: bool = lead
	_take_cards(seat, rank, count)
	var emptied: bool = hand_of(seat).is_empty()
	var power_mult: int = 1
	if mods != null and not RankSystem.is_joker(rank):
		power_mult = maxi(1, mods.combo_power_mult(seat, base_rank, count, was_lead, emptied))
	exec_order = false
	must_pass_seat = -1
	if RankSystem.is_joker(rank):
		# Joker = pile clear, same as everyone else having passed.
		# Does NOT dump the hand or end the round.
		var jlabel: String = "JOKER — pile cleared"
		last_play_label[seat] = jlabel
		history.append({"seat": seat, "rank": rank, "count": 1, "joker": true, "clear": true})
		_begin_new_pile(seat)
		if emptied and not finished.has(seat):
			finished.append(seat)
			last_play_label[seat] = "OUT %d%s" % [finished.size(), _ord(finished.size())]
			_check_round_over()
			if not round_over:
				# Emptied seat cannot lead the next pile.
				_next_player()
		return {"ok": true, "label": jlabel, "finished": emptied, "joker": true, "clear": true, "base_rank": base_rank, "count": count, "lead": was_lead}
	# Normal play: seat becomes trick winner. Passed seats stay locked out.
	trick_player = seat
	lead = false
	trick_printed = rank
	trick_count = count
	trick_power = base_power * power_mult
	trick_rank = RankSystem.rank_from_power(trick_power)
	var label: String = "%dx %s" % [count, RankSystem.short_label_for_power(trick_power)]
	if power_mult > 1:
		label = "%s ×%d" % [label, power_mult]
	last_play_label[seat] = label
	history.append({"seat": seat, "rank": rank, "count": count, "power": trick_power, "mult": power_mult, "base_rank": base_rank})
	if emptied and not finished.has(seat):
		finished.append(seat)
		last_play_label[seat] = "OUT %d%s" % [finished.size(), _ord(finished.size())]
	_advance_after_play()
	return {"ok": true, "label": label, "finished": finished.has(seat), "base_rank": base_rank, "mult": power_mult, "count": count, "lead": was_lead}

func pass_turn(seat: int) -> Dictionary:
	if round_over or seat != current_player:
		return {"ok": false}
	if lead:
		return {"ok": false, "reason": "cannot pass on lead"}
	if has_passed(seat):
		return {"ok": false, "reason": "already passed this pile"}
	last_play_label[seat] = "pass"
	_mark_passed(seat)
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
	# If everyone else already passed before this play, the pile ends immediately
	# (e.g. last non-passed seat played and emptied, or only they remained).
	if _all_others_passed():
		var leader: int = trick_player
		_begin_new_pile(leader)
		if finished.has(current_player):
			_next_player()
		_check_round_over()
		return
	_next_player()

func _advance_after_pass() -> void:
	var remain: Array = _living_unfinished()
	if remain.size() <= 1:
		_check_round_over()
		return
	# Everyone except the trick winner has passed → pile ends.
	if _all_others_passed():
		var leader: int = trick_player
		_begin_new_pile(leader)
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
	var attempts: int = 0
	while attempts < remain.size():
		idx = (idx + 1) % remain.size()
		current_player = int(remain[idx])
		attempts += 1
		if skip_seat == current_player:
			skip_seat = -1
			continue
		# Skip seats that already passed this pile (lockout).
		if not lead and has_passed(current_player):
			continue
		return
	# Every unfinished seat is locked out — end the pile (same as all others passed).
	if not lead and trick_player >= 0:
		var leader: int = trick_player
		_begin_new_pile(leader)
		if finished.has(current_player):
			var remain2: Array = _living_unfinished()
			if remain2.is_empty():
				return
			current_player = int(remain2[0])

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

func pack_hand(seat: int) -> Array:
	return CardData.pack_hand(hand_of(seat))

func pack_public() -> Dictionary:
	var counts: Array = []
	var labels: Array = []
	for s in range(SEATS):
		counts.append(hand_of(s).size())
		labels.append(str(last_play_label.get(s, "")))
	return {
		"living": living.duplicate(),
		"finished": finished.duplicate(),
		"current_player": current_player,
		"lead": lead,
		"trick_rank": trick_rank,
		"trick_printed": trick_printed,
		"trick_power": trick_power,
		"trick_count": trick_count,
		"trick_player": trick_player,
		"passes": passes,
		"passed_seats": passed_seats.duplicate(),
		"skip_seat": skip_seat,
		"must_pass_seat": must_pass_seat,
		"exec_order": exec_order,
		"peek_seat": peek_seat,
		"round_over": round_over,
		"history": history.duplicate(true),
		"hand_counts": counts,
		"last_play": labels,
		"kitty_n": kitty.size(),
		"peek_hand": pack_hand(peek_seat) if peek_seat >= 0 else [],
	}

## Client replica: your real hand, dummy backs for everyone else (plus Leak).
func apply_replica(d: Dictionary, my_seat: int, my_hand: Array) -> void:
	living = []
	for s in d.get("living", []):
		living.append(int(s))
	finished = []
	for s2 in d.get("finished", []):
		finished.append(int(s2))
	current_player = int(d.get("current_player", 0))
	lead = bool(d.get("lead", true))
	trick_rank = int(d.get("trick_rank", 0))
	trick_printed = int(d.get("trick_printed", trick_rank))
	trick_power = int(d.get("trick_power", 0))
	trick_count = int(d.get("trick_count", 0))
	trick_player = int(d.get("trick_player", -1))
	passed_seats = []
	for ps in d.get("passed_seats", []):
		passed_seats.append(int(ps))
	passes = passed_seats.size()
	skip_seat = int(d.get("skip_seat", -1))
	must_pass_seat = int(d.get("must_pass_seat", -1))
	exec_order = bool(d.get("exec_order", false))
	peek_seat = int(d.get("peek_seat", -1))
	round_over = bool(d.get("round_over", false))
	history = []
	for h in d.get("history", []):
		if h is Dictionary:
			history.append((h as Dictionary).duplicate())
	kitty.clear()
	var counts: Array = d.get("hand_counts", [])
	hands.clear()
	last_play_label.clear()
	var labels: Array = d.get("last_play", [])
	var peek_rows: Array = d.get("peek_hand", [])
	for s3 in range(SEATS):
		var n: int = int(counts[s3]) if s3 < counts.size() else 0
		if s3 < labels.size() and str(labels[s3]) != "":
			last_play_label[s3] = str(labels[s3])
		if s3 == my_seat:
			hands[s3] = CardData.unpack_hand(my_hand)
		elif s3 == peek_seat and not peek_rows.is_empty():
			hands[s3] = CardData.unpack_hand(peek_rows)
		else:
			var dummy: Array = []
			for i in range(n):
				dummy.append(CardData.new(3, i % 4, false))
			hands[s3] = dummy

func take_packed_from_hand(seat: int, packed: Array) -> Array:
	var out: Array = []
	var hand: Array = hand_of(seat)
	for row in packed:
		for c in hand:
			if c in out:
				continue
			if (c as CardData).matches_pack(row):
				out.append(c)
				break
	return out
