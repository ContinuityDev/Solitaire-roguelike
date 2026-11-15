class_name PresidentAI
extends RefCounted

## Heuristic President player. Personality 0 = timid (dump low, save bombs),
## 1 = balanced, 2 = aggressive (follows with 2s more often).

static func choose(game: PresidentGame, seat: int, personality: int = 1) -> Dictionary:
	var legal: Array = game.legal_combos(seat)
	if legal.is_empty():
		return {"pass": true}
	if game.must_pass_seat == seat:
		return {"pass": true}
	# Sort legal plays: lowest power first, then larger count (dump more).
	legal.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = RankSystem.president_power(int(a["rank"]))
		var pb: int = RankSystem.president_power(int(b["rank"]))
		if pa == pb:
			return int(a["count"]) > int(b["count"])
		return pa < pb
	)
	if game.lead:
		return _choose_lead(legal, personality)
	return _choose_follow(legal, personality, game)

static func _choose_lead(legal: Array, personality: int) -> Dictionary:
	# Prefer dumping 3s/4s; save 2s unless that is the whole hand.
	for combo in legal:
		if int(combo["rank"]) != 2:
			return {"pass": false, "combo": combo}
	return {"pass": false, "combo": legal[0]}

static func _choose_follow(legal: Array, personality: int, game: PresidentGame) -> Dictionary:
	var non_bomb: Array = []
	var bombs: Array = []
	for combo in legal:
		if int(combo["rank"]) == 2:
			bombs.append(combo)
		else:
			non_bomb.append(combo)
	if not non_bomb.is_empty():
		return {"pass": false, "combo": non_bomb[0]}
	# Only a 2 would follow. Timid seats pass unless emptying or aggressive.
	if bombs.is_empty():
		return {"pass": true}
	var hand_n: int = game.hand_of(game.current_player).size() if false else 99
	hand_n = game.hand_of(game.current_player).size()
	if personality >= 2 or hand_n <= int(bombs[0]["count"]) + 1:
		return {"pass": false, "combo": bombs[0]}
	if personality == 0:
		return {"pass": true}
	# Balanced: 40% bomb, else pass.
	return {"pass": true}
