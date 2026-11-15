class_name CardView
extends Control

## Code-drawn playing card. Presidential cream faces, column-back.

signal press_started(view: CardView, global_pos: Vector2)

const W: float = 70.0
const H: float = 98.0

var card: CardData = null
var placeholder_text: String = ""
var selected: bool = false
var dimmed: bool = false
var face_forced_down: bool = false

var display_size: Vector2 = Vector2(W, H)
var _last_processed_msec: int = 0

func _init(p_card: CardData = null, p_size: Vector2 = Vector2(W, H)) -> void:
	card = p_card
	set_display_size(p_size)
	mouse_filter = MOUSE_FILTER_STOP

func set_display_size(p_size: Vector2) -> void:
	display_size = p_size
	custom_minimum_size = p_size
	size = p_size
	queue_redraw()

func set_card(p_card: CardData) -> void:
	card = p_card
	queue_redraw()

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
	press_started.emit(self, get_global_mouse_position())

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
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
	sb.bg_color = Color(0.97, 0.95, 0.90)
	if selected:
		sb.border_color = Color(0.95, 0.75, 0.15)
		sb.set_border_width_all(4)
	else:
		sb.border_color = Color(0.18, 0.18, 0.22)
	draw_style_box(sb, rect)
	var col: Color = Color(0.72, 0.10, 0.12) if card.is_red() else Color(0.08, 0.10, 0.16)
	if dimmed:
		col.a = 0.4
	var s: float = clampf(size.x / W, 0.5, 1.2)
	var font: Font = get_theme_default_font()
	var label: String = RankSystem.short_label(card.rank)
	draw_string(font, Vector2(5, 20.0 * s), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18.0 * s), col)
	_draw_suit(Vector2(14.0 * s, 34.0 * s), 7.0 * s, col, card.suit)
	_draw_suit(Vector2(size.x * 0.5, size.y * 0.58), 16.0 * s, col, card.suit)
	if RankSystem.is_bomb(card.rank):
		draw_string(font, Vector2(3, size.y - 8), "BOMB", HORIZONTAL_ALIGNMENT_CENTER, size.x - 6.0, int(10.0 * s), Color(0.75, 0.12, 0.12))

func _draw_back(sb: StyleBoxFlat, rect: Rect2) -> void:
	sb.bg_color = Color(0.10, 0.18, 0.36)
	sb.border_color = Color(0.85, 0.70, 0.28)
	sb.set_border_width_all(3)
	draw_style_box(sb, rect)
	var gold: Color = Color(0.85, 0.70, 0.28, 0.9)
	# Four columns (White House-ish).
	var cx: float = size.x * 0.5
	var base_y: float = size.y * 0.72
	var top_y: float = size.y * 0.28
	draw_rect(Rect2(size.x * 0.18, top_y, size.x * 0.64, 8), gold)
	for i in range(4):
		var x: float = size.x * 0.24 + float(i) * size.x * 0.14
		draw_rect(Rect2(x, top_y + 8, 7, base_y - top_y - 8), gold)
	draw_rect(Rect2(size.x * 0.16, base_y, size.x * 0.68, 7), gold)
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
