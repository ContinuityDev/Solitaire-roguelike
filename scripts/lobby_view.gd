class_name LobbyView
extends Control

## Host a local hotseat lobby: seat count, human vs AI, start.
## Desktop also listens on LAN (host is player one).

signal started(config: LobbyConfig)
signal cancelled
signal host_name_changed(player_name: String)

var config: LobbyConfig = LobbyConfig.new()
var lan_host: bool = false
var _name_edit: LineEdit
var _you_edit: LineEdit
var _code_lab: Label
var _count_lab: Label
var _fill_btn: Button
var _rows: VBoxContainer
var _start_btn: Button
var _status: Label
var _lan_lab: Label
var _title_lab: Label
var _hint: Label

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
	_title_lab = Label.new()
	_title_lab.text = "LOCAL LOBBY"
	_title_lab.add_theme_font_size_override("font_size", 22)
	_title_lab.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	col.add_child(_title_lab)
	_hint = Label.new()
	_hint.text = "Pass-the-device on this phone or desktop. Empty seats become AIs when you toggle Fill."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
	col.add_child(_hint)
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	col.add_child(name_row)
	var nl: Label = Label.new()
	nl.text = "Table"
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
	var you_row: HBoxContainer = HBoxContainer.new()
	you_row.add_theme_constant_override("separation", 8)
	col.add_child(you_row)
	var yl: Label = Label.new()
	yl.text = "You"
	yl.custom_minimum_size = Vector2(52, 0)
	you_row.add_child(yl)
	_you_edit = LineEdit.new()
	_you_edit.placeholder_text = "Player one"
	_you_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_you_edit.max_length = 18
	_you_edit.text_changed.connect(_on_you_changed)
	you_row.add_child(_you_edit)
	_lan_lab = Label.new()
	_lan_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lan_lab.add_theme_font_size_override("font_size", 12)
	_lan_lab.add_theme_color_override("font_color", Color(0.70, 0.88, 0.72))
	col.add_child(_lan_lab)
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

func present(fresh: bool = true, as_lan: bool = false) -> void:
	lan_host = as_lan
	if fresh:
		config = LobbyConfig.new()
		config.lobby_name = "The Cabinet"
		config.lan = as_lan
		config.set_seat_count(6)
		config.fill_empty_with_ai()
		config.set_kind(0, LobbyConfig.KIND_HUMAN)
		config.set_display_name(0, "You")
	_name_edit.text = config.lobby_name
	_you_edit.text = config.name_of(0)
	_title_lab.text = "THE TABLE" if lan_host else "LOCAL LOBBY"
	if lan_host:
		if NetSession.uses_webrtc():
			_hint.text = "You are player one. Share the gold 4-letter code. Another browser opens Join Table, types the code and a name. Leftover seats stay AIs."
		else:
			_hint.text = "You are player one. Desktop LAN on UDP 24567. Joiners type your IP. Leftover seats stay AIs."
	else:
		_hint.text = "Pass-the-device on this phone or desktop. Empty seats become AIs when you toggle Fill."
	_rebuild()
	visible = true

func host_player_name() -> String:
	if _you_edit:
		var t: String = _you_edit.text.strip_edges()
		if t != "":
			return t
	return config.name_of(0)

func set_lan_status(t: String) -> void:
	if _lan_lab:
		_lan_lab.text = t
		_lan_lab.visible = t != ""

func _on_you_changed(t: String) -> void:
	config.set_display_name(0, t)
	host_name_changed.emit(config.name_of(0))
	_rebuild()

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
		if lan_host:
			_status.text = "%d human  ·  %d AI  ·  code %s  ·  you are player one" % [
				config.human_count(), config.ai_seats().size(), config.lobby_code]
		else:
			_status.text = "%d human  ·  %d AI  ·  hotseat %s" % [
				config.human_count(), config.ai_seats().size(),
				"ON" if config.is_hotseat() else "off (solo table)"]
	else:
		_status.text = "Need at least one human seat."
	if _you_edit and _you_edit.text.strip_edges() == "":
		_you_edit.placeholder_text = config.name_of(0)

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
		host.text = "P1 HOST"
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
