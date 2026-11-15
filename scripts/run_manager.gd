class_name RunManager
extends Node

## President run: HP, gold, round stake, owned upgrades, action inventory.
## Seat 0 is the human; seats 1-5 are AIs with their own HP.

signal changed

const SEATS: int = 6
const START_HP: int = 50
const NAMES: Array = ["You", "The Speaker", "The Whip", "The Veep", "The Justice", "The General"]
const GOLD_BY_PLACE: Array = [0, 4, 6, 8, 12, 16, 22] # index = place 1..6
const STREAK_UNIT: int = 6 # bonus gold = STREAK_UNIT * (streak - 1)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var round_n: int = 1
var gold: int = 0
var max_hp: int = START_HP
var hp: Array = [] # 6 ints
var owned_upgrades: Array = []
var actions: Array = [] # action ids in inventory
var favorite_rank: int = 0
var whip_used: bool = false
var last_payout: Array = [] # [{seat, place, gold, hp_delta, name, role}]
var last_first: int = 0 # previous round's President; leads the next deal
var last_finish: Array = [] # finish order; roles/trades read from living seats
var owned_enhancements: Array = []
var cancelled_tribute_seats: Array = [] # givers who JSN/pardon
var skip_tributes: bool = false
var trade_log: Array = []
var last_role: String = "" # your role last round, for Populist
var role_streak_role: Array = [] # last finish role per seat
var role_streak_len: Array = [] # consecutive count per seat
var shop_offers: Array = []
var shop_rerolls: int = 0
var run_over: bool = false
var run_won: bool = false

func _ready() -> void:
	rng.randomize()

func start_new_run() -> void:
	round_n = 1
	gold = 0
	max_hp = START_HP
	hp = []
	for _i in range(SEATS):
		hp.append(START_HP)
	owned_upgrades.clear()
	actions.clear()
	favorite_rank = 0
	whip_used = false
	last_payout.clear()
	last_first = 0
	last_finish.clear()
	owned_enhancements.clear()
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

func count_upgrade(id: String) -> int:
	var n: int = 0
	for u in owned_upgrades:
		if str(u) == id:
			n += 1
	return n

func has_upgrade(id: String) -> bool:
	return count_upgrade(id) > 0

func packed_level() -> int:
	return count_upgrade("packed")

func extra_cards() -> int:
	return count_upgrade("incumbent") + count_enhancement("lucky")

func count_enhancement(id: String) -> int:
	var n: int = 0
	for u in owned_enhancements:
		if str(u) == id:
			n += 1
	return n

func has_enhancement(id: String) -> bool:
	return count_enhancement(id) > 0

func shop_price(base: int) -> int:
	return maxi(1, base - 2 * count_upgrade("lobbyist"))

func owned_counts() -> Dictionary:
	var out: Dictionary = {}
	for u in owned_upgrades:
		out[str(u)] = int(out.get(str(u), 0)) + 1
	for e in owned_enhancements:
		out[str(e)] = int(out.get(str(e), 0)) + 1
	for a in actions:
		out[str(a)] = int(out.get(str(a), 0)) + 1
	return out

func living_finish() -> Array:
	var out: Array = []
	for s in last_finish:
		if is_alive(int(s)):
			out.append(int(s))
	return out

func priced_copy(item: Dictionary) -> Dictionary:
	var d: Dictionary = item.duplicate()
	d["price"] = shop_price(int(d.get("price", 0)))
	return d

func has_action(id: String) -> bool:
	return actions.has(id)

func consume_jsn(seat: int) -> bool:
	if seat != 0:
		return false
	return spend_action("just_say_no")

func cancel_hostile(target: int, action_id: String) -> bool:
	if target != 0 or not ActionDB.is_hostile(action_id):
		return false
	return consume_jsn(0)

func result_action_ids() -> Array:
	var out: Array = []
	for id in actions:
		var info: Dictionary = ActionDB.get_by_id(str(id))
		if str(info.get("when", "turn")) == "results" or str(id) == "just_say_no":
			if not out.has(id):
				out.append(id)
	return out

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
	if roles.has(0):
		last_role = str(roles[0]["role"])
	var s: int = stake()
	for i in range(n):
		var seat: int = int(last_finish[i])
		var place: int = i + 1
		var gold_gain: int = 0
		var hp_delta: int = 0
		# Map place onto a 6-player table when fewer living: split half.
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
			# Scale: first half gain, second half lose; gold still inverse.
			var golds: Array = [4, 6, 8, 12, 16, 22]
			gold_gain = int(golds[mini(place - 1 + (6 - n), 5)])
			if place <= upper:
				hp_delta = s if place == 1 else int(ceil(float(s) / 2.0))
			else:
				hp_delta = -s if place == n else -int(ceil(float(s) / 2.0))
		var role: String = str(roles.get(seat, {}).get("role", RoleTrade.ROLE_NEUTRAL))
		var streak: int = _tick_role_streak(seat, role)
		var streak_bonus: int = streak_bonus_gold(streak)
		if seat == 0:
			if has_enhancement("gilded") and place <= 2:
				gold_gain += 2 * count_enhancement("gilded")
			gold_gain += streak_bonus
			gold += gold_gain
		hp[seat] = clampi(int(hp[seat]) + hp_delta, 0, max_hp if seat == 0 else START_HP)
		if seat == 0 and has_upgrade("safe_seat") and int(hp[0]) > 0:
			hp[0] = maxi(int(hp[0]), 5)
		last_payout.append({
			"seat": seat, "place": place,
			"gold": gold_gain if seat == 0 else 0,
			"hp_delta": hp_delta, "name": NAMES[seat], "role": role,
			"streak": streak, "streak_bonus": streak_bonus,
		})
	# Human Deep Pockets only raises human max; AIs stay 50.
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
	if gold < price:
		return false
	gold -= price
	if id.begins_with("favorite_"):
		favorite_rank = int(id.substr(9))
		owned_upgrades.append("favorite")
	else:
		owned_upgrades.append(id)
		if id == "pockets":
			max_hp += 10
			hp[0] = mini(int(hp[0]) + 10, max_hp)
	changed.emit()
	return true

func buy_action(id: String, price: int) -> bool:
	if gold < price:
		return false
	gold -= price
	actions.append(id)
	changed.emit()
	return true

func buy_enhancement(id: String, price: int) -> bool:
	if gold < price:
		return false
	gold -= price
	owned_enhancements.append(id)
	changed.emit()
	return true

func spend_action(id: String) -> bool:
	var i: int = actions.find(id)
	if i < 0:
		return false
	actions.remove_at(i)
	changed.emit()
	return true

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
	if has_upgrade("populist") and last_role == RoleTrade.ROLE_SCUM and int(hp[0]) > 0:
		hp[0] = mini(int(hp[0]) + 8 * count_upgrade("populist"), max_hp)
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
	shop_offers = ShopStock.draw_offers(rng, self, ShopStock.SLOTS)
	changed.emit()

func reroll_cost() -> int:
	return shop_price(ShopStock.reroll_cost_at(shop_rerolls))

func reroll_shop() -> bool:
	var c: int = reroll_cost()
	if gold < c:
		return false
	gold -= c
	shop_rerolls += 1
	shop_offers = ShopStock.draw_offers(rng, self, ShopStock.SLOTS)
	changed.emit()
	return true

func take_shop_offer(id: String) -> void:
	var remain: Array = []
	for it in shop_offers:
		if str(it.get("id", "")) != id:
			remain.append(it)
	shop_offers = remain
