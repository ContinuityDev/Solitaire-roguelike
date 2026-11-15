class_name RunManager
extends Node

## President run: HP, gold, round stake, owned upgrades, action inventory.
## Seat 0 is the human; seats 1-5 are AIs. Every seat has gold and inventory.

signal changed

const SEATS: int = 6
const START_HP: int = 50
const NAMES: Array = ["You", "The Speaker", "The Whip", "The Veep", "The Justice", "The General"]
## index = place 1..6. Tight: 1st $2 … 6th $9. Mid-run you cannot buy the desk.
const GOLD_BY_PLACE: Array = [0, 2, 3, 4, 5, 7, 9]
const STREAK_UNIT: int = 3 # bonus gold = STREAK_UNIT * (streak - 1)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var round_n: int = 1
var seat_gold: Array = []
var seat_max_hp: Array = []
var seat_upgrades: Array = []
var seat_actions: Array = []
var seat_enhancements: Array = []
var seat_favorite: Array = []
var seat_rank_mods: Array = [] # Array of Array of {rank, effect}
var hp: Array = [] # 6 ints
var whip_used: bool = false
var last_payout: Array = [] # [{seat, place, gold, hp_delta, name, role}]
var last_first: int = 0 # previous round's President; leads the next deal
var last_finish: Array = [] # finish order; roles/trades read from living seats
var cancelled_tribute_seats: Array = [] # givers who JSN/pardon
var skip_tributes: bool = false
var trade_log: Array = []
var last_role: String = "" # your role last round, for Populist
var last_roles: Array = [] # role string per seat
var role_streak_role: Array = [] # last finish role per seat
var role_streak_len: Array = [] # consecutive count per seat
var shop_offers: Array = []
var shop_rerolls: int = 0
var run_over: bool = false
var run_won: bool = false

var gold: int:
	get:
		return gold_of(0)
	set(value):
		_ensure_seat_arrays()
		seat_gold[0] = value

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
	while last_roles.size() < SEATS:
		last_roles.append("")

func start_new_run() -> void:
	round_n = 1
	seat_gold = []
	seat_max_hp = []
	seat_upgrades = []
	seat_actions = []
	seat_enhancements = []
	seat_favorite = []
	seat_rank_mods = []
	hp = []
	last_roles = []
	for _i in range(SEATS):
		seat_gold.append(0)
		seat_max_hp.append(START_HP)
		seat_upgrades.append([])
		seat_actions.append([])
		seat_enhancements.append([])
		seat_favorite.append(0)
		seat_rank_mods.append([])
		hp.append(START_HP)
		last_roles.append("")
	_grant_ai_specialties()
	whip_used = false
	last_payout.clear()
	last_first = 0
	last_finish.clear()
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
	run_over = false
	run_won = false
	changed.emit()

func _grant_ai_specialties() -> void:
	for seat in RankModDB.AI_SPEC.keys():
		var spec: Dictionary = RankModDB.AI_SPEC[seat]
		(seat_rank_mods[int(seat)] as Array).append(RankModDB.make(int(spec["rank"]), str(spec["effect"])))

func living_seats() -> Array:
	var out: Array = []
	for i in range(SEATS):
		if int(hp[i]) > 0:
			out.append(i)
	return out

func is_alive(seat: int) -> bool:
	return int(hp[seat]) > 0

func stake() -> int:
	return 4 + round_n

func gold_of(seat: int) -> int:
	_ensure_seat_arrays()
	return int(seat_gold[seat])

func add_gold(seat: int, n: int) -> void:
	_ensure_seat_arrays()
	seat_gold[seat] = int(seat_gold[seat]) + n

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

func shop_price_of(seat: int, base: int) -> int:
	return maxi(1, base - 2 * count_upgrade_of(seat, "lobbyist"))

func shop_price(base: int) -> int:
	return shop_price_of(0, base)

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
	d["price"] = shop_price_of(seat, int(d.get("price", 0)))
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

func rank_power_bonus(seat: int, rank: int) -> int:
	var n: int = 0
	for m in rank_mods_of(seat):
		var d: Dictionary = m
		if int(d.get("rank", -1)) == rank and str(d.get("effect", "")) == "power":
			n += 1
	return n

func rank_gold_on_play(seat: int, rank: int) -> int:
	var n: int = 0
	for m in rank_mods_of(seat):
		var d: Dictionary = m
		if int(d.get("rank", -1)) == rank and str(d.get("effect", "")) == "gold_play":
			n += 1
	return n

func rank_always_legal(seat: int, rank: int) -> bool:
	for m in rank_mods_of(seat):
		var d: Dictionary = m
		if int(d.get("rank", -1)) == rank and str(d.get("effect", "")) == "always_legal":
			return true
	return false

func rank_mod_short(seat: int) -> String:
	var bits: PackedStringArray = PackedStringArray()
	for m in rank_mods_of(seat):
		var d: Dictionary = m
		bits.append(" %s%s" % [RankSystem.short_label(int(d.get("rank", 0))), RankModDB.effect_short(str(d.get("effect", "")))])
	return "".join(bits)

func bind_rank_mod(seat: int, rank: int, effect: String) -> void:
	_ensure_seat_arrays()
	(seat_rank_mods[seat] as Array).append(RankModDB.make(rank, effect))
	changed.emit()

## Place array is seats in finish order (1st ... last).
func apply_payouts(finish_order: Array) -> void:
	last_payout.clear()
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
	var s: int = stake()
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
		if has_enhancement_of(seat, "gilded") and place <= 2:
			gold_gain += 2 * count_enhancement_of(seat, "gilded")
		gold_gain += streak_bonus
		add_gold(seat, gold_gain)
		var cap: int = int(seat_max_hp[seat])
		hp[seat] = clampi(int(hp[seat]) + hp_delta, 0, cap)
		if has_upgrade_of(seat, "safe_seat") and int(hp[seat]) > 0:
			hp[seat] = maxi(int(hp[seat]), 5)
		last_payout.append({
			"seat": seat, "place": place,
			"gold": gold_gain,
			"hp_delta": hp_delta, "name": NAMES[seat], "role": role,
			"streak": streak, "streak_bonus": streak_bonus,
		})
	_check_end()
	changed.emit()

func _check_end() -> void:
	var live: Array = living_seats()
	if int(hp[0]) <= 0:
		run_over = true
		run_won = false
		return
	if live.size() == 1 and int(live[0]) == 0:
		run_over = true
		run_won = true

func buy_upgrade(id: String, price: int) -> bool:
	return buy_upgrade_for(0, id, price)

func buy_action(id: String, price: int) -> bool:
	return buy_action_for(0, id, price)

func buy_enhancement(id: String, price: int) -> bool:
	return buy_enhancement_for(0, id, price)

func buy_upgrade_for(seat: int, id: String, price: int) -> bool:
	_ensure_seat_arrays()
	if gold_of(seat) < price:
		return false
	seat_gold[seat] = gold_of(seat) - price
	if RankModDB.is_mod(id):
		var info: Dictionary = RankModDB.get_by_id(id)
		if info.is_empty():
			seat_gold[seat] = gold_of(seat) + price
			return false
		bind_rank_mod(seat, int(info.get("rank", 0)), str(info.get("effect", "")))
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
	if gold_of(seat) < price:
		return false
	seat_gold[seat] = gold_of(seat) - price
	actions_of(seat).append(id)
	changed.emit()
	return true

func buy_enhancement_for(seat: int, id: String, price: int) -> bool:
	_ensure_seat_arrays()
	if gold_of(seat) < price:
		return false
	seat_gold[seat] = gold_of(seat) - price
	enhancements_of(seat).append(id)
	changed.emit()
	return true

func spend_action(id: String) -> bool:
	return spend_action_for(0, id)

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
	changed.emit()

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
	shop_rerolls = 0
	shop_offers = ShopStock.draw_offers(rng, self, ShopStock.SLOTS, 0)
	changed.emit()

func reroll_cost() -> int:
	return shop_price(ShopStock.reroll_cost_at(shop_rerolls))

func reroll_shop() -> bool:
	var c: int = reroll_cost()
	if gold < c:
		return false
	gold -= c
	shop_rerolls += 1
	shop_offers = ShopStock.draw_offers(rng, self, ShopStock.SLOTS, 0)
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
	for seat in range(1, SEATS):
		if not is_alive(seat):
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
	var actor: String = NAMES[seat]
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
	for seat in range(1, SEATS):
		if not is_alive(seat):
			continue
		var offers: Array = ShopStock.draw_offers(rng, self, ShopStock.AI_SLOTS, seat)
		var priced: Array = []
		for o in offers:
			priced.append(priced_copy_of(seat, o))
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
			var line: String = "%s buys %s ($%d). Gold left $%d." % [NAMES[seat], str(pick.get("name", id)), price, gold_of(seat)]
			logs.append(line)
			log_event(line)
	return logs

func apply_deal_effects(game: PresidentGame) -> Array:
	var logs: Array = []
	for seat in game.living:
		var s: int = int(seat)
		Deck._apply_packed(game.hands, s, packed_level_of(s), rng)
		var fav: int = favorite_of(s)
		if fav >= 1 and fav <= 13:
			Deck._apply_favorite(game.hands, s, fav, rng)
		var promo: int = promote_level_of(s)
		if promo > 0 and game.hands.has(s):
			var changed: PackedStringArray = CardForge.promote_lowest(game.hands[s], promo)
			if not changed.is_empty():
				logs.append("%s incumbent: %s" % [NAMES[s], ", ".join(changed)])
		var lucky_n: int = count_enhancement_of(s, "lucky")
		for _i in range(lucky_n):
			if not game.hands.has(s):
				break
			var sw: String = CardForge.swap_lowest_with_kitty(game.hands[s], game.kitty, rng)
			if sw != "":
				logs.append("%s lucky swap: %s" % [NAMES[s], sw])
		if game.hands.has(s):
			EnhancementDB.apply_to_hand(game.hands[s], enhancements_of(s), rng)
			Deck._sort_hand(game.hands[s])
	game.mods = self
	return logs
