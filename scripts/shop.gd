class_name Shop
extends PanelContainer

## Limited desk: a handful of offer cards, reroll, leave. Gold + Survivor Chips.

signal bought_upgrade(item: Dictionary)
signal bought_action(item: Dictionary)
signal bought_enhancement(item: Dictionary)
signal bought_rank_fx(item: Dictionary)
signal reroll_pressed
signal closed

var _box: VBoxContainer
var _gold_label: Label
var _status: Label
var _reroll_btn: Button
var _offers: Array = []
var _gold: int = 0
var _chips: int = 0
var _owned: Dictionary = {}

func _ready() -> void:
	visible = false
	var panel_sb: StyleBoxFlat = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.07, 0.10, 0.20)
	panel_sb.border_color = Color(0.85, 0.70, 0.28)
	panel_sb.set_border_width_all(3)
	panel_sb.set_corner_radius_all(12)
	add_theme_stylebox_override("panel", panel_sb)
	custom_minimum_size = Vector2(280, 200)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)
	var title: Label = Label.new()
	title.text = "THE DESK"
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	title.add_theme_font_size_override("font_size", 22)
	outer.add_child(title)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.55))
	outer.add_child(_gold_label)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	outer.add_child(_status)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	var btns: HBoxContainer = HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	outer.add_child(btns)
	_reroll_btn = Button.new()
	_reroll_btn.text = "Reroll"
	_reroll_btn.custom_minimum_size = Vector2(0, 52)
	_reroll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll_btn.pressed.connect(func() -> void: reroll_pressed.emit())
	btns.add_child(_reroll_btn)
	var leave: Button = Button.new()
	leave.text = "Leave"
	leave.custom_minimum_size = Vector2(0, 52)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void: visible = false; closed.emit())
	btns.add_child(leave)

func present(gold: int, offers: Array, owned: Dictionary, reroll_cost: int, context: String, chips: int = 0) -> void:
	_gold = gold
	_chips = chips
	_offers = offers
	_owned = owned
	_gold_label.text = "Gold  $%d    Survivor Chips  ◈%d" % [gold, chips]
	_status.text = context
	_reroll_btn.text = "Reroll  $%d" % reroll_cost
	_reroll_btn.disabled = gold < reroll_cost
	var vp: Vector2 = get_viewport_rect().size
	custom_minimum_size = Vector2(minf(520.0, maxf(280.0, vp.x - 28.0)), minf(620.0, maxf(300.0, vp.y - 80.0)))
	_rebuild()
	visible = true

func _rebuild() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var btn_w: float = minf(480.0, maxf(240.0, custom_minimum_size.x - 36.0))
	_box.custom_minimum_size = Vector2(maxf(240.0, custom_minimum_size.x - 40.0), 0)
	if _offers.is_empty():
		var empty: Label = Label.new()
		empty.text = "Nothing left to stock. Leave the desk."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(empty)
		return
	for it in _offers:
		_box.add_child(_make_row(it, btn_w))

func _kind_label(kind: String, currency: String) -> String:
	match kind:
		"upgrade":
			return "UPGRADE" if currency != "chips" else "ECONOMY ◈"
		"rank_fx":
			return "RANK FX ◈"
		"action":
			return "ACTION"
		_:
			return "ENHANCE"

func _wallet_for(currency: String) -> int:
	return _chips if currency == "chips" else _gold

func _price_text(price: int, currency: String, can: bool) -> String:
	var sym: String = "◈%d" % price if currency == "chips" else "$%d" % price
	if can:
		return sym
	return "Need %s" % sym

func _make_row(item: Dictionary, btn_w: float) -> PanelContainer:
	var price: int = int(item.get("price", 0))
	var id: String = str(item.get("id", ""))
	var kind: String = str(item.get("kind", "upgrade"))
	var currency: String = UpgradeDB.currency_of(item)
	if RankEffectDB.is_rank_fx(id):
		kind = "rank_fx"
		currency = "chips"
	var owned_n: int = int(_owned.get(id, 0))
	if id.begins_with("favorite_"):
		owned_n = int(_owned.get("favorite", 0))
	var can: bool = _wallet_for(currency) >= price
	var wrap: PanelContainer = PanelContainer.new()
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(0.12, 0.16, 0.26) if can else Color(0.09, 0.10, 0.14)
	if currency == "chips":
		psb.border_color = Color(0.45, 0.85, 0.95, 0.9) if can else Color(0.35, 0.36, 0.42, 0.6)
	else:
		psb.border_color = Color(0.85, 0.70, 0.28, 0.85) if can else Color(0.35, 0.36, 0.42, 0.6)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(8)
	wrap.add_theme_stylebox_override("panel", psb)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	wrap.add_child(row)
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pad)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	pad.add_child(col)
	var kind_l: Label = Label.new()
	kind_l.text = _kind_label(kind, currency)
	kind_l.add_theme_font_size_override("font_size", 10)
	kind_l.add_theme_color_override("font_color", Color(0.55, 0.88, 0.95) if currency == "chips" else Color(0.92, 0.78, 0.35))
	col.add_child(kind_l)
	var name_l: Label = Label.new()
	var owned_bit: String = "  ·  Lv%d" % owned_n if owned_n > 0 and kind == "rank_fx" else ("  ·  owned ×%d" % owned_n if owned_n > 0 else "")
	name_l.text = "%s%s" % [str(item.get("name", "?")), owned_bit]
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", Color(0.96, 0.93, 0.82) if can else Color(0.55, 0.55, 0.58))
	col.add_child(name_l)
	var desc: Label = Label.new()
	desc.text = str(item.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86) if can else Color(0.45, 0.46, 0.50))
	col.add_child(desc)
	var buy: Button = Button.new()
	buy.text = _price_text(price, currency, can)
	buy.custom_minimum_size = Vector2(96, 56)
	buy.disabled = not can
	var captured: Dictionary = item.duplicate()
	captured["currency"] = currency
	captured["kind"] = kind
	buy.pressed.connect(func() -> void:
		match str(captured.get("kind", "upgrade")):
			"rank_fx":
				bought_rank_fx.emit(captured)
			"action":
				bought_action.emit(captured)
			"enhancement":
				bought_enhancement.emit(captured)
			_:
				bought_upgrade.emit(captured)
	)
	row.add_child(buy)
	wrap.custom_minimum_size = Vector2(btn_w, 0)
	return wrap
