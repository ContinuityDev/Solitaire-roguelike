class_name UpgradeDB
extends RefCounted

## Data-driven upgrade / relic definitions.
## To add an upgrade: append one Dictionary here. Fields:
##   id          unique StringName-ish id (String)
##   name        display name
##   icon        short text glyph shown on the shop card
##   desc        player-facing description
##   unique      true = can only be taken once per run
##   kind        "relic" | "rank_up" (rank_up is generated dynamically)
## Effects are read by RunManager / SolitaireBoard / Main via the id, e.g.
## RunManager.has_upgrade("wild_low"). Keep effects keyed by id in one place:
##   - scoring hooks:  RunManager.score_for_event()
##   - rules hooks:    SolitaireBoard.can_place_on_tableau()
##   - setup hooks:    Main.start_round()

const UPGRADES: Array = [
	{
		"id": "gilded_gloves",
		"name": "White Gloves",
		"icon": "+X",
		"desc": "+1 permanent Flair for the rest of the run.",
		"unique": false,
		"kind": "relic",
	},
	{
		"id": "royal_tithe",
		"name": "House Tithe",
		"icon": "TAX",
		"desc": "+0.25 Flair for every 8 cards on finale piles (this trick).",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "extra_redeal",
		"name": "Second Wind (Vanish & Return)",
		"icon": "RE",
		"desc": "+1 stock redeal every round.",
		"unique": false,
		"kind": "relic",
	},
	{
		"id": "wild_low",
		"name": "Sprouting Wand",
		"icon": "WILD",
		"desc": "Aces and 2s are wild on the tableau: they ignore colour when placed.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "metronome",
		"name": "Metronome",
		"icon": "CLK",
		"desc": "Every successful move scores +10 extra applause.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "wide_table",
		"name": "Wider Stage",
		"icon": "+COL",
		"desc": "+1 tableau column from the next round onward.",
		"unique": false,
		"kind": "relic",
	},
	{
		"id": "peek_stock",
		"name": "Sleight Specs",
		"icon": "EYE",
		"desc": "Peek at the top 3 cards of the stock.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "high_roller",
		"name": "Grand Showman",
		"icon": "HI",
		"desc": "Finale plays of Jack-or-higher cards score double applause.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "turncoat",
		"name": "Quick-Change Coat",
		"icon": "FLIP",
		"desc": "Revealing a face-down tableau card scores 40 applause (was 15).",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "streak_oil",
		"name": "Stardust Oil",
		"icon": "OIL",
		"desc": "Your finale streak builds Flair twice as fast.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "grace_chain",
		"name": "Safety Line",
		"icon": "GRACE",
		"desc": "Your encore chain survives one off-rank finale play per chain.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "chain_resonator",
		"name": "Echoing Hall",
		"icon": "RES",
		"desc": "Encore bonus applause is doubled.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "foil_press",
		"name": "Gold-Leaf Press",
		"icon": "FOIL",
		"desc": "Enchanted cards score +20 extra applause on finale piles.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "prism_lens",
		"name": "Crystal Lens",
		"icon": "LENS",
		"desc": "Crystal cards also give +0.5 Flair when played to a finale pile.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "hearts_sigil",
		"name": "Hearts Charm",
		"icon": "H+",
		"desc": "Hearts score +15 applause on finale piles.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "spades_sigil",
		"name": "Spades Charm",
		"icon": "S+",
		"desc": "Spades score +15 applause on finale piles.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "royal_mentor",
		"name": "Maestro Mentor",
		"icon": "TCHR",
		"desc": "Rank-polish rewards grant +1 extra level of stagecraft.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "tableau_tutor",
		"name": "Stagehand Tutor",
		"icon": "TUTR",
		"desc": "Tableau and waste moves no longer reset your streak (the show must go on).",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "pattern_fan",
		"name": "Encore Bunting",
		"icon": "TRK",
		"desc": "Every Pattern (Natural Run, Book of Four, Breakout...) pays +50% applause.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "silk_rope",
		"name": "Silk Rope",
		"icon": "ROPE",
		"desc": "Natural Runs and Silk Ropes pay double applause.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "bookbinder",
		"name": "Bookbinder's Mallet",
		"icon": "BOOK",
		"desc": "Books of Four pay +50% — and completing any Pattern still cracks Brick Walls.",
		"unique": true,
		"kind": "relic",
	},
	{
		"id": "sprout_fertilizer",
		"name": "Magic Bean Dust",
		"icon": "FERT",
		"desc": "Wild-enchanted cards score +15 applause on finale piles.",
		"unique": true,
		"kind": "relic",
	},
]

static func get_by_id(id: String) -> Dictionary:
	for u in UPGRADES:
		if str(u["id"]) == id:
			return u
	return {}

static func rank_single_offer(max_rank: int, rng: RandomNumberGenerator) -> Dictionary:
	var target: int = rng.randi_range(1, maxi(1, max_rank))
	return {
		"id": "rank_single", "name": "Polish: %s" % RankSystem.full_name(target), "icon": "LV+",
		"desc": "%s gains +1 level of stagecraft (encore and applause bonuses grow)." % RankSystem.full_name(target),
		"unique": false, "kind": "rank_upgrade", "target_rank": target, "amount": 1,
	}

static func rank_low_double_offer(max_rank: int, rng: RandomNumberGenerator) -> Dictionary:
	var target: int = rng.randi_range(1, mini(5, maxi(1, max_rank)))
	return {
		"id": "rank_low_double", "name": "Fast Study: %s" % RankSystem.full_name(target), "icon": "LV2",
		"desc": "A low rank gains +2 levels of stagecraft: %s levels up twice." % RankSystem.full_name(target),
		"unique": false, "kind": "rank_upgrade", "target_rank": target, "amount": 2,
	}

static func court_training_offer(max_rank: int) -> Dictionary:
	return {
		"id": "court_training", "name": "Court Rehearsal", "icon": "LVQ",
		"desc": "Jack, Queen and King each gain +1 level of stagecraft (for ranks in your deck).",
		"unique": false, "kind": "rank_upgrade",
	}

static func enhance_random_offer() -> Dictionary:
	return {
		"id": "enhance_random", "name": "Enchantment: Random Charm", "icon": "ENH",
		"desc": "A random card in your deck gains a random enchantment (Gilded / Sparkle / Wild / Rabbit's Foot / Crystal), permanently.",
		"unique": false, "kind": "enhancement",
	}

static func rank_up_offer(max_rank: int) -> Dictionary:
	var lo: int = max_rank + 1
	var hi: int = max_rank + 2
	return {
		"id": "rank_up",
		"name": "Raise the Curtain Cast",
		"icon": "UP",
		"desc": "Add ranks %s and %s (all 4 suits, 8 cards) to your cast from the next trick on." % [RankSystem.full_name(lo), RankSystem.full_name(hi)],
		"unique": false,
		"kind": "rank_up",
	}

## Build a shop offer: always offer rank_up (while below the prototype cap)
## plus random relics the player does not already own (if unique).
static func build_shop_choices(max_rank: int, owned: Array, count: int, rng: RandomNumberGenerator, prototype_max_rank: int) -> Array:
	# Guaranteed spread: one deck/rank slot, one enhancement slot, then a
	# mixed slot (relics + more rank upgrades), so the new systems are
	# always visible in the shop alongside relics.
	var choices: Array = []
	if max_rank < prototype_max_rank:
		choices.append(rank_up_offer(max_rank))
	else:
		choices.append(rank_single_offer(max_rank, rng))
	choices.append(enhance_random_offer())
	var pool: Array = []
	for u in UPGRADES:
		if bool(u["unique"]) and owned.has(str(u["id"])):
			continue
		pool.append(u)
	pool.append(rank_single_offer(max_rank, rng))
	pool.append(rank_low_double_offer(max_rank, rng))
	if max_rank >= 11:
		pool.append(court_training_offer(max_rank))
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for u in pool:
		if choices.size() >= count:
			break
		choices.append(u)
	return choices
