class_name JoinView
extends Control

## Type a name and the host’s table code (web) or IP (desktop).

signal cancelled
signal connect_pressed(target: String, player_name: String)

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _rows: VBoxContainer
var _connect_btn: Button
var _hint: Label

func _init() -> void:
	UiPin.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.12, 1.0)
	UiPin.full_rect(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 12)
	UiPin.full_rect(pad)
	add_child(pad)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)
	var title: Label = Label.new()
	title.text = "JOIN TABLE"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	col.add_child(title)
	_hint = Label.new()
	_hint.text = "Host is player one. Type your name and their 4-letter table code (same web page, two phones or two tabs)."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
	col.add_child(_hint)
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	col.add_child(name_row)
	var nl: Label = Label.new()
	nl.text = "You"
	nl.custom_minimum_size = Vector2(52, 0)
	name_row.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.max_length = 18
	name_row.add_child(_name_edit)
	var ip_row: HBoxContainer = HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 8)
	col.add_child(ip_row)
	var il: Label = Label.new()
	il.text = "Code"
	il.custom_minimum_size = Vector2(52, 0)
	il.name = "TargetLab"
	ip_row.add_child(il)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "ABCD"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.max_length = 18
	ip_row.add_child(_ip_edit)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	col.add_child(_status)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	var btns: HBoxContainer = HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	col.add_child(btns)
	var back: Button = Button.new()
	back.text = "Title"
	back.custom_minimum_size = Vector2(0, 52)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func() -> void: visible = false; cancelled.emit())
	btns.add_child(back)
	_connect_btn = Button.new()
	_connect_btn.text = "Sit down"
	_connect_btn.custom_minimum_size = Vector2(0, 52)
	_connect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connect_btn.pressed.connect(_on_connect)
	btns.add_child(_connect_btn)

func _enter_tree() -> void:
	UiPin.full_rect(self)

func present() -> void:
	if _name_edit.text.strip_edges() == "":
		_name_edit.text = "Guest"
	_connect_btn.disabled = false
	_connect_btn.text = "Sit down"
	var lab: Label = _ip_edit.get_parent().get_node_or_null("TargetLab") as Label
	if NetSession.uses_webrtc():
		_hint.text = "Open this same page on another phone or tab. Type the host’s 4-letter table code and your name."
		_ip_edit.placeholder_text = "ABCD"
		_ip_edit.max_length = 4
		if lab:
			lab.text = "Code"
		_status.text = "Same Wi-Fi is most reliable. Hard NATs may fail (no TURN server)."
	else:
		_hint.text = "Desktop LAN. Host is player one. Type their IP (127.0.0.1 for two windows on this machine)."
		_ip_edit.placeholder_text = "127.0.0.1"
		_ip_edit.text = "127.0.0.1"
		_ip_edit.max_length = 40
		if lab:
			lab.text = "Host"
		_status.text = "UDP port %d." % NetSession.PORT
	_rebuild_roster(null)
	visible = true

func set_status(t: String) -> void:
	_status.text = t

func player_name() -> String:
	return _name_edit.text.strip_edges()

func _on_connect() -> void:
	connect_pressed.emit(_ip_edit.text.strip_edges(), player_name())

func _rebuild_roster(cfg: LobbyConfig, my_seat: int = -1) -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	if cfg == null:
		var wait: Label = Label.new()
		wait.text = "Roster shows up after you connect."
		wait.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
		_rows.add_child(wait)
		return
	for i in range(cfg.seat_count):
		var lab: Label = Label.new()
		var tag: String = "AI"
		if i == 0:
			tag = "HOST"
		elif i == my_seat:
			tag = "YOU"
		elif cfg.is_human(i):
			tag = "HUMAN"
		lab.text = "%d.  %s   %s" % [i + 1, cfg.name_of(i), tag]
		lab.add_theme_font_size_override("font_size", 14)
		_rows.add_child(lab)

func show_lobby(cfg: LobbyConfig, my_seat: int = -1) -> void:
	_rebuild_roster(cfg, my_seat)
	_connect_btn.disabled = true
	_connect_btn.text = "Seated"
