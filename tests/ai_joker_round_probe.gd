extends SceneTree

## Reproduce the owner's report: AI plays a joker mid-round.
## Must clear the pile only — never end the round / dump the hand.

func _init() -> void:
	var failed: int = 0
	failed += 0 if _ai_follow_joker_mid_hand() else 1
	failed += 0 if _ai_choose_then_play_joker() else 1
	failed += 0 if _ai_joker_last_card_others_remain() else 1
	failed += 0 if _ai_joker_on_lead_does_not_end() else 1
	failed += 0 if _main_ai_act_path_simulation() else 1
	print("AI_JOKER_PROBE failed=%d" % failed)
	quit(1 if failed > 0 else 0)

func _ok(cond: bool, msg: String) -> bool:
	print(("PASS: " if cond else "FAIL: ") + msg)
	return cond

func _ai_follow_joker_mid_hand() -> bool:
	var g: PresidentGame = PresidentGame.new()
	g.living = [0, 1, 2, 3, 4, 5]
	g.hands = {
		0: [CardData.new(4, 0, true), CardData.new(5, 0, true)],
		1: [CardData.new(RankSystem.JOKER, 0, true), CardData.new(9, 1, true), CardData.new(10, 2, true)],
		2: [CardData.new(6, 0, true)],
		3: [CardData.new(7, 0, true)],
		4: [CardData.new(8, 0, true)],
		5: [CardData.new(3, 0, true)],
	}
	g.current_player = 0
	g.lead = true
	g.play(0, {"rank": 5, "count": 1})
	g.current_player = 1
	var before: int = g.hand_of(1).size()
	var r: Dictionary = g.play(1, {"rank": RankSystem.JOKER, "count": 1})
	return _ok(bool(r.get("joker", false)), "AI joker flagged") \
		and _ok(bool(r.get("clear", false)), "AI joker clears pile") \
		and _ok(not g.round_over, "AI joker does not set round_over") \
		and _ok(g.hand_of(1).size() == before - 1, "AI joker removes only itself") \
		and _ok(g.finished.is_empty(), "AI mid-hand joker does not finish seat") \
		and _ok(g.lead and g.current_player == 1, "AI joker player leads next pile") \
		and _ok(g.active_seats().size() == 6, "all seats still active")

func _ai_choose_then_play_joker() -> bool:
	var g: PresidentGame = PresidentGame.new()
	g.living = [0, 1, 2, 3, 4, 5]
	# Seat 1 (AI persona 1): only joker can follow a bomb — AI should pick joker.
	g.hands = {
		0: [CardData.new(2, 0, true), CardData.new(4, 0, true)],
		1: [CardData.new(RankSystem.JOKER, 1, true), CardData.new(3, 0, true), CardData.new(5, 1, true)],
		2: [CardData.new(6, 0, true), CardData.new(7, 0, true)],
		3: [CardData.new(8, 0, true)],
		4: [CardData.new(9, 0, true)],
		5: [CardData.new(10, 0, true)],
	}
	g.current_player = 0
	g.lead = true
	g.play(0, {"rank": 2, "count": 1})
	g.current_player = 1
	var choice: Dictionary = PresidentAI.choose(g, 1, 1)
	var ok_choose: bool = _ok(not bool(choice.get("pass", true)), "AI chooses to play vs bomb") \
		and _ok(RankSystem.is_joker(int(choice.get("combo", {}).get("rank", -1))), "AI chooses joker vs bomb")
	if not ok_choose:
		return false
	var before: int = g.hand_of(1).size()
	var r: Dictionary = g.play(1, choice["combo"])
	return _ok(bool(r.get("joker", false)) and not g.round_over, "AI-chosen joker clears pile, round continues") \
		and _ok(g.hand_of(1).size() == before - 1, "AI-chosen joker keeps rest of hand") \
		and _ok(g.lead and g.current_player == 1, "AI keeps lead after its joker")

func _ai_joker_last_card_others_remain() -> bool:
	var g: PresidentGame = PresidentGame.new()
	g.living = [0, 1, 2, 3]
	g.hands = {
		0: [CardData.new(5, 0, true)],
		1: [CardData.new(RankSystem.JOKER, 0, true)],
		2: [CardData.new(6, 0, true)],
		3: [CardData.new(7, 0, true)],
	}
	g.lead = false
	g.trick_rank = 10
	g.trick_count = 1
	g.trick_power = 10
	g.trick_player = 0
	g.current_player = 1
	var r: Dictionary = g.play(1, {"rank": RankSystem.JOKER, "count": 1})
	return _ok(bool(r.get("finished", false)), "last-card AI joker finishes that seat") \
		and _ok(not g.round_over, "last-card AI joker does not end round while others remain") \
		and _ok(g.finished.size() == 1, "only AI seat finished")

func _ai_joker_on_lead_does_not_end() -> bool:
	var g: PresidentGame = PresidentGame.new()
	g.living = [0, 1, 2]
	g.hands = {
		0: [CardData.new(4, 0, true)],
		1: [CardData.new(RankSystem.JOKER, 0, true), CardData.new(8, 0, true)],
		2: [CardData.new(5, 0, true)],
	}
	g.lead = true
	g.current_player = 1
	# Force lead joker via play (AI lead prefers non-joker, but path must be safe).
	var r: Dictionary = g.play(1, {"rank": RankSystem.JOKER, "count": 1})
	return _ok(bool(r.get("joker", false)) and not g.round_over, "lead joker does not end round") \
		and _ok(g.hand_of(1).size() == 1, "lead joker keeps other cards") \
		and _ok(g.lead and g.current_player == 1, "lead joker retains lead")

func _main_ai_act_path_simulation() -> bool:
	## Mirrors scripts/main.gd _ai_act: choose → play → continue (no dump).
	var g: PresidentGame = PresidentGame.new()
	g.living = [0, 1, 2, 3, 4, 5]
	g.hands = {
		0: [CardData.new(12, 0, true), CardData.new(4, 0, true)],
		1: [CardData.new(RankSystem.JOKER, 0, true), CardData.new(3, 1, true), CardData.new(6, 2, true)],
		2: [CardData.new(7, 0, true)],
		3: [CardData.new(8, 0, true)],
		4: [CardData.new(9, 0, true)],
		5: [CardData.new(10, 0, true)],
	}
	g.current_player = 0
	g.lead = true
	g.play(0, {"rank": 12, "count": 1})
	g.pass_turn(2)
	g.pass_turn(3)
	# Force seat 1 (can't beat King without joker/bomb).
	g.current_player = 1
	var persona: int = 1 % 3
	var choice: Dictionary = PresidentAI.choose(g, 1, persona)
	if bool(choice.get("pass", false)):
		return _ok(false, "AI should play joker rather than pass vs King with no other follow")
	var combo: Dictionary = choice["combo"]
	var r: Dictionary = g.play(1, combo)
	# Same post-conditions main relies on before _continue_turns.
	var continue_ok: bool = not g.round_over
	if g.round_over:
		return _ok(false, "main AI path would have called _end_round after joker")
	return _ok(bool(r.get("joker", false)), "main-path AI play is joker") \
		and _ok(continue_ok, "main-path would call _continue_turns not _end_round") \
		and _ok(g.hand_of(1).size() == 2, "main-path AI hand not dumped") \
		and _ok(g.lead, "main-path AI joker clears to lead")
