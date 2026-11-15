class_name CardView
extends Control

## A single card (or empty pile placeholder) drawn entirely with code:
## no textures or external assets. Emits `clicked` / `double_clicked`.

signal clicked(view: CardView)
signal double_clicked(view: CardView)

const W: float = 86.0
const H: float = 120.0

var card: CardData = null        # null = empty placeholder
var placeholder_text: String = ""
var placeholder_suit: int = -1
var rank_level: int = 1 # RunManager rank level, shown as pips/badge when > 1
var selected: bool = false
var dimmed: bool = false

var display_size: Vector2 = Vector2(W, H)
var _last_tap_msec: int = 0
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

## Handles mouse clicks AND raw screen touches. Project settings enable
## emulate-mouse-from-touch, so a touch can arrive as both event types;
## presses within 80 ms are de-duplicated. Double-tap is detected manually
## (<450 ms) in addition to the engine's double_click flag, because touch
## double-click reporting varies across phones / web browsers.
## No hover, drag-only, or right-click input is used anywhere in the game.
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
	if now - _last_tap_msec < 450:
		_last_tap_msec = 0
		double_clicked.emit(self)
	else:
		_last_tap_msec = now
		clicked.emit(self)

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	if card == null:
		sb.bg_color = Color(0, 0, 0, 0.25)
		sb.border_color = Color(0.85, 0.65, 0.20, 0.45)
		draw_style_box(sb, rect)
		if placeholder_suit >= 0:
			_draw_suit(Vector2(size.x * 0.5, size.y * 0.52), size.x * 0.16, Color(1, 1, 1, 0.55), placeholder_suit)
		if placeholder_text != "":
			var f: Font = get_theme_default_font()
			draw_string(f, Vector2(4, size.y * 0.55), placeholder_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8.0, int(clampf(13.0 * _scale(), 9.0, 13.0)), Color(1, 1, 1, 0.6))
		return
	if not card.face_up:
		# Stage-magic card back: midnight velvet, gold trim, top-hat + wand motif.
		sb.bg_color = Color(0.13, 0.07, 0.28)
		sb.border_color = Color(0.85, 0.65, 0.20)
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		draw_style_box(sb, rect)
		_draw_card_back_motif()
		return
	# Cream stage card face; ascended ranks get a lavender-velvet tint.
	sb.bg_color = Color(0.90, 0.84, 0.98) if RankSystem.tier(card.rank) == 2 else Color(0.98, 0.96, 0.88)
	if selected:
		sb.border_color = Color(1.0, 0.80, 0.15)
		sb.border_width_left = 4
		sb.border_width_right = 4
		sb.border_width_top = 4
		sb.border_width_bottom = 4
	elif card.enhancement != "":
		sb.border_color = EnhancementDB.border_color(card.enhancement)
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
	elif RankSystem.tier(card.rank) == 2:
		# Grand illusionists: dramatic deep-purple + gold double treatment.
		sb.border_color = Color(0.48, 0.16, 0.78)
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
	elif RankSystem.tier(card.rank) == 1:
		sb.border_color = Color(0.85, 0.65, 0.20)
	else:
		sb.border_color = Color(0.25, 0.25, 0.25)
	draw_style_box(sb, rect)
	var font: Font = get_theme_default_font()
	var col: Color = Color(0.75, 0.12, 0.12) if card.is_red() else Color(0.10, 0.10, 0.14)
	if dimmed:
		col.a = 0.45
	var s: float = _scale()
	var label: String = RankSystem.short_label(card.rank)
	var rank_size: int = int(clampf((20.0 if label.length() <= 2 else 14.0) * s, 10.0, 22.0))
	draw_string(font, Vector2(5, 24.0 * s), label, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_size, col)
	_draw_suit(Vector2(15.0 * s, 39.0 * s), 8.0 * s, col, card.suit)
	_draw_suit(Vector2(size.x * 0.5, size.y * 0.60), 19.0 * s, col, card.suit)
	if RankSystem.tier(card.rank) == 2:
		draw_string(font, Vector2(3, size.y - 6), RankSystem.full_name(card.rank), HORIZONTAL_ALIGNMENT_CENTER, size.x - 6.0, int(clampf(10.0 * s, 8.0, 11.0)), Color(0.42, 0.12, 0.68))
		# Sparkle accents for ascended (grand illusionist) ranks.
		_draw_star(Vector2(size.x * 0.82, size.y * 0.30), 5.0 * s, Color(0.85, 0.65, 0.20, 0.9))
		_draw_star(Vector2(size.x * 0.70, size.y * 0.42), 3.2 * s, Color(0.62, 0.30, 0.90, 0.8))
	elif RankSystem.tier(card.rank) == 1:
		draw_string(font, Vector2(3, size.y - 6), RankSystem.full_name(card.rank), HORIZONTAL_ALIGNMENT_CENTER, size.x - 6.0, int(clampf(10.0 * s, 8.0, 11.0)), Color(0.55, 0.38, 0.05))
	_draw_markers(s)

## Suits are drawn from circles/polygons (no font glyphs): the suit
## characters in the default font are missing in web exports and would
## render as boxes on phones/browsers.
func _draw_suit(center: Vector2, r: float, col: Color, suit: int) -> void:
	match suit:
		1: # Hearts: two lobes + downward point
			draw_circle(center + Vector2(-r * 0.45, -r * 0.25), r * 0.55, col)
			draw_circle(center + Vector2(r * 0.45, -r * 0.25), r * 0.55, col)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.95, -r * 0.05), center + Vector2(r * 0.95, -r * 0.05), center + Vector2(0, r * 1.05)]), col)
		2: # Diamonds
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r), center + Vector2(r * 0.7, 0), center + Vector2(0, r), center + Vector2(-r * 0.7, 0)]), col)
		0: # Spades: upward point + lobes + stem
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r * 1.05), center + Vector2(r * 0.95, r * 0.15), center + Vector2(-r * 0.95, r * 0.15)]), col)
			draw_circle(center + Vector2(-r * 0.45, r * 0.22), r * 0.55, col)
			draw_circle(center + Vector2(r * 0.45, r * 0.22), r * 0.55, col)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.18, r * 0.55), center + Vector2(r * 0.18, r * 0.55), center + Vector2(r * 0.38, r * 1.05), center + Vector2(-r * 0.38, r * 1.05)]), col)
		3: # Clubs: three lobes + stem
			draw_circle(center + Vector2(0, -r * 0.45), r * 0.58, col)
			draw_circle(center + Vector2(-r * 0.55, r * 0.3), r * 0.58, col)
			draw_circle(center + Vector2(r * 0.55, r * 0.3), r * 0.58, col)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.18, r * 0.35), center + Vector2(r * 0.18, r * 0.35), center + Vector2(r * 0.38, r * 1.05), center + Vector2(-r * 0.38, r * 1.05)]), col)

## Four-point stage sparkle (star) drawn as a polygon — no textures/fonts.
func _draw_star(center: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(8):
		var ang: float = -PI / 2.0 + float(i) * PI / 4.0
		var rad: float = r if i % 2 == 0 else r * 0.38
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, col)

## Card-back motif: top hat (crown + brim + gold band), a diagonal wand
## tipped with a star, and two sparkles. All primitive draws, no assets.
func _draw_card_back_motif() -> void:
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.46
	var w: float = size.x * 0.30
	var gold: Color = Color(0.85, 0.65, 0.20)
	var hat: Color = Color(0.05, 0.04, 0.10)
	# Wand, behind the hat: diagonal shaft + star tip.
	draw_line(Vector2(cx - w * 0.95, cy + w * 0.95), Vector2(cx + w * 0.85, cy - w * 0.85), Color(0.92, 0.88, 0.78), 2.5)
	_draw_star(Vector2(cx + w * 0.95, cy - w * 0.95), 6.0, gold)
	# Top hat crown + gold band + brim.
	draw_rect(Rect2(cx - w * 0.62, cy - w * 0.72, w * 1.24, w * 1.05), hat)
	draw_rect(Rect2(cx - w * 0.62, cy + w * 0.08, w * 1.24, w * 0.25), gold)
	draw_rect(Rect2(cx - w, cy + w * 0.33, w * 2.0, w * 0.20), hat)
	_draw_star(Vector2(size.x * 0.22, size.y * 0.20), 4.0, Color(1, 1, 1, 0.75))
	_draw_star(Vector2(size.x * 0.80, size.y * 0.76), 4.5, Color(1, 1, 1, 0.65))

func _draw_markers(s: float) -> void:
	if card == null or not card.face_up:
		return
	# Enhancement badge, top-right.
	if card.enhancement != "":
		var badge_col: Color = EnhancementDB.border_color(card.enhancement)
		var bw: float = 26.0 * s
		var badge: Rect2 = Rect2(size.x - bw - 4.0, 4.0, bw, 14.0 * s)
		var bsb: StyleBoxFlat = StyleBoxFlat.new()
		bsb.bg_color = badge_col
		bsb.corner_radius_top_left = 4
		bsb.corner_radius_top_right = 4
		bsb.corner_radius_bottom_left = 4
		bsb.corner_radius_bottom_right = 4
		draw_style_box(bsb, badge)
		var bf: Font = get_theme_default_font()
		draw_string(bf, Vector2(badge.position.x, badge.position.y + 11.0 * s), EnhancementDB.short_code(card.enhancement), HORIZONTAL_ALIGNMENT_CENTER, bw, int(clampf(10.0 * s, 8.0, 11.0)), Color(0, 0, 0, 0.85))
	# Rank-level pips + Lv badge, bottom strip (only when upgraded).
	if rank_level > 1:
		var pip_col: Color = Color(0.85, 0.60, 0.08)
		var n: int = mini(rank_level, 6)
		for i in range(n):
			draw_circle(Vector2(9.0 + float(i) * 9.0 * s, size.y - 14.0), 3.0 * s, pip_col)
		var lf: Font = get_theme_default_font()
		draw_string(lf, Vector2(size.x - 24.0, size.y - 10.0), "Lv%d" % rank_level, HORIZONTAL_ALIGNMENT_LEFT, -1, int(clampf(10.0 * s, 8.0, 11.0)), Color(0.45, 0.25, 0.65))

func _scale() -> float:
	return clampf(size.x / W, 0.45, 1.15)
