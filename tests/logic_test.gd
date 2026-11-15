extends SceneTree

## Headless logic smoke test (no UI). Run from the project root:
##   godot --headless --script tests/logic_test.gd
## Prints ALL TESTS PASSED and exits 0 on success, exits 1 otherwise.

var _failures: int = 0

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _init() -> void:
	# Rank system
	_check(RankSystem.short_label(1) == "A", "ace label")
	_check(RankSystem.short_label(13) == "K", "king label")
	_check(RankSystem.full_name(14) == "Emperor", "rank 14 is Emperor")
	_check(RankSystem.full_name(20) == "Deity", "rank 20 is Deity")
	_check(RankSystem.full_name(25) == "Transcendent 5", "rank >20 generated name")
	_check(RankSystem.chip_value(20) > RankSystem.chip_value(13), "ascended cards worth more than King")

	# Deck escalation
	_check(Deck.card_count(5) == 20, "starter deck A-5 has 20 cards")
	_check(Deck.card_count(13) == 52, "A-K deck has 52 cards")
	_check(Deck.card_count(15) == 60, "A-Empress deck has 60 cards")

	# Board setup conserves cards
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var board: SolitaireBoard = SolitaireBoard.new()
	board.setup(5, rng, 0, 1)
	var in_play: int = board.stock.size() + board.waste.size() + board.foundation_count()
	for pile in board.tableau:
		in_play += (pile as Array).size()
	_check(in_play == 20, "setup deals all 20 cards (got %d)" % in_play)
	_check(board.tableau.size() == 4, "starter deck uses 4 tableau columns")
	_check(not board.is_cleared(), "new board is not cleared")

	# Foundation rules: only Ace starts a foundation
	_check(board.can_place_on_foundation(CardData.new(1, 0)), "ace can start foundation")
	_check(not board.can_place_on_foundation(CardData.new(2, 0)), "2 cannot start foundation")

	# Tableau rules: descending alternating colours; empty column takes anything
	var black5: CardData = CardData.new(5, 0, true)
	var red4: CardData = CardData.new(4, 1, true)
	var black4: CardData = CardData.new(4, 3, true)
	_check(board.can_place_on_tableau(red4, [black5]), "red 4 on black 5")
	_check(not board.can_place_on_tableau(black4, [black5]), "black 4 on black 5 rejected")
	_check(board.can_place_on_tableau(black4, []), "any card fills empty column (prototype rule)")

	# Stock draw
	var before: int = board.stock.size()
	_check(board.draw_stock() and board.stock.size() == before - 1 and board.waste.size() == 1, "draw from stock to waste")

	# Shop always offers rank escalation below the cap
	var run: RunManager = RunManager.new()
	run.rng.seed = 999
	var choices: Array = UpgradeDB.build_shop_choices(5, [], 3, run.rng, RunManager.PROTOTYPE_MAX_RANK)
	_check(choices.size() == 3, "shop offers 3 choices")
	var has_rank_up: bool = false
	for c in choices:
		if str((c as Dictionary).get("id", "")) == "rank_up":
			has_rank_up = true
	_check(has_rank_up, "shop offers rank_up below cap")
	_check(UpgradeDB.UPGRADES.size() >= 6, "at least 6 relic upgrades defined")

	# Scoring + mult snowball
	run.start_new_run()
	var pts: int = run.score_for_event("foundation", CardData.new(14, 0))
	_check(pts >= RankSystem.chip_value(14), "Emperor foundation scores at least its chip value")
	_check(run.streak == 1, "foundation play builds streak")

	# --- Rank levels affect foundation scoring ---
	var run2: RunManager = RunManager.new()
	run2.rng.seed = 4242
	run2.start_new_run()
	var king_plain: CardData = CardData.new(13, 0)
	run2.score_for_event("foundation", king_plain)
	var plain_base: int = int(run2.last_breakdown.get("base_chips", 0))
	run2.upgrade_rank(13, 2) # Kings to level 3
	_check(run2.rank_level(13) == 3, "rank upgrade raises Kings to level 3")
	run2.score_for_event("foundation", CardData.new(13, 1))
	_check(int(run2.last_breakdown.get("base_chips", 0)) == plain_base + 20, "level 3 Kings score +20 base chips vs level 1")
	_check(int(run2.last_breakdown.get("combo_bonus", 0)) > 5, "combo bonus scales with rank level")

	# --- Combo chain builds on same rank, breaks on a different rank ---
	var run3: RunManager = RunManager.new()
	run3.rng.seed = 777
	run3.start_new_run()
	run3.score_for_event("foundation", CardData.new(5, 0))
	run3.score_for_event("foundation", CardData.new(5, 1))
	_check(run3.combo_rank == 5 and run3.combo_chain == 2, "two 5s build a x2 combo chain")
	run3.score_for_event("foundation", CardData.new(6, 0))
	_check(bool(run3.last_breakdown.get("broke", false)) and run3.combo_rank == 6 and run3.combo_chain == 1, "different rank breaks combo and starts a new chain")

	# --- Prism counts double for the chain ---
	run3.score_for_event("foundation", CardData.new(6, 2))
	var prism_card: CardData = CardData.new(6, 3)
	prism_card.enhancement = "prism"
	run3.score_for_event("foundation", prism_card)
	_check(run3.combo_chain == 4, "prism card adds 2 to the combo chain (got %d)" % run3.combo_chain)

	# --- Bonus enhancement is deterministic: +30 enhancement chips ---
	var bonus_card: CardData = CardData.new(7, 0)
	bonus_card.enhancement = "bonus"
	run3.score_for_event("foundation", bonus_card)
	_check(int(run3.last_breakdown.get("enh_chips", 0)) == 30, "Bonus enhancement adds exactly +30 chips")

	# --- Wild enhancement counts as any colour on the tableau ---
	var board2: SolitaireBoard = SolitaireBoard.new()
	var red_top: CardData = CardData.new(5, 1, true)
	var red_wild: CardData = CardData.new(4, 2, true)
	red_wild.enhancement = "wild"
	_check(board2.can_place_on_tableau(red_wild, [red_top]), "wild red 4 can be placed on red 5")
	var red_plain2: CardData = CardData.new(4, 2, true)
	_check(not board2.can_place_on_tableau(red_plain2, [red_top]), "plain red 4 still cannot be placed on red 5")

	# --- Shop guarantees rank and enhancement variety ---
	var choices2: Array = UpgradeDB.build_shop_choices(13, [], 3, run3.rng, RunManager.PROTOTYPE_MAX_RANK)
	var kinds: Array = []
	for c2 in choices2:
		kinds.append(str((c2 as Dictionary).get("kind", "")))
	_check(kinds.has("enhancement"), "shop offers an enhancement item")
	_check(kinds.has("rank_up") or kinds.has("rank_upgrade"), "shop offers a rank upgrade item")

	# --- Boss blinds: every 3rd ante, twists cycle ---
	_check(run3.boss_twist(3).get("id", "") == "half_hearts", "ante 3 boss is Half Hearts")
	_check(run3.boss_twist(4).is_empty(), "ante 4 is not a boss")
	_check(run3.boss_twist(6).get("id", "") == "no_redeals", "ante 6 boss is No Redeals")
	_check(UpgradeDB.UPGRADES.size() >= 14, "expanded relic pool (got %d)" % UpgradeDB.UPGRADES.size())
	_check(EnhancementDB.ENHANCEMENTS.size() >= 4, "at least 4 enhancements defined")

	run2.free()
	run3.free()
	run.free()
	if _failures == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		printerr("%d TEST(S) FAILED" % _failures)
		quit(1)
