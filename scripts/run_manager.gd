class_name RunManager
extends Node

## President run: HP, gold, round stake, owned upgrades, action inventory.
## Seat 0 is the human; seats 1-5 are AIs with their own HP.

signal changed

const SEATS: int = 6
const START_HP: int = 50
const NAMES: Array = ["You", "The Speaker", "The Whip", "The Veep", "The Justice", "The General"]
const GOLD_BY_PLACE: Array = [0, 4, 6, 8, 12, 16, 22] # index = place 1..6

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var round_n: int = 1
var gold: int = 0
var max_hp: int = START_HP
var hp: Array = [] # 6 ints
var owned_upgrades: Array = []
var actions: Array = [] # action ids in inventory
var favorite_rank: int = 0
var whip_used: bool = false
var last_payout: Array = [] # [{seat, place, gold, hp_delta}]
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
	return count_upgrade("incumbent")

## Place array is seats in finish order (1st ... last).
func apply_payouts(finish_order: Array) -> void:
	last_payout.clear()
	var n: int = finish_order.size()
	if n == 0:
		return
	var s: int = stake()
	for i in range(n):
		var seat: int = int(finish_order[i])
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
		if seat == 0:
			gold += gold_gain
		hp[seat] = clampi(int(hp[seat]) + hp_delta, 0, max_hp if seat == 0 else START_HP)
		last_payout.append({"seat": seat, "place": place, "gold": gold_gain if seat == 0 else 0, "hp_delta": hp_delta, "name": NAMES[seat]})
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

func spend_action(id: String) -> bool:
	var i: int = actions.find(id)
	if i < 0:
		return false
	actions.remove_at(i)
	changed.emit()
	return true

func next_round() -> void:
	if run_over:
		return
	round_n += 1
	whip_used = false
	changed.emit()
