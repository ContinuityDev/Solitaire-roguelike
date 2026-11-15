class_name RunManager
extends Node

## Owns roguelike run state: ante/blind progression, score, Mult, streak,
## owned upgrades, deck escalation (max_rank), per-rank levels, the combo
## chain, per-card enhancements, and Boss blind twists.
##
## FOUNDATION SCORING FORMULA (data-driven, all in score_for_event):
##   base_chips   = RankSystem.chip_value(rank)         (rank*10, +15/rank past K)
##                + (rank_level - 1) * 10               (rank-upgrade value)
##                + enhancement chips (Bonus +30 / Prism +20 / Lucky proc +50)
##                + relic chips (sigils +15, Foil Press +20 on enhanced, ...)
##   combo_bonus  = combo_chain * rank_level(rank) * COMBO_CHIP_PER_CHAIN (5)
##                  (x2 with Chain Resonator; Prism cards add 2 to the chain;
##                   on a Boss "High Chain" blind it only pays at chain >= 3)
##   points       = round( (base_chips + combo_bonus) * mult_used )
##   mult_used    = effective_mult() + enhancement Mult (Mult +0.5,
##                  Lucky proc +0.5, Prism Lens +0.5 on Prism cards)
##   Boss "Half Hearts": points are halved for Hearts foundation plays.
## Combo: consecutive foundation plays of the SAME rank build the chain.
## A different-rank foundation play breaks it (and starts a new chain at 1),
## unless Grace Chain (relic) saves it once per chain. Tableau moves do NOT
## break the combo (they do reset the separate streak, unless Tableau Tutor).

signal score_changed
signal run_lost
signal run_won

const PROTOTYPE_MAX_RANK: int = 20
const START_MAX_RANK: int = 5
const COMBO_CHIP_PER_CHAIN: int = 5
const RANK_LEVEL_CHIP_BONUS: int = 10

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var ante: int = 1
var max_ante: int = 8
var score: int = 0
var target: int = 0
var base_mult: float = 1.0
var streak: int = 0
var moves: int = 0
var foundation_this_round: int = 0
var max_rank: int = START_MAX_RANK
var owned_upgrades: Array = []
var round_active: bool = false
var run_over: bool = false
var endless: bool = false

# Rank upgrades: rank:int -> level:int (every rank starts at level 1).
var rank_levels: Dictionary = {}
# Card enhancements: "rank:suit" -> EnhancementDB id. Persist all run.
var enhancement_assignments: Dictionary = {}
# Combo chain state.
var combo_rank: int = 0 # 0 = no active chain
var combo_chain: int = 0
var combo_grace_available: bool = true
var last_breakdown: Dictionary = {}
var last_broken_chain: int = 0

func _ready() -> void:
	rng.randomize()

func start_new_run() -> void:
	ante = 1
	base_mult = 1.0
	max_rank = START_MAX_RANK
	owned_upgrades.clear()
	rank_levels.clear()
	enhancement_assignments.clear()
	run_over = false
	endless = false
	start_round()

# Pattern state (reset each round): foundation play sequence, reveal
# streak, per-Act pattern counts, and anti-farming tableau signatures.
var foundation_history: Array = [] # [{rank, suit, red}]
var flips_since_draw: int = 0
var patterns_this_round: Dictionary = {} # pattern id -> count
var awarded_tableau_patterns: Dictionary = {} # "id|column|signature" -> true
var book_done_this_round: bool = false
var books_completed: Dictionary = {} # rank:int -> true, so Book fires once per rank
var metrics: Dictionary = {"patterns": 0, "walls_opened": 0, "dead_boards": 0, "acts_played": 0}

func start_round() -> void:
	score = 0
	streak = 0
	moves = 0
	foundation_this_round = 0
	foundation_history.clear()
	flips_since_draw = 0
	patterns_this_round.clear()
	awarded_tableau_patterns.clear()
	book_done_this_round = false
	books_completed.clear()
	metrics["acts_played"] = int(metrics["acts_played"]) + 1
	combo_rank = 0
	combo_chain = 0
	combo_grace_available = true
	last_breakdown = {}
	last_broken_chain = 0
	target = target_for_ante(ante)
	round_active = true
	score_changed.emit()

func target_for_ante(a: int) -> int:
	return int(round(240.0 * pow(float(a), 1.45))) + (a - 1) * 60

# ------------------------------------------------------------ boss blinds

func is_boss_ante(a: int = -1) -> bool:
	var x: int = ante if a < 0 else a
	return x % 3 == 0

## Boss twist for an ante, or {} if not a boss. Twists cycle every 3rd ante.
func boss_twist(a: int = -1) -> Dictionary:
	var x: int = ante if a < 0 else a
	if not is_boss_ante(x):
		return {}
	var twists: Array = [
		{"id": "half_hearts", "name": "Sawed in Half", "desc": "The old sawing trick, with a twist: Hearts played to finale piles earn half applause."},
		{"id": "no_redeals", "name": "No Safety Net", "desc": "High above the stage with no net: no stock redeals this trick."},
		{"id": "high_chain", "name": "Death-Defying Encore", "desc": "The crowd only rewards a truly daring act: encore bonus only pays at chain 3 or more."},
	]
	return twists[(x / 3 - 1) % twists.size()]

func boss_id() -> String:
	return str(boss_twist().get("id", ""))

# ------------------------------------------------------------ ranks

func rank_level(rank: int) -> int:
	return int(rank_levels.get(rank, 1))

func upgrade_rank(rank: int, amount: int) -> void:
	if rank < 1:
		return
	rank_levels[rank] = rank_level(rank) + amount
	score_changed.emit()

# ------------------------------------------------------------ upgrades

func has_upgrade(id: String) -> bool:
	return owned_upgrades.has(id)

func count_upgrade(id: String) -> int:
	var n: int = 0
	for u in owned_upgrades:
		if str(u) == id:
			n += 1
	return n

func apply_upgrade(id: String) -> void:
	if id == "rank_up":
		max_rank = mini(max_rank + 2, PROTOTYPE_MAX_RANK)
		return
	owned_upgrades.append(id)
	if id == "gilded_gloves":
		base_mult += 1.0
	score_changed.emit()

## Apply any shop choice Dictionary (relic, rank_up, rank-level, enhancement).
## Returns a human-readable result string for the UI message.
func apply_shop_choice(choice: Dictionary) -> String:
	var id: String = str(choice.get("id", ""))
	match id:
		"rank_up":
			apply_upgrade(id)
			return "Your cast grows to A-%s." % RankSystem.full_name(max_rank)
		"rank_single", "rank_low_double":
			var target_rank: int = int(choice.get("target_rank", max_rank))
			var amount: int = int(choice.get("amount", 1))
			if has_upgrade("royal_mentor"):
				amount += 1 # Royal Mentor: rank upgrades grant +1 extra level
			upgrade_rank(target_rank, amount)
			return "%s is now level %d." % [RankSystem.full_name(target_rank), rank_level(target_rank)]
		"court_training":
			for r in [11, 12, 13]:
				if r <= max_rank:
					upgrade_rank(r, 1)
			return "Jack, Queen and King each gain a level of stagecraft."
		"enhance_random":
			var applied: Dictionary = grant_random_enhancement()
			if applied.is_empty():
				return "Every card is already enchanted!"
			return "Enchanted %s with %s (in your deck from now on)." % [
				(applied["card"] as CardData).display_name(), EnhancementDB.display_name(str(applied["enhancement"]))]
		_:
			apply_upgrade(id)
			return "Added to your prop case: %s." % str(choice.get("name", id))

## Grant a random enhancement to a random not-yet-enhanced card identity
## in the current deck. Returns {"card": CardData, "enhancement": id} or {}.
func grant_random_enhancement() -> Dictionary:
	var free_keys: Array = []
	for rank in range(1, max_rank + 1):
		for suit in range(4):
			var key: String = "%d:%d" % [rank, suit]
			if not enhancement_assignments.has(key):
				free_keys.append(key)
	if free_keys.is_empty():
		return {}
	var key2: String = str(free_keys[rng.randi_range(0, free_keys.size() - 1)])
	var parts: PackedStringArray = key2.split(":")
	var enh: String = EnhancementDB.random_id(rng)
	enhancement_assignments[key2] = enh
	score_changed.emit()
	return {"card": CardData.new(int(parts[0]), int(parts[1])), "enhancement": enh}

func extra_columns() -> int:
	return count_upgrade("wide_table")

func redeals_for_round() -> int:
	if boss_id() == "no_redeals":
		return 0
	# Act band: from Act 7 the stock no longer recycles for free;
	# Second Wind props still restore redeals on top of the band.
	var base: int = 1 if ante < 7 else 0
	return base + count_upgrade("extra_redeal")

## Board-changing Act bands (the scaling curve beyond target numbers):
## Acts 1-2 teach on clean boards, Act 3 raises the first Wall with its
## Grand Illusion, mid Acts rotate wall kinds, late Acts raise two walls.
func act_board_config(a: int = -1) -> Dictionary:
	var x: int = ante if a < 0 else a
	var kinds: Array = []
	match x:
		1, 2:
			kinds = []
		3:
			kinds = ["brick"]
		4:
			kinds = ["cracked"]
		5:
			kinds = ["iron"]
		6:
			kinds = ["brick", "cracked"]
		7:
			kinds = ["iron", "cracked"]
		_:
			var cycle: Array = [["iron", "brick"], ["cracked", "curtain"], ["brick", "iron"]]
			kinds = cycle[(x - 8) % cycle.size()]
	var specs: Array = []
	var names: Dictionary = {"brick": "Brick Wall", "cracked": "Cracked Wall", "iron": "Iron Wall", "curtain": "Curtain Wall"}
	for k in kinds:
		specs.append({"kind": str(k), "name": str(names.get(str(k), "Wall"))})
	var bury: int = 0
	if x >= 7:
		bury = 2
	elif x >= 4:
		bury = 1
	var band: String = "clean"
	if x == 3:
		band = "first_wall"
	elif x >= 4 and x <= 5:
		band = "walls"
	elif x >= 6:
		band = "double_walls"
	return {"wall_specs": specs, "band": band, "bury": bury}

# ------------------------------------------------------------ patterns

## Award a pattern once detected. Returns Applause points granted.
func register_pattern(id: String) -> int:
	if PatternDB.get_by_id(id).is_empty():
		return 0
	var pts: float = float(PatternDB.base_reward(id))
	if has_upgrade("pattern_fan"):
		pts *= 1.5
	if has_upgrade("silk_rope") and (id == "rope" or id == "natural_run"):
		pts *= 2.0
	if has_upgrade("bookbinder") and id == "book":
		pts *= 1.5
	var points: int = int(round(pts * effective_mult()))
	score += points
	patterns_this_round[id] = int(patterns_this_round.get(id, 0)) + 1
	metrics["patterns"] = int(metrics["patterns"]) + 1
	if id == "book":
		book_done_this_round = true
	score_changed.emit()
	return points

## Record a foundation (finale) play AFTER it lands; returns pattern ids
## it completed (Book / Staircase / Suit Surge / Mirror Pair).
func register_foundation_play(card: CardData, board: SolitaireBoard) -> Array:
	var found: Array = []
	foundation_history.append({"rank": card.rank, "suit": card.suit, "red": card.is_red()})
	var n: int = foundation_history.size()
	if n >= 2:
		var prev: Dictionary = foundation_history[n - 2]
		if int(prev["rank"]) == card.rank and bool(prev["red"]) != card.is_red():
			found.append("mirror_pair")
	if n >= 3:
		var a: Dictionary = foundation_history[n - 3]
		var b: Dictionary = foundation_history[n - 2]
		if int(a["suit"]) == card.suit and int(b["suit"]) == card.suit:
			found.append("suit_surge")
	if n >= 4:
		var asc: bool = true
		for i in range(n - 3, n):
			if int(foundation_history[i]["rank"]) != int(foundation_history[i - 1]["rank"]) + 1:
				asc = false
				break
		if asc:
			found.append("staircase")
	# Book: all four suits now reach this rank, and this play was the card
	# that completed it (this suit's pile top is exactly this rank).
	if board != null and not books_completed.has(card.rank):
		var complete: bool = true
		for s in range(4):
			if board.foundation_pile(s).size() < card.rank:
				complete = false
				break
		if complete and board.foundation_pile(card.suit).size() == card.rank:
			found.append("book")
			books_completed[card.rank] = true
	return found

## A face-down card flipped. Returns true when Excavation (3 in a row
## without a stock draw) completes.
func register_flip() -> bool:
	flips_since_draw += 1
	if flips_since_draw >= 3:
		flips_since_draw = 0
		return true
	return false

func note_draw() -> void:
	flips_since_draw = 0

func note_dead_board() -> void:
	metrics["dead_boards"] = int(metrics["dead_boards"]) + 1
	print("[metrics] dead board at Act ", ante, " metrics=", metrics)

func patterns_text() -> String:
	if patterns_this_round.is_empty():
		return "Tricks performed: none yet — build a run, book a rank, crack a wall."
	var parts: Array[String] = []
	for id in patterns_this_round.keys():
		parts.append("%s x%d" % [PatternDB.display_name(str(id)), int(patterns_this_round[id])])
	return "Tricks performed: " + ", ".join(parts)

func effective_mult() -> float:
	var m: float = base_mult
	var streak_step: int = 2 if has_upgrade("streak_oil") else 4
	m += float(streak / streak_step) * 0.5
	if has_upgrade("royal_tithe"):
		m += float(foundation_this_round / 8) * 0.25
	return m

# ------------------------------------------------------------ scoring

func score_for_event(event: String, card: CardData = null) -> int:
	if not round_active:
		return 0
	moves += 1
	var chips: int = 0
	var mult_used: float = effective_mult()
	last_breakdown = {}
	match event:
		"foundation":
			streak += 1
			foundation_this_round += 1
			var breakdown: Dictionary = _score_foundation(card)
			score += int(breakdown["points"])
			score_changed.emit()
			return int(breakdown["points"])
		"flip":
			chips = 40 if has_upgrade("turncoat") else 15
		"tableau_move", "waste_to_tableau":
			if not has_upgrade("tableau_tutor"):
				streak = 0
			chips = 5
		"foundation_to_tableau", "draw":
			if not has_upgrade("tableau_tutor"):
				streak = 0
			chips = 0
		_:
			chips = 0
	if has_upgrade("metronome") and event != "draw":
		chips += 10
	var points: int = int(round(float(chips) * mult_used)) if chips > 0 else 0
	score += points
	score_changed.emit()
	return points

func _score_foundation(card: CardData) -> Dictionary:
	last_broken_chain = 0
	var broke: bool = false
	var used_grace: bool = false
	if card == null:
		last_breakdown = {"points": 0}
		return last_breakdown
	# --- combo chain update ---
	var chain_add: int = 2 if card.enhancement == "prism" else 1
	if combo_rank == 0 or combo_rank == card.rank:
		combo_rank = card.rank
		combo_chain += chain_add
	elif has_upgrade("grace_chain") and combo_grace_available:
		combo_grace_available = false
		used_grace = true
		combo_rank = card.rank
		combo_chain += chain_add
	else:
		broke = true
		last_broken_chain = combo_chain
		combo_rank = card.rank
		combo_chain = chain_add
		combo_grace_available = true
	# --- chips ---
	var level: int = rank_level(card.rank)
	var base_chips: int = card.chip_value() + (level - 1) * RANK_LEVEL_CHIP_BONUS
	if has_upgrade("high_roller") and card.rank >= 11:
		base_chips *= 2
	var enh_chips: int = 0
	var extra_mult: float = 0.0
	var lucky_proc: bool = false
	match card.enhancement:
		"bonus":
			enh_chips += 30
		"prism":
			enh_chips += 20
			if has_upgrade("prism_lens"):
				extra_mult += 0.5
		"mult":
			extra_mult += 0.5
		"lucky":
			if rng.randf() < 0.25:
				lucky_proc = true
				enh_chips += 50
				extra_mult += 0.5
	if card.enhancement != "" and has_upgrade("foil_press"):
		enh_chips += 20
	if card.suit == 1 and has_upgrade("hearts_sigil"):
		enh_chips += 15
	if card.suit == 0 and has_upgrade("spades_sigil"):
		enh_chips += 15
	if card.enhancement == "wild" and has_upgrade("sprout_fertilizer"):
		enh_chips += 15
	# --- combo bonus ---
	var combo_bonus: int = 0
	if not (boss_id() == "high_chain" and combo_chain < 3):
		combo_bonus = combo_chain * level * COMBO_CHIP_PER_CHAIN
		if has_upgrade("chain_resonator"):
			combo_bonus *= 2
	var subtotal: int = base_chips + enh_chips + combo_bonus
	if has_upgrade("metronome"):
		subtotal += 10
	var mult_used: float = effective_mult() + extra_mult
	var points: int = int(round(float(subtotal) * mult_used))
	if boss_id() == "half_hearts" and card.suit == 1:
		points = points / 2
	last_breakdown = {
		"points": points, "base_chips": base_chips, "enh_chips": enh_chips,
		"combo_bonus": combo_bonus, "combo_rank": combo_rank, "combo_chain": combo_chain,
		"rank_level": level, "mult_used": mult_used, "broke": broke,
		"broken_chain": last_broken_chain, "used_grace": used_grace, "lucky_proc": lucky_proc,
		"enhancement": card.enhancement,
	}
	return last_breakdown

func combo_text() -> String:
	if combo_rank == 0 or combo_chain == 0:
		return "Encore: -"
	return "Encore: %s x%d (Lv%d) +%d applause" % [
		RankSystem.full_name(combo_rank), combo_chain, rank_level(combo_rank),
		combo_chain * rank_level(combo_rank) * COMBO_CHIP_PER_CHAIN * (2 if has_upgrade("chain_resonator") else 1)]

func board_clear_bonus() -> int:
	var points: int = int(round(float(300 * ante) * effective_mult()))
	score += points
	score_changed.emit()
	return points

func round_won_check(board_cleared: bool) -> bool:
	return board_cleared or score >= target

func advance_after_win() -> void:
	round_active = false
	if ante >= max_ante and not endless:
		run_won.emit()
	else:
		ante += 1

func fail_run() -> void:
	round_active = false
	run_over = true
	run_lost.emit()
