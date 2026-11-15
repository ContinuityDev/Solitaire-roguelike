class_name CardView
extends Control

## Code-drawn playing card. Cream faces, column-back, yellow legal highlight.

signal press_started(view: CardView, global_pos: Vector2)
signal double_pressed(view: CardView)

const W: float = 70.0
const H: float = 98.0

var card: CardData = null
var placeholder_text: String = ""
var selected: bool = false
var dimmed: bool = false
var highlighted: bool = false
var face_forced_down: bool = false

var display_size: Vector2 = Vector2(W, H)
var _last_processed_msec: int = 0
var _last_tap_msec: int = 0
## Dual rank: printed (suit color) + effective (blue badge) when buffed.
var shown_value: String = ""
var printed_label: String = ""
var value_buffed: bool = false

const BUFF_BLUE: Color = Color(0.08, 0.42, 0.98)

func _init(p_card: CardData = null, p_size: Vector2 = Vector2(W, H)) -> void:
	card = p_card
	_sync_value(0)
	set_display_size(p_size)
	mouse_filter = MOUSE_FILTER_STOP

func set_display_size(p_size: Vector2) -> void:
	display_size = p_size
	custom_minimum_size = p_size
	size = p_size
	queue_redraw()

func set_card(p_card: CardData, power_bonus: int = 0) -> void:
	card = p_card
	_sync_value(power_bonus)
	queue_redraw()

func _sync_value(power_bonus: int = 0) -> void:
	if card == null:
		shown_value = ""
		printed_label = ""
		value_buffed = false
		return
	var d: Dictionary = RankSystem.buff_display(card, power_bonus)
	shown_value = str(d.get("shown", ""))
	printed_label = str(d.get("printed", RankSystem.short_label(card.rank)))
	value_buffed = bool(d.get("buffed", false))

func _gui_input(event: InputEvent) -> void:
	var is_press: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		is_press = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	elif event is InputEventScreenTouch:
		is_press = (event as InputEventScreenTouch).pressed
	if not is_press:
		return
	accept_event()
	var now: int = Time.get_ticks_msec()
	if now - _last_processed_msec < 80:
		return
	_last_processed_msec = now
	if now - _last_tap_msec < 400:
		_last_tap_msec = 0
		double_pressed.emit(self)
	else:
		_last_tap_msec = now
		press_started.emit(self, get_global_mouse_position())

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(2, 3), size - Vector2(4, 6))
	# Drop shadow.
	draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.35), true, -1.0, true)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	if card == null:
		sb.bg_color = Color(0.10, 0.16, 0.28, 0.55)
		sb.border_color = Color(0.85, 0.70, 0.28, 0.45)
		draw_style_box(sb, rect)
		if placeholder_text != "":
			var f: Font = get_theme_default_font()
			draw_string(f, Vector2(4, size.y * 0.55), placeholder_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8.0, 11, Color(1, 1, 1, 0.7))
		return
	var show_face: bool = card.face_up and not face_forced_down
	if not show_face:
		_draw_back(sb, rect)
		return
	sb.bg_color = Color(0.86, 0.82, 0.74)
	if selected:
		sb.border_color = Color(1.0, 0.78, 0.08)
		sb.set_border_width_all(4)
	elif highlighted:
		sb.border_color = Color(0.98, 0.88, 0.12)
		sb.set_border_width_all(3)
		sb.bg_color = Color(0.92, 0.82, 0.28)
	else:
		sb.border_color = Color(0.16, 0.16, 0.20)
	if dimmed:
		sb.bg_color = sb.bg_color.lerp(Color(0.45, 0.45, 0.48), 0.45)
	draw_style_box(sb, rect)
	var inner: Rect2 = Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 10))
	var s: float = clampf(size.x / W, 0.5, 1.25)
	var font: Font = get_theme_default_font()
	if RankSystem.is_joker(card.rank):
		_draw_joker(font, rect, inner, s, dimmed)
		return
	var inner_col: Color = Color(1.0, 0.98, 0.78) if (highlighted or selected) else Color(0.99, 0.98, 0.94)
	if dimmed:
		inner_col = Color(0.86, 0.86, 0.88)
	draw_rect(inner, inner_col, true, -1.0, true)
	var suit_col: Color = Color(0.72, 0.10, 0.12) if card.is_red() else Color(0.08, 0.10, 0.16)
	if dimmed:
		suit_col.a = 0.38
	var face_lab: String = printed_label if printed_label != "" else RankSystem.short_label(card.rank)
	var rank_size: int = maxi(16, int(22.0 * s))
	if face_lab.length() > 2:
		rank_size = maxi(10, int(14.0 * s))
	elif face_lab.length() > 1:
		rank_size = maxi(14, int(18.0 * s))
	draw_string(font, Vector2(inner.position.x + 3, inner.position.y + 18.0 * s), face_lab, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size, suit_col)
	if value_buffed and shown_value != "" and shown_value != face_lab:
		if size.x >= 50.0:
			var arrow_size: int = maxi(11, int(14.0 * s))
			var face_w: float = font.get_string_size(face_lab, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size).x
			var arrow_col: Color = BUFF_BLUE
			if dimmed:
				arrow_col.a = 0.55
			draw_string(font, Vector2(inner.position.x + 3.0 + face_w, inner.position.y + 17.0 * s), "→", HORIZONTAL_ALIGNMENT_LEFT, -1, arrow_size, arrow_col)
		_draw_buff_badge(font, rect, s, shown_value, dimmed)
	_draw_suit(inner.position + Vector2(12.0 * s, 34.0 * s), 8.0 * s, suit_col, card.suit)
	_draw_suit(inner.position + Vector2(inner.size.x * 0.5, inner.size.y * 0.58), 16.0 * s, suit_col, card.suit)
	if RankSystem.is_bomb(card.rank):
		var ribbon: Rect2 = Rect2(rect.position.x, rect.end.y - 16.0 * s, rect.size.x, 14.0 * s)
		draw_rect(ribbon, Color(0.72, 0.10, 0.12, 0.92), true)
		draw_string(font, Vector2(ribbon.position.x, ribbon.end.y - 3), "BOMB", HORIZONTAL_ALIGNMENT_CENTER, ribbon.size.x, int(10.0 * s), Color(1, 0.92, 0.55))
	if card.enhancement == "steel":
		draw_string(font, Vector2(rect.position.x + 2, rect.position.y + rect.size.y * 0.72), "STEEL", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 4.0, int(9.0 * s), Color(0.55, 0.70, 0.95))

func _draw_joker(font: Font, rect: Rect2, inner: Rect2, s: float, is_dimmed: bool) -> void:
	var bg: Color = Color(0.18, 0.08, 0.28) if card.is_red() else Color(0.10, 0.10, 0.16)
	if highlighted or selected:
		bg = bg.lightened(0.12)
	if is_dimmed:
		bg = bg.lerp(Color(0.4, 0.4, 0.42), 0.4)
	draw_rect(inner, bg, true, -1.0, true)
	var ink: Color = Color(0.98, 0.82, 0.28) if card.is_red() else Color(0.88, 0.88, 0.92)
	if is_dimmed:
		ink.a = 0.5
	var cx: Vector2 = inner.position + inner.size * 0.5
	var r: float = 10.0 * s
	var star: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var a: float = -PI * 0.5 + float(i) * PI / 5.0
		var rad: float = r if i % 2 == 0 else r * 0.42
		star.append(cx + Vector2(cos(a) * rad, sin(a) * rad))
	draw_colored_polygon(star, ink)
	draw_string(font, Vector2(rect.position.x, inner.position.y + 16.0 * s), "Jk", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(14, int(18.0 * s)), ink)
	var ribbon: Rect2 = Rect2(rect.position.x, rect.end.y - 16.0 * s, rect.size.x, 14.0 * s)
	draw_rect(ribbon, Color(0.55, 0.22, 0.72, 0.95), true)
	draw_string(font, Vector2(ribbon.position.x, ribbon.end.y - 3), "JOKER", HORIZONTAL_ALIGNMENT_CENTER, ribbon.size.x, int(10.0 * s), Color(1, 0.92, 0.55))

func _draw_buff_badge(font: Font, rect: Rect2, s: float, label: String, is_dimmed: bool) -> void:
	var badge_size: int = maxi(13, int(16.0 * s))
	if label.length() > 3:
		badge_size = maxi(9, int(11.0 * s))
	elif label.length() > 1:
		badge_size = maxi(11, int(13.0 * s))
	var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_size).x
	var pad: float = maxf(3.0, 4.0 * s)
	var bw: float = tw + pad * 2.0
	var bh: float = float(badge_size) + pad * 1.15
	var bx: float = rect.end.x - bw - 4.0
	var by: float = rect.position.y + 3.0
	var bsb: StyleBoxFlat = StyleBoxFlat.new()
	bsb.bg_color = Color(0.07, 0.36, 0.95, 0.55 if is_dimmed else 0.96)
	bsb.set_corner_radius_all(maxi(4, int(6.0 * s)))
	draw_style_box(bsb, Rect2(bx, by, bw, bh))
	var ink: Color = Color(1.0, 1.0, 1.0, 0.7 if is_dimmed else 1.0)
	draw_string(font, Vector2(bx, by + bh - pad * 0.3), label, HORIZONTAL_ALIGNMENT_CENTER, bw, badge_size, ink)

func _draw_back(sb: StyleBoxFlat, rect: Rect2) -> void:
	sb.bg_color = Color(0.10, 0.18, 0.36)
	sb.border_color = Color(0.85, 0.70, 0.28)
	sb.set_border_width_all(3)
	draw_style_box(sb, rect)
	var gold: Color = Color(0.85, 0.70, 0.28, 0.9)
	var cx: float = rect.position.x + rect.size.x * 0.5
	var base_y: float = rect.position.y + rect.size.y * 0.72
	var top_y: float = rect.position.y + rect.size.y * 0.28
	draw_rect(Rect2(rect.position.x + rect.size.x * 0.18, top_y, rect.size.x * 0.64, 8), gold)
	for i in range(4):
		var x: float = rect.position.x + rect.size.x * 0.24 + float(i) * rect.size.x * 0.14
		draw_rect(Rect2(x, top_y + 8, 7, base_y - top_y - 8), gold)
	draw_rect(Rect2(rect.position.x + rect.size.x * 0.16, base_y, rect.size.x * 0.68, 7), gold)
	draw_circle(Vector2(cx, top_y - 4), 4, gold)

func _draw_suit(center: Vector2, r: float, col: Color, suit: int) -> void:
	match suit:
		1:
			draw_circle(center + Vector2(-r * 0.45, -r * 0.25), r * 0.55, col)
			draw_circle(center + Vector2(r * 0.45, -r * 0.25), r * 0.55, col)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.95, -r * 0.05), center + Vector2(r * 0.95, -r * 0.05), center + Vector2(0, r * 1.05)]), col)
		2:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r), center + Vector2(r * 0.7, 0), center + Vector2(0, r), center + Vector2(-r * 0.7, 0)]), col)
		0:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r * 1.05), center + Vector2(r * 0.95, r * 0.15), center + Vector2(-r * 0.95, r * 0.15)]), col)
			draw_circle(center + Vector2(-r * 0.45, r * 0.22), r * 0.55, col)
			draw_circle(center + Vector2(r * 0.45, r * 0.22), r * 0.55, col)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.18, r * 0.55), center + Vector2(r * 0.18, r * 0.55), center + Vector2(r * 0.38, r * 1.05), center + Vector2(-r * 0.38, r * 1.05)]), col)
		3:
			draw_circle(center + Vector2(0, -r * 0.45), r * 0.58, col)
			draw_circle(center + Vector2(-r * 0.55, r * 0.3), r * 0.58, col)
			draw_circle(center + Vector2(r * 0.55, r * 0.3), r * 0.58, col)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.18, r * 0.35), center + Vector2(r * 0.18, r * 0.35), center + Vector2(r * 0.38, r * 1.05), center + Vector2(-r * 0.38, r * 1.05)]), col)
