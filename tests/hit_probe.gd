extends SceneTree

## Geometry hit-test checklist for the leftmost-column bug.
## Passes when column_at_x maps each column's centre x back to itself,
## and when the tableau cards are laid out at explicit x = i*(w+gap).

var _frame: int = 0
var _main: Control
var _failures: int = 0
var _ran: bool = false

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _init() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 4 and not _ran:
		_ran = true
		_main.size = Vector2(390, 844)
		_main.call("_apply_responsive_layout")
		_main.call("_refresh")
		call_deferred("_run_checks")
	return false

func _run_checks() -> void:
	var board: SolitaireBoard = _main.get("board")
	var card_w: float = float((_main.get("_card_size") as Vector2).x)
	var gap: float = float(_main.get("_gap"))
	var cols: int = board.tableau.size()
	_check(cols >= 4, "tableau has columns (got %d)" % cols)
	for i in range(cols):
		var cx: float = float(i) * (card_w + gap) + card_w * 0.5
		var hit: int = SolitaireBoard.column_at_x(cx, card_w, gap, cols)
		_check(hit == i, "column_at_x centre of col %d -> %d" % [i, hit])
	var left_cx: float = card_w * 0.5
	var left_hit: int = SolitaireBoard.column_at_x(left_cx, card_w, gap, cols)
	_check(left_hit == 0, "leftmost centre hits col 0 (got %d, would-be-last=%d)" % [left_hit, cols - 1])
	var row: Control = _main.get("_tableau_row")
	var stride: float = card_w + gap
	for child in row.get_children():
		var cv: Control = child
		if not cv.has_meta("source"):
			continue
		var src: Dictionary = cv.get_meta("source")
		if str(src.get("type", "")) != "tableau":
			continue
		var expected_x: float = float(int(src["index"])) * stride
		_check(absf(cv.position.x - expected_x) < 0.5, "col %d card at x=%.1f (expected %.1f)" % [int(src["index"]), cv.position.x, expected_x])
	var run: RunManager = _main.get("run")
	run.ante = 3
	var cfg: Dictionary = run.act_board_config(3)
	board.setup(5, run.rng, 0, 1, {}, cfg["wall_specs"], int(cfg.get("bury", 0)))
	_check(not board.is_walled(0), "Act 3 first wall never seals column 0")
	_check(board.walls.size() == 1, "Act 3 places exactly one wall")
	if _failures == 0:
		print("ALL HIT TESTS PASSED")
		quit(0)
	else:
		printerr("%d HIT TEST(S) FAILED" % _failures)
		quit(1)
