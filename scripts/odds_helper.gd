class_name OddsHelper
extends RefCounted

## Honest-enough draw/hold odds from Hayden's seat: remaining ranks after
## his hand and cards that have hit the table, then weighted by AI hand
## sizes, personality (timid seats save bombs), and recent passes.

static func played_of(game: PresidentGame, rank: int) -> int:
	var n: int = 0
	for h in game.history:
		var d: Dictionary = h
		if int(d.get("rank", 0)) == rank:
			n += int(d.get("count", 0))
	return n

static func unseen_of(game: PresidentGame, rank: int, viewer: int = 0) -> int:
	var held: int = game.count_of_rank(viewer, rank)
	var copies: int = RankSystem.copies_in_deck(rank)
	return clampi(copies - held - played_of(game, rank), 0, copies)

static func unseen_pool(game: PresidentGame, viewer: int = 0) -> int:
	var n: int = game.kitty.size()
	for s in game.living:
		if int(s) == viewer:
			continue
		if game.finished.has(int(s)):
			continue
		n += game.hand_of(int(s)).size()
	return n

static func hyper_at_least_one(pop: int, success: int, draws: int) -> float:
	if draws <= 0 or success <= 0 or pop <= 0:
		return 0.0
	draws = mini(draws, pop)
	if pop - success < draws:
		return 1.0
	var p_none: float = 1.0
	for i in range(draws):
		p_none *= float(pop - success - i) / float(pop - i)
	return clampf(1.0 - p_none, 0.0, 1.0)

static func hyper_at_least_k(pop: int, success: int, draws: int, k: int) -> float:
	if k <= 0:
		return 1.0
	if draws < k or success < k or pop <= 0:
		return 0.0
	draws = mini(draws, pop)
	# 1 - P(X=0) - ... - P(X=k-1) via sequential hypergeometric terms.
	var p: float = 0.0
	for x in range(0, k):
		p += _hyper_eq(pop, success, draws, x)
	return clampf(1.0 - p, 0.0, 1.0)

static func _hyper_eq(pop: int, success: int, draws: int, x: int) -> float:
	if x < 0 or x > draws or x > success or draws - x > pop - success:
		return 0.0
	# C(success,x) * C(pop-success, draws-x) / C(pop, draws)
	var num: float = _log_choose(success, x) + _log_choose(pop - success, draws - x)
	var den: float = _log_choose(pop, draws)
	return exp(num - den)

static func _log_choose(n: int, k: int) -> float:
	if k < 0 or k > n:
		return -INF
	k = mini(k, n - k)
	var s: float = 0.0
	for i in range(1, k + 1):
		s += log(float(n - k + i)) - log(float(i))
	return s

static func personality(seat: int) -> int:
	return seat % 3

static func _played_rank(game: PresidentGame, seat: int, rank: int) -> bool:
	for h in game.history:
		var d: Dictionary = h
		if int(d.get("seat", -1)) == seat and int(d.get("rank", 0)) == rank:
			return true
	return false

## Bias: timid AIs who have not dumped 2s are likelier to still hold bombs.
static func bomb_bias(game: PresidentGame, seat: int, rank: int) -> float:
	if rank != 2:
		return 1.0
	var persona: int = personality(seat)
	if _played_rank(game, seat, 2):
		return 0.85
	if persona == 0:
		return 1.35
	if persona == 2:
		return 0.85
	return 1.10

## If they just passed a trick this rank could have followed, slash the odds.
static func pass_bias(game: PresidentGame, seat: int, rank: int) -> float:
	if str(game.last_play_label.get(seat, "")) != "pass":
		return 1.0
	if game.lead or game.trick_count <= 0:
		return 1.0
	if RankSystem.president_power(rank) >= game.trick_need_power():
		return 0.22
	return 1.0

static func p_seat_holds_rank(game: PresidentGame, seat: int, rank: int, viewer: int = 0) -> float:
	if seat == viewer:
		return 1.0 if game.count_of_rank(seat, rank) > 0 else 0.0
	if game.peek_seat == seat:
		return 1.0 if game.count_of_rank(seat, rank) > 0 else 0.0
	var n: int = game.hand_of(seat).size()
	var u: int = unseen_pool(game, viewer)
	var k: int = unseen_of(game, rank, viewer)
	var p: float = hyper_at_least_one(u, k, n)
	p *= bomb_bias(game, seat, rank)
	p *= pass_bias(game, seat, rank)
	return clampf(p, 0.0, 1.0)

static func p_pair_unseen(game: PresidentGame, rank: int, viewer: int = 0) -> float:
	var u: int = unseen_pool(game, viewer)
	var k: int = unseen_of(game, rank, viewer)
	# Typical AI hand size as the "draw".
	var n: int = 0
	var seats: int = 0
	for s in game.living:
		if int(s) == viewer or game.finished.has(int(s)):
			continue
		n += game.hand_of(int(s)).size()
		seats += 1
	if seats <= 0:
		return 1.0 if k >= 2 else 0.0
	var avg: int = int(round(float(n) / float(seats)))
	return hyper_at_least_k(u, k, avg, 2)

static func pct(p: float) -> String:
	return "%d%%" % int(round(p * 100.0))

static func hud_text(game: PresidentGame, run: RunManager, viewer: int = 0) -> String:
	if game == null or game.round_over:
		return ""
	var twos_u: int = unseen_of(game, 2, viewer)
	var aces_u: int = unseen_of(game, 1, viewer)
	var kings_u: int = unseen_of(game, 13, viewer)
	var you2: int = game.count_of_rank(viewer, 2)
	var youa: int = game.count_of_rank(viewer, 1)
	var youk: int = game.count_of_rank(viewer, 13)
	var line1: String = "Odds  2s unseen %d (you %d)  ·  Aces %d (you %d)  ·  Kings %d (you %d)" % [
		twos_u, you2, aces_u, youa, kings_u, youk]
	if not game.lead and game.trick_count > 0:
		line1 += "  ·  %s unseen %d" % [game.trick_follow_label(), unseen_of(game, game.trick_printed if game.trick_printed > 0 else game.trick_rank, viewer)]
	var bits: PackedStringArray = PackedStringArray()
	var next_s: int = _next_living(game, viewer)
	if next_s >= 0:
		var p_follow: float = 0.0
		if game.lead:
			p_follow = 1.0
		else:
			# Chance they hold at least trick_count copies of a beating rank is
			# more than we can know; show chance they still hold a 2, and the
			# trick rank.
			p_follow = p_seat_holds_rank(game, next_s, 2, viewer)
		var nm: String = run.name_of(next_s) if run != null else (RunManager.NAMES[next_s] if next_s < RunManager.NAMES.size() else "?")
		var style: String = _style_note(next_s)
		bits.append("%s ~%s holds a 2%s" % [nm.replace("The ", ""), pct(p_follow), style])
		if not game.lead:
			var hold_rank: int = game.trick_printed if game.trick_printed > 0 else game.trick_rank
			var p_rank: float = p_seat_holds_rank(game, next_s, hold_rank, viewer)
			bits.append("~%s holds a %s" % [pct(p_rank), game.trick_follow_label()])
	var pair_k: float = p_pair_unseen(game, 13, viewer)
	bits.append("pair of Ks in an AI hand ~%s" % pct(pair_k))
	if run != null:
		var spec: String = run.rank_mod_short(viewer)
		if spec != "":
			bits.append("your bind%s" % spec)
	return line1 + "\n" + "  ·  ".join(bits)

static func _style_note(seat: int) -> String:
	match personality(seat):
		0:
			return " (saves bombs)"
		2:
			return " (dumps bombs)"
		_:
			return ""

static func _next_living(game: PresidentGame, viewer: int) -> int:
	var remain: Array = game.active_seats()
	if remain.is_empty():
		return -1
	var idx: int = remain.find(viewer)
	if idx < 0:
		return int(remain[0])
	return int(remain[(idx + 1) % remain.size()])
