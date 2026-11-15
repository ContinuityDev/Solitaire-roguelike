extends Control

## Main scene: builds the whole UI in code (no art assets), wires the pure
## SolitaireBoard logic to CardViews, and drives the roguelike loop:
##   play round -> meet target / clear board -> shop (pick 1 of 3) -> next ante
## Controls: click a card to select, click a destination to move.
## Double-click a card to send it to its foundation. Click stock to draw.

# Card size / overlap are computed from the live viewport in
# _apply_responsive_layout() so portrait phones and desktop both fit.
var _card_size: Vector2 = Vector2(86, 120)
var _overlap: float = 30.0
var _gap: float = 12.0
var _ui_ready: bool = false
var _title_label: Label
var _hud_labels: Array = []

var run: RunManager
var board: SolitaireBoard

var _score_label: Label
var _target_label: Label
var _mult_label: Label
var _deck_label: Label
var _message_label: Label
var _peek_label: Label
var _combo_label: Label
var _boss_label: Label
var _ranks_label: Label
var _score_msg: String = ""
var _cash_out_btn: Button
var _top_row: HBoxContainer
var _tableau_row: Control
var _patterns_label: Label
var _dest_views: Array = [] # [{view, dest}] rebuilt every _refresh, for drag drop targets
var _drag_candidate: Dictionary = {}
var _drag_press_pos: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_layer: Control
var _drag_source_view: CardView
var _last_tap_msec: int = 0
var _last_tap_key: String = ""
var _pending_dest: Dictionary = {}
var _board_area: VBoxContainer
var _shop: Shop
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_body: Label
var _overlay_buttons: HBoxContainer

var _selection: Dictionary = {} # empty = nothing selected

func _ready() -> void:
	run = RunManager.new()
	add_child(run)
	board = SolitaireBoard.new()
	_build_ui()
	run.score_changed.connect(_refresh_header)
	get_tree().root.size_changed.connect(_on_window_resized)
	_ui_ready = true
	_apply_responsive_layout()
	run.start_new_run()
	_start_round()
	_message("The curtain rises! Deck: A-%s. Tap the stock to draw, tap cards to move them." % RankSystem.full_name(run.max_rank))

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.09, 0.05, 0.20)  # midnight velvet stage
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pad)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	pad.add_child(root)

	_title_label = Label.new()
	_title_label.text = "ABRACADABRA! SOLITAIRE"
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.74, 0.32))
	_title_label.add_theme_font_size_override("font_size", 26)
	root.add_child(_title_label)

	# 2-column grid: HUD reflows to 2x2 on narrow (portrait phone) screens
	# instead of clipping a single long row.
	var header: GridContainer = GridContainer.new()
	header.columns = 2
	header.add_theme_constant_override("h_separation", 14)
	header.add_theme_constant_override("v_separation", 2)
	root.add_child(header)
	_score_label = _make_label(header, "Applause: 0")
	_target_label = _make_label(header, "Target: 0")
	_mult_label = _make_label(header, "Flair: x1.0")
	_deck_label = _make_label(header, "")
	_combo_label = _make_label(header, "Encore: -")
	_boss_label = _make_label(header, "")
	_ranks_label = Label.new()
	_ranks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ranks_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_ranks_label)
	_patterns_label = Label.new()
	_patterns_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_patterns_label.add_theme_font_size_override("font_size", 12)
	_patterns_label.add_theme_color_override("font_color", Color(0.65, 0.95, 0.75))
	root.add_child(_patterns_label)

	# HFlowContainer wraps buttons onto a second row on narrow phone screens.
	var buttons: HFlowContainer = HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	root.add_child(buttons)
	_cash_out_btn = Button.new()
	_cash_out_btn.text = "Take a Bow (target met!)"
	_cash_out_btn.disabled = true
	_cash_out_btn.pressed.connect(_on_cash_out)
	_cash_out_btn.custom_minimum_size = Vector2(0, 44)
	buttons.add_child(_cash_out_btn)
	var hint_btn: Button = Button.new()
	hint_btn.text = "Hint"
	hint_btn.pressed.connect(_on_hint)
	hint_btn.custom_minimum_size = Vector2(64, 44)
	buttons.add_child(hint_btn)
	var restart_btn: Button = Button.new()
	restart_btn.text = "Restart Run"
	restart_btn.pressed.connect(func() -> void: run.start_new_run(); _start_round(); _message("Encore from the top! Deck back to A-5."))
	restart_btn.custom_minimum_size = Vector2(0, 44)
	buttons.add_child(restart_btn)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message_label)
	_peek_label = Label.new()
	root.add_child(_peek_label)

	_top_row = HBoxContainer.new()
	_top_row.add_theme_constant_override("separation", 14)
	root.add_child(_top_row)

	# Explicit-geometry tableau area (NOT a container): column x positions
	# are computed from card width + gap, so hit-testing and dragging map
	# a pointer position to a column arithmetically. This replaces the old
	# HBoxContainer arrangement behind the leftmost-column mis-taps.
	_tableau_row = Control.new()
	_tableau_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tableau_row.custom_minimum_size = Vector2(0, 260)
	root.add_child(_tableau_row)

	_drag_layer = Control.new()
	_drag_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_layer)

	var shop_holder: CenterContainer = CenterContainer.new()
	shop_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_holder.visible = false
	add_child(shop_holder)
	_shop = Shop.new()
	shop_holder.add_child(_shop)
	_shop.visibility_changed.connect(func() -> void: shop_holder.visible = _shop.visible)
	_shop.choice_made.connect(_on_shop_choice)
	_shop.skipped.connect(_on_shop_done)

	var overlay_holder: CenterContainer = CenterContainer.new()
	overlay_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_holder.visible = false
	add_child(overlay_holder)
	_overlay = PanelContainer.new()
	_overlay.visible = false
	overlay_holder.add_child(_overlay)
	_overlay.visibility_changed.connect(func() -> void: overlay_holder.visible = _overlay.visible)
	var om: MarginContainer = MarginContainer.new()
	om.add_theme_constant_override("margin_left", 24)
	om.add_theme_constant_override("margin_right", 24)
	om.add_theme_constant_override("margin_top", 20)
	om.add_theme_constant_override("margin_bottom", 20)
	_overlay.add_child(om)
	var ov: VBoxContainer = VBoxContainer.new()
	ov.add_theme_constant_override("separation", 10)
	om.add_child(ov)
	_overlay_title = Label.new()
	_overlay_title.add_theme_font_size_override("font_size", 30)
	ov.add_child(_overlay_title)
	_overlay_body = Label.new()
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov.add_child(_overlay_body)
	_overlay_buttons = HBoxContainer.new()
	_overlay_buttons.add_theme_constant_override("separation", 8)
	ov.add_child(_overlay_buttons)

func _make_label(parent: Control, text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	_hud_labels.append(l)
	return l

func _on_window_resized() -> void:
	if not _ui_ready:
		return
	_apply_responsive_layout()
	_refresh()

## Fit cards + HUD to the current viewport (portrait phone, landscape, web).
## Card width is driven by the widest row (tableau columns, min 6 for the
## stock/waste/foundation row), clamped so tap targets stay >= ~38 px wide
## (46 px at 390 px wide, 92 px max on desktop).
func _apply_responsive_layout() -> void:
	var vw: float = size.x if size.x > 10.0 else 1280.0
	var cols: int = 6
	if board != null and not board.tableau.is_empty():
		cols = maxi(cols, board.tableau.size())
	_gap = 6.0 if vw < 600.0 else 12.0
	var w: float = floorf((vw - 32.0 - float(cols - 1) * _gap) / float(cols))
	w = clampf(w, 38.0, 92.0)
	_card_size = Vector2(w, w * 1.4)
	_overlap = _card_size.y * 0.26
	if _top_row != null:
		_top_row.add_theme_constant_override("separation", int(_gap))
	var narrow: bool = vw < 640.0
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", 19 if narrow else 26)
	for l in _hud_labels:
		(l as Label).add_theme_font_size_override("font_size", 13 if narrow else 18)
		(l as Label).custom_minimum_size = Vector2(maxf(90.0, (vw - 46.0) / 2.0), 0)
	if _message_label != null:
		_message_label.add_theme_font_size_override("font_size", 13 if narrow else 16)


# ---------------------------------------------------------------- rounds

func _start_round() -> void:
	_selection = {}
	_overlay.visible = false
	board.wild_low = run.has_upgrade("wild_low")
	var band: Dictionary = run.act_board_config()
	board.setup(run.max_rank, run.rng, run.extra_columns(), run.redeals_for_round(), run.enhancement_assignments, band["wall_specs"], int(band.get("bury", 0)))
	_refresh()
	_refresh_header()
	print("[metrics] Act %d band=%s walls=%d bury=%d live_moves=%d redeals=%d" % [
		run.ante, str(band["band"]), board.walls.size(), int(band.get("bury", 0)),
		board.count_candidate_moves(), board.redeals_left])
	var twist2: Dictionary = run.boss_twist()
	var wall_note: String = _walls_blurb()
	if not twist2.is_empty():
		_message("THE GRAND ILLUSION BEGINS: %s - %s%s" % [str(twist2["name"]), str(twist2["desc"]), wall_note])
	elif wall_note != "":
		_message("Act %d. %s" % [run.ante, wall_note.strip_edges()])

func _refresh_header() -> void:
	if run == null:
		return
	var narrow: bool = size.x < 640.0
	if narrow:
		_score_label.text = "Applause: %d" % run.score
		_target_label.text = "Act %d · Target: %d" % [run.ante, run.target]
		_mult_label.text = "Flair x%.2f · Streak %d · Moves %d" % [run.effective_mult(), run.streak, run.moves]
		_deck_label.text = "A-%s · %dc · Redeal %d · F %d/%d" % [
			RankSystem.short_label(run.max_rank), board.total_cards(), board.redeals_left,
			board.foundation_count(), board.total_cards()]
	else:
		_score_label.text = "Applause: %d" % run.score
		_target_label.text = "Act %d  Applause target: %d" % [run.ante, run.target]
		_mult_label.text = "Flair: x%.2f  Streak: %d  Moves: %d" % [run.effective_mult(), run.streak, run.moves]
		_deck_label.text = "Deck: A-%s (%d cards)  Redeals: %d  Finale piles: %d/%d" % [
			RankSystem.full_name(run.max_rank), board.total_cards(), board.redeals_left,
			board.foundation_count(), board.total_cards()]
	_cash_out_btn.disabled = not (run.round_active and run.score >= run.target)
	_combo_label.text = run.combo_text()
	var twist: Dictionary = run.boss_twist()
	if twist.is_empty():
		var next_boss: int = (run.ante - 1) / 3 * 3 + 3
		_boss_label.text = "Next Grand Illusion: Act %d" % next_boss
		_boss_label.add_theme_color_override("font_color", Color(0.92, 0.74, 0.32))
	else:
		_boss_label.text = "GRAND ILLUSION: %s" % str(twist["name"])
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.40))
	var rank_parts: Array[String] = []
	for r in range(1, run.max_rank + 1):
		var lv: int = run.rank_level(r)
		rank_parts.append("%s Lv%d%s" % [RankSystem.short_label(r), lv, "*" if lv > 1 else ""])
	_ranks_label.text = "Cast of ranks: " + "  ".join(rank_parts)
	if _patterns_label != null:
		var wall_line: String = _walls_blurb()
		_patterns_label.text = run.patterns_text() + wall_line
	if run.has_upgrade("peek_stock") and not board.stock.is_empty():
		var peek: Array[String] = []
		for i in range(maxi(0, board.stock.size() - 3), board.stock.size()):
			peek.append((board.stock[i] as CardData).label())
		peek.reverse()
		_peek_label.text = "Sleight-of-hand peek (top of stock first): %s" % ", ".join(peek)
	else:
		_peek_label.text = ""

func _message(text: String) -> void:
	_message_label.text = text
# ---------------------------------------------------------------- rendering

func _refresh() -> void:
	_apply_responsive_layout()
	_dest_views.clear()
	for child in _top_row.get_children():
		_top_row.remove_child(child)
		child.queue_free()
	for child in _tableau_row.get_children():
		_tableau_row.remove_child(child)
		child.queue_free()

	# Stock
	var stock_view: CardView
	if board.stock.is_empty():
		stock_view = CardView.new(null, _card_size)
		stock_view.placeholder_text = "REDEAL\n(%d)" % board.redeals_left if board.redeals_left > 0 else "EMPTY"
	else:
		# Show a face-down card as the stock back (its identity stays hidden).
		stock_view = CardView.new(CardData.new(1, 0, false), _card_size)
	stock_view.set_meta("action", "stock")
	stock_view.press_started.connect(_on_press_started)
	_top_row.add_child(stock_view)

	# Waste (top card only is playable)
	var waste_view: CardView
	if board.waste.is_empty():
		waste_view = CardView.new(null, _card_size)
		waste_view.placeholder_text = "WASTE"
	else:
		waste_view = CardView.new(board.waste[board.waste.size() - 1], _card_size)
	if not board.waste.is_empty():
		waste_view.rank_level = run.rank_level((board.waste[board.waste.size() - 1] as CardData).rank)
	waste_view.set_meta("source", {"type": "waste"})
	waste_view.set_meta("dest", {"type": "waste"})
	waste_view.press_started.connect(_on_press_started)
	_top_row.add_child(waste_view)
	_dest_views.append({"view": waste_view, "dest": {"type": "waste"}})

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(_gap * 1.5, 10)
	_top_row.add_child(spacer)

	# Foundations
	for suit in range(4):
		var pile: Array = board.foundation_pile(suit)
		var fv: CardView
		if pile.is_empty():
			fv = CardView.new(null, _card_size)
			fv.placeholder_suit = suit
		else:
			fv = CardView.new(pile[pile.size() - 1], _card_size)
			if _selection.get("type", "") == "foundation" and int(_selection.get("suit", -1)) == suit:
				fv.selected = true
		if not pile.is_empty():
			fv.rank_level = run.rank_level((pile[pile.size() - 1] as CardData).rank)
		fv.set_meta("source", {"type": "foundation", "suit": suit})
		fv.set_meta("dest", {"type": "foundation", "suit": suit})
		fv.press_started.connect(_on_press_started)
		_top_row.add_child(fv)
		_dest_views.append({"view": fv, "dest": {"type": "foundation", "suit": suit}})

	# Tableau: cards are direct children at explicit x positions (column i
	# starts at i * (card width + gap)). Taps and drops resolve the column
	# from that geometry via SolitaireBoard.column_at_x, so a left-edge
	# press cannot be delivered to the rightmost column by container order.
	var tallest: float = _card_size.y
	for i in range(board.tableau.size()):
		var pile2: Array = board.tableau[i]
		var x: float = float(i) * (_card_size.x + _gap)
		var walled: bool = board.is_walled(i)
		var wall: Dictionary = board.wall_at(i)
		if pile2.is_empty():
			var empty: CardView = CardView.new(null, _card_size)
			empty.position = Vector2(x, 0)
			empty.placeholder_text = "DROP"
			empty.set_meta("dest", {"type": "tableau", "index": i})
			empty.press_started.connect(_on_press_started)
			_tableau_row.add_child(empty)
			_dest_views.append({"view": empty, "dest": {"type": "tableau", "index": i}})
			continue
		for k in range(pile2.size()):
			var cv: CardView = CardView.new(pile2[k], _card_size)
			cv.position = Vector2(x, _overlap * float(k))
			cv.rank_level = run.rank_level((pile2[k] as CardData).rank)
			cv.set_meta("source", {"type": "tableau", "index": i, "start": k})
			cv.set_meta("dest", {"type": "tableau", "index": i})
			if walled and k == pile2.size() - 1:
				cv.wall_text = str(wall.get("name", "WALL"))
				cv.wall_sub = _wall_how(wall)
			if _selection.get("type", "") == "tableau" and int(_selection.get("index", -1)) == i and int(_selection.get("start", -1)) == k:
				cv.selected = true
			cv.press_started.connect(_on_press_started)
			_tableau_row.add_child(cv)
			_dest_views.append({"view": cv, "dest": {"type": "tableau", "index": i}})
		tallest = maxf(tallest, _overlap * float(pile2.size() - 1) + _card_size.y)
	_tableau_row.custom_minimum_size = Vector2(0, tallest)
	_refresh_header()

# ---------------------------------------------------------------- input

func _walls_blurb() -> String:
	if board == null or board.walls.is_empty():
		return ""
	var parts: Array[String] = []
	var keys: Array = board.walls.keys()
	keys.sort()
	for ci in keys:
		var w: Dictionary = board.wall_at(int(ci))
		parts.append("col %d %s (%s)" % [int(ci) + 1, str(w.get("name", "Wall")), _wall_how(w)])
	return " Walls: " + "; ".join(parts) + "."

func _wall_how(wall: Dictionary) -> String:
	match str(wall.get("kind", "")):
		"brick":
			return "crack with any Pattern"
		"curtain":
			return "a Pattern lifts it and flips the card behind"
		"iron":
			return "play a Jack or higher to a finale pile"
		"cracked":
			return "%d/3 finale plays" % int(wall.get("cracks", 0))
	return "sealed"

func _source_key(src: Dictionary) -> String:
	return "%s:%d:%d:%d" % [str(src.get("type", "")), int(src.get("index", -1)), int(src.get("start", -1)), int(src.get("suit", -1))]

func _on_press_started(view: CardView, global_pos: Vector2) -> void:
	if _dragging:
		return
	_drag_candidate = {"view": view}
	_drag_press_pos = global_pos
	_drag_source_view = view

func _pointer_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if _drag_candidate.is_empty() and not _dragging:
		return
	var is_move: bool = event is InputEventMouseMotion or event is InputEventScreenDrag
	var is_release: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		is_release = mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed
	elif event is InputEventScreenTouch:
		is_release = not (event as InputEventScreenTouch).pressed
	if is_move and not _dragging and not _drag_candidate.is_empty():
		if _pointer_pos(event).distance_to(_drag_press_pos) >= 14.0:
			_begin_drag()
	elif is_move and _dragging:
		_move_drag(_pointer_pos(event))
	elif is_release:
		if _dragging:
			_end_drag(_pointer_pos(event))
		elif not _drag_candidate.is_empty():
			_finish_tap(_drag_source_view)
		_drag_candidate = {}

func _begin_drag() -> void:
	var view: CardView = _drag_source_view
	if view == null or not view.has_meta("source"):
		_drag_candidate = {}
		return
	var src: Dictionary = view.get_meta("source")
	if str(src.get("type", "")) == "tableau" and board.is_walled(int(src.get("index", -1))):
		_drag_candidate = {}
		_message("Sealed — %s." % _wall_how(board.wall_at(int(src.get("index", -1)))))
		return
	var moving: Array = board._peek_source(src)
	if moving.is_empty():
		_drag_candidate = {}
		return
	_dragging = true
	_selection = src
	_drag_offset = _drag_press_pos - view.global_position
	view.modulate.a = 0.35
	for i in range(moving.size()):
		var ghost: CardView = CardView.new(moving[i], _card_size)
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.rank_level = run.rank_level((moving[i] as CardData).rank)
		ghost.position = view.global_position + Vector2(0, _overlap * float(i))
		ghost.z_index = 100 + i
		_drag_layer.add_child(ghost)
	_highlight_legal(moving[0], moving.size() == 1)
	_move_drag(_drag_press_pos)

func _move_drag(pointer: Vector2) -> void:
	var kids: Array = _drag_layer.get_children()
	for i in range(kids.size()):
		(kids[i] as Control).global_position = pointer - _drag_offset + Vector2(0, _overlap * float(i))

func _highlight_legal(bottom: CardData, single: bool) -> void:
	for entry in _dest_views:
		var dest: Dictionary = entry["dest"]
		var view: CardView = entry["view"]
		var ok: bool = false
		if str(dest.get("type", "")) == "foundation":
			ok = single and int(dest.get("suit", -1)) == bottom.suit and board.can_place_on_foundation(bottom)
		elif str(dest.get("type", "")) == "tableau":
			var di: int = int(dest.get("index", -1))
			ok = not board.is_walled(di) and board.can_place_on_tableau(bottom, board.tableau[di])
			if ok and _selection.get("type", "") == "tableau" and int(_selection.get("index", -2)) == di:
				ok = false
		if ok:
			view.highlighted = true
			view.queue_redraw()

func _end_drag(pointer: Vector2) -> void:
	var dest: Dictionary = _dest_under(pointer)
	_dragging = false
	_drag_candidate = {}
	for child in _drag_layer.get_children():
		_drag_layer.remove_child(child)
		child.queue_free()
	if dest.is_empty():
		_message("Dropped back.")
		_refresh()
		return
	_try_move_selection_to(dest)

func _dest_under(pointer: Vector2) -> Dictionary:
	# Prefer the card actually under the pointer (top-most last).
	var found: Dictionary = {}
	for entry in _dest_views:
		var view: CardView = entry["view"]
		if view.get_global_rect().has_point(pointer):
			found = entry["dest"]
	if not found.is_empty() and str(found.get("type", "")) != "waste":
		return found
	# Otherwise map x onto a tableau column, including the empty space under a short pile.
	if _tableau_row != null:
		var local: Vector2 = pointer - _tableau_row.global_position
		var ci: int = SolitaireBoard.column_at_x(local.x, _card_size.x, _gap, board.tableau.size())
		if ci >= 0 and local.y >= -8.0:
			return {"type": "tableau", "index": ci}
	return {}

func _finish_tap(view: CardView) -> void:
	if view == null or not is_instance_valid(view):
		return
	if str(view.get_meta("action", "")) == "stock":
		_last_tap_msec = 0
		_on_stock_clicked(view)
		return
	var src: Dictionary = view.get_meta("source", {})
	var now: int = Time.get_ticks_msec()
	var key: String = _source_key(src)
	if now - _last_tap_msec < 450 and key == _last_tap_key and not src.is_empty():
		_last_tap_msec = 0
		_last_tap_key = ""
		_on_card_double_clicked(view)
	else:
		_last_tap_msec = now
		_last_tap_key = key
		_on_card_clicked(view)

func _on_stock_clicked(_view: CardView) -> void:
	if not run.round_active:
		return
	_selection = {}
	if not board.stock.is_empty():
		board.draw_stock()
		run.note_draw()
		run.score_for_event("draw")
		_message("Drew %s." % (board.waste[board.waste.size() - 1] as CardData).display_name())
	elif board.recycle_waste():
		_message("Recycled the waste (%d redeals left)." % board.redeals_left)
	else:
		_message("Stock is empty and no redeals remain.")
	_refresh()
	_check_end_conditions()

func _on_card_clicked(view: CardView) -> void:
	if not run.round_active:
		return
	# Destination click while something is selected?
	if not _selection.is_empty() and view.has_meta("dest"):
		var dest: Dictionary = view.get_meta("dest")
		# Clicking the selected card itself deselects.
		if view.has_meta("source"):
			var src2: Dictionary = view.get_meta("source")
			if str(src2.get("type", "")) == str(_selection.get("type", "")) \
					and int(src2.get("index", -9)) == int(_selection.get("index", -8)) \
					and int(src2.get("start", -9)) == int(_selection.get("start", -8)) \
					and int(src2.get("suit", -9)) == int(_selection.get("suit", -8)):
				_selection = {}
				_refresh()
				return
		if _try_move_selection_to(dest):
			return
		# Fall through: maybe they meant to select this card instead.
	if view.has_meta("source"):
		var src: Dictionary = view.get_meta("source")
		if str(src.get("type", "")) == "tableau" and board.is_walled(int(src.get("index", -1))):
			_selection = {}
			_message("That column is sealed — %s." % _wall_how(board.wall_at(int(src.get("index", -1)))))
			_refresh()
			return
		# Trust geometry over the view's stored column: the card under the
		# pointer's x is the one the player aimed at.
		if str(src.get("type", "")) == "tableau":
			var aimed: int = SolitaireBoard.column_at_x(view.get_global_rect().get_center().x - _tableau_row.global_position.x, _card_size.x, _gap, board.tableau.size())
			if aimed >= 0 and aimed != int(src.get("index", -1)):
				src = {"type": "tableau", "index": aimed, "start": int(src.get("start", 0))}
				src["start"] = mini(int(src["start"]), board.tableau[aimed].size() - 1)
		var moving: Array = board._peek_source(src)
		if moving.is_empty():
			_selection = {}
			_message("Nothing playable there.")
		else:
			_selection = src
			_message("Selected %s. Tap a pile, drag it, or double-tap for the best spot." % (moving[0] as CardData).display_name())
	else:
		_selection = {}
	_refresh()

func _on_card_double_clicked(view: CardView) -> void:
	if not run.round_active or not view.has_meta("source"):
		return
	var src: Dictionary = view.get_meta("source")
	if str(src.get("type", "")) == "tableau" and board.is_walled(int(src.get("index", -1))):
		_message("That column is sealed — %s." % _wall_how(board.wall_at(int(src.get("index", -1)))))
		return
	var best: Dictionary = board.find_best_move(src)
	if best.is_empty():
		_message("No good spot for that card yet.")
		return
	_selection = src
	var reason: String = str(best.get("reason", "tableau"))
	if not _try_move_selection_to(best["dest"]):
		return
	var card_name: String = ""
	if _score_msg != "":
		card_name = _score_msg
	match reason:
		"foundation":
			_message("Double-tap sent it to its finale pile. " + card_name)
		"reveal":
			_message("Parked it to reveal the card beneath. " + card_name)
		"free_column":
			_message("Moved it and freed the column. " + card_name)
		"pattern":
			_message("Moved it into a Pattern. " + card_name)
		_:
			_message("Moved it to the best open spot. " + card_name)

func _try_move_selection_to(dest: Dictionary) -> bool:
	var src: Dictionary = _selection
	var result: Dictionary = board.try_move(src, dest)
	if not bool(result.get("ok", false)):
		_message("Illegal move.")
		return false
	_selection = {}
	_pending_dest = dest
	_apply_move_scoring(result, src)
	_pending_dest = {}
	_message(_score_msg if _score_msg != "" else "Moved %s." % (result["card"] as CardData).display_name())
	_refresh()
	_check_end_conditions()
	return true

func _apply_move_scoring(result: Dictionary, src: Dictionary) -> void:
	_score_msg = ""
	if bool(result.get("to_foundation", false)):
		var pts: int = run.score_for_event("foundation", result["card"])
		var b: Dictionary = run.last_breakdown
		_score_msg = "Finale +%d applause (applause %d + encore %d, Flair x%.2f)." % [pts, int(b.get("base_chips", 0)) + int(b.get("enh_chips", 0)), int(b.get("combo_bonus", 0)), float(b.get("mult_used", 1.0))]
		if bool(b.get("broke", false)) and int(b.get("broken_chain", 0)) >= 2:
			_score_msg = "ENCORE DROPPED (was x%d)! " % int(b.get("broken_chain", 0)) + _score_msg
		elif bool(b.get("used_grace", false)):
			_score_msg += " The Safety Line saved the encore!"
		if bool(b.get("lucky_proc", false)):
			_score_msg += " A RABBIT FROM THE HAT!"
		_message(_score_msg)
	elif str(src.get("type", "")) == "foundation":
		run.score_for_event("foundation_to_tableau")
	elif str(src.get("type", "")) == "waste":
		run.score_for_event("waste_to_tableau")
	else:
		run.score_for_event("tableau_move")
	if bool(result.get("flipped", false)):
		var fpts: int = run.score_for_event("flip")
		_score_msg += " Reveal +%d applause." % fpts
		if run.register_flip():
			var epts: int = run.register_pattern("excavation")
			_score_msg += " EXCAVATION +%d!" % epts
	_score_msg += _award_followups(result, src)

func _award_followups(result: Dictionary, src: Dictionary) -> String:
	var bits: Array[String] = []
	var cracked_a_pattern: bool = false
	if bool(result.get("to_foundation", false)):
		for pid in run.register_foundation_play(result["card"], board):
			var pts: int = run.register_pattern(str(pid))
			bits.append("%s +%d" % [PatternDB.display_name(str(pid)), pts])
			cracked_a_pattern = true
	var dest_col: int = -1
	if str(result.get("dest_type", "")) == "tableau":
		dest_col = int(result.get("dest_index", -1))
	# Destination column isn't on the move result; recover it from the board
	# by scanning for the moved card when the caller set it. The try_move
	# path below passes dest via _pending_dest.
	if _pending_dest.get("type", "") == "tableau":
		dest_col = int(_pending_dest.get("index", -1))
	if dest_col >= 0 and dest_col < board.tableau.size():
		for inst in PatternDB.tableau_instances(board.tableau[dest_col]):
			var sig: String = "%s|%s" % [str(inst["id"]), str(inst["signature"])]
			if run.awarded_tableau_patterns.has(sig):
				continue
			run.awarded_tableau_patterns[sig] = true
			var tpts: int = run.register_pattern(str(inst["id"]))
			bits.append("%s +%d" % [PatternDB.display_name(str(inst["id"])), tpts])
			cracked_a_pattern = true
	if str(src.get("type", "")) == "tableau":
		var sp: Array = board.tableau[int(src.get("index", 0))]
		if sp.is_empty():
			var bpts: int = run.register_pattern("breakout")
			bits.append("Breakout +%d" % bpts)
			cracked_a_pattern = true
			if run.book_done_this_round:
				var hpts: int = run.register_pattern("housekeeping")
				bits.append("Full House-keeping +%d" % hpts)
	if cracked_a_pattern:
		bits.append_array(_open_walls(board.register_wall_event("pattern")))
	if bool(result.get("to_foundation", false)):
		bits.append_array(_open_walls(board.register_wall_event("foundation", result["card"])))
	if bits.is_empty():
		return ""
	return " " + " · ".join(bits)

func _open_walls(opened: Array) -> Array[String]:
	var bits: Array[String] = []
	for o in opened:
		run.metrics["walls_opened"] = int(run.metrics["walls_opened"]) + 1
		var kind: String = str(o["kind"])
		bits.append("%s down on column %d" % [kind.capitalize(), int(o["column"]) + 1])
		if bool(o.get("flipped", false)):
			var fpts: int = run.score_for_event("flip")
			bits.append("curtain reveal +%d" % fpts)
			print("[metrics] wall opened kind=%s col=%d" % [kind, int(o["column"])])
	return bits

# ---------------------------------------------------------------- flow

func _check_end_conditions() -> void:
	if not run.round_active:
		return
	if board.is_cleared():
		var bonus: int = run.board_clear_bonus()
		_message("A flawless finale - board cleared! Bonus applause +%d." % bonus)
		_win_round(true)
		return
	if run.score >= run.target:
		_message("The crowd is roaring! Press 'Take a Bow' to end the trick in triumph, or keep playing for more applause.")
		# Auto-prompt is friendlier for a prototype: treat meeting target as a win
		# only via the button, so players can push their luck. Nothing to do here.
	if not board.has_any_legal_move():
		run.note_dead_board()
		run.fail_run()
		_show_overlay("THE TRICK FALLS FLAT...", "No legal moves remain in Act %d.\nFinal applause this trick: %d / %d target.\nHighest deck rank: %s. The crowd shuffles out..." % [run.ante, run.score, run.target, RankSystem.full_name(run.max_rank)], ["New Run"])

func _on_cash_out() -> void:
	if run.round_active and run.score >= run.target:
		_win_round(false)

func _win_round(cleared: bool) -> void:
	run.round_active = false
	if run.ante >= run.max_ante and not run.endless:
		run.run_won.emit()
		_show_overlay("THE CROWD GOES WILD!", "A standing ovation! You performed all %d acts! Final deck: A-%s.\nPress Endless to keep the show going, or start a New Run." % [run.max_ante, RankSystem.full_name(run.max_rank)], ["Endless Mode", "New Run"])
		return
	var choices: Array = UpgradeDB.build_shop_choices(run.max_rank, run.owned_upgrades, 3, run.rng, RunManager.PROTOTYPE_MAX_RANK)
	var ctx: String = "Act %d trick complete%s! Applause: %d / %d." % [run.ante, " (a flawless finale - board cleared!)" if cleared else "", run.score, run.target]
	_shop.present(choices, ctx)
	_refresh()

func _on_shop_choice(choice: Dictionary) -> void:
	var result_text: String = run.apply_shop_choice(choice)
	_on_shop_done()
	_message("%s Act %d. Applause target %d." % [result_text, run.ante, run.target])

func _on_shop_done() -> void:
	run.ante += 1
	run.start_round()
	_start_round()
	_message("Act %d begins. Applause target %d. Deck: A-%s (%d cards)." % [run.ante, run.target, RankSystem.full_name(run.max_rank), board.total_cards()])

func _on_hint() -> void:
	var sources: Array = []
	if not board.waste.is_empty():
		sources.append({"type": "waste"})
	for i in range(board.tableau.size()):
		if board.is_walled(i):
			continue
		var pile: Array = board.tableau[i]
		for start in range(pile.size() - 1, -1, -1):
			if (pile[start] as CardData).face_up:
				sources.append({"type": "tableau", "index": i, "start": start})
				break
	for src in sources:
		var best: Dictionary = board.find_best_move(src)
		if best.is_empty():
			continue
		var moving: Array = board._peek_source(src)
		var who: String = (moving[0] as CardData).display_name() if not moving.is_empty() else "that card"
		_message("Hint: %s — %s (%d live moves)." % [who, str(best.get("reason", "move")), board.count_candidate_moves()])
		return
	if board.has_any_legal_move():
		_message("Hint: draw from the stock. %d live moves." % board.count_candidate_moves())
	else:
		_message("Hint: no legal moves remain.")

func _show_overlay(title_text: String, body: String, actions: Array) -> void:
	_overlay_body.custom_minimum_size = Vector2(minf(420.0, maxf(240.0, size.x - 72.0)), 0)
	_overlay_title.text = title_text
	_overlay_body.text = body
	for child in _overlay_buttons.get_children():
		_overlay_buttons.remove_child(child)
		child.queue_free()
	for action in actions:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(0, 44)
		b.text = str(action)
		var captured: String = str(action)
		b.pressed.connect(func() -> void: _on_overlay_action(captured))
		_overlay_buttons.add_child(b)
	_overlay.visible = true

func _on_overlay_action(action: String) -> void:
	_overlay.visible = false
	match action:
		"New Run":
			run.start_new_run()
			_start_round()
			_message("The curtain rises on a new show! Deck: A-%s." % RankSystem.full_name(run.max_rank))
		"Endless Mode":
			run.endless = true
			run.ante += 1
			run.start_round()
			_start_round()
			_message("Endless encores: Act %d." % run.ante)
