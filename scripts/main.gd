extends Control

## President vs five AIs. Seat 0 is you.

var run: RunManager
var game: PresidentGame
var _ui_ready: bool = false
var _title: Label
var _hud: Label
var _msg: Label
var _ai_row: HBoxContainer
var _trick_label: Label
var _trick_cards: HBoxContainer
var _hand_row: Control
var _btn_row: HFlowContainer
var _action_row: HFlowContainer
var _play_btn: Button
var _pass_btn: Button
var _shop: Shop
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_body: Label
var _overlay_buttons: HBoxContainer
var _selected: Array = [] # CardData
var _card_size: Vector2 = Vector2(58, 82)
var _ai_timer: Timer
var _busy: bool = false
var _shop_upgrades: Array = []
var _shop_actions: Array = []

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
	bg.color = Color(0.07, 0.12, 0.22)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
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
	_ai_row = HBoxContainer.new()
	_ai_row.add_theme_constant_override("separation", 6)
	root.add_child(_ai_row)
	_trick_label = Label.new()
	_trick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_trick_label)
	_trick_cards = HBoxContainer.new()
	_trick_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_trick_cards)
	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_font_size_override("font_size", 13)
	root.add_child(_msg)
	_hand_row = Control.new()
	_hand_row.custom_minimum_size = Vector2(0, 110)
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
	_shop.closed.connect(_on_shop_closed)
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
	_ai_timer = Timer.new()
	_ai_timer.one_shot = true
	_ai_timer.wait_time = 0.55
	_ai_timer.timeout.connect(_ai_act)
	add_child(_ai_timer)

func _start_round() -> void:
	_overlay.visible = false
	_shop.visible = false
	_selected.clear()
	_busy = false
	if run.run_over:
		_show_run_over()
		return
	var live: Array = run.living_seats()
	if live.size() < 2:
		_show_run_over()
		return
	game.setup(live, run.rng, run.packed_level(), run.favorite_rank, run.extra_cards())
	_message("Round %d. Stake %d. %s leads." % [run.round_n, run.stake(), RunManager.NAMES[game.current_player]])
	_refresh()
	_continue_turns()

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
			_message("%s is filibustered and passes." % RunManager.NAMES[who])
			_refresh()
			_continue_turns()
			return
	if game.current_player == 0:
		_busy = false
		_refresh()
		_message("Your turn. Tap equal ranks, then Play — or Pass.")
		return
	_busy = true
	_refresh()
	_ai_timer.start()

func _ai_act() -> void:
	if game.round_over or game.current_player == 0:
		_continue_turns()
		return
	var seat: int = game.current_player
	var persona: int = (seat % 3)
	var choice: Dictionary = PresidentAI.choose(game, seat, persona)
	if bool(choice.get("pass", false)):
		game.pass_turn(seat)
		_message("%s passes." % RunManager.NAMES[seat])
	else:
		var r: Dictionary = game.play(seat, choice["combo"])
		if bool(r.get("ok", false)):
			_message("%s plays %s." % [RunManager.NAMES[seat], str(r.get("label", ""))])
		else:
			game.pass_turn(seat)
			_message("%s passes." % RunManager.NAMES[seat])
	_refresh()
	_continue_turns()

func _on_play() -> void:
	if _busy or game.current_player != 0 or game.round_over:
		return
	if _selected.is_empty():
		_message("Select cards of one rank first.")
		return
	var rank: int = (_selected[0] as CardData).rank
	var combo: Dictionary = {"rank": rank, "count": _selected.size()}
	var r: Dictionary = game.play(0, combo)
	if not bool(r.get("ok", false)):
		_message("Illegal play (%s)." % str(r.get("reason", "")))
		return
	_selected.clear()
	_message("You play %s." % str(r.get("label", "")))
	_refresh()
	_continue_turns()

func _on_pass() -> void:
	if _busy or game.current_player != 0 or game.round_over:
		return
	if game.lead:
		_message("You have the lead — play something.")
		return
	game.pass_turn(0)
	_selected.clear()
	_message("You pass.")
	_refresh()
	_continue_turns()

func _on_card_press(view: CardView, _pos: Vector2) -> void:
	if _busy or game.current_player != 0 or view.card == null:
		return
	var card: CardData = view.card
	if _selected.has(card):
		_selected.erase(card)
	else:
		if not _selected.is_empty() and (_selected[0] as CardData).rank != card.rank:
			_selected.clear()
		_selected.append(card)
	_refresh()

func _use_action(id: String) -> void:
	if _busy or game.current_player != 0 or game.round_over:
		_message("Actions are for your turn.")
		return
	if not run.spend_action(id):
		return
	match id:
		"veto":
			game.skip_seat = _next_opponent()
			_message("Veto — %s will be skipped." % RunManager.NAMES[game.skip_seat])
		"filibuster":
			game.must_pass_seat = _next_opponent()
			_message("Filibuster — %s must pass." % RunManager.NAMES[game.must_pass_seat])
		"exec":
			game.exec_order = true
			_message("Executive Order — any rank of the required count.")
		"leak":
			game.peek_seat = _next_opponent()
			_message("Leak — peeking %s." % RunManager.NAMES[game.peek_seat])
		"tax":
			_tax()
		"rally":
			_rally()
	_refresh()

func _next_opponent() -> int:
	var remain: Array = game.active_seats()
	var idx: int = remain.find(0)
	if idx < 0:
		return int(remain[0]) if not remain.is_empty() else 1
	return int(remain[(idx + 1) % remain.size()])

func _tax() -> void:
	var last: int = -1
	var worst_n: int = -1
	for s in game.active_seats():
		if s == 0:
			continue
		var n: int = game.hand_of(s).size()
		if n >= worst_n:
			worst_n = n
			last = s
	if last < 0 or game.hand_of(last).is_empty():
		_message("Tax fizzled — nobody to steal from.")
		run.actions.append("tax")
		return
	var oh: Array = game.hands[last]
	var card: CardData = oh[run.rng.randi_range(0, oh.size() - 1)]
	oh.erase(card)
	game.hands[0].append(card)
	Deck._sort_hand(game.hands[0])
	_message("Taxed %s for %s." % [RunManager.NAMES[last], card.display_name()])

func _rally() -> void:
	for _i in range(2):
		if not game.kitty.is_empty():
			game.hands[0].append(game.kitty.pop_back())
		else:
			game.hands[0].append(CardData.new(3, _i % 4, true))
	Deck._sort_hand(game.hands[0])
	_message("Rally — two more cards.")

func _end_round() -> void:
	_busy = true
	run.apply_payouts(game.finished)
	var lines: Array[String] = []
	for p in run.last_payout:
		var d: Dictionary = p
		lines.append("%d. %s  HP %+d%s" % [int(d["place"]), str(d["name"]), int(d["hp_delta"]), "  +$%d" % int(d["gold"]) if int(d["seat"]) == 0 else ""])
	var ctx: String = "Round %d results (stake %d):\n%s\nYou: HP %d/%d   Gold %d" % [
		run.round_n, run.stake(), "\n".join(lines), int(run.hp[0]), run.max_hp, run.gold]
	if run.run_over:
		_show_run_over()
		return
	_shop_upgrades = UpgradeDB.shop_offers(run.rng, 3)
	_shop_actions = ActionDB.shop_offers(run.rng, 3)
	_shop.present(run.gold, _shop_upgrades, _shop_actions, ctx)

func _on_buy_upgrade(item: Dictionary) -> void:
	if run.buy_upgrade(str(item["id"]), int(item["price"])):
		_shop.set_gold(run.gold)
		_message("Bought %s." % str(item["name"]))
		_shop.present(run.gold, _shop_upgrades, _shop_actions, "Gold: %d" % run.gold)
	else:
		_message("Not enough gold.")

func _on_buy_action(item: Dictionary) -> void:
	if run.buy_action(str(item["id"]), int(item["price"])):
		_shop.set_gold(run.gold)
		_message("Pocketed %s." % str(item["name"]))
		_shop.present(run.gold, _shop_upgrades, _shop_actions, "Gold: %d" % run.gold)
	else:
		_message("Not enough gold.")

func _on_shop_closed() -> void:
	run.next_round()
	_start_round()

func _show_run_over() -> void:
	var title: String = "THE OVAL IS YOURS" if run.run_won else "REMOVED FROM OFFICE"
	var body: String = "You lasted %d round(s). Gold in pocket: %d.\n%s" % [
		run.round_n, run.gold, "Last seat standing." if run.run_won else "HP hit zero. The cabinet outlasted you."]
	_show_overlay(title, body, ["New Run"])

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
	_hud.text = "Round %d  Stake %d  HP %d/%d  Gold %d  Living %d" % [
		run.round_n, run.stake(), int(run.hp[0]), run.max_hp, run.gold, run.living_seats().size()]

func _refresh() -> void:
	_refresh_hud()
	var vw: float = size.x if size.x > 10.0 else 390.0
	var nhand: int = maxi(1, game.hand_of(0).size())
	var w: float = clampf(floorf((vw - 20.0) / float(mini(nhand, 10))), 36.0, 70.0)
	_card_size = Vector2(w, w * 1.4)
	_rebuild_ais()
	_rebuild_trick()
	_rebuild_hand()
	_rebuild_actions()
	var yours: bool = game.current_player == 0 and not game.round_over and not _busy
	_play_btn.disabled = not yours
	_pass_btn.disabled = not yours or game.lead

func _rebuild_ais() -> void:
	for c in _ai_row.get_children():
		_ai_row.remove_child(c)
		c.queue_free()
	for seat in range(1, 6):
		var box: VBoxContainer = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bust: ColorRect = ColorRect.new()
		bust.custom_minimum_size = Vector2(36, 28)
		bust.color = AI_COLORS[seat - 1]
		if not run.is_alive(seat):
			bust.color = Color(0.2, 0.2, 0.22)
		box.add_child(bust)
		var nm: Label = Label.new()
		nm.text = str(RunManager.NAMES[seat]).replace("The ", "")
		nm.add_theme_font_size_override("font_size", 10)
		nm.clip_text = true
		box.add_child(nm)
		var hp: Label = Label.new()
		hp.add_theme_font_size_override("font_size", 10)
		if run.is_alive(seat):
			hp.text = "HP %d  %dc" % [int(run.hp[seat]), game.hand_of(seat).size()]
		else:
			hp.text = "OUT"
		if game.current_player == seat:
			hp.add_theme_color_override("font_color", Color(0.95, 0.82, 0.3))
		box.add_child(hp)
		var last: Label = Label.new()
		last.add_theme_font_size_override("font_size", 10)
		last.text = str(game.last_play_label.get(seat, "—"))
		last.clip_text = true
		box.add_child(last)
		if game.peek_seat == seat:
			var peek: Label = Label.new()
			peek.add_theme_font_size_override("font_size", 9)
			var bits: Array[String] = []
			for c2 in game.hand_of(seat):
				bits.append((c2 as CardData).label())
			peek.text = " ".join(bits)
			peek.autowrap_mode = TextServer.AUTOWRAP_OFF
			peek.clip_text = true
			box.add_child(peek)
		if run.has_upgrade("whip") and not run.whip_used:
			var wb: Button = Button.new()
			wb.text = "?"
			wb.custom_minimum_size = Vector2(28, 28)
			var cap: int = seat
			wb.pressed.connect(func() -> void: _whip(cap))
			box.add_child(wb)
		_ai_row.add_child(box)

func _whip(seat: int) -> void:
	if run.whip_used:
		return
	run.whip_used = true
	var legal: Array = game.legal_combos(seat)
	_message("Whip Count: %s %s follow." % [RunManager.NAMES[seat], "CAN" if not legal.is_empty() else "cannot"])
	_refresh()

func _rebuild_trick() -> void:
	for c in _trick_cards.get_children():
		_trick_cards.remove_child(c)
		c.queue_free()
	if game.lead or game.trick_count <= 0:
		_trick_label.text = "Lead anything."
		return
	_trick_label.text = "Follow %d× %s (or pass)" % [game.trick_count, RankSystem.short_label(game.trick_rank)]
	for i in range(game.trick_count):
		var cv: CardView = CardView.new(CardData.new(game.trick_rank, i % 4, true), _card_size)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_trick_cards.add_child(cv)

func _rebuild_hand() -> void:
	for c in _hand_row.get_children():
		_hand_row.remove_child(c)
		c.queue_free()
	var hand: Array = game.hand_of(0)
	var n: int = hand.size()
	var gap: float = 4.0
	var total: float = float(n) * _card_size.x + float(maxi(0, n - 1)) * gap
	var start: float = maxf(0.0, (_hand_row.size.x - total) * 0.5)
	if _hand_row.size.x < 10.0:
		start = 0.0
	for i in range(n):
		var cv: CardView = CardView.new(hand[i], _card_size)
		cv.position = Vector2(start + float(i) * (_card_size.x + gap), 0)
		cv.selected = _selected.has(hand[i])
		cv.press_started.connect(_on_card_press)
		_hand_row.add_child(cv)
	_hand_row.custom_minimum_size = Vector2(0, _card_size.y + 8)

func _rebuild_actions() -> void:
	for c in _action_row.get_children():
		_action_row.remove_child(c)
		c.queue_free()
	if run.actions.is_empty():
		return
	for id in run.actions:
		var info: Dictionary = ActionDB.get_by_id(str(id))
		var b: Button = Button.new()
		b.text = str(info.get("name", id))
		b.custom_minimum_size = Vector2(0, 36)
		var cap: String = str(id)
		b.pressed.connect(func() -> void: _use_action(cap))
		_action_row.add_child(b)
