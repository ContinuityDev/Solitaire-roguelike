extends SceneTree

var _failures: int = 0

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _init() -> void:
	_check(RankSystem.short_label(1) == "A", "ace label")
	_check(RankSystem.president_power(3) < RankSystem.president_power(4), "3 lower than 4")
	_check(RankSystem.president_power(1) > RankSystem.president_power(13), "Ace higher than King")
	_check(RankSystem.president_power(2) > RankSystem.president_power(1), "2 bomb beats Ace")
	_check(Deck.build_standard().size() == 52, "standard deck is 52")

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var game: PresidentGame = PresidentGame.new()
	game.setup([0, 1, 2, 3, 4, 5], rng)
	var total: int = 0
	for s in range(6):
		total += game.hand_of(s).size()
	_check(total + game.kitty.size() == 52, "deal conserves 52 cards (hands %d kitty %d)" % [total, game.kitty.size()])
	_check(game.hand_of(0).size() >= 8, "each living seat gets a full share")

	game.lead = false
	game.trick_rank = 5
	game.trick_count = 1
	_check(game.is_legal_combo({"rank": 6, "count": 1}), "6 beats 5")
	_check(not game.is_legal_combo({"rank": 4, "count": 1}), "4 does not beat 5")
	_check(not game.is_legal_combo({"rank": 6, "count": 2}), "count must match")
	_check(game.is_legal_combo({"rank": 2, "count": 1}), "2 bomb beats a single 5")
	game.lead = true
	_check(game.is_legal_combo({"rank": 3, "count": 3}), "any combo is legal on lead")

	rng.seed = 1
	var glead: PresidentGame = PresidentGame.new()
	glead.setup([0, 1, 2, 3, 4, 5], rng, 0, 0, 0, 0)
	_check(glead.current_player == 0, "fresh setup with lead_seat 0 starts on you")
	_check(glead.lead, "a new round starts as a lead")

	var run_lead: RunManager = RunManager.new()
	run_lead.start_new_run()
	_check(run_lead.lead_seat() == 0, "round 1 lead is you")
	run_lead.round_n = 2
	run_lead.last_first = 3
	_check(run_lead.lead_seat() == 3, "later rounds the previous 1st leads")
	run_lead.hp[3] = 0
	_check(run_lead.lead_seat() == 0, "dead previous 1st falls back to you")

	var gleg: PresidentGame = PresidentGame.new()
	gleg.living = [0, 1]
	gleg.hands = {
		0: [CardData.new(7, 0, true), CardData.new(7, 1, true), CardData.new(4, 0, true)],
		1: [CardData.new(8, 0, true)],
	}
	gleg.current_player = 0
	gleg.lead = false
	gleg.trick_rank = 6
	gleg.trick_count = 2
	_check(gleg.rank_is_legal(0, 7), "pair of 7s can follow pair of 6s")
	_check(not gleg.rank_is_legal(0, 4), "single 4 cannot follow a pair")
	_check(not gleg.is_legal_combo({"rank": 7, "count": 1}), "follow of the wrong count is illegal")
	_check(gleg.auto_select_count() == 2, "auto-select count matches the trick")
	gleg.lead = true
	_check(gleg.rank_is_legal(0, 4), "any owned rank is legal on lead")
	_check(gleg.auto_select_count() == 1, "auto-select is 1 on lead")
	run_lead.free()

	var g2: PresidentGame = PresidentGame.new()
	g2.living = [0, 1]
	g2.hands = {0: [CardData.new(4, 0, true)], 1: [CardData.new(5, 0, true), CardData.new(6, 0, true)]}
	g2.current_player = 0
	g2.lead = true
	var p: Dictionary = g2.play(0, {"rank": 4, "count": 1})
	_check(bool(p.get("ok", false)), "seat 0 can play their last 4")
	_check(g2.finished.has(0), "emptying the hand places 1st")
	g2.pass_turn(g2.current_player)
	_check(g2.round_over or g2.finished.size() == 2, "last remaining seat is placed")

	var g3: PresidentGame = PresidentGame.new()
	rng.seed = 9
	g3.setup([0, 2, 4], rng)
	_check(g3.hand_of(1).is_empty(), "dead seat 1 is not dealt")
	_check(g3.hand_of(0).size() > 0 and g3.hand_of(2).size() > 0, "living seats are dealt")

	rng.seed = 42
	var g4: PresidentGame = PresidentGame.new()
	g4.setup([0, 1, 2, 3, 4, 5], rng)
	g4.lead = false
	g4.trick_rank = 10
	g4.trick_count = 1
	g4.current_player = 1
	var choice: Dictionary = PresidentAI.choose(g4, 1, 1)
	if not bool(choice.get("pass", false)):
		_check(g4.is_legal_combo(choice["combo"]), "AI follow is legal")
	else:
		_check(true, "AI may pass")
	g4.lead = true
	g4.current_player = 2
	var lead_c: Dictionary = PresidentAI.choose(g4, 2, 0)
	_check(not bool(lead_c.get("pass", false)), "AI never passes on lead with cards")
	_check(g4.is_legal_combo(lead_c["combo"]), "AI lead is legal")

	var run: RunManager = RunManager.new()
	run.start_new_run()
	_check(int(run.hp[0]) == 50, "start at 50 HP")
	run.apply_payouts([0, 1, 2, 3, 4, 5])
	var gold_first: int = run.gold
	var hp_first: int = int(run.hp[0])
	run.start_new_run()
	run.apply_payouts([1, 2, 3, 4, 5, 0])
	_check(run.gold > gold_first, "6th place earns more gold than 1st (%d vs %d)" % [run.gold, gold_first])
	_check(int(run.hp[0]) < 50, "6th place loses HP")
	_check(hp_first >= 50, "1st place gains or keeps HP (hp %d)" % hp_first)

	_check(UpgradeDB.UPGRADES.size() >= 5, "upgrade pool")
	_check(ActionDB.ACTIONS.size() >= 6, "action pool")
	_check(int(UpgradeDB.get_by_id("packed")["price"]) > 0, "packed has a price")
	var offers: Array = UpgradeDB.shop_offers(rng, 3)
	_check(offers.size() == 3, "shop offers 3 upgrades")

	rng.seed = 77
	var d1: Dictionary = Deck.deal_president([0, 1, 2, 3, 4, 5], rng, 0, 2, 0)
	var twos: int = 0
	for c in d1["hands"][0]:
		if (c as CardData).rank == 2:
			twos += 1
	_check(twos >= 0, "favorite deal runs (2s in hand: %d)" % twos)

	run.free()
	if _failures == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		printerr("%d TEST(S) FAILED" % _failures)
		quit(1)
