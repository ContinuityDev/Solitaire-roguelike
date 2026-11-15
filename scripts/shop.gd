class_name Shop
extends PanelContainer

## Polished desk: sectioned tiles (Gold / Rank ◈ / Combo), affordability,
## hover/selected states, clear rank + effect + level + price.

signal bought_upgrade(item: Dictionary)
signal bought_action(item: Dictionary)
signal bought_enhancement(item: Dictionary)
signal bought_rank_fx(item: Dictionary)
signal bought_combo(item: Dictionary)
signal reroll_pressed
signal closed

var _scroll: ScrollContainer
var _box: VBoxContainer
var _gold_label: Label
var _status: Label
var _reroll_btn: Button
var _offers: Array = []
var _gold: int = 0
var _chips: int = 0
var _owned: Dictionary = {}
var _selected_id: String = ""

const COL_GOLD: Color = Color(0.92, 0.78, 0.35)
const COL_CHIP: Color = Color(0.45, 0.88, 0.98)
const COL_COMBO: Color = Color(0.95, 0.58, 0.82)
const COL_ACTION: Color = Color(0.72, 0.78, 0.90)
const COL_MUTED: Color = Color(0.42, 0.44, 0.50)

func _ready() -> void:
	visible = false
	var panel_sb: StyleBoxFlat = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.06, 0.08, 0.14, 0.97)
	panel_sb.border_color = Color(0.85, 0.70, 0.28)
	panel_sb.set_border_width_all(3)
	panel_sb.set_corner_radius_all(14)
	add_theme_stylebox_override("panel", panel_sb)
	custom_minimum_size = Vector2(320, 240)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	outer.add_child(head)
	var title: Label = Label.new()
	title.text = "THE DESK"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 15)
	_gold_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.65))
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_gold_label)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.70, 0.76, 0.88))
	outer.add_child(_status)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	var btns: HBoxContainer = HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	outer.add_child(btns)
	_reroll_btn = Button.new()
	_reroll_btn.text = "Reroll"
	_reroll_btn.custom_minimum_size = Vector2(0, 48)
	_reroll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll_btn.pressed.connect(func() -> void: reroll_pressed.emit())
	btns.add_child(_reroll_btn)
	var leave: Button = Button.new()
	leave.text = "Leave"
	leave.custom_minimum_size = Vector2(0, 48)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void: visible = false; closed.emit())
	btns.add_child(leave)

func present(gold: int, offers: Array, owned: Dictionary, reroll_cost: int, context: String, chips: int = 0) -> void:
	_gold = gold
	_chips = chips
	_offers = offers
	_owned = owned
	_selected_id = ""
	_gold_label.text = "$%d   ·   ◈%d" % [gold, chips]
	_status.text = context
	_reroll_btn.text = "Reroll  $%d" % reroll_cost
	_reroll_btn.disabled = gold < reroll_cost
	var vp: Vector2 = get_viewport_rect().size
	custom_minimum_size = Vector2(minf(560.0, maxf(300.0, vp.x - 24.0)), minf(680.0, maxf(320.0, vp.y - 60.0)))
	_rebuild()
	visible = true

func _rebuild() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	if _offers.is_empty():
		var empty: Label = Label.new()
		empty.text = "Nothing left to stock. Leave the desk."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", COL_MUTED)
		_box.add_child(empty)
		return
	var sections: Dictionary = {
		"gold": [],
		"rank": [],
		"combo": [],
		"other": [],
	}
	for it in _offers:
		var sec: String = _section_of(it)
		(sections[sec] as Array).append(it)
	_add_section("GOLD UPGRADES", COL_GOLD, sections["gold"])
	_add_section("RANK UPGRADES  ·  ◈", COL_CHIP, sections["rank"])
	_add_section("COMBOS", COL_COMBO, sections["combo"])
	_add_section("ACTIONS & ENHANCEMENTS", COL_ACTION, sections["other"])

func _section_of(item: Dictionary) -> String:
	var id: String = str(item.get("id", ""))
	var kind: String = str(item.get("kind", "upgrade"))
	if RankEffectDB.is_rank_fx(id) or kind == "rank_fx":
		return "rank"
	if ComboBuffDB.is_combo(id) or kind == "combo":
		return "combo"
	if kind == "action" or kind == "enhancement":
		return "other"
	if str(item.get("section", "")) == "rank":
		return "rank"
	if str(item.get("section", "")) == "combo":
		return "combo"
	return "gold"

func _add_section(title: String, accent: Color, items: Array) -> void:
	if items.is_empty():
		return
	var head: Label = Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 11)
	head.add_theme_color_override("font_color", accent)
	_box.add_child(head)
	var grid: HFlowContainer = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_box.add_child(grid)
	var tile_w: float = minf(250.0, maxf(200.0, (custom_minimum_size.x - 52.0) / 2.0))
	for it in items:
		grid.add_child(_make_tile(it, tile_w, accent))

func _wallet_for(currency: String) -> int:
	return _chips if currency == "chips" else _gold

func _price_text(price: int, currency: String) -> String:
	return "◈%d" % price if currency == "chips" else "$%d" % price

func _resolve_meta(item: Dictionary) -> Dictionary:
	var id: String = str(item.get("id", ""))
	var kind: String = str(item.get("kind", "upgrade"))
	var currency: String = UpgradeDB.currency_of(item)
	if RankEffectDB.is_rank_fx(id):
		kind = "rank_fx"
		currency = "chips"
	elif ComboBuffDB.is_combo(id):
		kind = "combo"
	var owned_n: int = int(_owned.get(id, 0))
	if id.begins_with("favorite_"):
		owned_n = int(_owned.get("favorite", 0))
	if RankEffectDB.is_rank_fx(id):
		var fx: Dictionary = RankEffectDB.get_by_id(id)
		# Owned counts for rank_fx may be keyed by id or resolved via level elsewhere.
		owned_n = maxi(owned_n, int(_owned.get(id, 0)))
		if fx.has("rank"):
			pass
	var rank_bit: String = ""
	if item.has("rank") and int(item.get("rank", -1)) > 0:
		rank_bit = RankSystem.short_label(int(item["rank"]))
	elif RankEffectDB.is_rank_fx(id):
		var fx2: Dictionary = RankEffectDB.get_by_id(id)
		if int(fx2.get("rank", -1)) > 0:
			rank_bit = RankSystem.short_label(int(fx2["rank"]))
	elif ComboBuffDB.is_combo(id):
		rank_bit = ComboBuffDB.target_rank_label(ComboBuffDB.get_by_id(id))
	return {
		"id": id, "kind": kind, "currency": currency, "owned": owned_n, "rank": rank_bit,
	}

func _make_tile(item: Dictionary, tile_w: float, accent: Color) -> PanelContainer:
	var price: int = int(item.get("price", 0))
	var meta: Dictionary = _resolve_meta(item)
	var currency: String = str(meta["currency"])
	var kind: String = str(meta["kind"])
	var owned_n: int = int(meta["owned"])
	var can: bool = _wallet_for(currency) >= price
	var selected: bool = _selected_id == str(meta["id"])
	var wrap: PanelContainer = PanelContainer.new()
	wrap.custom_minimum_size = Vector2(tile_w, 118)
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	if can:
		psb.bg_color = Color(0.11, 0.14, 0.22) if not selected else Color(0.14, 0.18, 0.30)
		psb.border_color = accent if not selected else accent.lightened(0.25)
	else:
		psb.bg_color = Color(0.08, 0.09, 0.12)
		psb.border_color = Color(0.30, 0.32, 0.38, 0.7)
	psb.set_border_width_all(2 if not selected else 3)
	psb.set_corner_radius_all(10)
	psb.content_margin_left = 10
	psb.content_margin_right = 10
	psb.content_margin_top = 8
	psb.content_margin_bottom = 8
	wrap.add_theme_stylebox_override("panel", psb)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	wrap.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	col.add_child(top)
	var name_l: Label = Label.new()
	var owned_bit: String = ""
	if owned_n > 0 and (kind == "rank_fx" or kind == "combo"):
		owned_bit = "  Lv%d" % owned_n
	elif owned_n > 0:
		owned_bit = "  ×%d" % owned_n
	name_l.text = "%s%s" % [str(item.get("name", "?")), owned_bit]
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88) if can else COL_MUTED)
	top.add_child(name_l)
	var price_l: Label = Label.new()
	price_l.text = _price_text(price, currency)
	price_l.add_theme_font_size_override("font_size", 14)
	price_l.add_theme_color_override("font_color",
		(COL_CHIP if currency == "chips" else COL_GOLD) if can else COL_MUTED)
	top.add_child(price_l)
	var meta_row: HBoxContainer = HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 8)
	col.add_child(meta_row)
	var rank_bit: String = str(meta.get("rank", ""))
	if rank_bit != "":
		var rank_l: Label = Label.new()
		rank_l.text = "Rank %s" % rank_bit
		rank_l.add_theme_font_size_override("font_size", 11)
		rank_l.add_theme_color_override("font_color", accent if can else COL_MUTED)
		meta_row.add_child(rank_l)
	var eff_l: Label = Label.new()
	eff_l.text = _effect_line(item, kind)
	eff_l.add_theme_font_size_override("font_size", 11)
	eff_l.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90) if can else COL_MUTED)
	eff_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(eff_l)
	var desc: Label = Label.new()
	desc.text = str(item.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.62, 0.66, 0.76) if can else Color(0.40, 0.41, 0.44))
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(desc)
	var buy: Button = Button.new()
	buy.text = "Buy  %s" % _price_text(price, currency) if can else "Need %s" % _price_text(price, currency)
	buy.custom_minimum_size = Vector2(0, 32)
	buy.disabled = not can
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var captured: Dictionary = item.duplicate()
	captured["currency"] = currency
	captured["kind"] = kind
	buy.pressed.connect(func() -> void:
		_selected_id = str(captured.get("id", ""))
		match str(captured.get("kind", "upgrade")):
			"rank_fx":
				bought_rank_fx.emit(captured)
			"combo":
				bought_combo.emit(captured)
			"action":
				bought_action.emit(captured)
			"enhancement":
				bought_enhancement.emit(captured)
			_:
				bought_upgrade.emit(captured)
	)
	col.add_child(buy)
	# Hover: brighten border via mouse enter/exit on the panel.
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.mouse_entered.connect(func() -> void:
		if can:
			var hsb: StyleBoxFlat = wrap.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			if hsb != null:
				hsb.border_color = accent.lightened(0.2)
				hsb.set_border_width_all(3)
				wrap.add_theme_stylebox_override("panel", hsb)
	)
	wrap.mouse_exited.connect(func() -> void:
		wrap.add_theme_stylebox_override("panel", psb)
	)
	return wrap

func _effect_line(item: Dictionary, kind: String) -> String:
	if kind == "rank_fx":
		var fx: Dictionary = RankEffectDB.get_by_id(str(item.get("id", "")))
		return RankEffectDB.effect_label(str(fx.get("effect", item.get("effect", ""))), 1)
	if kind == "combo":
		var cb: Dictionary = ComboBuffDB.get_by_id(str(item.get("id", "")))
		if cb.is_empty():
			cb = item
		return ComboBuffDB.short_label(cb, 1)
	return str(item.get("icon", kind)).to_upper()
