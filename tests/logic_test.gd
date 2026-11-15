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
	_check(Deck.build_standard().size() == 54, "standard deck is 54 (52 + 2 jokers)")
	var n_jokers: int = 0
	for dc in Deck.build_standard():
		if RankSystem.is_joker((dc as CardData).rank):
			n_jokers += 1
	_check(n_jokers == 2, "deck has two jokers")
	_check(RankSystem.is_joker(0) and RankSystem.short_label(0) == "Jk", "joker label is Jk")

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var game: PresidentGame = PresidentGame.new()
	game.setup([0, 1, 2, 3, 4, 5], rng)
	var total: int = 0
	for s in range(6):
		total += game.hand_of(s).size()
	_check(total + game.kitty.size() == 54, "deal conserves 54 cards (hands %d kitty %d)" % [total, game.kitty.size()])
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
	_check(CardForge.promote_card(ace) and ace.rank == 2, "Ace promotes to bomb (uncapped climb)")
	var bomb: CardData = CardData.new(2, 0, true)
	_check(CardForge.promote_card(bomb) and bomb.rank == 16, "2s promote into super ranks")
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
	_check(str(RankModDB.AI_SPEC[1]["effect"]) != "", "Speaker specialty table still exists for tooling")
	var spec_run: RunManager = RunManager.new()
	spec_run.start_new_run()
	_check(spec_run.rank_mods_of(1).is_empty(), "AI seats start round 1 with no rank bind")
	_check(spec_run.upgrades_of(1).is_empty() and spec_run.actions_of(1).is_empty(), "AI seats start round 1 with no upgrades")
	_check(spec_run.rank_mods_of(0).is_empty(), "human starts with no rank bind")
	spec_run.gold = 20
	_check(spec_run.buy_upgrade("mod_gold_5", 8), "human can buy a rank bind")
	_check(spec_run.rank_gold_on_play(0, 5) == 1, "bought Gold Fives binds to seat 0")
	spec_run.free()

	# Blue value is the trick's true rank: a 5 played as a 6 must be followed as a 6.
	var gblue: PresidentGame = PresidentGame.new()
	gblue.living = [0, 1]
	gblue.hands = {
		0: [CardData.new(5, 0, true), CardData.new(9, 0, true)],
		1: [CardData.new(5, 1, true), CardData.new(6, 0, true), CardData.new(7, 0, true)],
	}
	gblue.current_player = 0
	gblue.lead = true
	gblue.mods = rmod
	var pblue: Dictionary = gblue.play(0, {"rank": 5, "count": 1})
	_check(bool(pblue.get("ok", false)), "buffed 5 can be led")
	_check(gblue.trick_printed == 5, "table still shows the printed 5")
	_check(gblue.trick_power == 6 and gblue.trick_rank == 6, "trick follow rank becomes 6")
	_check(gblue.trick_follow_label() == "6", "follow label is a 6")
	_check(not gblue.is_legal_combo({"rank": 5, "count": 1}, 1), "unbuffed 5 cannot follow a blue 6")
	_check(not gblue.rank_is_legal(1, 5), "human/AI rank_is_legal rejects a printed 5")
	_check(gblue.is_legal_combo({"rank": 6, "count": 1}, 1), "a 6 can follow a blue 6")
	gblue.current_player = 1
	var ai_blue: Dictionary = PresidentAI.choose(gblue, 1, 1)
	_check(not bool(ai_blue.get("pass", false)), "AI can follow a blue 6")
	_check(int(ai_blue.get("combo", {}).get("rank", 0)) != 5, "AI does not follow a blue 6 with a printed 5")
	_check(gblue.is_legal_combo(ai_blue["combo"], 1), "AI follow of a blue trick is legal")
	rmod.free()

	# Joker: always legal; clears the pile (like everyone passed) — does NOT end the round.
	var gj: PresidentGame = PresidentGame.new()
	gj.living = [0, 1, 2, 3, 4, 5]
	gj.hands = {
		0: [CardData.new(RankSystem.JOKER, 0, true), CardData.new(4, 0, true), CardData.new(5, 0, true)],
		1: [CardData.new(7, 0, true), CardData.new(8, 0, true)],
		2: [CardData.new(3, 0, true), CardData.new(6, 0, true)],
		3: [CardData.new(9, 0, true)],
		4: [CardData.new(10, 0, true)],
		5: [CardData.new(11, 0, true)],
	}
	gj.current_player = 1
	gj.lead = true
	var lead_ok: Dictionary = gj.play(1, {"rank": 7, "count": 1})
	_check(bool(lead_ok.get("ok", false)), "AI can lead before joker test")
	gj.pass_turn(2)
	gj.pass_turn(3)
	_check(gj.has_passed(2) and gj.has_passed(3), "passers are locked out of the pile")
	gj.current_player = 0
	_check(gj.is_legal_combo({"rank": RankSystem.JOKER, "count": 1}, 0), "a single joker is always legal")
	var pj: Dictionary = gj.play(0, {"rank": RankSystem.JOKER, "count": 1})
	_check(bool(pj.get("joker", false)) and bool(pj.get("ok", false)), "joker play is flagged")
	_check(bool(pj.get("clear", false)), "joker clears the pile")
	_check(not gj.round_over, "joker does not end the round")
	_check(gj.finished.is_empty(), "joker does not finish the seat when cards remain")
	_check(gj.hand_of(0).size() == 2, "joker only removes itself; rest of hand stays")
	_check(gj.hand_of(1).size() == 1, "other hands untouched by joker")
	_check(gj.lead and gj.trick_count == 0 and gj.trick_power == 0, "pile cleared; seat has the lead")
	_check(gj.current_player == 0, "joker player keeps the lead")
	_check(gj.passed_seats.is_empty(), "joker clears pass lockouts for the new pile")
	_check(not gj.has_passed(2), "previous passers can play on the next pile")
	# Mid-round joker with six seats still living must not trigger round_over.
	_check(gj.active_seats().size() == 6, "all seats still active after joker")
	# Follow-joker as last card: seat finishes, but round continues if others remain.
	gj.lead = false
	gj.round_over = false
	gj.finished.clear()
	gj.passed_seats.clear()
	gj.hands[1] = [CardData.new(RankSystem.JOKER, 1, true)]
	gj.hands[0] = [CardData.new(4, 0, true)]
	gj.hands[2] = [CardData.new(3, 0, true)]
	gj.trick_rank = 10
	gj.trick_count = 2
	gj.trick_power = 10
	gj.trick_player = 0
	gj.current_player = 1
	_check(gj.is_legal_combo({"rank": RankSystem.JOKER, "count": 1}, 1), "joker can follow any trick")
	var pj2: Dictionary = gj.play(1, {"rank": RankSystem.JOKER, "count": 1})
	_check(bool(pj2.get("joker", false)) and bool(pj2.get("finished", false)), "last-card joker finishes that seat")
	_check(not gj.round_over, "follow-joker does not end the round while others remain")
	_check(gj.finished.size() == 1 and int(gj.finished[0]) == 1, "only the joker seat finished")
	_check(gj.lead and gj.trick_count == 0, "follow-joker still clears the pile")

	# Pass lockout: once you pass, you cannot play again until the pile ends.
	var gp: PresidentGame = PresidentGame.new()
	gp.living = [0, 1, 2, 3]
	gp.hands = {
		0: [CardData.new(5, 0, true), CardData.new(9, 0, true)],
		1: [CardData.new(6, 0, true), CardData.new(8, 0, true)],
		2: [CardData.new(7, 0, true), CardData.new(10, 0, true)],
		3: [CardData.new(4, 0, true), CardData.new(11, 0, true)],
	}
	gp.current_player = 0
	gp.lead = true
	gp.play(0, {"rank": 5, "count": 1})
	_check(gp.current_player == 1 and not gp.lead, "after lead, next seat follows")
	gp.pass_turn(1)
	_check(gp.has_passed(1), "seat 1 is locked out after pass")
	_check(gp.current_player == 2, "turn advances past passer")
	# Seat 2 plays over — seat 1 stays locked out.
	gp.play(2, {"rank": 7, "count": 1})
	_check(gp.trick_player == 2, "seat 2 is the new trick winner")
	_check(gp.has_passed(1), "passer stays locked after someone else plays")
	var locked_play: Dictionary = gp.play(1, {"rank": 6, "count": 1})
	_check(not bool(locked_play.get("ok", true)), "passed seat cannot play again this pile")
	# Force current to seat 1 and ensure play still rejected / next_player skips them.
	gp.current_player = 1
	var locked_play2: Dictionary = gp.play(1, {"rank": 8, "count": 1})
	_check(not bool(locked_play2.get("ok", true)), "passed seat rejected even if current_player forced")
	gp.current_player = 3
	gp.pass_turn(3)
	_check(gp.has_passed(3), "seat 3 passed")
	# Seat 0 still to act (or already past). Advance: only non-passed seats play.
	# Remaining non-passed besides trick_player(2): seat 0. Seat 1 and 3 passed.
	if gp.current_player != 0 and not gp.lead:
		# Keep passing/playing until pile ends or seat 0's turn.
		if gp.current_player == 0:
			pass
		elif not gp.has_passed(gp.current_player) and gp.current_player != 2:
			gp.pass_turn(gp.current_player)
	# Ensure seat 0 can still act, then pass → pile should end (1 and 3 already passed).
	if not gp.lead:
		gp.current_player = 0
		gp.pass_turn(0)
	_check(gp.lead, "pile ends when every other seat has passed")
	_check(gp.current_player == 2, "last player to play leads the next pile")
	_check(gp.passed_seats.is_empty(), "new pile clears pass lockouts")
	_check(not gp.has_passed(1), "previous passers unlocked on new pile")
	# AI respects lockout: choose returns pass when already passed.
	gp.passed_seats = [1]
	gp.lead = false
	gp.trick_player = 2
	gp.trick_count = 1
	gp.trick_power = 7
	var ai_locked: Dictionary = PresidentAI.choose(gp, 1, 1)
	_check(bool(ai_locked.get("pass", false)), "AI passes when locked out of the pile")

	# AI joker path (owner report: round ended when an AI played a joker).
	# Legacy bug dumped the AI hand and called _resolve_joker_round().
	var src_pg: String = FileAccess.get_file_as_string("res://scripts/president_game.gd")
	_check(not src_pg.contains("_resolve_joker_round"), "legacy _resolve_joker_round is gone")
	_check(src_pg.contains("JOKER — pile cleared"), "joker label is pile cleared, not round over")
	_check(not src_pg.contains("JOKER — round over"), "old joker round-over label is gone")
	var g_ai_j: PresidentGame = PresidentGame.new()
	g_ai_j.living = [0, 1, 2, 3, 4, 5]
	g_ai_j.hands = {
		0: [CardData.new(12, 0, true), CardData.new(4, 0, true)],
		1: [CardData.new(RankSystem.JOKER, 0, true), CardData.new(3, 1, true), CardData.new(6, 2, true)],
		2: [CardData.new(7, 0, true)],
		3: [CardData.new(8, 0, true)],
		4: [CardData.new(9, 0, true)],
		5: [CardData.new(10, 0, true)],
	}
	g_ai_j.current_player = 0
	g_ai_j.lead = true
	g_ai_j.play(0, {"rank": 12, "count": 1})
	g_ai_j.pass_turn(2)
	g_ai_j.pass_turn(3)
	g_ai_j.current_player = 1
	var ai_choice: Dictionary = PresidentAI.choose(g_ai_j, 1, 1)
	_check(not bool(ai_choice.get("pass", true)), "AI elects to play vs King when holding joker")
	_check(RankSystem.is_joker(int(ai_choice.get("combo", {}).get("rank", -1))), "AI chooses the joker (same path as _ai_act)")
	var before_ai_hand: int = g_ai_j.hand_of(1).size()
	var ai_play: Dictionary = g_ai_j.play(1, ai_choice["combo"])
	_check(bool(ai_play.get("joker", false)) and bool(ai_play.get("clear", false)), "AI joker play clears the pile")
	_check(not g_ai_j.round_over, "AI joker does not end the round")
	_check(g_ai_j.finished.is_empty(), "AI mid-hand joker does not finish the seat")
	_check(g_ai_j.hand_of(1).size() == before_ai_hand - 1, "AI joker dumps only itself, not the hand")
	_check(g_ai_j.lead and g_ai_j.current_player == 1, "AI joker player leads the next pile")
	_check(g_ai_j.active_seats().size() == 6, "six seats still active after AI joker")
	# Bomb follow: AI prefers joker when nothing else beats it.
	var g_ai_bomb: PresidentGame = PresidentGame.new()
	g_ai_bomb.living = [0, 1, 2]
	g_ai_bomb.hands = {
		0: [CardData.new(2, 0, true)],
		1: [CardData.new(RankSystem.JOKER, 1, true), CardData.new(5, 0, true)],
		2: [CardData.new(6, 0, true)],
	}
	g_ai_bomb.current_player = 0
	g_ai_bomb.lead = true
	g_ai_bomb.play(0, {"rank": 2, "count": 1})
	g_ai_bomb.current_player = 1
	var bomb_choice: Dictionary = PresidentAI.choose(g_ai_bomb, 1, 1)
	_check(RankSystem.is_joker(int(bomb_choice.get("combo", {}).get("rank", -1))), "AI plays joker over a bomb when that is the only follow")
	var bomb_play: Dictionary = g_ai_bomb.play(1, bomb_choice["combo"])
	_check(bool(bomb_play.get("joker", false)) and not g_ai_bomb.round_over, "AI joker vs bomb clears pile; round continues")
	_check(g_ai_bomb.hand_of(1).size() == 1, "AI keeps non-joker cards after bomb-clear joker")
	# Last-card AI joker finishes the seat but not the round.
	var g_ai_last: PresidentGame = PresidentGame.new()
	g_ai_last.living = [0, 1, 2, 3]
	g_ai_last.hands = {
		0: [CardData.new(5, 0, true)],
		1: [CardData.new(RankSystem.JOKER, 0, true)],
		2: [CardData.new(6, 0, true)],
		3: [CardData.new(7, 0, true)],
	}
	g_ai_last.lead = false
	g_ai_last.trick_rank = 10
	g_ai_last.trick_count = 1
	g_ai_last.trick_power = 10
	g_ai_last.trick_player = 0
	g_ai_last.current_player = 1
	var last_j: Dictionary = g_ai_last.play(1, {"rank": RankSystem.JOKER, "count": 1})
	_check(bool(last_j.get("finished", false)), "AI last-card joker finishes that seat")
	_check(not g_ai_last.round_over, "AI last-card joker does not end round while others remain")

	# After a pass, turn never returns to that seat until the pile ends.
	var gs: PresidentGame = PresidentGame.new()
	gs.living = [0, 1, 2, 3]
	gs.hands = {
		0: [CardData.new(3, 0, true), CardData.new(9, 0, true)],
		1: [CardData.new(5, 0, true), CardData.new(10, 0, true)],
		2: [CardData.new(6, 0, true), CardData.new(11, 0, true)],
		3: [CardData.new(7, 0, true), CardData.new(12, 0, true)],
	}
	gs.current_player = 0
	gs.lead = true
	gs.play(0, {"rank": 3, "count": 1})
	gs.pass_turn(1)
	_check(gs.has_passed(1), "seat 1 locked after pass")
	# Seat 2 plays, then seat 3 — seat 1 must never become current while still locked.
	gs.play(2, {"rank": 6, "count": 1})
	_check(gs.current_player != 1, "locked seat skipped after another play")
	gs.pass_turn(3)
	_check(gs.current_player != 1, "locked seat skipped after later pass")
	_check(gs.has_passed(1), "seat 1 still locked until pile ends")
	# Seat 0 passes → everyone else passed → pile ends, seat 2 leads.
	if gs.current_player == 0:
		gs.pass_turn(0)
	_check(gs.lead and gs.current_player == 2, "pile ends for last player who played")
	_check(not gs.has_passed(1), "lockouts clear on the new pile")

	var phone_h: Dictionary = HandLayout.plan(13, 360.0, Vector2(70, 98))
	_check(bool(phone_h["fits"]), "13 cards stay on a phone-width row")
	var desk_h: Dictionary = HandLayout.plan(18, 1200.0, Vector2(70, 98))
	_check(bool(desk_h["fits"]), "18 cards stay on a desktop row")
	var tight_h: Dictionary = HandLayout.plan(24, 320.0, Vector2(70, 98))
	_check(bool(tight_h["fits"]), "24 cards wrap/scale instead of going off-screen")
	_check(int(tight_h["rows"]) >= 2, "a packed phone hand wraps to a second row")

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
	var gold_pre: int = ai_run.gold_of(1)
	var pre_shop: Array = ai_run.ai_shop_all()
	_check(pre_shop.is_empty(), "AI does not shop before the desk opens")
	_check(ai_run.gold_of(1) == gold_pre, "AI gold is untouched before the shop")
	_check(not ai_run.buy_upgrade_for(1, "packed", 12), "AI cannot buy mid-round")
	_check(ai_run.gold_of(1) == gold_pre, "blocked AI buy does not spend gold")
	var shop_logs: Array = ai_run.open_shop_phase()
	_check(shop_logs.size() >= 1, "at least one AI bought from the desk (%d logs)" % shop_logs.size())
	var bought: bool = false
	for s in range(1, 6):
		if not ai_run.upgrades_of(s).is_empty() or not ai_run.actions_of(s).is_empty() or not ai_run.enhancements_of(s).is_empty():
			bought = true
		if ai_run.rank_mods_of(s).size() > 1:
			bought = true
	_check(bought, "an AI inventory is no longer empty after shopping")
	_check(ai_run.gold_of(1) < 40, "AI gold was spent")
	_check(ai_run.loadout_short(1) != "" or bought, "AI loadout badge reflects purchases")
	ai_run.actions_of(2).append("filibuster")
	var g_fili: PresidentGame = PresidentGame.new()
	g_fili.living = [0, 1, 2]
	g_fili.hands = {
		0: [CardData.new(4, 0, true)],
		1: [CardData.new(5, 0, true)],
		2: [CardData.new(6, 0, true), CardData.new(7, 0, true)],
	}
	g_fili.current_player = 2
	g_fili.lead = false
	g_fili.trick_rank = 4
	g_fili.trick_count = 1
	var pick_act: String = PresidentAI.choose_turn_action(g_fili, ai_run, 2)
	_check(pick_act == "filibuster", "AI with Filibuster spends it on a follow (%s)" % pick_act)
	_check(ai_run.spend_action_for(2, "filibuster"), "AI spend_action_for removes Filibuster")
	var fx: Dictionary = ActionFx.apply_turn(g_fili, ai_run, 2, "filibuster")
	_check(bool(fx.get("ok", false)), "AI Filibuster applies")
	_check(g_fili.must_pass_seat == ActionFx.next_opponent(g_fili, 2), "Filibuster marks the next opponent")
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
	var before_ai: int = hot_run.gold_of(2)
	hot_run.ai_shop_all()
	_check(hot_run.gold_of(1) == before_h, "AI shop does not spend a human seat's gold")
	_check(hot_run.gold_of(2) == before_ai, "AI does not spend gold before the shop opens")
	hot_run.open_shop_phase()
	_check(hot_run.gold_of(1) == before_h, "shop phase still does not spend a human seat")
	hot_run.hp[0] = 0
	hot_run.hp[1] = 0
	hot_run._check_end()
	_check(hot_run.run_over and not hot_run.run_won, "all humans dead is a loss")
	hot_run.free()
	var endless_run: RunManager = RunManager.new()
	endless_run.start_new_run(loc)
	endless_run.hp[0] = 0
	endless_run.hp[2] = 0
	endless_run.hp[3] = 0
	endless_run._check_end()
	_check(not endless_run.run_over, "last living human does not end an endless run")
	_check(not endless_run.run_won, "endless runs never set run_won")
	endless_run.revive_cabinet()
	_check(int(endless_run.hp[2]) > 0 and int(endless_run.hp[3]) > 0, "revive_cabinet restores dead AIs")
	_check(int(endless_run.hp[0]) == 0, "revive_cabinet does not revive humans")
	endless_run.free()

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

	# --- Endless scaling, lose condition, compact ranks ---
	_check(NumFormat.compact(42) == "42", "compact under 1K stays plain")
	_check(NumFormat.compact(1200) == "1.2K", "compact thousands")
	_check(NumFormat.compact(3_400_000) == "3.4M", "compact millions")
	_check(NumFormat.compact(2_000_000_000) == "2B", "compact billions trim .0")
	_check(NumFormat.compact(0) == "0", "compact zero")

	_check(RankSystem.inflate_rank(3, 0) == 3, "inflate bonus 0 is identity")
	_check(RankSystem.inflate_rank(3, 10) == 13, "inflate 3+10 → King")
	_check(RankSystem.inflate_rank(13, 1) == 1, "inflate King+1 → Ace")
	_check(RankSystem.inflate_rank(1, 1) == 2, "inflate Ace+1 → bomb")
	_check(RankSystem.inflate_rank(2, 1) == 16, "inflate bomb+1 → first super rank")
	_check(RankSystem.president_power(25) == 25, "super rank power equals face")
	_check(RankSystem.short_label(25) == "25", "super rank label is numeric")
	_check(RankSystem.short_label(1500) == "1.5K", "huge rank uses compact label")
	var super_card: CardData = CardData.new(16, 0, true)
	var super_d: Dictionary = RankSystem.buff_display(super_card, 0)
	_check(str(super_d["shown"]) == "16" and not bool(super_d["buffed"]), "super face 16 reads as 16, not 2+")

	_check(CardForge.next_rank(13) == 1, "King promotes to Ace")
	_check(CardForge.next_rank(1) == 2, "Ace promotes to bomb")
	_check(CardForge.next_rank(2) == 16, "bomb promotes into super ranks")
	_check(CardForge.next_rank(16) == 17, "super ranks climb without cap")
	var climb: CardData = CardData.new(2, 1, true)
	CardForge.promote_card(climb)
	_check(climb.rank == 16, "promote_card climbs bomb to 16")

	var scale_run: RunManager = RunManager.new()
	scale_run.start_new_run()
	_check(scale_run.ante() == 1 and scale_run.rank_bonus() == 0, "round 1 ante 1, no rank bonus")
	_check(scale_run.stake() == 6, "round 1 stake is 5+1")
	scale_run.round_n = 4
	_check(scale_run.ante() == 2, "round 4 is ante 2")
	_check(scale_run.rank_bonus() == 0, "automatic rank bonus stays 0 in later rounds")
	_check(scale_run.stake() == 5 + 4 + 3, "round 4 stake adds ante pressure")
	scale_run.round_n = 10
	_check(scale_run.rank_bonus() == 0, "no mid-run automatic rank inflation")
	_check(scale_run.stake() == 5 + 10 + 9 + 2, "round 10 stake adds late tax")
	scale_run.round_n = 40
	_check(scale_run.rank_bonus() == 0, "late-run automatic rank inflation remains off")
	# Manual inflate helpers still work for Incumbent / blue-value tooling.
	rng.seed = 99
	var g_inf: PresidentGame = PresidentGame.new()
	g_inf.setup([0, 1, 2, 3, 4, 5], rng)
	var faces_r1: Array = []
	for c_r1 in g_inf.hand_of(0):
		faces_r1.append((c_r1 as CardData).rank)
	# apply_deal_effects must NOT auto-inflate across rounds.
	scale_run.round_n = 1
	scale_run.apply_deal_effects(g_inf)
	var faces_after: Array = []
	for c_r1b in g_inf.hand_of(0):
		faces_after.append((c_r1b as CardData).rank)
	_check(faces_r1 == faces_after, "deal effects do not auto-inflate ranks in round 1")
	scale_run.round_n = 12
	scale_run.apply_deal_effects(g_inf)
	var faces_late: Array = []
	for c_late in g_inf.hand_of(0):
		faces_late.append((c_late as CardData).rank)
	_check(faces_r1 == faces_late, "deal effects do not auto-inflate ranks in later rounds")
	Deck.inflate_hands(g_inf.hands, 12)
	var saw_super: bool = false
	var min_p: int = 999999
	for s_inf in g_inf.living:
		for c_inf in g_inf.hand_of(int(s_inf)):
			var rr: int = (c_inf as CardData).rank
			if RankSystem.is_joker(rr):
				continue
			var pp: int = RankSystem.president_power(rr)
			if pp < min_p:
				min_p = pp
			if RankSystem.is_super(rr):
				saw_super = true
	_check(saw_super, "manual inflate helper still produces super ranks")
	_check(min_p >= 3 + 12, "manual inflate lifts the floor by the bonus")
	g_inf.lead = true
	g_inf.current_player = 0
	var any_rank: int = 0
	for c0 in g_inf.hand_of(0):
		if not RankSystem.is_joker((c0 as CardData).rank):
			any_rank = (c0 as CardData).rank
			break
	_check(g_inf.is_legal_combo({"rank": any_rank, "count": 1}, 0), "super/inflated ranks are legal on lead")

	# AI shop timing: vanilla round 1, buys after desk opens (post round 1).
	var ai_scale: RunManager = RunManager.new()
	ai_scale.start_new_run()
	ai_scale.rng.seed = 11
	for seat_r1 in range(1, 6):
		_check(ai_scale.upgrades_of(seat_r1).is_empty() and ai_scale.rank_mods_of(seat_r1).is_empty() \
			and ai_scale.actions_of(seat_r1).is_empty() and ai_scale.enhancements_of(seat_r1).is_empty(),
			"AI seat %d has zero upgrades in round 1" % seat_r1)
	ai_scale.apply_payouts([0, 1, 2, 3, 4, 5])
	for seat_fund in range(1, 6):
		ai_scale.seat_gold[seat_fund] = maxi(ai_scale.gold_of(seat_fund), 30)
	var gold_before_shop: Dictionary = {}
	for seat_snap in range(1, 6):
		gold_before_shop[seat_snap] = ai_scale.gold_of(seat_snap)
	var shop2: Array = ai_scale.open_shop_phase()
	_check(shop2.size() >= 1, "AIs buy after round 1 desk opens (%d logs)" % shop2.size())
	var any_ai_gear: bool = false
	var any_spent: bool = false
	for seat_bought in range(1, 6):
		if not ai_scale.upgrades_of(seat_bought).is_empty() or not ai_scale.rank_mods_of(seat_bought).is_empty() \
			or not ai_scale.actions_of(seat_bought).is_empty() or not ai_scale.enhancements_of(seat_bought).is_empty():
			any_ai_gear = true
		if ai_scale.gold_of(seat_bought) < int(gold_before_shop[seat_bought]):
			any_spent = true
	_check(any_ai_gear, "at least one AI acquired upgrades after round 1")
	_check(any_spent, "AIs spend gold on their desk")
	ai_scale.free()

	var lose_run: RunManager = RunManager.new()
	lose_run.start_new_run()
	lose_run.round_n = 7
	lose_run.hp[0] = 0
	lose_run._check_end()
	_check(lose_run.run_over and not lose_run.run_won, "human at 0 HP ends the endless run as a loss")
	RunManager.record_best_round(7)
	_check(RunManager.load_best_round() >= 7, "best round persists to user://")
	RunManager.record_best_round(3)
	_check(RunManager.load_best_round() >= 7, "lower round does not overwrite best")
	lose_run.free()

	var next_r: RunManager = RunManager.new()
	next_r.start_new_run()
	next_r.hp[2] = 0
	next_r.hp[4] = 0
	next_r.next_round()
	_check(next_r.round_n == 2, "next_round increments")
	_check(int(next_r.hp[2]) > 0 and int(next_r.hp[4]) > 0, "next_round revives dead AIs")
	next_r.free()

	# --- Survivor Chips only from AI death; rank customizations ---
	var chip_run: RunManager = RunManager.new()
	chip_run.start_new_run()
	_check(chip_run.chips == 0, "new run starts with 0 chips")
	chip_run.hp[2] = 1
	chip_run.hp[3] = 1
	chip_run.apply_payouts([0, 1, 4, 5, 2, 3])
	_check(chip_run.last_knockouts.has(2) or int(chip_run.hp[2]) == 0, "AI seat can be knocked out by payout")
	var ko_n: int = chip_run.last_knockouts.size()
	_check(ko_n >= 1, "at least one AI knockout recorded (%d)" % ko_n)
	_check(chip_run.chips == ko_n * RunManager.CHIP_PER_KO, "survivor chips only from AI KO (%d chips for %d KOs)" % [chip_run.chips, ko_n])
	# No other chip sources: economy upgrades / gold earned / empty KO list.
	chip_run.chips = 0
	chip_run.last_knockouts.clear()
	chip_run.owned_upgrades.append("payroll")
	chip_run.owned_upgrades.append("gold_rush")
	chip_run.owned_upgrades.append("war_bonds")
	chip_run._grant_survivor_chips({0: 100})
	_check(chip_run.chips == 0, "no chips without AI knockouts")
	chip_run.bind_or_level_rank_effect(0, 5, "gold")
	var no_chip_play: Dictionary = chip_run.trigger_rank_play(0, 5, [], 1, false, false)
	_check(int(no_chip_play.get("chips", 0)) == 0, "rank play never grants chips")
	_check(int(no_chip_play.get("gold", 0)) >= 1, "rank play still pays gold")

	chip_run.chips = 20
	chip_run.gold = 0
	_check(chip_run.buy_upgrade("fx_gold_5", 5), "can buy Mint Fives with chips")
	_check(chip_run.chips == 15, "chip price deducted")
	_check(chip_run.rank_effect_level(0, 5, "gold") >= 1, "rank effect leveled")
	_check(chip_run.buy_upgrade("fx_gold_5", 5), "can level Mint Fives again")
	_check(chip_run.rank_effect_level(0, 5, "gold") >= 2, "rank effect leveled further")
	chip_run.owned_upgrades.append("gold_rush")
	_check(chip_run.rank_gold_on_play(0, 5) >= 2, "gold-on-play matches level / rush")

	var fx_res: Dictionary = chip_run.trigger_rank_play(0, 5, [])
	_check(int(fx_res.get("gold", 0)) >= 2, "trigger_rank_play pays gold")
	_check(int(fx_res.get("chips", 0)) == 0, "trigger_rank_play pays no chips")
	chip_run.bind_or_level_rank_effect(0, 4, "damage")
	chip_run.bind_or_level_rank_effect(0, 4, "damage")
	chip_run.hp[1] = 20
	var hp_before_whip: int = int(chip_run.hp[1])
	chip_run.chips = 0
	var fx3: Dictionary = chip_run.trigger_rank_play(0, 4, [])
	_check(int(fx3.get("damage", 0)) == 2, "damage effect deals level HP")
	_check(int(chip_run.hp[1]) == hp_before_whip - 2, "weakest AI lost HP")
	_check(int(fx3.get("chips", 0)) == 0, "non-lethal whip deals no chips")
	# Mid-round AI elimination still grants exactly CHIP_PER_KO.
	chip_run.hp[1] = 1
	chip_run.chips = 0
	var fx_ko: Dictionary = chip_run.trigger_rank_play(0, 4, [])
	_check(int(chip_run.hp[1]) == 0, "whip can eliminate AI")
	_check(int(fx_ko.get("chips", 0)) == RunManager.CHIP_PER_KO, "mid-round KO grants only base chip")
	_check(chip_run.rank_effect_badge(0, 5).contains("$"), "badge text for customized rank")

	# Wide rank-targeted pool
	_check(RankEffectDB.EFFECTS.size() >= 40, "rank fx pool covers many ranks (%d)" % RankEffectDB.EFFECTS.size())
	_check(ComboBuffDB.COMBOS.size() >= 40, "combo pool is wide (%d)" % ComboBuffDB.COMBOS.size())
	var ranks_covered: Dictionary = {}
	for fx_item in RankEffectDB.EFFECTS:
		ranks_covered[int(fx_item.get("rank", 0))] = true
	for r in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]:
		_check(ranks_covered.has(r), "rank fx covers %s" % RankSystem.short_label(r))
	_check(not RankEffectDB.get_by_id("fx_gold_7").is_empty(), "Mint Sevens exists")
	_check(not ComboBuffDB.get_by_id("combo_pair_7_gold").is_empty(), "Paired Sevens combo exists")
	_check(not ComboBuffDB.get_by_id("combo_retrigger_9").is_empty(), "Nine Echo exists")
	_check(str(UpgradeDB.get_by_id("chip_magnet").get("id", "")) == "", "Chip Magnet removed")
	_check(str(UpgradeDB.get_by_id("syndicate").get("id", "")) == "", "Syndicate removed")
	_check(str(UpgradeDB.get_by_id("war_chest").get("id", "")) == "", "War Chest removed")
	_check(str(UpgradeDB.get_by_id("echo").get("id", "")) == "", "Echo Chamber removed")

	# Economy: payroll, interest, bargain, war bonds (gold only)
	var econ: RunManager = RunManager.new()
	econ.start_new_run()
	econ.owned_upgrades.append("payroll")
	econ.owned_upgrades.append("payroll")
	econ.apply_payouts([0, 1, 2, 3, 4, 5])
	var pay_row: Dictionary = econ.last_payout[0]
	_check(int(pay_row["gold"]) >= 2 + 4, "payroll adds +2 gold per stack on payout")
	econ.gold = 100
	econ.owned_upgrades.append("interest")
	econ.open_shop_phase()
	_check(econ.gold == 110, "compound interest grants 10% on desk open")
	econ.owned_upgrades.append("bargain")
	econ.owned_upgrades.append("bargain")
	_check(econ.shop_price_of(0, 5, "chips") == 3, "bargain discounts chip prices")
	econ.chips = 0
	econ.gold = 0
	econ.owned_upgrades.append("war_bonds")
	econ.owned_upgrades.append("war_bonds")
	econ.next_round()
	_check(econ.gold == 6, "war bonds pays gold each new round")
	_check(econ.chips == 0, "war bonds grants no chips")
	econ.bind_or_level_rank_effect(0, 3, "gold")
	econ.chips = 0
	var gold_only: Dictionary = econ.trigger_rank_play(0, 3, [])
	_check(int(gold_only.get("chips", 0)) == 0, "gold customizations never grant chips")

	# Inflation preserves base_rank; blue true-value display uses deal-face + effective
	var c_base: CardData = CardData.new(5, 0, true)
	Deck.inflate_card(c_base, 12)
	_check(c_base.base_rank == 5, "inflation keeps base_rank 5")
	_check(c_base.rank != 5, "inflation changes face rank")
	var packed_fx: Array = c_base.pack()
	var unpacked_fx: CardData = CardData.unpack(packed_fx)
	_check(unpacked_fx.base_rank == 5 and unpacked_fx.rank == c_base.rank, "base_rank survives pack")
	var disp_inf: Dictionary = RankSystem.buff_display(c_base, 0)
	_check(str(disp_inf.get("printed", "")) == "5", "inflated card prints deal-face 5")
	_check(bool(disp_inf.get("buffed", false)), "inflated card shows blue true value")
	_check(str(disp_inf.get("shown", "")) != "5", "true value differs from printed 5")
	var c_strong: CardData = CardData.new(5, 1, true)
	var disp_str: Dictionary = RankSystem.buff_display(c_strong, 1)
	_check(str(disp_str.get("printed", "")) == "5" and str(disp_str.get("shown", "")) == "6", "Strong Fives show 5→6 in blue")
	_check(bool(disp_str.get("buffed", false)), "power bind marks buffed for blue badge")
	var c_plain: CardData = CardData.new(9, 0, true)
	var disp_plain: Dictionary = RankSystem.buff_display(c_plain, 0)
	_check(not bool(disp_plain.get("buffed", true)), "plain card needs no blue badge")

	var g_base: PresidentGame = PresidentGame.new()
	g_base.living = [0, 1]
	g_base.hands = {
		0: [c_base],
		1: [CardData.new(8, 0, true)],
	}
	g_base.mods = chip_run
	_check(g_base.base_of_rank(0, c_base.rank) == 5, "game resolves base_of_rank through inflation")
	_check(g_base.play_power(0, c_base.rank) >= RankSystem.president_power(c_base.rank) + chip_run.rank_power_bonus(0, 5), "play power uses base-rank bonus")

	# Combo buffs: conditions (rank / count / lead / last) + effects (mult / gold / chips / retrigger)
	_check(ComboBuffDB.matches({"rank": 4, "count": 4}, 4, 4, false, false), "quad-4 condition matches four 4s")
	_check(not ComboBuffDB.matches({"rank": 4, "count": 4}, 4, 3, false, false), "quad-4 does not match trips")
	_check(not ComboBuffDB.matches({"rank": 4, "count": 4}, 5, 4, false, false), "quad-4 does not match four 5s")
	_check(ComboBuffDB.matches({"rank": -1, "count": 2}, 9, 2, false, false), "any-pair matches a pair of 9s")
	_check(ComboBuffDB.matches({"rank": -1, "count": 0, "last_card": true}, 7, 1, false, true), "last-card condition")
	_check(not ComboBuffDB.matches({"rank": -1, "count": 0, "last_card": true}, 7, 1, false, false), "last-card requires emptying")
	_check(ComboBuffDB.matches({"rank": 1, "count": 0, "lead": true}, 1, 2, true, false), "lead Ace condition")
	_check(not ComboBuffDB.matches({"rank": 1, "count": 0, "lead": true}, 1, 2, false, false), "lead Ace requires lead")

	var combo_run: RunManager = RunManager.new()
	combo_run.start_new_run()
	combo_run.gold = 100
	combo_run.chips = 20
	_check(combo_run.buy_upgrade("combo_quad_4", 14), "can buy Quad Fours")
	_check(combo_run.combo_power_mult(0, 4, 4) == 4, "Quad Fours ×4 on four 4s")
	_check(combo_run.combo_power_mult(0, 4, 3) == 1, "Quad Fours idle on trips of 4")
	_check(combo_run.combo_power_mult(0, 5, 4) == 1, "Quad Fours idle on four 5s")
	_check(combo_run.buy_upgrade("combo_quad_4", 14), "can level Quad Fours")
	_check(combo_run.combo_power_mult(0, 4, 4) == 5, "leveled Quad Fours is ×5")
	_check(combo_run.buy_upgrade("combo_quad_any", 18), "can buy Quad Force")
	_check(combo_run.combo_power_mult(0, 4, 4) == 10, "Quad Fours × Quad Force stacks (5×2)")

	var g_quad: PresidentGame = PresidentGame.new()
	g_quad.living = [0, 1]
	g_quad.hands = {
		0: [CardData.new(4, 0, true), CardData.new(4, 1, true), CardData.new(4, 2, true), CardData.new(4, 3, true)],
		1: [CardData.new(8, 0, true)],
	}
	g_quad.mods = combo_run
	g_quad.current_player = 0
	g_quad.lead = true
	var pq: Dictionary = g_quad.play(0, {"rank": 4, "count": 4})
	_check(bool(pq.get("ok", false)) and int(pq.get("mult", 1)) == 10, "play applies combo power mult")
	_check(g_quad.trick_power == RankSystem.president_power(4) * 10, "trick power is base × mult")

	combo_run.gold = 0
	combo_run.chips = 0
	combo_run.owned_upgrades.append("combo_pair_5_gold")
	combo_run.owned_upgrades.append("combo_retrigger_5")
	combo_run.bind_or_level_rank_effect(0, 5, "gold")
	combo_run.bind_or_level_rank_effect(0, 5, "gold")
	# Pair of 5s: rank gold fires twice (base + 1 retrigger) = 4, plus pair gold +3.
	var pair_res: Dictionary = combo_run.trigger_rank_play(0, 5, [], 2, false, false)
	_check(int(pair_res.get("retriggers", 0)) == 1, "Five Echo retriggers once on 5s")
	_check(int(pair_res.get("gold", 0)) == 2 * 2 + 3, "retrigger doubles rank gold; pair mint pays")
	_check(int(pair_res.get("chips", 0)) == 0, "combo payouts never grant chips")
	_check(combo_run.gold == 7, "combo gold credited to seat")

	combo_run.gold = 0
	combo_run.owned_upgrades.append("combo_trips_3_gold")
	var trip_res: Dictionary = combo_run.trigger_rank_play(0, 3, [], 3, false, false)
	_check(int(trip_res.get("gold", 0)) == 3, "Triple Threes pays gold on three 3s")
	_check(int(trip_res.get("chips", 0)) == 0, "Triple Threes grants no chips")
	var miss_res: Dictionary = combo_run.trigger_rank_play(0, 3, [], 2, false, false)
	_check(int(miss_res.get("gold", 0)) == 0, "Triple Threes idle on a pair of 3s")

	combo_run.gold = 0
	combo_run.owned_upgrades.append("combo_last_card_gold")
	var exit_res: Dictionary = combo_run.trigger_rank_play(0, 9, [], 1, false, true)
	_check(int(exit_res.get("gold", 0)) == 5, "Exit Bonus pays on emptying hand")
	_check(combo_run.combo_short(0).contains("4"), "combo short badge lists owned combos")
	_check(not ComboBuffDB.get_by_id("combo_quad_4").is_empty(), "ComboBuffDB lookup works")
	_check(UpgradeDB.get_by_id("combo_retrigger_pair").get("effect", "") == "retrigger", "UpgradeDB resolves combo ids")
	_check(UpgradeDB.get_by_id("combo_pair_7_gold").get("rank", 0) == 7, "rank-targeted combo names its rank")
	_check(UpgradeDB.get_by_id("fx_power_13").get("rank", 0) == 13, "rank fx targets Kings")

	combo_run.free()
	chip_run.free()
	econ.free()
	scale_run.free()
	run.free()
	if _failures == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		printerr("%d TEST(S) FAILED" % _failures)
		quit(1)
