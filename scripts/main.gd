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
var _tableau_row: HBoxContainer
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

	_tableau_row = HBoxContainer.new()
	_tableau_row.add_theme_constant_override("separation", 14)
	_tableau_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(_tableau_row)

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
	if _tableau_row != null:
		_tableau_row.add_theme_constant_override("separation", int(_gap))
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
	board.setup(run.max_rank, run.rng, run.extra_columns(), run.redeals_for_round(), run.enhancement_assignments)
	_refresh()
	_refresh_header()
	var twist2: Dictionary = run.boss_twist()
	if not twist2.is_empty():
		_message("THE GRAND ILLUSION BEGINS: %s - %s" % [str(twist2["name"]), str(twist2["desc"])])

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
	stock_view.clicked.connect(_on_stock_clicked)
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
	waste_view.clicked.connect(_on_card_clicked)
	waste_view.double_clicked.connect(_on_card_double_clicked)
	_top_row.add_child(waste_view)

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
		fv.clicked.connect(_on_card_clicked)
		fv.double_clicked.connect(_on_card_double_clicked)
		_top_row.add_child(fv)

	# Tableau
	for i in range(board.tableau.size()):
		var pile2: Array = board.tableau[i]
		var col: Control = Control.new()
		col.custom_minimum_size = Vector2(_card_size.x, _card_size.y + _overlap * float(maxi(0, pile2.size() - 1)))
		_tableau_row.add_child(col)
		if pile2.is_empty():
			var empty: CardView = CardView.new(null, _card_size)
			empty.placeholder_text = "DROP"
			empty.set_meta("dest", {"type": "tableau", "index": i})
			empty.clicked.connect(_on_card_clicked)
			col.add_child(empty)
			continue
		for k in range(pile2.size()):
			var cv: CardView = CardView.new(pile2[k], _card_size)
			cv.position = Vector2(0, _overlap * float(k))
			cv.rank_level = run.rank_level((pile2[k] as CardData).rank)
			cv.set_meta("source", {"type": "tableau", "index": i, "start": k})
			cv.set_meta("dest", {"type": "tableau", "index": i})
			if _selection.get("type", "") == "tableau" and int(_selection.get("index", -1)) == i and int(_selection.get("start", -1)) == k:
				cv.selected = true
			cv.clicked.connect(_on_card_clicked)
			cv.double_clicked.connect(_on_card_double_clicked)
			col.add_child(cv)
	_refresh_header()

# ---------------------------------------------------------------- input

func _on_stock_clicked(_view: CardView) -> void:
	if not run.round_active:
		return
	_selection = {}
	if not board.stock.is_empty():
		board.draw_stock()
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
		var moving: Array = board._peek_source(src)
		if moving.is_empty():
			_selection = {}
			_message("Nothing playable there.")
		else:
			_selection = src
			_message("Selected %s. Click a destination pile." % (moving[0] as CardData).display_name())
	else:
		_selection = {}
	_refresh()

func _on_card_double_clicked(view: CardView) -> void:
	if not run.round_active or not view.has_meta("source"):
		return
	var src: Dictionary = view.get_meta("source")
	var result: Dictionary = board.try_auto_foundation(src)
	if bool(result.get("ok", false)):
		_selection = {}
		_apply_move_scoring(result, src)
		if _score_msg == "":
			_message("Sent %s to its finale pile." % (result["card"] as CardData).display_name())
		else:
			_message(_score_msg)
		_refresh()
		_check_end_conditions()
	else:
		_message("That card cannot take its finale bow yet.")

func _try_move_selection_to(dest: Dictionary) -> bool:
	var src: Dictionary = _selection
	var result: Dictionary = board.try_move(src, dest)
	if not bool(result.get("ok", false)):
		_message("Illegal move.")
		return false
	_selection = {}
	_apply_move_scoring(result, src)
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
		_message("Revealed a hidden card! +%d applause." % fpts)

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
	if board.has_any_legal_move():
		_message("Hint: a legal move exists. Check waste/tableau tops against the finale piles (Ace first) and descending alternating colours.")
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
