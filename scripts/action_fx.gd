class_name ActionFx
extends RefCounted

## Turn-time action resolution for any seat (human or AI).

static func next_opponent(game: PresidentGame, seat: int) -> int:
	var remain: Array = game.active_seats()
	if remain.is_empty():
		return -1
	var idx: int = remain.find(seat)
	if idx < 0:
		return int(remain[0])
	return int(remain[(idx + 1) % remain.size()])

static func last_place_other(game: PresidentGame, seat: int) -> int:
	var last: int = -1
	var worst: int = -1
	for s in game.active_seats():
		if int(s) == seat:
			continue
		var n: int = game.hand_of(int(s)).size()
		if n >= worst:
			worst = n
			last = int(s)
	return last

## Returns {ok, message, refund}. Caller spends the action first.
static func apply_turn(game: PresidentGame, run: RunManager, seat: int, id: String) -> Dictionary:
	var actor: String = run.name_of(seat)
	match id:
		"veto":
			var vs: int = next_opponent(game, seat)
			if vs < 0:
				return {"ok": false, "message": "%s's Veto fizzled." % actor, "refund": true}
			if run.cancel_hostile(vs, "veto"):
				return {"ok": true, "message": "Just Say No — %s's Veto cancelled." % actor, "refund": false}
			game.skip_seat = vs
			return {"ok": true, "message": "%s plays Veto — %s will be skipped." % [actor, run.name_of(vs)], "refund": false}
		"filibuster":
			var fs: int = next_opponent(game, seat)
			if fs < 0:
				return {"ok": false, "message": "%s's Filibuster fizzled." % actor, "refund": true}
			if run.cancel_hostile(fs, "filibuster"):
				return {"ok": true, "message": "Just Say No — %s's Filibuster cancelled." % actor, "refund": false}
			game.must_pass_seat = fs
			return {"ok": true, "message": "%s plays Filibuster — %s must pass." % [actor, run.name_of(fs)], "refund": false}
		"exec":
			game.exec_order = true
			return {"ok": true, "message": "%s plays Executive Order — any rank of the required count." % actor, "refund": false}
		"leak":
			var ls: int = next_opponent(game, seat)
			if ls < 0:
				return {"ok": false, "message": "%s's Leak fizzled." % actor, "refund": true}
			game.peek_seat = ls
			return {"ok": true, "message": "%s plays Leak — peeking %s." % [actor, run.name_of(ls)], "refund": false}
		"tax":
			return _tax(game, run, seat, actor)
		"rally":
			var changed: PackedStringArray = CardForge.promote_lowest(game.hand_of(seat), 2)
			Deck._sort_hand(game.hands[seat])
			if changed.is_empty():
				return {"ok": false, "message": "%s's Rally fizzled — nothing to promote." % actor, "refund": true}
			return {"ok": true, "message": "%s plays Rally — %s." % [actor, ", ".join(changed)], "refund": false}
		"forge":
			var lab: String = CardForge.forge_bomb(game.hand_of(seat))
			Deck._sort_hand(game.hands[seat])
			if lab == "":
				return {"ok": false, "message": "%s's Forge fizzled." % actor, "refund": true}
			return {"ok": true, "message": "%s forges a bomb — %s." % [actor, lab], "refund": false}
		_:
			return {"ok": false, "message": "Unknown action %s." % id, "refund": true}

static func _tax(game: PresidentGame, run: RunManager, seat: int, actor: String) -> Dictionary:
	var last: int = last_place_other(game, seat)
	if last < 0 or game.hand_of(last).is_empty():
		return {"ok": false, "message": "%s's Tax fizzled — nobody to steal from." % actor, "refund": true}
	if run.cancel_hostile(last, "tax"):
		return {"ok": true, "message": "Just Say No — %s's Tax cancelled." % actor, "refund": false}
	var oh: Array = game.hands[last]
	var card: CardData = oh[run.rng.randi_range(0, oh.size() - 1)]
	oh.erase(card)
	game.hands[seat].append(card)
	Deck._sort_hand(game.hands[seat])
	return {"ok": true, "message": "%s taxes %s for %s." % [actor, run.name_of(last), card.display_name()], "refund": false}
