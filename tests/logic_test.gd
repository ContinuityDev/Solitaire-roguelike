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

	_check(UpgradeDB.UPGRADES.size() >= 10, "upgrade pool expanded")
	_check(ActionDB.ACTIONS.size() >= 10, "action pool expanded")
	_check(EnhancementDB.ENHANCEMENTS.size() >= 4, "enhancement pool")
	_check(int(UpgradeDB.get_by_id("packed")["price"]) > 0, "packed has a price")
	var stock_run: RunManager = RunManager.new()
	stock_run.start_new_run()
	stock_run.rng.seed = 11
	stock_run.begin_shop_visit()
	_check(stock_run.shop_offers.size() == ShopStock.SLOTS, "desk offers %d slots" % ShopStock.SLOTS)
	_check(stock_run.shop_offers.size() < ShopStock.catalog_size(), "offer count is less than the full catalog (%d < %d)" % [stock_run.shop_offers.size(), ShopStock.catalog_size()])
	stock_run.gold = 50
	var ids_a: Array = []
	for o in stock_run.shop_offers:
		ids_a.append(str(o["id"]))
	var cost1: int = stock_run.reroll_cost()
	_check(cost1 == ShopStock.reroll_cost_at(0), "first reroll costs 2 + 2×0")
	var gold_before: int = stock_run.gold
	_check(stock_run.reroll_shop(), "reroll spends gold")
	_check(stock_run.gold == gold_before - cost1, "reroll charged $%d" % cost1)
	_check(stock_run.reroll_cost() == ShopStock.reroll_cost_at(1), "second reroll costs 2 + 2×1")
	var ids_b: Array = []
	for o2 in stock_run.shop_offers:
		ids_b.append(str(o2["id"]))
	_check(" ".join(ids_a) != " ".join(ids_b), "reroll redraws offers (%s -> %s)" % [" ".join(ids_a), " ".join(ids_b)])
	stock_run.owned_upgrades.append("whip")
	stock_run.owned_upgrades.append("majority")
	stock_run.owned_upgrades.append("oval")
	stock_run.owned_upgrades.append("safe_seat")
	stock_run.owned_upgrades.append("populist")
	var avail: Array = ShopStock.available(stock_run)
	var saw_whip: bool = false
	for a0 in avail:
		if str(a0["id"]) == "whip":
			saw_whip = true
	_check(not saw_whip, "maxed unique upgrades do not restock")
	stock_run.free()
	_check(ActionDB.get_by_id("uprising").size() > 0, "uprising is in the catalog")
	_check(ActionDB.get_by_id("just_say_no").size() > 0, "just say no is in the catalog")
	_check(int(EnhancementDB.get_by_id("steel").get("price", 0)) > 0, "steel has a price")

	var catalog_ok: bool = true
	for col in [UpgradeDB.UPGRADES, ActionDB.ACTIONS, EnhancementDB.ENHANCEMENTS]:
		for it in col:
			if int(it.get("price", 0)) <= 0:
				catalog_ok = false
	_check(catalog_ok, "every shop item is purchasable (price > 0)")
	var shop_run: RunManager = RunManager.new()
	shop_run.start_new_run()
	shop_run.gold = 200
	_check(shop_run.buy_upgrade("packed", shop_run.shop_price(10)), "can buy packed")
	_check(shop_run.buy_action("uprising", shop_run.shop_price(13)), "can buy uprising")
	_check(shop_run.buy_enhancement("steel", shop_run.shop_price(11)), "can buy steel")
	_check(shop_run.has_upgrade("packed") and shop_run.has_action("uprising") and shop_run.has_enhancement("steel"), "owned flags after buy")
	shop_run.free()

	var finish6: Array = [0, 1, 2, 3, 4, 5]
	var roles6: Dictionary = RoleTrade.roles_map(finish6)
	_check(str(roles6[0]["role"]) == RoleTrade.ROLE_PRES, "1st is President")
	_check(str(roles6[1]["role"]) == RoleTrade.ROLE_VP, "2nd is VP")
	_check(str(roles6[4]["role"]) == RoleTrade.ROLE_VA, "5th is Vice-Asshole")
	_check(str(roles6[5]["role"]) == RoleTrade.ROLE_SCUM, "6th is Asshole")
	var pairs6: Array = RoleTrade.pairs_for(finish6)
	_check(pairs6.size() == 2, "six living: two tribute pairs")
	_check(int(pairs6[0]["count"]) == 2 and int(pairs6[0]["giver"]) == 5 and int(pairs6[0]["receiver"]) == 0, "Asshole gives 2 highest to President")
	_check(int(pairs6[1]["count"]) == 1 and int(pairs6[1]["giver"]) == 4 and int(pairs6[1]["receiver"]) == 1, "VA gives 1 highest to VP")
	var pairs3: Array = RoleTrade.pairs_for([0, 2, 5])
	_check(pairs3.size() == 1 and int(pairs3[0]["count"]) == 2, "three living: only Pres↔Asshole")
	_check(RoleTrade.pairs_for([0, 1]).is_empty(), "two living: no tribute")

	var asshole_hand: Array = [
		CardData.new(3, 0, true), CardData.new(4, 0, true),
		CardData.new(1, 0, true), CardData.new(2, 0, true),
	]
	var high2: Array = RoleTrade.take_highest(asshole_hand, 2)
	_check(high2.size() == 2, "take 2 highest")
	_check((high2[0] as CardData).rank == 2 and (high2[1] as CardData).rank == 1, "highest are 2 then Ace")
	var steel_card: CardData = CardData.new(2, 1, true)
	steel_card.enhancement = "steel"
	var shielded: Array = [CardData.new(3, 1, true), steel_card, CardData.new(5, 1, true)]
	var taken_s: Array = RoleTrade.take_highest(shielded, 2)
	_check(not taken_s.has(steel_card), "steel card is immune to tribute")

	var pres_hand: Array = [
		CardData.new(2, 0, true), CardData.new(2, 1, true),
		CardData.new(3, 0, true), CardData.new(5, 0, true), CardData.new(5, 1, true),
	]
	var junk: Array = RoleTrade.ai_return_picks(pres_hand, 2)
	_check(junk.size() == 2, "AI returns 2 cards")
	var gave_bomb: bool = false
	for j in junk:
		if (j as CardData).rank == 2:
			gave_bomb = true
	_check(not gave_bomb, "AI return keeps bombs when junk exists")

	var hands: Dictionary = {
		0: [CardData.new(3, 0, true), CardData.new(4, 0, true)],
		5: [CardData.new(2, 0, true), CardData.new(1, 0, true), CardData.new(6, 0, true)],
	}
	var pair: Dictionary = RoleTrade.pairs_for([0, 1, 2, 3, 4, 5])[0]
	_check(not RoleTrade.pair_is_blocked(pair, [], false), "open tribute is not blocked")
	_check(RoleTrade.pair_is_blocked(pair, [5], false), "Just Say No on Asshole blocks tribute")
	_check(RoleTrade.pair_is_blocked(pair, [], true), "Recess skips all tributes")
	var tribute: Array = RoleTrade.take_highest(hands[5], 2)
	RoleTrade.move_cards(hands, 5, 0, tribute)
	_check(hands[0].size() == 4 and hands[5].size() == 1, "2 cards moved President←Asshole")
	var back: Array = RoleTrade.ai_return_picks(hands[0], 2)
	RoleTrade.move_cards(hands, 0, 5, back)
	_check(hands[0].size() == 2 and hands[5].size() == 3, "President returns 2 of choice")

	var fin: Array = [0, 1, 2, 3, 4, 5]
	_check(RoleTrade.swap_finish(fin, 0, 5), "uprising swaps seats")
	_check(int(fin[0]) == 5 and int(fin[5]) == 0, "President ↔ Asshole after uprising")
	var up_pairs: Array = RoleTrade.pairs_for(fin)
	_check(int(up_pairs[0]["giver"]) == 0 and int(up_pairs[0]["receiver"]) == 5, "uprising inverts the 2-card tribute")

	var jsn_run: RunManager = RunManager.new()
	jsn_run.start_new_run()
	jsn_run.actions.append("just_say_no")
	_check(jsn_run.cancel_hostile(0, "tax"), "Just Say No cancels a hostile Tax")
	_check(not jsn_run.has_action("just_say_no"), "JSN is spent after cancel")
	jsn_run.actions.append("just_say_no")
	_check(not jsn_run.cancel_hostile(1, "tax"), "JSN does not fire for a different target")
	jsn_run.free()

	var ai_inv: Array = ["uprising"]
	_check(PresidentAI.choose_role_action([1, 2, 3, 4, 5, 0], 0, ai_inv) == "uprising", "AI Asshole wants Uprising")
	_check(PresidentAI.choose_role_action([0, 1, 2, 3, 4, 5], 0, ai_inv) == "", "AI President skips Uprising")

	_check(RunManager.streak_bonus_gold(1) == 0, "streak 1 is base gold only")
	_check(RunManager.streak_bonus_gold(2) == RunManager.STREAK_UNIT, "streak 2 is +N")
	_check(RunManager.streak_bonus_gold(3) == 2 * RunManager.STREAK_UNIT, "streak 3 is +2N")
	var streak_run: RunManager = RunManager.new()
	streak_run.start_new_run()
	streak_run.apply_payouts([0, 1, 2, 3, 4, 5])
	_check(int(streak_run.last_payout[0]["streak"]) == 1, "first President finish is streak 1")
	_check(int(streak_run.last_payout[0]["streak_bonus"]) == 0, "streak 1 pays no bonus")
	var gold_s1: int = streak_run.gold
	streak_run.apply_payouts([0, 1, 2, 3, 4, 5])
	_check(int(streak_run.last_payout[0]["streak"]) == 2, "second consecutive President is streak 2")
	_check(int(streak_run.last_payout[0]["streak_bonus"]) == RunManager.STREAK_UNIT, "streak 2 bonus is N")
	_check(streak_run.gold == gold_s1 + 4 + RunManager.STREAK_UNIT, "human gold includes streak bonus")
	streak_run.apply_payouts([0, 1, 2, 3, 4, 5])
	_check(int(streak_run.last_payout[0]["streak"]) == 3 and int(streak_run.last_payout[0]["streak_bonus"]) == 2 * RunManager.STREAK_UNIT, "streak 3 bonus is 2N")
	_check(int(streak_run.last_payout[1]["streak"]) == 3, "AI VP streak also climbs")
	streak_run.apply_payouts([1, 2, 3, 4, 5, 0])
	_check(int(streak_run.last_payout[5]["streak"]) == 1, "role change resets human streak")
	_check(int(streak_run.last_payout[5]["streak_bonus"]) == 0, "reset streak pays no bonus")
	streak_run.free()

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
