class_name PresidentAI
extends RefCounted

## Heuristic President player. Personality 0 = timid (dump low, save bombs),
## 1 = balanced, 2 = aggressive (follows with 2s more often).

static func choose(game: PresidentGame, seat: int, personality: int = 1) -> Dictionary:
	if game.has_passed(seat):
		return {"pass": true}
	var legal: Array = game.legal_combos(seat)
	if legal.is_empty():
		return {"pass": true}
	if game.must_pass_seat == seat:
		return {"pass": true}
	legal.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = game.play_power(seat, int(a["rank"]))
		var pb: int = game.play_power(seat, int(b["rank"]))
		if pa == pb:
			return int(a["count"]) > int(b["count"])
		return pa < pb
	)
	if game.lead:
		return _choose_lead(legal, personality)
	return _choose_follow(legal, personality, game)

static func _choose_lead(legal: Array, personality: int) -> Dictionary:
	for combo in legal:
		var r: int = int(combo["rank"])
		if not RankSystem.is_joker(r) and r != 2:
			return {"pass": false, "combo": combo}
	for combo2 in legal:
		if not RankSystem.is_joker(int(combo2["rank"])):
			return {"pass": false, "combo": combo2}
	return {"pass": false, "combo": legal[0]}

static func _choose_follow(legal: Array, personality: int, game: PresidentGame) -> Dictionary:
	var non_bomb: Array = []
	var bombs: Array = []
	var jokers: Array = []
	for combo in legal:
		var r: int = int(combo["rank"])
		if RankSystem.is_joker(r):
			jokers.append(combo)
		elif r == 2:
			bombs.append(combo)
		else:
			non_bomb.append(combo)
	if not non_bomb.is_empty():
		return {"pass": false, "combo": non_bomb[0]}
	var hand_n: int = game.hand_of(game.current_player).size()
	if not bombs.is_empty() and (personality >= 2 or hand_n <= int(bombs[0]["count"]) + 1):
		return {"pass": false, "combo": bombs[0]}
	if not jokers.is_empty() and (personality >= 1 or hand_n <= 3 or bombs.is_empty()):
		return {"pass": false, "combo": jokers[0]}
	if not bombs.is_empty() and personality != 0:
		return {"pass": false, "combo": bombs[0]}
	if not jokers.is_empty():
		return {"pass": false, "combo": jokers[0]}
	return {"pass": true}

## After a round, if this seat holds a results-time action, pick one.
static func choose_role_action(finish: Array, seat: int, inventory: Array) -> String:
	if inventory.is_empty() or finish.size() < 3:
		return ""
	var role: String = RoleTrade.role_of(finish, seat)
	if inventory.has("uprising") and (role == RoleTrade.ROLE_SCUM or role == RoleTrade.ROLE_VA):
		return "uprising"
	if inventory.has("coup") and role != RoleTrade.ROLE_PRES:
		return "coup"
	if inventory.has("pardon") and (role == RoleTrade.ROLE_SCUM or role == RoleTrade.ROLE_VA):
		return "pardon"
	if inventory.has("just_say_no") and (role == RoleTrade.ROLE_SCUM or role == RoleTrade.ROLE_VA):
		return "just_say_no"
	if inventory.has("recess") and role == RoleTrade.ROLE_SCUM:
		return "recess"
	if inventory.has("impeach") and role == RoleTrade.ROLE_VP:
		return "impeach"
	return ""

## 0–1 buy from a personal 2-offer desk. Empty dict = skip.
static func choose_shop(offers: Array, gold: int, personality: int, role: String) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = 0
	for o in offers:
		var d: Dictionary = o
		var price: int = int(d.get("price", 0))
		if price <= 0 or price > gold:
			continue
		var id: String = str(d.get("id", ""))
		var score: int = 2
		if id == "just_say_no" and (role == RoleTrade.ROLE_SCUM or role == RoleTrade.ROLE_VA):
			score += 8
		if id == "uprising" and (role == RoleTrade.ROLE_SCUM or role == RoleTrade.ROLE_VA):
			score += 7
		if id == "packed":
			score += 5
		if RankModDB.is_mod(id):
			score += 5
		if ComboBuffDB.is_combo(id):
			score += 5
		if id == "incumbent" or id == "forge" or id == "rally":
			score += 4
		if id == "veto" or id == "filibuster" or id == "tax":
			score += 4
		if id == "exec" and personality >= 2:
			score += 3
		if id == "coup" and role != RoleTrade.ROLE_PRES:
			score += 3
		if personality == 0 and id == "just_say_no":
			score += 2
		if personality == 2 and (id == "filibuster" or id == "veto"):
			score += 2
		if score > best_score:
			best = d
			best_score = score
		elif score == best_score and not best.is_empty() and price < int(best.get("price", 999)):
			best = d
	if best.is_empty():
		return {}
	# Timid seats keep a little gold instead of emptying the purse on a luxury.
	if personality == 0 and gold - int(best.get("price", 0)) == 0 and int(best.get("price", 0)) >= 12:
		return {}
	return best

## Pick a turn action to actually fire, or "" to play cards instead.
static func choose_turn_action(game: PresidentGame, run: RunManager, seat: int) -> String:
	var inv: Array = run.actions_of(seat)
	if inv.is_empty():
		return ""
	var persona: int = seat % 3
	var legal: Array = game.legal_combos(seat)
	if inv.has("exec") and legal.is_empty() and not game.lead:
		return "exec"
	if inv.has("forge") and _has_promotable(game, seat):
		return "forge"
	if inv.has("rally") and _has_promotable(game, seat):
		return "rally"
	if inv.has("tax") and _someone_fatter(game, seat):
		return "tax"
	if inv.has("filibuster") and not game.lead and persona >= 1:
		return "filibuster"
	if inv.has("veto") and persona >= 2:
		return "veto"
	if inv.has("leak") and persona == 1 and game.peek_seat < 0:
		return "leak"
	# If they still hold a turn action after those filters, dump the first one.
	for id in ["tax", "filibuster", "veto", "exec", "forge", "rally", "leak"]:
		if inv.has(id):
			return str(id)
	return ""

static func _has_promotable(game: PresidentGame, seat: int) -> bool:
	for c in game.hand_of(seat):
		var r: int = (c as CardData).rank
		if r != 2 and r != 1 and not RankSystem.is_joker(r):
			return true
	return false

static func _someone_fatter(game: PresidentGame, seat: int) -> bool:
	var mine: int = game.hand_of(seat).size()
	for s in game.active_seats():
		if int(s) == seat:
			continue
		if game.hand_of(int(s)).size() >= mine + 1:
			return true
	return false
