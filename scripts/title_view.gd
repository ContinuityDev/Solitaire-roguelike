class_name TitleView
extends Control

## Magician / cabinet title. Solo vs AIs, or a local lobby.

signal solo_pressed
signal lobby_pressed
signal join_pressed

func _init() -> void:
	UiPin.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.10, 1.0)
	UiPin.full_rect(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var felt: _TitleFelt = _TitleFelt.new()
	UiPin.full_rect(felt)
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(felt)
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 22)
	pad.add_theme_constant_override("margin_right", 22)
	pad.add_theme_constant_override("margin_top", 36)
	pad.add_theme_constant_override("margin_bottom", 24)
	UiPin.full_rect(pad)
	add_child(pad)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(col)
	var kicker: Label = Label.new()
	kicker.text = "THE CABINET"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	col.add_child(kicker)
	var title: Label = Label.new()
	title.text = "PRESIDENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.98, 0.90, 0.55))
	col.add_child(title)
	var sub: Label = Label.new()
	sub.text = "Shed your hand. Survive the table.\nA magician’s cabinet of ranks, gold, and vetoes."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.78, 0.82, 0.90))
	col.add_child(sub)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	col.add_child(spacer)
	col.add_child(_mode_btn("Solo  /  vs AIs", "You versus five cabinet AIs. Same President run as before.", func() -> void: solo_pressed.emit()))
	col.add_child(_mode_btn("Local Lobby", "Host 2–6 seats. You are player one — rename yourself. Share the 4-letter table code. Empty seats stay AIs. Hotseat still works on this device.", func() -> void: lobby_pressed.emit()))
	col.add_child(_mode_btn("Join Table", "Another browser, same page. Type the host’s table code and your name.", func() -> void: join_pressed.emit()))
	var foot: Label = Label.new()
	if NetSession.uses_webrtc():
		foot.text = "Two phones or two tabs: host a lobby, share the code, Join Table. Peer-to-peer WebRTC — no install."
	else:
		foot.text = "Desktop LAN is UDP %d (join by IP). The web page uses a table code instead." % NetSession.PORT
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 11)
	foot.add_theme_color_override("font_color", Color(0.55, 0.58, 0.64))
	col.add_child(foot)

func _enter_tree() -> void:
	UiPin.full_rect(self)

func _mode_btn(name_text: String, desc: String, on_press: Callable) -> PanelContainer:
	var wrap: PanelContainer = PanelContainer.new()
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.10, 0.18)
	psb.border_color = Color(0.85, 0.70, 0.28)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(12)
	wrap.add_theme_stylebox_override("panel", psb)
	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	wrap.add_child(m)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	var b: Button = Button.new()
	b.text = name_text
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(on_press)
	v.add_child(b)
	var d: Label = Label.new()
	d.text = desc
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 12)
	d.add_theme_color_override("font_color", Color(0.70, 0.74, 0.82))
	v.add_child(d)
	return wrap

class _TitleFelt extends Control:
	func _draw() -> void:
		var c: Vector2 = size * 0.5 + Vector2(0, 18)
		var rx: float = size.x * 0.46
		var ry: float = size.y * 0.38
		draw_colored_polygon(_ellipse(c, rx, ry, 48), Color(0.72, 0.56, 0.18, 0.55))
		draw_colored_polygon(_ellipse(c, rx - 8.0, ry - 8.0, 48), Color(0.07, 0.16, 0.28, 0.7))
		# Magician hat
		var hat: Vector2 = Vector2(size.x * 0.5, 78)
		draw_colored_polygon(PackedVector2Array([
			hat + Vector2(-36, 18), hat + Vector2(36, 18), hat + Vector2(22, -28), hat + Vector2(-22, -28),
		]), Color(0.12, 0.08, 0.16))
		draw_rect(Rect2(hat + Vector2(-48, 14), Vector2(96, 10)), Color(0.10, 0.07, 0.14))
		draw_rect(Rect2(hat + Vector2(-18, -8), Vector2(36, 8)), Color(0.72, 0.18, 0.22))

	func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(n):
			var a: float = TAU * float(i) / float(n)
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return pts
