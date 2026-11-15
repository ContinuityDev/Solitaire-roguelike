class_name JoinView
extends Control

## Type a name, type the host IP, sit down. Desktop ENet only.

signal cancelled
signal connect_pressed(ip: String, player_name: String)

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _rows: VBoxContainer
var _connect_btn: Button
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
	var title: Label = Label.new()
	title.text = "JOIN LAN"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	col.add_child(title)
	_hint = Label.new()
	_hint.text = "Same Wi-Fi as the host. Host is player one. You pick a name and take the next empty seat."
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
	il.text = "Host"
	il.custom_minimum_size = Vector2(52, 0)
	ip_row.add_child(il)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "127.0.0.1"
	_ip_edit.text = "127.0.0.1"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_ip_edit)
	var port_l: Label = Label.new()
	port_l.text = ":%d" % NetSession.PORT
	port_l.add_theme_color_override("font_color", Color(0.98, 0.90, 0.55))
	ip_row.add_child(port_l)
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

func present() -> void:
	if _name_edit.text.strip_edges() == "":
		_name_edit.text = "Guest"
	_status.text = "UDP port %d. Two windows on this machine: use 127.0.0.1." % NetSession.PORT
	if not NetSession.lan_supported():
		_status.text = "This web page cannot join LAN. Open the desktop Godot build."
		_connect_btn.disabled = true
	else:
		_connect_btn.disabled = false
	_rebuild_roster(null)
	visible = true

func set_status(t: String) -> void:
	_status.text = t

func player_name() -> String:
	return _name_edit.text.strip_edges()

func _on_connect() -> void:
	if not NetSession.lan_supported():
		return
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
