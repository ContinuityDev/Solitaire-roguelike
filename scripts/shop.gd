class_name Shop
extends PanelContainer

## Gold shop: three upgrades + three action cards. Buy any you can afford.

signal bought_upgrade(item: Dictionary)
signal bought_action(item: Dictionary)
signal closed

var _box: VBoxContainer
var _gold_label: Label
var _status: Label
var _upgrades: Array = []
var _actions: Array = []
var _gold: int = 0

func _ready() -> void:
	visible = false
	var panel_sb: StyleBoxFlat = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.08, 0.12, 0.22)
	panel_sb.border_color = Color(0.85, 0.70, 0.28)
	panel_sb.set_border_width_all(3)
	panel_sb.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", panel_sb)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	margin.add_child(_box)
	var title: Label = Label.new()
	title.text = "THE DESK — spend your war chest"
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	title.add_theme_font_size_override("font_size", 20)
	_box.add_child(title)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 16)
	_box.add_child(_gold_label)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_status)

func present(gold: int, upgrades: Array, actions: Array, context: String) -> void:
	_gold = gold
	_upgrades = upgrades
	_actions = actions
	_gold_label.text = "Gold: %d" % gold
	_status.text = context
	while _box.get_child_count() > 3:
		var child: Node = _box.get_child(3)
		_box.remove_child(child)
		child.queue_free()
	var btn_w: float = minf(520.0, maxf(260.0, get_viewport_rect().size.x - 48.0))
	_section("Upgrades (keep)")
	for u in upgrades:
		_box.add_child(_make_btn(u, true, btn_w))
	_section("Action cards (one-shot, use in a round)")
	for a in actions:
		_box.add_child(_make_btn(a, false, btn_w))
	var leave: Button = Button.new()
	leave.text = "Leave the desk"
	leave.custom_minimum_size = Vector2(btn_w, 48)
	leave.pressed.connect(func() -> void: visible = false; closed.emit())
	_box.add_child(leave)
	visible = true

func set_gold(gold: int) -> void:
	_gold = gold
	if _gold_label:
		_gold_label.text = "Gold: %d" % gold

func _section(text: String) -> void:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	_box.add_child(l)

func _make_btn(item: Dictionary, is_up: bool, btn_w: float) -> Button:
	var price: int = int(item.get("price", 0))
	var b: Button = Button.new()
	b.text = "$%d  %s  %s\n%s" % [price, str(item.get("icon", "")), str(item.get("name", "?")), str(item.get("desc", ""))]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(btn_w, 72)
	b.disabled = _gold < price
	var captured: Dictionary = item
	if is_up:
		b.pressed.connect(func() -> void: bought_upgrade.emit(captured))
	else:
		b.pressed.connect(func() -> void: bought_action.emit(captured))
	return b
