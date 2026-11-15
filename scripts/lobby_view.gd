class_name LobbyView
extends Control

## Host a local hotseat lobby: seat count, human vs AI, start.

signal started(config: LobbyConfig)
signal cancelled

var config: LobbyConfig = LobbyConfig.new()
var _name_edit: LineEdit
var _code_lab: Label
var _count_lab: Label
var _fill_btn: Button
var _rows: VBoxContainer
var _start_btn: Button
var _status: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.12, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 12)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pad)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)
	var title: Label = Label.new()
	title.text = "LOCAL LOBBY"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	col.add_child(title)
	var hint: Label = Label.new()
	hint.text = "Pass-the-device on this phone or desktop. Empty seats become AIs when you toggle Fill."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
	col.add_child(hint)
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	col.add_child(name_row)
	var nl: Label = Label.new()
	nl.text = "Name"
	nl.custom_minimum_size = Vector2(52, 0)
	name_row.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "The Cabinet"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t: String) -> void: config.lobby_name = t)
	name_row.add_child(_name_edit)
	_code_lab = Label.new()
	_code_lab.add_theme_font_size_override("font_size", 16)
	_code_lab.add_theme_color_override("font_color", Color(0.98, 0.90, 0.55))
	name_row.add_child(_code_lab)
	var count_row: HBoxContainer = HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 8)
	col.add_child(count_row)
	var minus: Button = Button.new()
	minus.text = "–"
	minus.custom_minimum_size = Vector2(48, 44)
	minus.pressed.connect(func() -> void: config.set_seat_count(config.seat_count - 1); _rebuild())
	count_row.add_child(minus)
	_count_lab = Label.new()
	_count_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_lab.add_theme_font_size_override("font_size", 16)
	count_row.add_child(_count_lab)
	var plus: Button = Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(48, 44)
	plus.pressed.connect(func() -> void: config.set_seat_count(config.seat_count + 1); _rebuild())
	count_row.add_child(plus)
	_fill_btn = Button.new()
	_fill_btn.text = "Empty → AI"
	_fill_btn.custom_minimum_size = Vector2(0, 40)
	_fill_btn.pressed.connect(func() -> void: config.fill_empty_with_ai(); _rebuild())
	col.add_child(_fill_btn)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	col.add_child(_status)
	var btns: HBoxContainer = HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	col.add_child(btns)
	var back: Button = Button.new()
	back.text = "Title"
	back.custom_minimum_size = Vector2(0, 52)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func() -> void: visible = false; cancelled.emit())
	btns.add_child(back)
	_start_btn = Button.new()
	_start_btn.text = "Start"
	_start_btn.custom_minimum_size = Vector2(0, 52)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.pressed.connect(_on_start)
	btns.add_child(_start_btn)

func present(fresh: bool = true) -> void:
	if fresh:
		config = LobbyConfig.new()
		config.lobby_name = "The Cabinet"
		config.set_seat_count(6)
		config.fill_empty_with_ai()
		config.set_kind(0, LobbyConfig.KIND_HUMAN)
	_name_edit.text = config.lobby_name
	_rebuild()
	visible = true

func _rebuild() -> void:
	_code_lab.text = "code %s" % config.lobby_code
	_count_lab.text = "%d seats" % config.seat_count
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for i in range(config.seat_count):
		_rows.add_child(_make_seat_row(i))
	var ok: bool = config.can_start()
	_start_btn.disabled = not ok
	if ok:
		_status.text = "%d human  ·  %d AI  ·  hotseat %s" % [
			config.human_count(), config.ai_seats().size(),
			"ON" if config.is_hotseat() else "off (solo table)"]
	else:
		_status.text = "Need at least one human seat."

func _make_seat_row(seat: int) -> PanelContainer:
	var wrap: PanelContainer = PanelContainer.new()
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(0.10, 0.13, 0.22)
	psb.set_corner_radius_all(8)
	psb.set_border_width_all(1)
	psb.border_color = Color(0.85, 0.70, 0.28, 0.45) if config.is_human(seat) else Color(0.35, 0.40, 0.50, 0.5)
	wrap.add_theme_stylebox_override("panel", psb)
	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	wrap.add_child(m)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	m.add_child(row)
	var lab: Label = Label.new()
	lab.text = "%d.  %s" % [seat + 1, config.name_of(seat)]
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_font_size_override("font_size", 14)
	row.add_child(lab)
	if seat == 0:
		var host: Label = Label.new()
		host.text = "HOST"
		host.add_theme_font_size_override("font_size", 11)
		host.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
		row.add_child(host)
	else:
		var human_b: Button = Button.new()
		human_b.text = "Human"
		human_b.custom_minimum_size = Vector2(72, 40)
		human_b.disabled = config.is_human(seat)
		var cap: int = seat
		human_b.pressed.connect(func() -> void: config.set_kind(cap, LobbyConfig.KIND_HUMAN); _rebuild())
		row.add_child(human_b)
		var ai_b: Button = Button.new()
		ai_b.text = "AI"
		ai_b.custom_minimum_size = Vector2(56, 40)
		ai_b.disabled = config.is_ai(seat)
		ai_b.pressed.connect(func() -> void: config.set_kind(cap, LobbyConfig.KIND_AI); _rebuild())
		row.add_child(ai_b)
	return wrap

func _on_start() -> void:
	if not config.can_start():
		return
	config.lobby_name = _name_edit.text.strip_edges()
	if config.lobby_name == "":
		config.lobby_name = "The Cabinet"
	visible = false
	started.emit(config)
