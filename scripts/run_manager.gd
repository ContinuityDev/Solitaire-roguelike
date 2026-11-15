class_name RunManager
extends Node

## Endless President run: HP, gold, Survivor Chips, escalating stake/ranks,
## owned upgrades, rank customizations. Human vs AI is LobbyConfig.
## The run never "wins" — it continues until every human hits 0 HP.
## Arc: chip/gold synergies snowball early–mid; ante/stake outpace late.

signal changed

const SEATS: int = 6
const START_HP: int = 50
const NAMES: Array = ["You", "The Speaker", "The Whip", "The Veep", "The Justice", "The General"]
## index = place 1..6. Tight: 1st $2 … 6th $9. Mid-run you cannot buy the desk.
const GOLD_BY_PLACE: Array = [0, 2, 3, 4, 5, 7, 9]
const STREAK_UNIT: int = 3 # bonus gold = STREAK_UNIT * (streak - 1)
const BEST_PATH: String = "user://president_best.cfg"
## Dead AI seats return with this much HP (scaled up by stake) so the table
## never collapses into a last-seat "win".
const AI_REVIVE_BASE: int = 20
## Base Survivor Chips granted to each living human per AI knockout.
const CHIP_PER_KO: int = 1

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var round_n: int = 1
var seat_gold: Array = []
var seat_chips: Array = [] ## Survivor Chips — second upgrade currency (humans)
var seat_max_hp: Array = []
var seat_upgrades: Array = []
var seat_actions: Array = []
var seat_enhancements: Array = []
var seat_favorite: Array = []
var seat_rank_mods: Array = [] # Array of Array of {rank, effect} — legacy gold binds
var seat_rank_effects: Array = [] # Array of Array of {rank, effect, level} — chip customizations
var hp: Array = [] # 6 ints
var whip_used: bool = false
var last_payout: Array = [] # [{seat, place, gold, hp_delta, name, role, chips}]
var last_first: int = 0 # previous round's President; leads the next deal
var last_finish: Array = [] # finish order; roles/trades read from living seats
var last_knockouts: Array = [] # AI seats that hit 0 HP this payout
var cancelled_tribute_seats: Array = [] # givers who JSN/pardon
var skip_tributes: bool = false
var trade_log: Array = []
var last_role: String = "" # your role last round, for Populist
var last_roles: Array = [] # role string per seat
var role_streak_role: Array = [] # last finish role per seat
var role_streak_len: Array = [] # consecutive count per seat
var shop_offers: Array = []
var shop_rerolls: int = 0
var shop_seat: int = 0
var shop_phase: bool = false ## AIs may buy only while the desk is open
var run_over: bool = false
var run_won: bool = false
var lobby: LobbyConfig = null
var seat_count: int = 6
var human_seats: Array = [0]
var seat_names: Array = []

var gold: int:
	get:
		return gold_of(0)
	set(value):
		_ensure_seat_arrays()
		seat_gold[0] = value

var chips: int:
	get:
		return chips_of(0)
	set(value):
		_ensure_seat_arrays()
		seat_chips[0] = value

var max_hp: int:
	get:
		_ensure_seat_arrays()
		return int(seat_max_hp[0])
	set(value):
		_ensure_seat_arrays()
		seat_max_hp[0] = value

var owned_upgrades: Array:
	get:
		_ensure_seat_arrays()
		return seat_upgrades[0]
	set(value):
		_ensure_seat_arrays()
		seat_upgrades[0] = value

var actions: Array:
	get:
		_ensure_seat_arrays()
		return seat_actions[0]
	set(value):
		_ensure_seat_arrays()
		seat_actions[0] = value

var owned_enhancements: Array:
	get:
		_ensure_seat_arrays()
		return seat_enhancements[0]
	set(value):
		_ensure_seat_arrays()
		seat_enhancements[0] = value

var favorite_rank: int:
	get:
		return favorite_of(0)
	set(value):
		_ensure_seat_arrays()
		seat_favorite[0] = value

func _ready() -> void:
	rng.randomize()

func _ensure_seat_arrays() -> void:
	while seat_gold.size() < SEATS:
		seat_gold.append(0)
	while seat_chips.size() < SEATS:
		seat_chips.append(0)
	while seat_max_hp.size() < SEATS:
		seat_max_hp.append(START_HP)
	while seat_upgrades.size() < SEATS:
		seat_upgrades.append([])
	while seat_actions.size() < SEATS:
		seat_actions.append([])
	while seat_enhancements.size() < SEATS:
		seat_enhancements.append([])
	while seat_favorite.size() < SEATS:
		seat_favorite.append(0)
	while seat_rank_mods.size() < SEATS:
		seat_rank_mods.append([])
	while seat_rank_effects.size() < SEATS:
		seat_rank_effects.append([])
	while last_roles.size() < SEATS:
		last_roles.append("")

func is_human(seat: int) -> bool:
	return human_seats.has(seat)

func is_ai(seat: int) -> bool:
	return seat >= 0 and seat < seat_count and not is_human(seat)

func name_of(seat: int) -> String:
	if seat >= 0 and seat < seat_names.size() and str(seat_names[seat]) != "":
		return str(seat_names[seat])
	if seat >= 0 and seat < NAMES.size():
		return str(NAMES[seat])
	return "Seat %d" % seat

func living_humans() -> Array:
	var out: Array = []
	for s in living_seats():
		if is_human(int(s)):
			out.append(int(s))
	return out

func start_new_run(config = null) -> void:
	var cfg: LobbyConfig = config as LobbyConfig
	if cfg == null:
		cfg = LobbyConfig.solo()
	lobby = cfg
	seat_count = clampi(cfg.seat_count, 2, SEATS)
	human_seats = cfg.human_seats().duplicate()
	if human_seats.is_empty():
		human_seats = [0]
	seat_names = cfg.display_names.duplicate()
	while seat_names.size() < SEATS:
		seat_names.append("")
	round_n = 1
	seat_gold = []
	seat_chips = []
	seat_max_hp = []
	seat_upgrades = []
	seat_actions = []
	seat_enhancements = []
	seat_favorite = []
	seat_rank_mods = []
	seat_rank_effects = []
	hp = []
	last_roles = []
	for i in range(SEATS):
		seat_gold.append(0)
		seat_chips.append(0)
		seat_max_hp.append(START_HP)
		seat_upgrades.append([])
		seat_actions.append([])
		seat_enhancements.append([])
		seat_favorite.append(0)
		seat_rank_mods.append([])
		seat_rank_effects.append([])
		last_roles.append("")
		if i < seat_count:
			hp.append(START_HP)
		else:
			hp.append(0)
	_grant_ai_specialties()
	whip_used = false
	last_payout.clear()
	last_first = 0
	last_finish.clear()
	last_knockouts.clear()
	cancelled_tribute_seats.clear()
	skip_tributes = false
	trade_log.clear()
	last_role = ""
	role_streak_role.clear()
	role_streak_len.clear()
	for _s in range(SEATS):
		role_streak_role.append("")
		role_streak_len.append(0)
	shop_offers.clear()
	shop_rerolls = 0
	shop_seat = 0
	shop_phase = false
	run_over = false
	run_won = false
	changed.emit()

func _grant_ai_specialties() -> void:
	for seat in range(seat_count):
		if not is_ai(seat):
			continue
		var spec: Dictionary = {}
		if RankModDB.AI_SPEC.has(seat):
			spec = RankModDB.AI_SPEC[seat]
		else:
			spec = RankModDB.AI_SPEC[1]
		(seat_rank_mods[seat] as Array).append(RankModDB.make(int(spec["rank"]), str(spec["effect"])))

func living_seats() -> Array:
	var out: Array = []
	for i in range(SEATS):
		if int(hp[i]) > 0:
			out.append(i)
	return out

func is_alive(seat: int) -> bool:
	return int(hp[seat]) > 0

## Balatro-ish ante index (1-based). Bumps every 3 rounds.
func ante() -> int:
	return int((round_n - 1) / 3) + 1

## HP stake for the round. Early is gentle; late ante + late-round tax outpaces snowballs.
## Round 1 → 6, Round 4 → 13, Round 10 → 27, Round 20 → 55, …
func stake() -> int:
	var late: int = int((round_n - 1) / 5) * 2
	return 5 + round_n + (ante() - 1) * 3 + late

## Follow-power added to every dealt card this round (physical rank inflation).
## Round 1 → 0; accelerates so faces hit K/M while stake climbs faster than economy.
## Round 2 → 1, Round 5 → 7, Round 10 → 24, Round 20 → 82, Round 40 → 299, …
func rank_bonus() -> int:
	var r: int = round_n - 1
	if r <= 0:
		return 0
	return r + int((r * r) / 6)

func gold_of(seat: int) -> int:
	_ensure_seat_arrays()
	return int(seat_gold[seat])

func chips_of(seat: int) -> int:
	_ensure_seat_arrays()
	return int(seat_chips[seat])

func add_gold(seat: int, n: int) -> void:
	_ensure_seat_arrays()
	seat_gold[seat] = int(seat_gold[seat]) + n

func add_chips(seat: int, n: int) -> void:
	if n == 0:
		return
	_ensure_seat_arrays()
	seat_chips[seat] = maxi(0, int(seat_chips[seat]) + n)

func favorite_of(seat: int) -> int:
	_ensure_seat_arrays()
	return int(seat_favorite[seat])

func upgrades_of(seat: int) -> Array:
	_ensure_seat_arrays()
	return seat_upgrades[seat]

func actions_of(seat: int) -> Array:
	_ensure_seat_arrays()
	return seat_actions[seat]

func enhancements_of(seat: int) -> Array:
	_ensure_seat_arrays()
	return seat_enhancements[seat]

func rank_mods_of(seat: int) -> Array:
	_ensure_seat_arrays()
	return seat_rank_mods[seat]

func rank_effects_of(seat: int) -> Array:
	_ensure_seat_arrays()
	return seat_rank_effects[seat]

func count_upgrade_of(seat: int, id: String) -> int:
	var n: int = 0
	for u in upgrades_of(seat):
		if str(u) == id:
			n += 1
	return n

func has_upgrade_of(seat: int, id: String) -> bool:
	return count_upgrade_of(seat, id) > 0

func count_upgrade(id: String) -> int:
	return count_upgrade_of(0, id)

func has_upgrade(id: String) -> bool:
	return has_upgrade_of(0, id)

func packed_level() -> int:
	return packed_level_of(0)

func packed_level_of(seat: int) -> int:
	return count_upgrade_of(seat, "packed")

func extra_cards() -> int:
	return 0

func promote_level_of(seat: int) -> int:
	return count_upgrade_of(seat, "incumbent")

func count_enhancement_of(seat: int, id: String) -> int:
	var n: int = 0
	for u in enhancements_of(seat):
		if str(u) == id:
			n += 1
	return n

func has_enhancement_of(seat: int, id: String) -> bool:
	return count_enhancement_of(seat, id) > 0

func count_enhancement(id: String) -> int:
	return count_enhancement_of(0, id)

func has_enhancement(id: String) -> bool:
	return has_enhancement_of(0, id)

func shop_price_of(seat: int, base: int, currency: String = "gold") -> int:
	if currency == "chips":
		return maxi(1, base - count_upgrade_of(seat, "patronage"))
	return maxi(1, base - 2 * count_upgrade_of(seat, "lobbyist"))

func shop_price(base: int, currency: String = "gold") -> int:
	return shop_price_of(0, base, currency)

func owned_counts_of(seat: int) -> Dictionary:
	var out: Dictionary = {}
	for u in upgrades_of(seat):
		out[str(u)] = int(out.get(str(u), 0)) + 1
	for e in enhancements_of(seat):
		out[str(e)] = int(out.get(str(e), 0)) + 1
	for a in actions_of(seat):
		out[str(a)] = int(out.get(str(a), 0)) + 1
	for m in rank_mods_of(seat):
		var d: Dictionary = m
		var key: String = "mod_%s_%d" % [str(d.get("effect", "")), int(d.get("rank", 0))]
		out[key] = int(out.get(key, 0)) + 1
	for m2 in RankModDB.MODS:
		var mid: String = str(m2["id"])
		var info: Dictionary = m2
		for owned in rank_mods_of(seat):
			var od: Dictionary = owned
			if int(od.get("rank", -1)) == int(info.get("rank", -2)) and str(od.get("effect", "")) == str(info.get("effect", "?")):
				out[mid] = int(out.get(mid, 0)) + 1
	for fx in RankEffectDB.EFFECTS:
		var fid: String = str(fx["id"])
		var lvl: int = rank_effect_level(seat, int(fx.get("rank", -1)), str(fx.get("effect", "")))
		if lvl > 0:
			out[fid] = lvl
	return out

func owned_counts() -> Dictionary:
	return owned_counts_of(0)

func living_finish() -> Array:
	var out: Array = []
	for s in last_finish:
		if is_alive(int(s)):
			out.append(int(s))
	return out

func priced_copy(item: Dictionary) -> Dictionary:
	return priced_copy_of(0, item)

func priced_copy_of(seat: int, item: Dictionary) -> Dictionary:
	var d: Dictionary = item.duplicate()
	var cur: String = UpgradeDB.currency_of(d)
	d["currency"] = cur
	d["price"] = shop_price_of(seat, int(d.get("price", 0)), cur)
	return d

func has_action_of(seat: int, id: String) -> bool:
	return actions_of(seat).has(id)

func has_action(id: String) -> bool:
	return has_action_of(0, id)

func consume_jsn(seat: int) -> bool:
	return spend_action_for(seat, "just_say_no")

func cancel_hostile(target: int, action_id: String) -> bool:
	if not ActionDB.is_hostile(action_id):
		return false
	return consume_jsn(target)

func result_action_ids_of(seat: int) -> Array:
	var out: Array = []
	for id in actions_of(seat):
		var info: Dictionary = ActionDB.get_by_id(str(id))
		if str(info.get("when", "turn")) == "results" or str(id) == "just_say_no":
			if not out.has(id):
				out.append(id)
	return out

func result_action_ids() -> Array:
	return result_action_ids_of(0)

## `rank` here is the deal-face / base_rank slot (classic 1–13), not the inflated face.
func rank_power_bonus(seat: int, rank: int) -> int:
	var n: int = 0
	for m in rank_mods_of(seat):
		var d: Dictionary = m
		if int(d.get("rank", -1)) == rank and str(d.get("effect", "")) == "power":
			n += 1
	n += rank_effect_level(seat, rank, "power")
	return n

func rank_gold_on_play(seat: int, rank: int) -> int:
	var n: int = 0
	for m in rank_mods_of(seat):
		var d: Dictionary = m
		if int(d.get("rank", -1)) == rank and str(d.get("effect", "")) == "gold_play":
			n += 1
	n += rank_effect_level(seat, rank, "gold")
	var rush: int = count_upgrade_of(seat, "gold_rush")
	if rush > 0 and n > 0:
		n *= (1 + rush)
	return n

func rank_chips_on_play(seat: int, rank: int) -> int:
	return rank_effect_level(seat, rank, "chips")

func rank_always_legal(seat: int, rank: int) -> bool:
	for m in rank_mods_of(seat):
		var d: Dictionary = m
		if int(d.get("rank", -1)) == rank and str(d.get("effect", "")) == "always_legal":
			return true
	return rank_effect_level(seat, rank, "always_legal") > 0

func rank_effect_level(seat: int, rank: int, effect: String) -> int:
	for fx in rank_effects_of(seat):
		var d: Dictionary = fx
		if int(d.get("rank", -1)) == rank and str(d.get("effect", "")) == effect:
			return int(d.get("level", 1))
	return 0

func rank_effects_for_base(seat: int, base_rank: int) -> Array:
	var out: Array = []
	for fx in rank_effects_of(seat):
		var d: Dictionary = fx
		if int(d.get("rank", -1)) == base_rank:
			out.append(d.duplicate())
	for m in rank_mods_of(seat):
		var md: Dictionary = m
		if int(md.get("rank", -1)) == base_rank:
			out.append({"rank": base_rank, "effect": str(md.get("effect", "")), "level": 1, "legacy": true})
	return out

func rank_effect_badge(seat: int, base_rank: int) -> String:
	var bits: PackedStringArray = PackedStringArray()
	for fx in rank_effects_for_base(seat, base_rank):
		var eff: String = str(fx.get("effect", ""))
		if eff == "gold_play":
			eff = "gold"
		bits.append(RankEffectDB.effect_label(eff, int(fx.get("level", 1))))
	return " ".join(bits)

func rank_mod_short(seat: int) -> String:
	var bits: PackedStringArray = PackedStringArray()
	for m in rank_mods_of(seat):
		var d: Dictionary = m
		bits.append(" %s%s" % [RankSystem.short_label(int(d.get("rank", 0))), RankModDB.effect_short(str(d.get("effect", "")))])
	for fx in rank_effects_of(seat):
		var d2: Dictionary = fx
		bits.append(" %s%s" % [
			RankSystem.short_label(int(d2.get("rank", 0))),
			RankEffectDB.effect_label(str(d2.get("effect", "")), int(d2.get("level", 1))),
		])
	return "".join(bits)

func bind_rank_mod(seat: int, rank: int, effect: String) -> void:
	_ensure_seat_arrays()
	(seat_rank_mods[seat] as Array).append(RankModDB.make(rank, effect))
	changed.emit()

func bind_or_level_rank_effect(seat: int, rank: int, effect: String) -> int:
	_ensure_seat_arrays()
	for fx in rank_effects_of(seat):
		var d: Dictionary = fx
		if int(d.get("rank", -1)) == rank and str(d.get("effect", "")) == effect:
			d["level"] = int(d.get("level", 1)) + 1
			changed.emit()
			return int(d["level"])
	(seat_rank_effects[seat] as Array).append(RankEffectDB.make(rank, effect, 1))
	changed.emit()
	return 1

## Place array is seats in finish order (1st ... last).
func apply_payouts(finish_order: Array) -> void:
	last_payout.clear()
	last_knockouts.clear()
	last_finish = []
	for s0 in finish_order:
		last_finish.append(int(s0))
	if not last_finish.is_empty():
		last_first = int(last_finish[0])
	var n: int = last_finish.size()
	if n == 0:
		return
	var roles: Dictionary = RoleTrade.roles_map(last_finish)
	_ensure_seat_arrays()
	if roles.has(0):
		last_role = str(roles[0]["role"])
	for si in range(SEATS):
		if roles.has(si):
			last_roles[si] = str(roles[si]["role"])
	var alive_before: Dictionary = {}
	for bi in range(SEATS):
		alive_before[bi] = int(hp[bi]) > 0
	var s: int = stake()
	var gold_earned: Dictionary = {}
	for i in range(n):
		var seat: int = int(last_finish[i])
		var place: int = i + 1
		var gold_gain: int = 0
		var hp_delta: int = 0
		var upper: int = int(ceil(float(n) / 2.0))
		if n >= 6:
			gold_gain = int(GOLD_BY_PLACE[place])
			if place <= 2:
				hp_delta = s
			elif place == 3:
				hp_delta = int(ceil(float(s) / 2.0))
			elif place == 4:
				hp_delta = -int(ceil(float(s) / 2.0))
			else:
				hp_delta = -s
		else:
			var golds: Array = GOLD_BY_PLACE.slice(1)
			gold_gain = int(golds[mini(place - 1 + (6 - n), golds.size() - 1)])
			if place <= upper:
				hp_delta = s if place == 1 else int(ceil(float(s) / 2.0))
			else:
				hp_delta = -s if place == n else -int(ceil(float(s) / 2.0))
		var role: String = str(roles.get(seat, {}).get("role", RoleTrade.ROLE_NEUTRAL))
		var streak: int = _tick_role_streak(seat, role)
		var streak_bonus: int = streak_bonus_gold(streak)
		# Ante stipend keeps the desk reachable as stakes climb.
		var ante_gold: int = ante() - 1
		gold_gain += ante_gold
		gold_gain += 2 * count_upgrade_of(seat, "payroll")
		if has_enhancement_of(seat, "gilded") and place <= 2:
			gold_gain += 2 * count_enhancement_of(seat, "gilded")
		gold_gain += streak_bonus
		add_gold(seat, gold_gain)
		gold_earned[seat] = gold_gain
		var cap: int = int(seat_max_hp[seat])
		hp[seat] = clampi(int(hp[seat]) + hp_delta, 0, cap)
		if has_upgrade_of(seat, "safe_seat") and int(hp[seat]) > 0:
			hp[seat] = maxi(int(hp[seat]), 5)
		last_payout.append({
			"seat": seat, "place": place,
			"gold": gold_gain,
			"hp_delta": hp_delta, "name": name_of(seat), "role": role,
			"streak": streak, "streak_bonus": streak_bonus,
			"chips": 0,
		})
	# Survivor Chips: each AI that just hit 0 HP pays chips to living humans.
	for ko in range(SEATS):
		if not is_ai(ko):
			continue
		if bool(alive_before.get(ko, false)) and int(hp[ko]) <= 0:
			last_knockouts.append(ko)
	_grant_survivor_chips(gold_earned)
	_check_end()
	changed.emit()

func _grant_survivor_chips(gold_earned: Dictionary) -> void:
	for human in living_humans():
		var h: int = int(human)
		var chip_gain: int = 0
		if not last_knockouts.is_empty():
			var per: int = CHIP_PER_KO + count_upgrade_of(h, "chip_magnet")
			chip_gain += per * last_knockouts.size()
		var syn: int = count_upgrade_of(h, "syndicate")
		if syn > 0:
			var earned: int = int(gold_earned.get(h, 0))
			chip_gain += syn * int(earned / 5)
		if chip_gain > 0:
			add_chips(h, chip_gain)
			log_event("%s banks %d Survivor Chip(s)." % [name_of(h), chip_gain])
			for row in last_payout:
				if int(row.get("seat", -1)) == h:
					row["chips"] = int(row.get("chips", 0)) + chip_gain
					break

## Fire rank customizations when a seat plays a combo. `base_rank` is the deal-face.
## Returns {gold, chips, damage, heal, logs, target}.
func trigger_rank_play(seat: int, base_rank: int, hand: Array = []) -> Dictionary:
	var out: Dictionary = {"gold": 0, "chips": 0, "damage": 0, "heal": 0, "logs": [], "target": -1}
	if base_rank <= 0:
		return out
	var gold_n: int = rank_gold_on_play(seat, base_rank)
	if gold_n > 0:
		add_gold(seat, gold_n)
		out["gold"] = gold_n
		(out["logs"] as Array).append("%s earns $%d on %s." % [name_of(seat), gold_n, RankSystem.short_label(base_rank)])
		var echo_n: int = count_upgrade_of(seat, "echo")
		if echo_n > 0:
			add_chips(seat, echo_n)
			out["chips"] = int(out["chips"]) + echo_n
			(out["logs"] as Array).append("%s Echo: +%d◈." % [name_of(seat), echo_n])
	var chip_n: int = rank_chips_on_play(seat, base_rank)
	if chip_n > 0:
		add_chips(seat, chip_n)
		out["chips"] = int(out["chips"]) + chip_n
		(out["logs"] as Array).append("%s earns %d◈ on %s." % [name_of(seat), chip_n, RankSystem.short_label(base_rank)])
	var dmg: int = rank_effect_level(seat, base_rank, "damage")
	if dmg > 0:
		var target: int = _weakest_living_ai(seat)
		if target >= 0:
			hp[target] = maxi(0, int(hp[target]) - dmg)
			out["damage"] = dmg
			out["target"] = target
			(out["logs"] as Array).append("%s whips %s for %d HP." % [name_of(seat), name_of(target), dmg])
			if int(hp[target]) <= 0 and is_ai(target):
				# Mid-round KO still banks Survivor Chips for living humans.
				var ko_chips: int = CHIP_PER_KO + count_upgrade_of(seat, "chip_magnet")
				if is_human(seat) and ko_chips > 0:
					add_chips(seat, ko_chips)
					out["chips"] = int(out["chips"]) + ko_chips
					(out["logs"] as Array).append("%s Survivor Chip(s) +%d (mid-round KO)." % [name_of(seat), ko_chips])
	var heal_n: int = rank_effect_level(seat, base_rank, "heal")
	if heal_n > 0 and is_alive(seat):
		var before: int = int(hp[seat])
		hp[seat] = mini(int(seat_max_hp[seat]), before + heal_n)
		out["heal"] = int(hp[seat]) - before
		if int(out["heal"]) > 0:
			(out["logs"] as Array).append("%s heals %d HP." % [name_of(seat), int(out["heal"])])
	var buff_n: int = rank_effect_level(seat, base_rank, "buff_hand")
	if buff_n > 0 and not hand.is_empty():
		var labs: PackedStringArray = CardForge.promote_lowest(hand, buff_n)
		if not labs.is_empty():
			(out["logs"] as Array).append("%s coaches: %s" % [name_of(seat), ", ".join(labs)])
	for line in out["logs"]:
		log_event(str(line))
	if not (out["logs"] as Array).is_empty():
		changed.emit()
	return out

func _weakest_living_ai(except_seat: int = -1) -> int:
	var best: int = -1
	var best_hp: int = 999999
	for seat in living_seats():
		var s: int = int(seat)
		if s == except_seat or not is_ai(s):
			continue
		var h: int = int(hp[s])
		if h < best_hp or (h == best_hp and s < best):
			best_hp = h
			best = s
	return best

## Endless: only a total human wipeout ends the run. Last seat standing is
## not a win — dead AIs are revived before the next deal.
func _check_end() -> void:
	var live_h: Array = living_humans()
	if live_h.is_empty():
		run_over = true
		run_won = false
		record_best_round(round_n)
		return
	run_over = false
	run_won = false

## Bring every dead AI seat back so the cabinet always fills the table.
## Late antes revive tankier so knockouts (and chips) slow while stake keeps rising.
func revive_cabinet() -> void:
	_ensure_seat_arrays()
	var revive_hp: int = mini(START_HP, maxi(AI_REVIVE_BASE, stake() + 5 + ante() * 2))
	for seat in range(seat_count):
		if is_human(seat):
			continue
		if int(hp[seat]) <= 0:
			hp[seat] = revive_hp
	changed.emit()

static func load_best_round() -> int:
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(BEST_PATH) != OK:
		return 0
	return int(cf.get_value("stats", "best_round", 0))

static func record_best_round(reached: int) -> void:
	if reached <= 0:
		return
	var cf: ConfigFile = ConfigFile.new()
	cf.load(BEST_PATH)
	var prev: int = int(cf.get_value("stats", "best_round", 0))
	if reached > prev:
		cf.set_value("stats", "best_round", reached)
		cf.save(BEST_PATH)

func buy_upgrade(id: String, price: int) -> bool:
	return buy_upgrade_for(shop_seat, id, price)

func buy_action(id: String, price: int) -> bool:
	return buy_action_for(shop_seat, id, price)

func buy_enhancement(id: String, price: int) -> bool:
	return buy_enhancement_for(shop_seat, id, price)

func _seat_may_buy(seat: int) -> bool:
	if is_human(seat):
		return true
	return shop_phase

func _pay(seat: int, price: int, currency: String) -> bool:
	if currency == "chips":
		if chips_of(seat) < price:
			return false
		seat_chips[seat] = chips_of(seat) - price
		return true
	if gold_of(seat) < price:
		return false
	seat_gold[seat] = gold_of(seat) - price
	return true

func _refund(seat: int, price: int, currency: String) -> void:
	if currency == "chips":
		seat_chips[seat] = chips_of(seat) + price
	else:
		seat_gold[seat] = gold_of(seat) + price

func buy_upgrade_for(seat: int, id: String, price: int) -> bool:
	_ensure_seat_arrays()
	if not _seat_may_buy(seat):
		return false
	var info: Dictionary = UpgradeDB.get_by_id(id)
	var currency: String = UpgradeDB.currency_of(info) if not info.is_empty() else "gold"
	if RankEffectDB.is_rank_fx(id):
		currency = "chips"
	if not _pay(seat, price, currency):
		return false
	if RankEffectDB.is_rank_fx(id):
		var fx: Dictionary = RankEffectDB.get_by_id(id)
		if fx.is_empty():
			_refund(seat, price, currency)
			return false
		bind_or_level_rank_effect(seat, int(fx.get("rank", 0)), str(fx.get("effect", "")))
		changed.emit()
		return true
	if RankModDB.is_mod(id):
		var mod: Dictionary = RankModDB.get_by_id(id)
		if mod.is_empty():
			_refund(seat, price, currency)
			return false
		bind_rank_mod(seat, int(mod.get("rank", 0)), str(mod.get("effect", "")))
		changed.emit()
		return true
	if id.begins_with("favorite_"):
		seat_favorite[seat] = int(id.substr(9))
		upgrades_of(seat).append("favorite")
	else:
		upgrades_of(seat).append(id)
		if id == "pockets":
			seat_max_hp[seat] = int(seat_max_hp[seat]) + 10
			hp[seat] = mini(int(hp[seat]) + 10, int(seat_max_hp[seat]))
	changed.emit()
	return true

func buy_action_for(seat: int, id: String, price: int) -> bool:
	_ensure_seat_arrays()
	if not _seat_may_buy(seat):
		return false
	if not _pay(seat, price, "gold"):
		return false
	actions_of(seat).append(id)
	changed.emit()
	return true

func buy_enhancement_for(seat: int, id: String, price: int) -> bool:
	_ensure_seat_arrays()
	if not _seat_may_buy(seat):
		return false
	if not _pay(seat, price, "gold"):
		return false
	enhancements_of(seat).append(id)
	changed.emit()
	return true

func spend_action(id: String) -> bool:
	return spend_action_for(shop_seat, id)

func spend_action_for(seat: int, id: String) -> bool:
	var inv: Array = actions_of(seat)
	var i: int = inv.find(id)
	if i < 0:
		return false
	inv.remove_at(i)
	changed.emit()
	return true

func restore_action_for(seat: int, id: String) -> void:
	actions_of(seat).append(id)
	changed.emit()

func lead_seat() -> int:
	if round_n <= 1:
		return 0
	if is_alive(last_first):
		return last_first
	if is_alive(0):
		return 0
	var live: Array = living_seats()
	if live.is_empty():
		return 0
	return int(live[0])

func next_round() -> void:
	if run_over:
		return
	round_n += 1
	whip_used = false
	close_shop_phase()
	revive_cabinet()
	_grant_war_chest()
	changed.emit()

func _grant_war_chest() -> void:
	for seat in range(seat_count):
		if not is_alive(seat):
			continue
		var n: int = count_upgrade_of(seat, "war_chest")
		if n > 0:
			add_chips(seat, n)
			log_event("%s War Chest: +%d◈." % [name_of(seat), n])

func open_shop_phase() -> Array:
	shop_phase = true
	_apply_interest_all()
	return ai_shop_all()

func close_shop_phase() -> void:
	shop_phase = false

func _apply_interest_all() -> void:
	for seat in range(seat_count):
		if not is_alive(seat):
			continue
		var stacks: int = count_upgrade_of(seat, "interest")
		if stacks <= 0:
			continue
		# 10% + 5% per extra stack of current gold.
		var pct: int = 10 + 5 * (stacks - 1)
		var gain: int = int(gold_of(seat) * pct / 100)
		if gain > 0:
			add_gold(seat, gain)
			log_event("%s Compound Interest: +$%d." % [name_of(seat), gain])

func reset_tribute_flags() -> void:
	cancelled_tribute_seats.clear()
	skip_tributes = false
	trade_log.clear()

func apply_populist() -> void:
	for seat in range(SEATS):
		if not is_alive(seat):
			continue
		if has_upgrade_of(seat, "populist") and str(last_roles[seat]) == RoleTrade.ROLE_SCUM:
			hp[seat] = mini(int(hp[seat]) + 8 * count_upgrade_of(seat, "populist"), int(seat_max_hp[seat]))
	changed.emit()

## streak 1 (first time in this role) = 0; streak 2 = +N; streak 3 = +2N; …
static func streak_bonus_gold(streak: int) -> int:
	if streak <= 1:
		return 0
	return STREAK_UNIT * (streak - 1)

func _tick_role_streak(seat: int, role: String) -> int:
	while role_streak_role.size() < SEATS:
		role_streak_role.append("")
		role_streak_len.append(0)
	if str(role_streak_role[seat]) == role:
		role_streak_len[seat] = int(role_streak_len[seat]) + 1
	else:
		role_streak_role[seat] = role
		role_streak_len[seat] = 1
	return int(role_streak_len[seat])

func begin_shop_visit() -> void:
	begin_shop_visit_for(0)

func begin_shop_visit_for(seat: int) -> void:
	shop_seat = seat
	shop_rerolls = 0
	shop_offers = ShopStock.draw_offers(rng, self, ShopStock.SLOTS, seat)
	changed.emit()

func reroll_cost() -> int:
	return shop_price_of(shop_seat, ShopStock.reroll_cost_at(shop_rerolls), "gold")

func reroll_shop() -> bool:
	var c: int = reroll_cost()
	if gold_of(shop_seat) < c:
		return false
	seat_gold[shop_seat] = gold_of(shop_seat) - c
	shop_rerolls += 1
	shop_offers = ShopStock.draw_offers(rng, self, ShopStock.SLOTS, shop_seat)
	changed.emit()
	return true

func take_shop_offer(id: String) -> void:
	var remain: Array = []
	for it in shop_offers:
		if str(it.get("id", "")) != id:
			remain.append(it)
	shop_offers = remain

func log_event(line: String) -> void:
	if line == "":
		return
	trade_log.append(line)

## After payouts, AIs fire role actions then buy 0–1 desk item with their gold.
func ai_results_actions() -> Array:
	var logs: Array = []
	for seat in range(SEATS):
		if not is_alive(seat) or is_human(seat):
			continue
		var pick: String = PresidentAI.choose_role_action(last_finish, seat, actions_of(seat).duplicate())
		if pick == "":
			continue
		if not spend_action_for(seat, pick):
			continue
		var line: String = apply_results_action(seat, pick)
		if line != "":
			logs.append(line)
			log_event(line)
	return logs

func apply_results_action(seat: int, id: String) -> String:
	var live: Array = living_finish()
	var actor: String = name_of(seat)
	match id:
		"uprising":
			if live.size() >= 3:
				RoleTrade.swap_finish(last_finish, int(live[0]), int(live[live.size() - 1]))
				return "%s plays Uprising — President ↔ Asshole." % actor
		"impeach":
			if live.size() >= 4:
				RoleTrade.swap_finish(last_finish, int(live[0]), int(live[1]))
				return "%s plays Impeach — President ↔ Vice-President." % actor
		"coup":
			if live.size() >= 3 and int(live[0]) != seat:
				RoleTrade.swap_finish(last_finish, int(live[0]), seat)
				return "%s plays Coup — seizes the Presidency." % actor
		"pardon":
			cancelled_tribute_seats.append(seat)
			return "%s plays Pardon — outgoing tribute waved." % actor
		"just_say_no":
			cancelled_tribute_seats.append(seat)
			return "%s plays Just Say No — refuses the tribute." % actor
		"recess":
			skip_tributes = true
			return "%s plays Recess — no tributes this deal." % actor
	return "%s's %s fizzled." % [actor, id]

func ai_shop_all() -> Array:
	var logs: Array = []
	if not shop_phase:
		return logs
	for seat in range(SEATS):
		if not is_alive(seat) or is_human(seat):
			continue
		var offers: Array = ShopStock.draw_offers(rng, self, ShopStock.AI_SLOTS, seat)
		var priced: Array = []
		for o in offers:
			# AIs only spend gold — skip chip-priced customizations / economy.
			if UpgradeDB.currency_of(o) == "chips" or RankEffectDB.is_rank_fx(str(o.get("id", ""))):
				continue
			priced.append(priced_copy_of(seat, o))
		if priced.is_empty():
			continue
		var role: String = RoleTrade.role_of(last_finish, seat)
		var pick: Dictionary = PresidentAI.choose_shop(priced, gold_of(seat), seat % 3, role)
		if pick.is_empty():
			continue
		var id: String = str(pick.get("id", ""))
		var price: int = int(pick.get("price", 0))
		var ok: bool = false
		match str(pick.get("kind", "upgrade")):
			"action":
				ok = buy_action_for(seat, id, price)
			"enhancement":
				ok = buy_enhancement_for(seat, id, price)
			_:
				ok = buy_upgrade_for(seat, id, price)
		if ok:
			var line: String = "%s buys %s ($%d). Gold left $%d." % [name_of(seat), str(pick.get("name", id)), price, gold_of(seat)]
			logs.append(line)
			log_event(line)
	return logs

func apply_deal_effects(game: PresidentGame) -> Array:
	var logs: Array = []
	var bonus: int = rank_bonus()
	if bonus > 0:
		Deck.inflate_hands(game.hands, bonus)
		Deck.inflate_card_list(game.kitty, bonus)
		logs.append("Rank inflation +%s (ante %d)." % [NumFormat.compact(bonus), ante()])
	for seat in game.living:
		var s: int = int(seat)
		Deck._apply_packed(game.hands, s, packed_level_of(s), rng)
		var fav: int = favorite_of(s)
		if fav >= 1 and fav <= 13:
			Deck._apply_favorite(game.hands, s, fav, rng)
		var promo: int = promote_level_of(s)
		if promo > 0 and game.hands.has(s):
			var changed_labs: PackedStringArray = CardForge.promote_lowest(game.hands[s], promo)
			if not changed_labs.is_empty():
				logs.append("%s incumbent: %s" % [name_of(s), ", ".join(changed_labs)])
		var lucky_n: int = count_enhancement_of(s, "lucky")
		for _i in range(lucky_n):
			if not game.hands.has(s):
				break
			var sw: String = CardForge.swap_lowest_with_kitty(game.hands[s], game.kitty, rng)
			if sw != "":
				logs.append("%s lucky swap: %s" % [name_of(s), sw])
		if game.hands.has(s):
			EnhancementDB.apply_to_hand(game.hands[s], enhancements_of(s), rng)
			Deck._sort_hand(game.hands[s])
	game.mods = self
	return logs

func pack_public() -> Dictionary:
	_ensure_seat_arrays()
	return {
		"round_n": round_n,
		"seat_count": seat_count,
		"hp": hp.duplicate(),
		"seat_gold": seat_gold.duplicate(),
		"seat_chips": seat_chips.duplicate(),
		"seat_max_hp": seat_max_hp.duplicate(),
		"seat_names": seat_names.duplicate(),
		"human_seats": human_seats.duplicate(),
		"seat_upgrades": _dup_arrays(seat_upgrades),
		"seat_actions": _dup_arrays(seat_actions),
		"seat_enhancements": _dup_arrays(seat_enhancements),
		"seat_favorite": seat_favorite.duplicate(),
		"seat_rank_mods": _dup_mods(seat_rank_mods),
		"seat_rank_effects": _dup_mods(seat_rank_effects),
		"whip_used": whip_used,
		"last_payout": last_payout.duplicate(true),
		"last_first": last_first,
		"last_finish": last_finish.duplicate(),
		"last_knockouts": last_knockouts.duplicate(),
		"cancelled_tribute_seats": cancelled_tribute_seats.duplicate(),
		"skip_tributes": skip_tributes,
		"trade_log": trade_log.duplicate(),
		"last_roles": last_roles.duplicate(),
		"last_role": last_role,
		"role_streak_role": role_streak_role.duplicate(),
		"role_streak_len": role_streak_len.duplicate(),
		"shop_offers": shop_offers.duplicate(true),
		"shop_rerolls": shop_rerolls,
		"shop_seat": shop_seat,
		"shop_phase": shop_phase,
		"run_over": run_over,
		"run_won": run_won,
	}

func apply_public(d: Dictionary) -> void:
	_ensure_seat_arrays()
	round_n = int(d.get("round_n", 1))
	seat_count = int(d.get("seat_count", 6))
	hp = _ints_of(d.get("hp", hp))
	seat_gold = _ints_of(d.get("seat_gold", seat_gold))
	seat_chips = _ints_of(d.get("seat_chips", seat_chips))
	seat_max_hp = _ints_of(d.get("seat_max_hp", seat_max_hp))
	seat_names = _strs_of(d.get("seat_names", seat_names))
	human_seats = _ints_of(d.get("human_seats", human_seats))
	seat_upgrades = _dup_arrays(d.get("seat_upgrades", seat_upgrades))
	seat_actions = _dup_arrays(d.get("seat_actions", seat_actions))
	seat_enhancements = _dup_arrays(d.get("seat_enhancements", seat_enhancements))
	seat_favorite = _ints_of(d.get("seat_favorite", seat_favorite))
	seat_rank_mods = _dup_mods(d.get("seat_rank_mods", seat_rank_mods))
	seat_rank_effects = _dup_mods(d.get("seat_rank_effects", seat_rank_effects))
	whip_used = bool(d.get("whip_used", false))
	last_payout = []
	for p in d.get("last_payout", []):
		if p is Dictionary:
			last_payout.append((p as Dictionary).duplicate())
	last_first = int(d.get("last_first", 0))
	last_finish = _ints_of(d.get("last_finish", []))
	last_knockouts = _ints_of(d.get("last_knockouts", []))
	cancelled_tribute_seats = _ints_of(d.get("cancelled_tribute_seats", []))
	skip_tributes = bool(d.get("skip_tributes", false))
	trade_log = _strs_of(d.get("trade_log", []))
	last_roles = _strs_of(d.get("last_roles", last_roles))
	last_role = str(d.get("last_role", ""))
	role_streak_role = _strs_of(d.get("role_streak_role", role_streak_role))
	role_streak_len = _ints_of(d.get("role_streak_len", role_streak_len))
	shop_offers = []
	for o in d.get("shop_offers", []):
		if o is Dictionary:
			shop_offers.append((o as Dictionary).duplicate())
	shop_rerolls = int(d.get("shop_rerolls", 0))
	shop_seat = int(d.get("shop_seat", 0))
	shop_phase = bool(d.get("shop_phase", false))
	run_over = bool(d.get("run_over", false))
	run_won = bool(d.get("run_won", false))
	if lobby == null:
		lobby = LobbyConfig.new()
	lobby.seat_count = seat_count
	lobby.display_names = seat_names.duplicate()
	lobby.kinds.clear()
	for i in range(LobbyConfig.MAX_SEATS):
		lobby.kinds.append(LobbyConfig.KIND_HUMAN if human_seats.has(i) else LobbyConfig.KIND_AI)
	lobby.lan = true
	changed.emit()

func _dup_arrays(src) -> Array:
	var out: Array = []
	for row in src:
		var inner: Array = []
		if row is Array:
			for v in row:
				inner.append(v)
		out.append(inner)
	return out

func _dup_mods(src) -> Array:
	var out: Array = []
	for row in src:
		var inner: Array = []
		if row is Array:
			for v in row:
				if v is Dictionary:
					inner.append((v as Dictionary).duplicate())
		out.append(inner)
	return out

func _ints_of(src) -> Array:
	var out: Array = []
	for v in src:
		out.append(int(v))
	return out

func _strs_of(src) -> Array:
	var out: Array = []
	for v in src:
		out.append(str(v))
	return out
