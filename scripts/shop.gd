class_name Shop
extends PanelContainer

## The Desk: persistent upgrades, one-shot actions, enhancements.

signal bought_upgrade(item: Dictionary)
signal bought_action(item: Dictionary)
signal bought_enhancement(item: Dictionary)
signal closed

var _scroll: ScrollContainer
var _box: VBoxContainer
var _gold_label: Label
var _status: Label
var _upgrades: Array = []
var _actions: Array = []
var _enhancements: Array = []
var _gold: int = 0
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
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	var leave: Button = Button.new()
	leave.text = "Leave the desk"
	leave.custom_minimum_size = Vector2(0, 52)
	leave.pressed.connect(func() -> void: visible = false; closed.emit())
	outer.add_child(leave)

func present(gold: int, upgrades: Array, actions: Array, enhancements: Array, owned: Dictionary, context: String) -> void:
	_gold = gold
	_upgrades = upgrades
	_actions = actions
	_enhancements = enhancements
	_owned = owned
	_gold_label.text = "Gold  $%d" % gold
	_status.text = context
	var vp: Vector2 = get_viewport_rect().size
	custom_minimum_size = Vector2(minf(520.0, maxf(280.0, vp.x - 28.0)), minf(640.0, maxf(320.0, vp.y - 80.0)))
	_scroll.custom_minimum_size = Vector2(0, custom_minimum_size.y - 160.0)
	_rebuild()
	visible = true

func set_gold(gold: int) -> void:
	_gold = gold
	if _gold_label:
		_gold_label.text = "Gold  $%d" % gold

func _rebuild() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var btn_w: float = minf(480.0, maxf(240.0, custom_minimum_size.x - 36.0))
	_box.custom_minimum_size = Vector2(maxf(240.0, custom_minimum_size.x - 40.0), 0)
	_section("Persistent upgrades", "Keep these for the rest of the run.")
	for u in _upgrades:
		_box.add_child(_make_row(u, "upgrade", btn_w))
	_section("One-shot actions", "Spend on your turn or at results.")
	for a in _actions:
		_box.add_child(_make_row(a, "action", btn_w))
	_section("Enhancements", "Stamp the next deals.")
	for e in _enhancements:
		_box.add_child(_make_row(e, "enhancement", btn_w))

func _section(title_text: String, sub: String) -> void:
	var l: Label = Label.new()
	l.text = title_text
	l.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	l.add_theme_font_size_override("font_size", 16)
	_box.add_child(l)
	var s: Label = Label.new()
	s.text = sub
	s.add_theme_color_override("font_color", Color(0.70, 0.76, 0.88))
	s.add_theme_font_size_override("font_size", 11)
	_box.add_child(s)

func _make_row(item: Dictionary, kind: String, btn_w: float) -> PanelContainer:
	var price: int = int(item.get("price", 0))
	var id: String = str(item.get("id", ""))
	var owned_n: int = int(_owned.get(id, 0))
	if id.begins_with("favorite_"):
		owned_n = int(_owned.get("favorite", 0))
	var can: bool = _gold >= price
	var wrap: PanelContainer = PanelContainer.new()
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(0.12, 0.16, 0.26) if can else Color(0.09, 0.10, 0.14)
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
	var name_l: Label = Label.new()
	var owned_bit: String = "  ·  owned ×%d" % owned_n if owned_n > 0 else ""
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
	buy.text = "$%d" % price if can else "Need $%d" % price
	buy.custom_minimum_size = Vector2(88, 56)
	buy.disabled = not can
	var captured: Dictionary = item
	var cap_kind: String = kind
	buy.pressed.connect(func() -> void:
		match cap_kind:
			"upgrade":
				bought_upgrade.emit(captured)
			"action":
				bought_action.emit(captured)
			_:
				bought_enhancement.emit(captured)
	)
	row.add_child(buy)
	wrap.custom_minimum_size = Vector2(btn_w, 0)
	return wrap
