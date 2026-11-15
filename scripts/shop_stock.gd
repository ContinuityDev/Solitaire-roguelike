class_name ShopStock
extends RefCounted

## Limited desk stock. 4 offers per visit, mixed kinds, no maxed reprints.

const SLOTS: int = 4
const REROLL_BASE: int = 2
const REROLL_STEP: int = 2
const AI_SLOTS: int = 2

static func catalog_size() -> int:
	return UpgradeDB.UPGRADES.size() + ActionDB.ACTIONS.size() + EnhancementDB.ENHANCEMENTS.size() + RankModDB.MODS.size()

static func reroll_cost_at(rerolls_done: int) -> int:
	return REROLL_BASE + REROLL_STEP * rerolls_done

static func tagged(item: Dictionary, kind: String) -> Dictionary:
	var d: Dictionary = item.duplicate()
	d["kind"] = kind
	return d

static func full_catalog() -> Array:
	var out: Array = []
	for u in UpgradeDB.UPGRADES:
		out.append(tagged(u, "upgrade"))
	for m in RankModDB.MODS:
		out.append(tagged(m, "upgrade"))
	for a in ActionDB.ACTIONS:
		out.append(tagged(a, "action"))
	for e in EnhancementDB.ENHANCEMENTS:
		out.append(tagged(e, "enhancement"))
	return out

static func max_owned(item: Dictionary) -> int:
	if item.has("max"):
		return int(item["max"])
	var kind: String = str(item.get("kind", "upgrade"))
	var id: String = str(item.get("id", ""))
	if RankModDB.is_mod(id):
		return 1
	if kind == "action" or kind == "enhancement":
		return 2
	if id == "packed" or id == "incumbent" or id == "pockets" or id == "lobbyist":
		return 3
	return 1

static func owned_of(run: RunManager, item: Dictionary, seat: int = 0) -> int:
	var id: String = str(item.get("id", ""))
	if id.begins_with("favorite_"):
		var rank: int = int(id.substr(9))
		return 1 if run.favorite_of(seat) == rank else 0
	return int(run.owned_counts_of(seat).get(id, 0))

static func is_maxed(run: RunManager, item: Dictionary, seat: int = 0) -> bool:
	return owned_of(run, item, seat) >= max_owned(item)

static func available(run: RunManager, seat: int = 0) -> Array:
	var out: Array = []
	for it in full_catalog():
		if not is_maxed(run, it, seat):
			out.append(it)
	return out

static func _weight(item: Dictionary) -> int:
	return 2 if str(item.get("kind", "")) == "enhancement" else 3

static func _pick_weighted(rng: RandomNumberGenerator, items: Array) -> Dictionary:
	var total: int = 0
	for it in items:
		total += _weight(it)
	if total <= 0:
		return items[0]
	var r: int = rng.randi_range(1, total)
	var acc: int = 0
	for it2 in items:
		acc += _weight(it2)
		if r <= acc:
			return it2
	return items[items.size() - 1]

## Mix: try one of each kind, then weighted fill. Never repeats an id in one draw.
static func draw_offers(rng: RandomNumberGenerator, run: RunManager, count: int = SLOTS, seat: int = 0) -> Array:
	var pool: Array = available(run, seat)
	var out: Array = []
	var used: Dictionary = {}
	for kind in ["upgrade", "action", "enhancement"]:
		if out.size() >= count:
			break
		var bag: Array = []
		for it in pool:
			if str(it.get("kind", "")) == kind and not used.has(str(it["id"])):
				bag.append(it)
		if bag.is_empty():
			continue
		var pick: Dictionary = bag[rng.randi_range(0, bag.size() - 1)]
		out.append(pick)
		used[str(pick["id"])] = true
	while out.size() < count:
		var rest: Array = []
		for it2 in pool:
			if not used.has(str(it2["id"])):
				rest.append(it2)
		if rest.is_empty():
			break
		var pick2: Dictionary = _pick_weighted(rng, rest)
		out.append(pick2)
		used[str(pick2["id"])] = true
	return out
