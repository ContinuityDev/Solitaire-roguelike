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
	_check(RankSystem.short_label_for_power(6) == "6", "power 6 is a 6")
	_check(RankSystem.short_label_for_power(14) == "A", "power 14 is an Ace")
	_check(RankSystem.short_label_for_power(15) == "2", "power 15 is a bomb")
	_check(RankSystem.short_label_for_power(16) == "2+", "power 16 is a heavier bomb")
	var nat: CardData = CardData.new(7, 0, true)
	var nat_d: Dictionary = RankSystem.buff_display(nat, 0)
	_check(not bool(nat_d["buffed"]) and str(nat_d["shown"]) == "7" and str(nat_d["printed"]) == "7", "unbuffed 7 stays a 7")
	var five: CardData = CardData.new(5, 1, true)
	var five_d: Dictionary = RankSystem.buff_display(five, 1)
	_check(bool(five_d["buffed"]) and str(five_d["shown"]) == "6" and str(five_d["printed"]) == "5", "Strong Fives keep a printed 5 and a blue 6")
	var ace_p: CardData = CardData.new(1, 0, true)
	_check(str(RankSystem.buff_display(ace_p, 1)["shown"]) == "2", "Ace Authority reads as a blue 2")
	var king_p: CardData = CardData.new(13, 0, true)
	_check(str(RankSystem.buff_display(king_p, 1)["shown"]) == "A", "Kingmaker reads as a blue Ace")
	var bomb_p: CardData = CardData.new(2, 0, true)
	_check(str(RankSystem.buff_display(bomb_p, 1)["shown"]) == "2+", "Heavier Bombs read as 2+")
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
	_check(shop_run.buy_upgrade("packed", shop_run.shop_price(int(UpgradeDB.get_by_id("packed")["price"]))), "can buy packed")
	_check(shop_run.buy_action("uprising", shop_run.shop_price(int(ActionDB.get_by_id("uprising")["price"]))), "can buy uprising")
	_check(shop_run.buy_enhancement("steel", shop_run.shop_price(int(EnhancementDB.get_by_id("steel")["price"]))), "can buy steel")
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
	_check(streak_run.gold == gold_s1 + int(RunManager.GOLD_BY_PLACE[1]) + RunManager.STREAK_UNIT, "human gold includes streak bonus")
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

	_check(int(RunManager.GOLD_BY_PLACE[1]) == 2, "1st place gold is 2")
	_check(int(RunManager.GOLD_BY_PLACE[2]) == 3, "2nd place gold is 3")
	_check(int(RunManager.GOLD_BY_PLACE[3]) == 4, "3rd place gold is 4")
	_check(int(RunManager.GOLD_BY_PLACE[4]) == 5, "4th place gold is 5")
	_check(int(RunManager.GOLD_BY_PLACE[5]) == 7, "5th place gold is 7")
	_check(int(RunManager.GOLD_BY_PLACE[6]) == 9, "6th place gold is 9")
	_check(RunManager.STREAK_UNIT == 3, "streak unit is 3")
	_check(int(UpgradeDB.get_by_id("packed")["price"]) == 12, "packed costs 12")
	_check(int(ActionDB.get_by_id("veto")["price"]) == 10, "veto costs 10")
	_check(int(EnhancementDB.get_by_id("lucky")["price"]) == 9, "lucky costs 9")
	_check(int(RankModDB.get_by_id("mod_gold_5")["price"]) == 8, "gold fives costs 8")

	var eco: RunManager = RunManager.new()
	eco.start_new_run()
	eco.apply_payouts([0, 1, 2, 3, 4, 5])
	_check(eco.gold == 2, "human 1st earns $2")
	_check(eco.gold_of(5) == 9, "AI 6th earns $9")
	_check(eco.gold_of(1) == 3, "AI 2nd earns $3")
	eco.free()

	# Card-replace: incumbent / lucky / rally do not add cards.
	_check(ActionDB.get_by_id("rally")["desc"].find("Promote") >= 0, "rally is a promote, not a draw")
	_check(ActionDB.get_by_id("forge").size() > 0, "forge bomb is in the catalog")
	_check(EnhancementDB.get_by_id("lucky")["desc"].find("swap") >= 0, "lucky swaps with kitty")
	_check(UpgradeDB.get_by_id("incumbent")["desc"].find("promote") >= 0, "incumbent promotes")
	var c3: CardData = CardData.new(3, 0, true)
	_check(CardForge.promote_card(c3) and c3.rank == 4, "promote 3→4")
	_check(c3.origin_rank == 3, "promote keeps the printed origin")
	var promo_d: Dictionary = RankSystem.buff_display(c3, 0)
	_check(bool(promo_d["buffed"]) and str(promo_d["shown"]) == "4" and str(promo_d["printed"]) == "3", "Incumbent/Rally keeps a printed 3 and a blue 4")
	var ace: CardData = CardData.new(1, 0, true)
	_check(not CardForge.promote_card(ace) and ace.rank == 1, "Ace does not promote")
	var bomb: CardData = CardData.new(2, 0, true)
	_check(not CardForge.promote_card(bomb) and bomb.rank == 2, "2s do not promote")
	var forge_hand: Array = [CardData.new(4, 1, true), CardData.new(9, 0, true)]
	var n_forge: int = forge_hand.size()
	var flab: String = CardForge.forge_bomb(forge_hand)
	_check(flab != "" and forge_hand.size() == n_forge, "forge replaces in place")
	_check((forge_hand[0] as CardData).rank == 2, "lowest card became a 2")
	_check((forge_hand[0] as CardData).origin_rank == 4, "forge keeps the printed origin")
	var forge_d: Dictionary = RankSystem.buff_display(forge_hand[0] as CardData, 0)
	_check(bool(forge_d["buffed"]) and str(forge_d["shown"]) == "2" and str(forge_d["printed"]) == "4", "forged bomb keeps a printed 4 and a blue 2")
	var promo_hand: Array = [CardData.new(3, 0, true), CardData.new(5, 1, true)]
	var pn: int = promo_hand.size()
	var plab: PackedStringArray = CardForge.promote_lowest(promo_hand, 2)
	_check(promo_hand.size() == pn, "rally/promote does not add cards")
	_check(plab.size() == 2, "two cards promoted")
	var inc_run: RunManager = RunManager.new()
	inc_run.start_new_run()
	inc_run.owned_upgrades.append("incumbent")
	inc_run.owned_enhancements.append("lucky")
	rng.seed = 99
	var ginc: PresidentGame = PresidentGame.new()
	ginc.setup([0, 1, 2, 3, 4, 5], rng)
	var h0: int = ginc.hand_of(0).size()
	var k0: int = ginc.kitty.size()
	inc_run.apply_deal_effects(ginc)
	_check(ginc.hand_of(0).size() == h0, "incumbent+lucky do not add hand cards (%d vs %d)" % [ginc.hand_of(0).size(), h0])
	_check(ginc.kitty.size() == k0, "lucky swap keeps kitty size")
	_check(inc_run.extra_cards() == 0, "extra_cards grant is gone")
	inc_run.free()

	# Rank effects are seat-scoped.
	var gr: PresidentGame = PresidentGame.new()
	gr.living = [0, 1]
	gr.hands = {
		0: [CardData.new(5, 0, true)],
		1: [CardData.new(5, 1, true), CardData.new(6, 0, true)],
	}
	gr.current_player = 0
	gr.lead = false
	gr.trick_rank = 6
	gr.trick_count = 1
	var rmod: RunManager = RunManager.new()
	rmod.start_new_run()
	rmod.bind_rank_mod(0, 5, "power")
	gr.mods = rmod
	_check(gr.is_legal_combo({"rank": 5, "count": 1}, 0), "your 5s with +1 power equal a 6")
	_check(not gr.is_legal_combo({"rank": 5, "count": 1}, 1), "AI 5s without the bind do not beat a 6")
	_check(gr.play_power(0, 5) == RankSystem.president_power(5) + 1, "player 5 power is base+1")
	_check(gr.play_power(1, 5) == RankSystem.president_power(5), "AI 5 power is base")
	rmod.bind_rank_mod(1, 1, "always_legal")
	gr.hands[1].append(CardData.new(1, 2, true))
	gr.trick_rank = 2
	_check(gr.is_legal_combo({"rank": 1, "count": 1}, 1), "AI Ace privilege follows a bomb")
	_check(not gr.is_legal_combo({"rank": 1, "count": 1}, 0), "player Aces without the bind cannot follow a bomb")
	rmod.bind_rank_mod(0, 5, "gold_play")
	_check(rmod.rank_gold_on_play(0, 5) == 1, "player earns gold on 5s")
	_check(rmod.rank_gold_on_play(1, 5) == 0, "AI without gold-5s earns nothing on 5s")
	_check(str(RankModDB.AI_SPEC[1]["effect"]) != "", "Speaker has a starter specialty")
	var spec_run: RunManager = RunManager.new()
	spec_run.start_new_run()
	_check(spec_run.rank_mods_of(1).size() >= 1, "AI seats start with a rank bind")
	_check(spec_run.rank_mods_of(0).is_empty(), "human starts with no rank bind")
	spec_run.gold = 20
	_check(spec_run.buy_upgrade("mod_gold_5", 8), "human can buy a rank bind")
	_check(spec_run.rank_gold_on_play(0, 5) == 1, "bought Gold Fives binds to seat 0")
	spec_run.free()
	rmod.free()

	# Odds helper: remaining cards + AI influence, not isolated deck math.
	var og: PresidentGame = PresidentGame.new()
	og.living = [0, 1, 2]
	og.hands = {
		0: [CardData.new(2, 0, true), CardData.new(2, 1, true), CardData.new(9, 0, true)],
		1: [CardData.new(5, 0, true), CardData.new(5, 1, true), CardData.new(5, 2, true), CardData.new(8, 0, true)],
		2: [CardData.new(4, 0, true), CardData.new(4, 1, true), CardData.new(7, 0, true)],
	}
	og.kitty = []
	og.history = []
	og.last_play_label = {}
	_check(OddsHelper.unseen_of(og, 2, 0) == 2, "two 2s unseen (you hold 2, none played)")
	_check(OddsHelper.unseen_of(og, 1, 0) == 4, "all aces unseen")
	og.history.append({"seat": 2, "rank": 2, "count": 1})
	_check(OddsHelper.unseen_of(og, 2, 0) == 1, "played 2 drops unseen 2s to 1")
	og.living = [0, 3, 2]
	og.hands[3] = [CardData.new(5, 0, true), CardData.new(5, 1, true), CardData.new(5, 2, true), CardData.new(8, 0, true)]
	og.hands[2] = [CardData.new(4, 0, true), CardData.new(4, 1, true), CardData.new(7, 0, true), CardData.new(8, 1, true)]
	var p_save: float = OddsHelper.p_seat_holds_rank(og, 3, 2, 0)
	var p_dump: float = OddsHelper.p_seat_holds_rank(og, 2, 2, 0)
	_check(p_save > p_dump, "timid seat more likely to still hold a 2 than aggressive (%f vs %f)" % [p_save, p_dump])
	og.last_play_label[3] = "pass"
	og.lead = false
	og.trick_rank = 2
	og.trick_count = 1
	var p_pass: float = OddsHelper.p_seat_holds_rank(og, 3, 2, 0)
	_check(p_pass < p_save, "a pass on a 2-trick slashes P(holds a 2) (%f vs %f)" % [p_pass, p_save])
	var hud: String = OddsHelper.hud_text(og, null, 0)
	_check(hud.find("unseen") >= 0, "odds HUD mentions unseen ranks")
	_check(OddsHelper.p_pair_unseen(og, 13, 0) >= 0.0 and OddsHelper.p_pair_unseen(og, 13, 0) <= 1.0, "pair odds in 0..1")

	# AI purchase + use path.
	var ai_run: RunManager = RunManager.new()
	ai_run.start_new_run()
	ai_run.rng.seed = 4
	ai_run.apply_payouts([1, 2, 3, 4, 5, 0])
	_check(ai_run.gold_of(1) > 0, "AI President earned gold")
	ai_run.seat_gold[1] = 40
	ai_run.last_finish = [1, 2, 3, 4, 5, 0]
	var shop_logs: Array = ai_run.ai_shop_all()
	_check(shop_logs.size() >= 1, "at least one AI bought from the desk (%d logs)" % shop_logs.size())
	var bought: bool = false
	for s in range(1, 6):
		if not ai_run.upgrades_of(s).is_empty() or not ai_run.actions_of(s).is_empty() or not ai_run.enhancements_of(s).is_empty():
			bought = true
		if ai_run.rank_mods_of(s).size() > 1:
			bought = true
	_check(bought, "an AI inventory is no longer empty after shopping")
	_check(ai_run.gold_of(1) < 40, "AI gold was spent")
	ai_run.actions_of(2).append("filibuster")
	var gai: PresidentGame = PresidentGame.new()
	gai.living = [0, 1, 2]
	gai.hands = {
		0: [CardData.new(4, 0, true)],
		1: [CardData.new(5, 0, true)],
		2: [CardData.new(6, 0, true), CardData.new(7, 0, true)],
	}
	gai.current_player = 2
	gai.lead = false
	gai.trick_rank = 4
	gai.trick_count = 1
	var pick_act: String = PresidentAI.choose_turn_action(gai, ai_run, 2)
	_check(pick_act == "filibuster", "AI with Filibuster spends it on a follow (%s)" % pick_act)
	_check(ai_run.spend_action_for(2, "filibuster"), "AI spend_action_for removes Filibuster")
	var fx: Dictionary = ActionFx.apply_turn(gai, ai_run, 2, "filibuster")
	_check(bool(fx.get("ok", false)), "AI Filibuster applies")
	_check(gai.must_pass_seat == ActionFx.next_opponent(gai, 2), "Filibuster marks the next opponent")
	_check(str(fx.get("message", "")).find("Filibuster") >= 0, "use is logged")
	ai_run.actions_of(1).append("uprising")
	ai_run.last_finish = [0, 2, 3, 4, 5, 1]
	var role_logs: Array = ai_run.ai_results_actions()
	_check(role_logs.size() >= 1, "AI Asshole fires Uprising")
	_check(int(ai_run.last_finish[0]) == 1, "Uprising swapped AI into President")
	ai_run.free()

	var shop_pick: Dictionary = PresidentAI.choose_shop(
		[{"id": "just_say_no", "name": "Just Say No", "price": 13, "kind": "action"}],
		20, 0, RoleTrade.ROLE_SCUM)
	_check(str(shop_pick.get("id", "")) == "just_say_no", "AI Asshole prefers Just Say No")

	# Title modes: solo vs AIs + local hotseat lobby.
	var solo: LobbyConfig = LobbyConfig.solo()
	_check(solo.seat_count == 6, "solo is 6 seats")
	_check(solo.human_seats() == [0], "solo human is seat 0")
	_check(solo.is_human(0) and solo.is_ai(1) and solo.is_ai(5), "solo: you vs five AIs")
	_check(solo.can_start(), "solo can start")
	_check(not solo.is_hotseat(), "solo is not hotseat")
	_check(not LobbyConfig.needs_handoff(solo, 0, 0), "solo never hands off")
	_check(LobbyConfig.is_human_turn(solo, 0) and not LobbyConfig.is_human_turn(solo, 2), "solo turn ownership is seat 0")
	_check(LobbyConfig.make_code().length() == 4, "lobby code is 4 characters")

	var loc: LobbyConfig = LobbyConfig.new()
	loc.set_seat_count(4)
	loc.set_kind(0, LobbyConfig.KIND_HUMAN)
	loc.set_kind(1, LobbyConfig.KIND_HUMAN)
	loc.set_kind(2, LobbyConfig.KIND_AI)
	loc.set_kind(3, LobbyConfig.KIND_AI)
	_check(loc.seat_count == 4, "lobby seat count 4")
	_check(loc.human_seats() == [0, 1], "two human seats")
	_check(loc.ai_seats() == [2, 3], "two AI seats")
	_check(loc.is_hotseat(), "two humans is hotseat")
	_check(LobbyConfig.needs_handoff(loc, 0, 1), "handoff when the next human is a different seat")
	_check(not LobbyConfig.needs_handoff(loc, 0, 2), "no handoff for an AI seat")
	_check(not LobbyConfig.needs_handoff(loc, 1, 1), "no handoff when already viewing that human")
	_check(LobbyConfig.is_human_turn(loc, 1), "P2 owns their turn")
	loc.set_kind(1, LobbyConfig.KIND_AI)
	_check(loc.human_seats() == [0], "kick human → AI leaves host")
	loc.fill_empty_with_ai()
	_check(loc.is_ai(1) and loc.is_ai(2) and loc.is_ai(3), "fill empty with AI")
	loc.set_kind(1, LobbyConfig.KIND_HUMAN)
	var hot_run: RunManager = RunManager.new()
	hot_run.start_new_run(loc)
	_check(hot_run.living_seats() == [0, 1, 2, 3], "4-seat lobby deals 4 living")
	_check(int(hot_run.hp[4]) == 0 and int(hot_run.hp[5]) == 0, "unused seats sit out at 0 HP")
	_check(hot_run.is_human(0) and hot_run.is_human(1), "run tracks both humans")
	_check(hot_run.is_ai(2) and not hot_run.is_human(2), "seat 2 is AI")
	_check(hot_run.living_humans() == [0, 1], "living humans")
	hot_run.seat_gold[1] = 40
	hot_run.seat_gold[2] = 40
	hot_run.last_finish = [0, 1, 2, 3]
	var before_h: int = hot_run.gold_of(1)
	hot_run.ai_shop_all()
	_check(hot_run.gold_of(1) == before_h, "AI shop does not spend a human seat's gold")
	hot_run.hp[0] = 0
	hot_run.hp[1] = 0
	hot_run._check_end()
	_check(hot_run.run_over and not hot_run.run_won, "all humans dead is a loss")
	hot_run.free()
	var win_run: RunManager = RunManager.new()
	win_run.start_new_run(loc)
	win_run.hp[0] = 0
	win_run.hp[2] = 0
	win_run.hp[3] = 0
	win_run._check_end()
	_check(win_run.run_over and win_run.run_won, "last living human wins")
	win_run.free()

	# LAN table: host is seat 0, joiners take empty AI seats, names stick.
	var lan: LobbyConfig = LobbyConfig.new()
	lan.lan = true
	lan.set_seat_count(4)
	lan.set_display_name(0, "Hayden")
	_check(lan.name_of(0) == "Hayden", "host can rename")
	lan.set_kind(1, LobbyConfig.KIND_HUMAN)
	_check(lan.name_of(0) == "Hayden", "rename survives extra humans")
	_check(not lan.is_hotseat(), "LAN is not pass-the-device")
	_check(not LobbyConfig.needs_handoff(lan, 0, 1), "LAN never covers the host hand")
	lan.set_kind(1, LobbyConfig.KIND_AI)
	var s1: int = lan.take_lan_seat("Ada")
	var s2: int = lan.take_lan_seat("Bo")
	var s3: int = lan.take_lan_seat("Cy")
	_check(s1 == 1 and s2 == 2 and s3 == 3, "joiners fill the next AI seats")
	_check(lan.is_human(1) and lan.name_of(1) == "Ada", "joiner keeps their name")
	_check(lan.take_lan_seat("Full") == -1, "full table rejects")
	lan.release_lan_seat(2)
	_check(lan.is_ai(2), "leave converts the seat back to AI")
	var packed_l: Dictionary = lan.to_dict()
	var lan2: LobbyConfig = LobbyConfig.from_dict(packed_l)
	_check(lan2.lan and lan2.name_of(0) == "Hayden" and lan2.name_of(1) == "Ada", "lobby dict round-trips")
	_check(NetSession.lan_supported(), "a table can be hosted from this build")
	_check(NetSession.uses_webrtc() == OS.has_feature("web"), "web uses WebRTC, desktop uses ENet")
	_check(NetSession.PORT == 24567, "desktop LAN port is 24567")
	_check(MqttWs.topic_for("ab12") == "continuity-president/AB12", "MQTT topic uppercases the table code")
	var rem: PackedByteArray = MqttWs.encode_remaining_length(0)
	_check(rem.size() == 1 and rem[0] == 0, "MQTT remaining length 0")
	var rem2: PackedByteArray = MqttWs.encode_remaining_length(200)
	_check(rem2.size() == 2 and rem2[0] == 200 and rem2[1] == 1, "MQTT remaining length 200")

	var cpack: CardData = CardData.new(12, 2, true)
	cpack.enhancement = "steel"
	var crow: Array = cpack.pack()
	var c2: CardData = CardData.unpack(crow)
	_check(c2.rank == 12 and c2.suit == 2 and c2.enhancement == "steel", "card pack round-trips")
	_check(c2.origin_rank == 12, "unpromoted pack keeps origin")
	_check(cpack.matches_pack(crow), "card matches its pack")
	var cprom: CardData = CardData.new(3, 0, true)
	CardForge.promote_card(cprom)
	var crow2: Array = cprom.pack()
	var c3p: CardData = CardData.unpack(crow2)
	_check(c3p.rank == 4 and c3p.origin_rank == 3, "promoted pack round-trips origin")

	var pg: PresidentGame = PresidentGame.new()
	pg.setup([0, 1, 2, 3], rng, 0, 0, 0, 0)
	var pub: Dictionary = pg.pack_public()
	_check(int(pub["current_player"]) == pg.current_player, "public snapshot has the current seat")
	_check((pub["hand_counts"] as Array).size() == 6, "hand counts cover six seats")
	var replica: PresidentGame = PresidentGame.new()
	replica.apply_replica(pub, 1, pg.pack_hand(1))
	_check(replica.hand_of(1).size() == pg.hand_of(1).size(), "replica keeps the viewer hand size")
	_check(replica.hand_of(0).size() == pg.hand_of(0).size(), "replica dummy hand matches count")
	_check(str(CardData.pack_hand(replica.hand_of(1))) == str(pg.pack_hand(1)), "viewer hand ranks survive the replica")
	_check(str(CardData.pack_hand(replica.hand_of(0))) != str(pg.pack_hand(0)), "hidden hands are dummy backs, not copies")
	var nrun: RunManager = RunManager.new()
	nrun.start_new_run(lan2)
	nrun.seat_gold[1] = 11
	var rpub: Dictionary = nrun.pack_public()
	var nrun2: RunManager = RunManager.new()
	nrun2.apply_public(rpub)
	_check(nrun2.gold_of(1) == 11 and nrun2.seat_count == 4, "run snapshot round-trips gold and seats")
	_check(nrun2.is_human(0) and nrun2.is_human(1), "run snapshot keeps human seats")
	nrun.free()
	nrun2.free()

	var pin_host: Control = Control.new()
	pin_host.size = Vector2(390, 844)
	root.add_child(pin_host)
	var pin_child: Control = Control.new()
	pin_host.add_child(pin_child)
	UiPin.full_rect(pin_child)
	_check(is_equal_approx(pin_child.anchor_right, 1.0) and is_equal_approx(pin_child.anchor_bottom, 1.0), "UiPin stretches anchors to the parent")
	_check(is_equal_approx(pin_child.offset_left, 0.0) and is_equal_approx(pin_child.offset_right, 0.0), "UiPin zeroes offsets so the layer is not min-sized")
	var tv: TitleView = TitleView.new()
	pin_host.add_child(tv)
	_check(is_equal_approx(tv.anchor_right, 1.0) and is_equal_approx(tv.anchor_bottom, 1.0), "title view pins full-rect")
	_check(tv.mouse_filter == Control.MOUSE_FILTER_STOP, "title eats clicks instead of passing them to the table")
	var bg_ok: bool = false
	for ch in tv.get_children():
		if ch is ColorRect:
			bg_ok = is_equal_approx((ch as ColorRect).color.a, 1.0)
			break
	_check(bg_ok, "title backdrop is fully opaque")
	tv.queue_free()
	pin_host.queue_free()

	run.free()
	if _failures == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		printerr("%d TEST(S) FAILED" % _failures)
		quit(1)
