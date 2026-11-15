extends Control

## President vs five AIs. Seat 0 is you.

signal trade_confirmed

var run: RunManager
var game: PresidentGame
var _ui_ready: bool = false
var _title: Label
var _hud: Label
var _banner: Label
var _msg: Label
var _ai_row: HBoxContainer
var _trick_label: Label
var _odds: Label
var _trick_cards: Control
var _hand_row: Control
var _btn_row: HFlowContainer
var _action_row: HFlowContainer
var _play_btn: Button
var _pass_btn: Button
var _shop: Shop
var _results: ResultsView
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_body: Label
var _overlay_buttons: HBoxContainer
var _fly_layer: Control
var _felt: TableFelt
var _selected: Array = []
var _card_size: Vector2 = Vector2(58, 82)
var _ai_timer: Timer
var _busy: bool = false
var _ai_plaques: Array = []
var _hand_views: Array = []
var _trick_views: Array = []
var _deal_anim: bool = false
var _trade_waiting: bool = false
var _trade_need: int = 0
var _trade_picks: Array = []
var _trade_panel: PanelContainer
var _trade_prompt: Label
var _trade_confirm: Button

const AI_COLORS: Array = [
	Color(0.55, 0.22, 0.22),
	Color(0.22, 0.45, 0.28),
	Color(0.22, 0.32, 0.55),
	Color(0.50, 0.38, 0.12),
	Color(0.40, 0.22, 0.48),
]

func _ready() -> void:
	run = RunManager.new()
	add_child(run)
	game = PresidentGame.new()
	_build_ui()
	run.changed.connect(_refresh_hud)
	get_tree().root.size_changed.connect(func() -> void: if _ui_ready: _refresh())
	_ui_ready = true
	run.start_new_run()
	_start_round()

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_felt = TableFelt.new()
	_felt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_felt.offset_left = 4
	_felt.offset_top = 66
	_felt.offset_right = -4
	_felt.offset_bottom = -4
	_felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_felt)
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pad)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	pad.add_child(root)
	_title = Label.new()
	_title.text = "PRESIDENT"
	_title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	_title.add_theme_font_size_override("font_size", 22)
	root.add_child(_title)
	_hud = Label.new()
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_theme_font_size_override("font_size", 13)
	root.add_child(_hud)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 16)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	root.add_child(_banner)
	_ai_row = HBoxContainer.new()
	_ai_row.add_theme_constant_override("separation", 4)
	root.add_child(_ai_row)
	for seat in range(1, 6):
		var wrap: PanelContainer = _make_ai_plaque(seat)
		_ai_row.add_child(wrap)
		_ai_plaques.append(wrap)
	_trick_label = Label.new()
	_trick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_trick_label)
	_odds = Label.new()
	_odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_odds.add_theme_font_size_override("font_size", 11)
	_odds.add_theme_color_override("font_color", Color(0.78, 0.82, 0.70))
	root.add_child(_odds)
	_trick_cards = Control.new()
	_trick_cards.custom_minimum_size = Vector2(0, 96)
	_trick_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_trick_cards)
	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_font_size_override("font_size", 13)
	root.add_child(_msg)
	_hand_row = Control.new()
	_hand_row.custom_minimum_size = Vector2(0, 110)
	_hand_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_hand_row)
	_btn_row = HFlowContainer.new()
	_btn_row.add_theme_constant_override("h_separation", 8)
	root.add_child(_btn_row)
	_play_btn = Button.new()
	_play_btn.text = "Play"
	_play_btn.custom_minimum_size = Vector2(90, 44)
	_play_btn.pressed.connect(_on_play)
	_btn_row.add_child(_play_btn)
	_pass_btn = Button.new()
	_pass_btn.text = "Pass"
	_pass_btn.custom_minimum_size = Vector2(90, 44)
	_pass_btn.pressed.connect(_on_pass)
	_btn_row.add_child(_pass_btn)
	var restart: Button = Button.new()
	restart.text = "New Run"
	restart.custom_minimum_size = Vector2(90, 44)
	restart.pressed.connect(func() -> void: run.start_new_run(); _start_round())
	_btn_row.add_child(restart)
	_action_row = HFlowContainer.new()
	_action_row.add_theme_constant_override("h_separation", 6)
	root.add_child(_action_row)
	var shop_holder: CenterContainer = CenterContainer.new()
	shop_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_holder.visible = false
	add_child(shop_holder)
	_shop = Shop.new()
	shop_holder.add_child(_shop)
	_shop.visibility_changed.connect(func() -> void: shop_holder.visible = _shop.visible)
	_shop.bought_upgrade.connect(_on_buy_upgrade)
	_shop.bought_action.connect(_on_buy_action)
	_shop.bought_enhancement.connect(_on_buy_enhancement)
	_shop.reroll_pressed.connect(_on_shop_reroll)
	_shop.closed.connect(_on_shop_closed)
	var resh: CenterContainer = CenterContainer.new()
	resh.set_anchors_preset(Control.PRESET_FULL_RECT)
	resh.visible = false
	add_child(resh)
	_results = ResultsView.new()
	resh.add_child(_results)
	_results.visibility_changed.connect(func() -> void: resh.visible = _results.visible)
	_results.continued.connect(_on_results_continued)
	_results.used_action.connect(_on_results_action)
	_results.rematch.connect(func() -> void: run.start_new_run(); _start_round())
	_trade_panel = PanelContainer.new()
	_trade_panel.visible = false
	_trade_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_trade_panel.offset_top = -150
	_trade_panel.offset_left = 10
	_trade_panel.offset_right = -10
	_trade_panel.offset_bottom = -58
	var tsb: StyleBoxFlat = StyleBoxFlat.new()
	tsb.bg_color = Color(0.08, 0.12, 0.22, 0.96)
	tsb.border_color = Color(0.92, 0.78, 0.35)
	tsb.set_border_width_all(2)
	tsb.set_corner_radius_all(8)
	_trade_panel.add_theme_stylebox_override("panel", tsb)
	add_child(_trade_panel)
	var tm: MarginContainer = MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 12)
	tm.add_theme_constant_override("margin_right", 12)
	tm.add_theme_constant_override("margin_top", 8)
	tm.add_theme_constant_override("margin_bottom", 8)
	_trade_panel.add_child(tm)
	var tv: VBoxContainer = VBoxContainer.new()
	tm.add_child(tv)
	_trade_prompt = Label.new()
	_trade_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_prompt.add_theme_font_size_override("font_size", 14)
	tv.add_child(_trade_prompt)
	_trade_confirm = Button.new()
	_trade_confirm.text = "Confirm tribute"
	_trade_confirm.custom_minimum_size = Vector2(0, 48)
	_trade_confirm.pressed.connect(func() -> void: trade_confirmed.emit())
	tv.add_child(_trade_confirm)
	var ovh: CenterContainer = CenterContainer.new()
	ovh.set_anchors_preset(Control.PRESET_FULL_RECT)
	ovh.visible = false
	add_child(ovh)
	_overlay = PanelContainer.new()
	_overlay.visible = false
	ovh.add_child(_overlay)
	_overlay.visibility_changed.connect(func() -> void: ovh.visible = _overlay.visible)
	var om: MarginContainer = MarginContainer.new()
	om.add_theme_constant_override("margin_left", 20)
	om.add_theme_constant_override("margin_right", 20)
	om.add_theme_constant_override("margin_top", 16)
	om.add_theme_constant_override("margin_bottom", 16)
	_overlay.add_child(om)
	var ov: VBoxContainer = VBoxContainer.new()
	om.add_child(ov)
	_overlay_title = Label.new()
	_overlay_title.add_theme_font_size_override("font_size", 26)
	ov.add_child(_overlay_title)
	_overlay_body = Label.new()
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov.add_child(_overlay_body)
	_overlay_buttons = HBoxContainer.new()
	ov.add_child(_overlay_buttons)
	_fly_layer = Control.new()
	_fly_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fly_layer)
	_ai_timer = Timer.new()
	_ai_timer.one_shot = true
	_ai_timer.wait_time = 0.45
	_ai_timer.timeout.connect(_ai_act)
	add_child(_ai_timer)

func _make_ai_plaque(seat: int) -> PanelContainer:
	var wrap: PanelContainer = PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.set_meta("seat", seat)
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.10, 0.16, 0.88)
	psb.set_corner_radius_all(10)
	psb.set_border_width_all(2)
	psb.border_color = Color(0.85, 0.70, 0.28, 0.35)
	wrap.add_theme_stylebox_override("panel", psb)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 2)
	wrap.add_child(box)
	var fan: Control = Control.new()
	fan.name = "Fan"
	fan.custom_minimum_size = Vector2(0, 38)
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fan)
	var bust: SeatBust = SeatBust.new()
	bust.name = "Bust"
	bust.custom_minimum_size = Vector2(0, 28)
	bust.bust_color = AI_COLORS[seat - 1]
	box.add_child(bust)
	var nm: Label = Label.new()
	nm.name = "Name"
	nm.text = str(RunManager.NAMES[seat]).replace("The ", "")
	nm.add_theme_font_size_override("font_size", 10)
	nm.clip_text = true
	box.add_child(nm)
	var badge: Label = Label.new()
	badge.name = "Badge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", Color(1.0, 0.90, 0.40))
	box.add_child(badge)
	var hp: Label = Label.new()
	hp.name = "Hp"
	hp.add_theme_font_size_override("font_size", 10)
	box.add_child(hp)
	var last: Label = Label.new()
	last.name = "Last"
	last.add_theme_font_size_override("font_size", 10)
	last.clip_text = true
	box.add_child(last)
	var peek: Label = Label.new()
	peek.name = "Peek"
	peek.add_theme_font_size_override("font_size", 9)
	peek.clip_text = true
	peek.visible = false
	box.add_child(peek)
	var whip: Button = Button.new()
	whip.name = "Whip"
	whip.text = "?"
	whip.custom_minimum_size = Vector2(28, 28)
	whip.visible = false
	var cap: int = seat
	whip.pressed.connect(func() -> void: _whip(cap))
	box.add_child(whip)
	return wrap

func _start_round() -> void:
	_overlay.visible = false
	_shop.visible = false
	_results.visible = false
	_trade_panel.visible = false
	_selected.clear()
	_busy = false
	if run.run_over:
		_show_run_over()
		return
	var live: Array = run.living_seats()
	if live.size() < 2:
		_show_run_over()
		return
	run.apply_populist()
	game.setup(live, run.rng, 0, 0, 0, run.lead_seat())
	var deal_logs: Array = run.apply_deal_effects(game)
	if game.current_player == 0:
		_message("Round %d. Stake %d. You lead — yellow cards can be played." % [run.round_n, run.stake()])
	else:
		_message("Round %d. %s leads." % [run.round_n, RunManager.NAMES[game.current_player]])
	if not deal_logs.is_empty():
		for line in deal_logs:
			run.log_event(str(line))
	_deal_anim = true
	await get_tree().process_frame
	await get_tree().process_frame
	_refresh()
	_deal_pop()
	await get_tree().create_timer(0.34).timeout
	_deal_anim = false
	await _resolve_tributes()
	_continue_turns()

func _deal_pop() -> void:
	for cv in _hand_views:
		var c: Control = cv
		var dest: Vector2 = c.position
		c.position = dest + Vector2(0, 56)
		c.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(c, "position", dest, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "modulate:a", 1.0, 0.22)
	for wrap in _ai_plaques:
		var fan: Control = (wrap as Node).get_node("Box/Fan")
		fan.modulate.a = 0.0
		var tw2: Tween = create_tween()
		tw2.tween_property(fan, "modulate:a", 1.0, 0.28)

func _continue_turns() -> void:
	if game.round_over:
		_end_round()
		return
	if game.must_pass_seat == game.current_player:
		if game.lead:
			game.must_pass_seat = -1
		else:
			var who: int = game.current_player
			game.pass_turn(who)
			_pop_pass(who)
			_message("%s is filibustered and passes." % RunManager.NAMES[who])
			_refresh()
			_continue_turns()
			return
	_update_banner()
	_pulse_turn(game.current_player)
	if game.current_player == 0:
		_busy = false
		_refresh()
		if game.lead:
			_message("Your lead. Yellow cards are playable — tap one, then Play (or double-tap).")
		else:
			_message("Your turn. Yellow cards beat %d× %s. Double-tap to play, or Pass." % [game.trick_count, RankSystem.short_label(game.trick_rank)])
		return
	_busy = true
	_refresh()
	_ai_timer.start()

func _pulse_turn(seat: int) -> void:
	var twb: Tween = create_tween()
	_banner.modulate = Color(1.4, 1.3, 0.7)
	twb.tween_property(_banner, "modulate", Color.WHITE, 0.35)
	if seat <= 0 or seat > _ai_plaques.size():
		return
	var wrap: Control = _ai_plaques[seat - 1]
	wrap.pivot_offset = wrap.size * 0.5
	wrap.scale = Vector2(1.06, 1.06)
	var tw: Tween = create_tween()
	tw.tween_property(wrap, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_banner() -> void:
	if game.round_over:
		_banner.text = "Round over"
		return
	if game.current_player == 0:
		_banner.text = "YOUR TURN"
		_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	else:
		_banner.text = "%s is playing…" % RunManager.NAMES[game.current_player]
		_banner.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))

func _ai_act() -> void:
	if game.round_over or game.current_player == 0:
		_continue_turns()
		return
	var seat: int = game.current_player
	var persona: int = (seat % 3)
	var act_id: String = PresidentAI.choose_turn_action(game, run, seat)
	if act_id != "":
		_fire_turn_action(seat, act_id)
		_refresh()
		await get_tree().create_timer(0.22).timeout
	var choice: Dictionary = PresidentAI.choose(game, seat, persona)
	if bool(choice.get("pass", false)):
		game.pass_turn(seat)
		_pop_pass(seat)
		_message("%s passes." % RunManager.NAMES[seat])
		_refresh()
		_continue_turns()
		return
	var combo: Dictionary = choice["combo"]
	var origins: Array = _seat_origins(seat, int(combo.get("count", 1)))
	var r: Dictionary = game.play(seat, combo)
	if not bool(r.get("ok", false)):
		game.pass_turn(seat)
		_pop_pass(seat)
		_message("%s passes." % RunManager.NAMES[seat])
		_refresh()
		_continue_turns()
		return
	_award_rank_gold(seat, int(combo.get("rank", 0)))
	_message("%s plays %s." % [RunManager.NAMES[seat], str(r.get("label", ""))])
	await _fly_from(origins, combo)
	_refresh()
	_continue_turns()

func _on_play() -> void:
	if _busy or game.current_player != 0 or game.round_over:
		return
	if _selected.is_empty():
		_message("Tap a yellow card first.")
		return
	var rank: int = (_selected[0] as CardData).rank
	var combo: Dictionary = {"rank": rank, "count": _selected.size()}
	if not game.is_legal_combo(combo, 0):
		_message("Need %d of that rank to follow." % game.trick_count if not game.lead else "Illegal combo.")
		return
	var origins: Array = _selected_origins()
	var r: Dictionary = game.play(0, combo)
	if not bool(r.get("ok", false)):
		_message("Illegal play (%s)." % str(r.get("reason", "")))
		return
	_selected.clear()
	_award_rank_gold(0, rank)
	_message("You play %s." % str(r.get("label", "")))
	_busy = true
	await _fly_from(origins, combo)
	_refresh()
	_continue_turns()

func _on_pass() -> void:
	if _busy or game.current_player != 0 or game.round_over:
		return
	if game.lead:
		_message("You have the lead — play a yellow card.")
		return
	game.pass_turn(0)
	_selected.clear()
	_pop_pass(0)
	_message("You pass.")
	_refresh()
	_continue_turns()

func _on_card_press(view: CardView, _pos: Vector2) -> void:
	if view.card == null:
		return
	if _trade_waiting:
		_toggle_trade_pick(view.card)
		return
	if _busy or game.current_player != 0:
		return
	_select_from_card(view.card, false)

func _on_card_double(view: CardView) -> void:
	if _busy or game.current_player != 0 or view.card == null:
		return
	if not game.rank_is_legal(0, view.card.rank):
		_select_from_card(view.card, true)
		return
	_select_from_card(view.card, true)
	if not _selected.is_empty():
		_on_play()

func _select_from_card(card: CardData, for_play: bool) -> void:
	var rank: int = card.rank
	if not game.rank_is_legal(0, rank):
		_message("That rank cannot follow %d× %s." % [game.trick_count, RankSystem.short_label(game.trick_rank)])
		return
	var of_rank: Array = []
	for c in game.hand_of(0):
		if (c as CardData).rank == rank:
			of_rank.append(c)
	if game.lead:
		if for_play:
			_selected = [card]
		elif _selected.is_empty() or (_selected[0] as CardData).rank != rank:
			_selected = [card]
		elif _selected.has(card):
			_selected.erase(card)
		else:
			_selected.append(card)
	else:
		var need: int = game.auto_select_count()
		_selected.clear()
		if of_rank.has(card):
			_selected.append(card)
		for c2 in of_rank:
			if _selected.size() >= need:
				break
			if not _selected.has(c2):
				_selected.append(c2)
	_sync_hand()
	_set_buttons()

func _selected_origins() -> Array:
	var out: Array = []
	for cv in _hand_views:
		if cv is CardView and (cv as CardView).selected:
			out.append((cv as CardView).global_position)
	return out

func _seat_origins(seat: int, count: int) -> Array:
	var out: Array = []
	if seat <= 0 or seat - 1 >= _ai_plaques.size():
		return out
	var plaque: Control = _ai_plaques[seat - 1]
	var gp: Vector2 = plaque.global_position + Vector2(plaque.size.x * 0.22, 14)
	for i in range(count):
		out.append(gp + Vector2(float(i) * 8.0, 0))
	return out

func _trick_dest() -> Vector2:
	return _trick_cards.global_position + Vector2(maxf(20.0, _trick_cards.size.x * 0.5 - 20.0), 10.0)

func _fly_from(origins: Array, combo: Dictionary) -> void:
	if origins.is_empty():
		await get_tree().create_timer(0.12).timeout
		return
	var dest: Vector2 = _trick_dest()
	var rank: int = int(combo.get("rank", 1))
	for i in range(origins.size()):
		var ghost: CardView = CardView.new(CardData.new(rank, i % 4, true), _card_size)
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fly_layer.add_child(ghost)
		ghost.global_position = origins[i]
		var tw: Tween = create_tween()
		tw.tween_property(ghost, "global_position", dest + Vector2(float(i) * 8.0, float(i) * 7.0), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ghost, "rotation", 0.08 * float(i - 1), 0.26)
	await get_tree().create_timer(0.30).timeout
	for child in _fly_layer.get_children():
		if child is CardView:
			_fly_layer.remove_child(child)
			child.queue_free()

func _pop_pass(seat: int) -> void:
	var chip: Label = Label.new()
	chip.text = "PASS"
	chip.add_theme_font_size_override("font_size", 18)
	chip.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
	_fly_layer.add_child(chip)
	var pos: Vector2
	if seat == 0:
		pos = _hand_row.global_position + Vector2(_hand_row.size.x * 0.4, 20)
	elif seat - 1 < _ai_plaques.size():
		var p: Control = _ai_plaques[seat - 1]
		pos = p.global_position + Vector2(8, 24)
	else:
		pos = Vector2(size.x * 0.4, 120)
	chip.global_position = pos
	chip.scale = Vector2(0.4, 0.4)
	var tw: Tween = create_tween()
	tw.tween_property(chip, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_property(chip, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		if is_instance_valid(chip):
			chip.queue_free()
	)

func _award_rank_gold(seat: int, rank: int) -> void:
	var n: int = run.rank_gold_on_play(seat, rank)
	if n <= 0:
		return
	run.add_gold(seat, n)
	var who: String = "You" if seat == 0 else RunManager.NAMES[seat]
	run.log_event("%s earns $%d on %s." % [who, n, RankSystem.short_label(rank)])

func _fire_turn_action(seat: int, id: String) -> bool:
	if not run.spend_action_for(seat, id):
		return false
	var fx: Dictionary = ActionFx.apply_turn(game, run, seat, id)
	if bool(fx.get("refund", false)):
		run.restore_action_for(seat, id)
	var msg: String = str(fx.get("message", ""))
	if msg != "":
		_message(msg)
		run.log_event(msg)
	return bool(fx.get("ok", false))

func _use_action(id: String) -> void:
	var info: Dictionary = ActionDB.get_by_id(id)
	var when: String = str(info.get("when", "turn"))
	if when == "results" or id == "just_say_no":
		_message("%s is for the results desk, after the round." % str(info.get("name", id)))
		return
	if _busy or game.current_player != 0 or game.round_over:
		_message("Actions are for your turn.")
		return
	_fire_turn_action(0, id)
	_refresh()

func _end_round() -> void:
	_busy = true
	run.apply_payouts(game.finished)
	run.ai_results_actions()
	run.ai_shop_all()
	_float_payouts()
	_show_results()

func _float_payouts() -> void:
	for p in run.last_payout:
		var d: Dictionary = p
		var seat: int = int(d["seat"])
		var chip: Label = Label.new()
		var hp_d: int = int(d["hp_delta"])
		chip.text = ("%+d HP" % hp_d) + ("  +$%d" % int(d["gold"]) if int(d["gold"]) > 0 else "")
		chip.add_theme_font_size_override("font_size", 14)
		chip.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if hp_d >= 0 else Color(1.0, 0.4, 0.35))
		_fly_layer.add_child(chip)
		var pos: Vector2 = _hand_row.global_position + Vector2(40, 0)
		if seat > 0 and seat - 1 < _ai_plaques.size():
			pos = (_ai_plaques[seat - 1] as Control).global_position
		chip.global_position = pos
		var tw: Tween = create_tween()
		tw.tween_property(chip, "global_position", pos + Vector2(0, -28), 0.8)
		tw.parallel().tween_property(chip, "modulate:a", 0.0, 0.8)
		tw.tween_callback(func() -> void:
			if is_instance_valid(chip):
				chip.queue_free()
		)

func _on_buy_upgrade(item: Dictionary) -> void:
	if run.buy_upgrade(str(item["id"]), int(item["price"])):
		run.take_shop_offer(str(item["id"]))
		_message("Bought %s." % str(item["name"]))
		_reopen_shop()
	else:
		_message("Not enough gold.")

func _on_buy_action(item: Dictionary) -> void:
	if run.buy_action(str(item["id"]), int(item["price"])):
		run.take_shop_offer(str(item["id"]))
		_message("Pocketed %s." % str(item["name"]))
		_reopen_shop()
	else:
		_message("Not enough gold.")

func _on_buy_enhancement(item: Dictionary) -> void:
	if run.buy_enhancement(str(item["id"]), int(item["price"])):
		run.take_shop_offer(str(item["id"]))
		_message("Stamped %s." % str(item["name"]))
		_reopen_shop()
	else:
		_message("Not enough gold.")

func _priced_offers(raw: Array) -> Array:
	var out: Array = []
	for it in raw:
		out.append(run.priced_copy(it))
	return out

func _open_shop() -> void:
	run.begin_shop_visit()
	_reopen_shop()

func _reopen_shop() -> void:
	_shop.present(run.gold, _priced_offers(run.shop_offers), run.owned_counts(), run.reroll_cost(), "Gold $%d  ·  HP %d/%d  ·  %d offers" % [run.gold, int(run.hp[0]), run.max_hp, run.shop_offers.size()])

func _on_shop_reroll() -> void:
	var cost: int = run.reroll_cost()
	if run.reroll_shop():
		_message("Rerolled the desk for $%d." % cost)
		_reopen_shop()
	else:
		_message("Need $%d to reroll." % cost)

func _on_shop_closed() -> void:
	run.next_round()
	_start_round()

func _results_rows() -> Array:
	return run.last_payout.duplicate()

func _tribute_preview() -> String:
	var lines: PackedStringArray = RoleTrade.preview_lines(run.living_finish(), RunManager.NAMES)
	return "Next tribute:\n" + "\n".join(lines)

func _show_results() -> void:
	var title: String = "Round %d  ·  stake %d" % [run.round_n, run.stake()]
	var log_text: String = "\n".join(run.trade_log) if not run.trade_log.is_empty() else ""
	_results.present_round(title, _results_rows(), _tribute_preview(), log_text, run.result_action_ids())

func _on_results_continued() -> void:
	if run.run_over:
		_show_run_over()
		return
	_open_shop()

func _on_results_action(id: String) -> void:
	if not run.has_action(id):
		return
	if not run.spend_action(id):
		return
	var line: String = run.apply_results_action(0, id)
	if line != "":
		run.log_event(line)
	_show_results()

func _adjust_pair(pair: Dictionary) -> void:
	var g: int = int(pair["giver"])
	var r: int = int(pair["receiver"])
	var n: int = int(pair["count"])
	if run.has_upgrade_of(r, "oval"):
		n += run.count_upgrade_of(r, "oval")
	var union_n: int = run.count_enhancement_of(g, "union") + run.count_enhancement_of(r, "union")
	if union_n > 0:
		n = maxi(1, n - union_n)
	pair["count"] = n
	var ret_n: int = n
	if run.has_enhancement_of(r, "wax"):
		ret_n = maxi(1, ret_n - run.count_enhancement_of(r, "wax"))
	pair["return_count"] = ret_n

func _resolve_tributes() -> void:
	if run.round_n <= 1:
		return
	if run.skip_tributes:
		_message("Recess — tributes skipped.")
		run.reset_tribute_flags()
		return
	var pairs: Array = RoleTrade.pairs_for(run.living_finish())
	if pairs.is_empty():
		run.reset_tribute_flags()
		return
	_busy = true
	for pair0 in pairs:
		var pair: Dictionary = pair0
		_adjust_pair(pair)
		await _run_one_tribute(pair)
	run.reset_tribute_flags()
	_busy = false
	_refresh()

func _run_one_tribute(pair: Dictionary) -> void:
	var giver: int = int(pair["giver"])
	var receiver: int = int(pair["receiver"])
	var n: int = int(pair["count"])
	if run.cancelled_tribute_seats.has(giver):
		var msg: String = "%s refuses the tribute (Just Say No / Pardon)." % RunManager.NAMES[giver]
		_message(msg)
		run.trade_log.append(msg)
		return
	if not game.hands.has(giver) or not game.hands.has(receiver):
		return
	var taken: Array = RoleTrade.take_highest(game.hand_of(giver), n)
	RoleTrade.move_cards(game.hands, giver, receiver, taken)
	var up: String = "%s (%s) tributes %s → %s" % [
		RunManager.NAMES[giver], pair["giver_role"], RoleTrade.labels_of(taken), RunManager.NAMES[receiver]]
	_message(up)
	run.trade_log.append(up)
	_refresh()
	await get_tree().create_timer(0.35).timeout
	var ret_n: int = int(pair.get("return_count", n))
	var picks: Array = []
	if receiver == 0:
		picks = await _await_player_picks(ret_n, "Give %d card(s) back to %s (%s)" % [ret_n, RunManager.NAMES[giver], pair["giver_role"]])
	else:
		picks = RoleTrade.ai_return_picks(game.hand_of(receiver), ret_n)
	RoleTrade.move_cards(game.hands, receiver, giver, picks)
	var down: String = "%s returns %s → %s" % [RunManager.NAMES[receiver], RoleTrade.labels_of(picks), RunManager.NAMES[giver]]
	_message(down)
	run.trade_log.append(down)
	_refresh()
	await get_tree().create_timer(0.25).timeout

func _await_player_picks(count: int, prompt: String) -> Array:
	_trade_need = mini(count, game.hand_of(0).size())
	_trade_picks.clear()
	_trade_waiting = true
	_trade_prompt.text = prompt
	_trade_confirm.disabled = true
	_trade_panel.visible = true
	_busy = true
	_refresh()
	await trade_confirmed
	var out: Array = _trade_picks.duplicate()
	_trade_waiting = false
	_trade_panel.visible = false
	_trade_picks.clear()
	return out

func _toggle_trade_pick(card: CardData) -> void:
	if _trade_picks.has(card):
		_trade_picks.erase(card)
	elif _trade_picks.size() < _trade_need:
		_trade_picks.append(card)
	_trade_confirm.disabled = _trade_picks.size() != _trade_need
	_trade_confirm.text = "Confirm  %d/%d" % [_trade_picks.size(), _trade_need]
	_sync_hand()

func _show_run_over() -> void:
	var title: String = "THE OVAL IS YOURS" if run.run_won else "REMOVED FROM OFFICE"
	var body: String = "You lasted %d round(s). Gold in pocket: %d.\n%s" % [
		run.round_n, run.gold, "Last seat standing." if run.run_won else "HP hit zero. The cabinet outlasted you."]
	_results.present_game_over(title, _results_rows(), body)

func _show_overlay(title_text: String, body: String, actions: Array) -> void:
	_overlay_title.text = title_text
	_overlay_body.text = body
	_overlay_body.custom_minimum_size = Vector2(minf(420.0, maxf(240.0, size.x - 48.0)), 0)
	for child in _overlay_buttons.get_children():
		_overlay_buttons.remove_child(child)
		child.queue_free()
	for a in actions:
		var b: Button = Button.new()
		b.text = str(a)
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(func() -> void:
			_overlay.visible = false
			run.start_new_run()
			_start_round()
		)
		_overlay_buttons.add_child(b)
	_overlay.visible = true

func _message(t: String) -> void:
	_msg.text = t

func _refresh_hud() -> void:
	if _hud == null:
		return
	var role: String = RoleTrade.role_of(run.living_finish(), 0)
	var role_bit: String = "  %s" % role if not run.living_finish().is_empty() else ""
	var bind: String = run.rank_mod_short(0)
	_hud.text = "Round %d  Stake %d  HP %d/%d  Gold %d  Living %d%s%s" % [
		run.round_n, run.stake(), int(run.hp[0]), run.max_hp, run.gold, run.living_seats().size(), role_bit, bind]

func _set_buttons() -> void:
	var yours: bool = game.current_player == 0 and not game.round_over and not _busy and not _trade_waiting
	_play_btn.disabled = not yours
	_pass_btn.disabled = not yours or game.lead

func _refresh() -> void:
	_refresh_hud()
	_update_banner()
	var vw: float = size.x if size.x > 10.0 else 390.0
	var nhand: int = maxi(1, game.hand_of(0).size())
	var w: float = clampf(floorf((vw - 20.0) / float(mini(nhand, 10))), 36.0, 70.0)
	_card_size = Vector2(w, w * 1.4)
	_sync_ais()
	_sync_trick()
	_sync_odds()
	_sync_hand()
	_rebuild_actions()
	_set_buttons()

func _sync_ais() -> void:
	var mini: Vector2 = Vector2(maxf(22.0, _card_size.x * 0.38), maxf(30.0, _card_size.y * 0.38))
	for i in range(_ai_plaques.size()):
		var seat: int = i + 1
		var wrap: PanelContainer = _ai_plaques[i]
		var box: Node = wrap.get_node("Box")
		var fan: Control = box.get_node("Fan")
		var bust: SeatBust = box.get_node("Bust")
		var badge: Label = box.get_node("Badge")
		var hp: Label = box.get_node("Hp")
		var last: Label = box.get_node("Last")
		var peek: Label = box.get_node("Peek")
		var whip: Button = box.get_node("Whip")
		var psb: StyleBoxFlat = StyleBoxFlat.new()
		psb.bg_color = Color(0.06, 0.10, 0.16, 0.88)
		psb.set_corner_radius_all(10)
		psb.set_border_width_all(3 if game.current_player == seat else 2)
		if game.current_player == seat:
			psb.border_color = Color(1.0, 0.85, 0.25)
			psb.bg_color = Color(0.16, 0.16, 0.08, 0.92)
		else:
			psb.border_color = Color(0.85, 0.70, 0.28, 0.35)
		wrap.add_theme_stylebox_override("panel", psb)
		bust.bust_color = AI_COLORS[seat - 1] if run.is_alive(seat) else Color(0.22, 0.22, 0.24)
		bust.queue_redraw()
		var nshow: int = 0
		if run.is_alive(seat):
			nshow = mini(game.hand_of(seat).size(), 8)
		while fan.get_child_count() > nshow:
			var extra: Node = fan.get_child(fan.get_child_count() - 1)
			fan.remove_child(extra)
			extra.queue_free()
		while fan.get_child_count() < nshow:
			var back: CardView = CardView.new(CardData.new(2, 0, false), mini)
			back.face_forced_down = true
			back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fan.add_child(back)
		for fi in range(fan.get_child_count()):
			var cv: CardView = fan.get_child(fi)
			cv.set_display_size(mini)
			cv.position = Vector2(4.0 + float(fi) * 7.0, 4)
		fan.custom_minimum_size = Vector2(0, mini.y + 8)
		if run.is_alive(seat):
			badge.text = str(game.hand_of(seat).size())
			badge.add_theme_font_size_override("font_size", 22)
			hp.text = "HP %d  $%d" % [int(run.hp[seat]), run.gold_of(seat)]
		else:
			badge.text = "OUT"
			badge.add_theme_font_size_override("font_size", 12)
			hp.text = ""
		var role: String = RoleTrade.short_role(RoleTrade.role_of(run.living_finish(), seat))
		last.text = "%s  %s%s" % [role, str(game.last_play_label.get(seat, "—")), run.rank_mod_short(seat)]
		if game.peek_seat == seat:
			var bits: Array[String] = []
			for c2 in game.hand_of(seat):
				bits.append((c2 as CardData).label())
			peek.text = " ".join(bits)
			peek.visible = true
		else:
			peek.visible = false
		whip.visible = run.has_upgrade("whip") and run.is_alive(seat) and (not run.whip_used or run.has_upgrade("majority"))

func _sync_odds() -> void:
	if _odds == null:
		return
	_odds.text = OddsHelper.hud_text(game, run, 0)

func _whip(seat: int) -> void:
	if run.whip_used and not run.has_upgrade("majority"):
		return
	if not run.has_upgrade("majority"):
		run.whip_used = true
	var legal: Array = game.legal_combos(seat)
	_message("Whip Count: %s %s follow." % [RunManager.NAMES[seat], "CAN" if not legal.is_empty() else "cannot"])
	_refresh()

func _sync_trick() -> void:
	if game.lead or game.trick_count <= 0:
		_trick_label.text = "Lead anything (yellow cards)."
		while _trick_views.size() > 0:
			var extra: Node = _trick_views.pop_back()
			_trick_cards.remove_child(extra)
			extra.queue_free()
		return
	_trick_label.text = "Follow %d× %s  —  or Pass" % [game.trick_count, RankSystem.short_label(game.trick_rank)]
	while _trick_views.size() > game.trick_count:
		var drop: Node = _trick_views.pop_back()
		_trick_cards.remove_child(drop)
		drop.queue_free()
	while _trick_views.size() < game.trick_count:
		var cv: CardView = CardView.new(CardData.new(game.trick_rank, _trick_views.size() % 4, true), _card_size)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_trick_cards.add_child(cv)
		_trick_views.append(cv)
	var row_w: float = _trick_cards.size.x
	if row_w < 20.0:
		row_w = maxf(80.0, size.x - 20.0)
	var start: float = maxf(8.0, row_w * 0.5 - _card_size.x * 0.5)
	for i in range(_trick_views.size()):
		var v: CardView = _trick_views[i]
		v.set_card(CardData.new(game.trick_rank, i % 4, true))
		v.set_display_size(_card_size)
		v.position = Vector2(start + float(i) * 10.0, 6.0 + float(i) * 5.0)
		v.rotation = 0.05 * float(i - 1)

func _sync_hand() -> void:
	var hand: Array = game.hand_of(0)
	var n: int = hand.size()
	while _hand_views.size() > n:
		var extra: CardView = _hand_views.pop_back()
		_hand_row.remove_child(extra)
		extra.queue_free()
	while _hand_views.size() < n:
		var cv: CardView = CardView.new(null, _card_size)
		cv.press_started.connect(_on_card_press)
		cv.double_pressed.connect(_on_card_double)
		_hand_row.add_child(cv)
		_hand_views.append(cv)
	var gap: float = 4.0
	var total: float = float(n) * _card_size.x + float(maxi(0, n - 1)) * gap
	var row_w: float = _hand_row.size.x
	if row_w < 20.0:
		row_w = maxf(0.0, size.x - 20.0)
	var start: float = maxf(0.0, (row_w - total) * 0.5)
	var yours: bool = game.current_player == 0 and not _busy and not game.round_over
	var picking: bool = _trade_waiting
	for i in range(n):
		var card: CardData = hand[i]
		var cv2: CardView = _hand_views[i]
		if cv2.card != card:
			cv2.set_card(card)
		cv2.set_display_size(_card_size)
		cv2.selected = _trade_picks.has(card) if picking else _selected.has(card)
		var legal: bool = yours and game.rank_is_legal(0, card.rank)
		cv2.highlighted = picking or (legal and not cv2.selected)
		cv2.dimmed = yours and not legal and not picking
		var dest: Vector2 = Vector2(start + float(i) * (_card_size.x + gap), -16.0 if cv2.selected else (-5.0 if cv2.highlighted else 0.0))
		if not _deal_anim:
			cv2.position = dest
		else:
			# Keep the incoming tween; only store the target via a meta so deal_pop can use current.
			if cv2.modulate.a >= 0.99:
				cv2.position = dest
		cv2.queue_redraw()
	_hand_row.custom_minimum_size = Vector2(0, _card_size.y + 16)

func _rebuild_actions() -> void:
	for c in _action_row.get_children():
		_action_row.remove_child(c)
		c.queue_free()
	if run.actions.is_empty():
		return
	for id in run.actions:
		var info: Dictionary = ActionDB.get_by_id(str(id))
		var b: Button = Button.new()
		var when: String = str(info.get("when", "turn"))
		b.text = str(info.get("name", id)) + (" · desk" if when != "turn" else "")
		b.custom_minimum_size = Vector2(0, 40)
		var cap: String = str(id)
		b.pressed.connect(func() -> void: _use_action(cap))
		_action_row.add_child(b)

class TableFelt extends Control:
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var rx: float = size.x * 0.48
		var ry: float = size.y * 0.46
		draw_colored_polygon(_ellipse(c, rx, ry, 56), Color(0.72, 0.56, 0.18))
		draw_colored_polygon(_ellipse(c, rx - 7.0, ry - 7.0, 56), Color(0.10, 0.22, 0.38))
		draw_colored_polygon(_ellipse(c, rx - 14.0, ry - 14.0, 56), Color(0.07, 0.16, 0.30))
		var inner: PackedVector2Array = _ellipse(c, rx - 22.0, ry - 20.0, 56)
		draw_colored_polygon(inner, Color(0.08, 0.20, 0.16, 0.55))

	func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(n):
			var a: float = TAU * float(i) / float(n)
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return pts

class SeatBust extends Control:
	var bust_color: Color = Color.WHITE

	func _draw() -> void:
		var cx: float = size.x * 0.5
		var head_r: float = minf(size.x, size.y) * 0.28
		var head: Vector2 = Vector2(cx, size.y * 0.32)
		draw_circle(head, head_r, bust_color)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - head_r * 1.6, size.y),
			Vector2(cx + head_r * 1.6, size.y),
			Vector2(cx + head_r * 0.9, size.y * 0.52),
			Vector2(cx - head_r * 0.9, size.y * 0.52),
		]), bust_color)
		draw_circle(head + Vector2(0, -head_r * 0.15), head_r * 0.35, bust_color.lightened(0.15))
