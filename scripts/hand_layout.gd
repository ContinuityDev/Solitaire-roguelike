class_name HandLayout
extends RefCounted

## Fit n cards into a row width. Overlap, then wrap, then scale so nothing
## is claimed off-screen (x < 0 or x + width > row_w).

const MIN_W: float = 28.0
const MIN_STEP: float = 18.0
const GAP: float = 4.0
const ROW_GAP: float = 8.0

static func plan(n: int, row_w: float, prefer: Vector2) -> Dictionary:
	var empty: Dictionary = {
		"size": prefer, "positions": [], "rows": 1, "height": prefer.y + 16.0, "fits": true,
	}
	if n <= 0 or row_w < 8.0:
		return empty
	var card_w: float = clampf(prefer.x, MIN_W, 70.0)
	var rows: int = 1
	var per_row: int = n
	if n >= 2:
		var need: float = float(n) * card_w + float(n - 1) * GAP
		if need > row_w:
			var step: float = (row_w - card_w) / float(n - 1)
			if step < MIN_STEP:
				rows = 2
				per_row = int(ceil(float(n) / 2.0))
				if per_row >= 2:
					var row_need: float = float(per_row) * card_w + float(per_row - 1) * GAP
					if row_need > row_w:
						var room: float = row_w - float(per_row - 1) * MIN_STEP
						card_w = clampf(room, MIN_W, card_w)
	var card_h: float = card_w * (prefer.y / prefer.x if prefer.x > 0.1 else 1.4)
	var positions: Array = []
	for i in range(n):
		var r: int = 0
		var col: int = i
		var count_this: int = n
		if rows == 2:
			r = 0 if i < per_row else 1
			col = i if r == 0 else i - per_row
			count_this = per_row if r == 0 else n - per_row
		var st: float = card_w + GAP
		if count_this >= 2:
			var row_full: float = float(count_this) * card_w + float(count_this - 1) * GAP
			if row_full > row_w:
				st = (row_w - card_w) / float(count_this - 1)
		var total: float = card_w if count_this <= 1 else st * float(count_this - 1) + card_w
		var start: float = maxf(0.0, (row_w - total) * 0.5)
		var x: float = start + float(col) * st
		x = clampf(x, 0.0, maxf(0.0, row_w - card_w))
		var y: float = float(r) * (card_h + ROW_GAP)
		positions.append(Vector2(x, y))
	var height: float = card_h + 16.0 if rows == 1 else card_h * 2.0 + ROW_GAP + 20.0
	var fits: bool = true
	for p in positions:
		var pt: Vector2 = p
		if pt.x < -0.51 or pt.x + card_w > row_w + 0.51:
			fits = false
	return {
		"size": Vector2(card_w, card_h),
		"positions": positions,
		"rows": rows,
		"height": height,
		"fits": fits,
	}
