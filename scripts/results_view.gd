class_name ResultsView
extends PanelContainer

## Post-round standings with roles, HP, gold, tribute preview, and game-over.

signal continued
signal used_action(id: String)
signal rematch
signal title_pressed

var _title: Label
var _body: VBoxContainer
var _preview: Label
var _log: Label
var _action_row: HFlowContainer
var _continue_btn: Button
var _title_btn: Button
var _mode: String = "round"

func _ready() -> void:
	visible = false
	var panel_sb: StyleBoxFlat = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.07, 0.10, 0.20)
	panel_sb.border_color = Color(0.85, 0.70, 0.28)
	panel_sb.set_border_width_all(3)
	panel_sb.set_corner_radius_all(12)
	add_theme_stylebox_override("panel", panel_sb)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 220)
	outer.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_preview = Label.new()
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.add_theme_font_size_override("font_size", 13)
	_preview.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	outer.add_child(_preview)
	_log = Label.new()
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.add_theme_font_size_override("font_size", 12)
	_log.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	outer.add_child(_log)
	_action_row = HFlowContainer.new()
	_action_row.add_theme_constant_override("h_separation", 8)
	_action_row.add_theme_constant_override("v_separation", 6)
	outer.add_child(_action_row)
	_continue_btn = Button.new()
	_continue_btn.custom_minimum_size = Vector2(0, 52)
	_continue_btn.pressed.connect(_on_continue)
	outer.add_child(_continue_btn)
	_title_btn = Button.new()
	_title_btn.text = "Title"
	_title_btn.custom_minimum_size = Vector2(0, 44)
	_title_btn.visible = false
	_title_btn.pressed.connect(func() -> void: visible = false; title_pressed.emit())
	outer.add_child(_title_btn)

func present_round(title_text: String, rows: Array, preview: String, log_text: String, action_ids: Array) -> void:
	_mode = "round"
	_title.text = title_text
	_preview.text = preview
	_log.text = log_text
	_continue_btn.text = "Continue"
	if _title_btn:
		_title_btn.visible = false
	_fill_rows(rows)
	_fill_actions(action_ids)
	_size_to_view()
	visible = true

func present_game_over(title_text: String, rows: Array, body: String) -> void:
	_mode = "over"
	_title.text = title_text
	_preview.text = body
	_log.text = ""
	_continue_btn.text = "New Run"
	if _title_btn:
		_title_btn.visible = true
	_fill_rows(rows)
	_fill_actions([])
	_size_to_view()
	visible = true

func _size_to_view() -> void:
	var vp: Vector2 = get_viewport_rect().size
	custom_minimum_size = Vector2(minf(520.0, maxf(280.0, vp.x - 28.0)), minf(680.0, maxf(360.0, vp.y - 70.0)))

func _fill_rows(rows: Array) -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	for r in rows:
		var d: Dictionary = r
		var wrap: PanelContainer = PanelContainer.new()
		var psb: StyleBoxFlat = StyleBoxFlat.new()
		psb.bg_color = Color(0.11, 0.14, 0.22)
		psb.set_corner_radius_all(6)
		var role: String = str(d.get("role", ""))
		if role == RoleTrade.ROLE_PRES:
			psb.border_color = Color(0.92, 0.78, 0.35)
			psb.set_border_width_all(2)
		elif role == RoleTrade.ROLE_SCUM:
			psb.border_color = Color(0.72, 0.22, 0.22)
			psb.set_border_width_all(2)
		else:
			psb.border_color = Color(0.40, 0.44, 0.55, 0.5)
			psb.set_border_width_all(1)
		wrap.add_theme_stylebox_override("panel", psb)
		var m: MarginContainer = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 8)
		m.add_theme_constant_override("margin_right", 8)
		m.add_theme_constant_override("margin_top", 6)
		m.add_theme_constant_override("margin_bottom", 6)
		wrap.add_child(m)
		var lab: Label = Label.new()
		var gold_bit: String = "   +$%d" % int(d["gold"]) if int(d.get("gold", 0)) > 0 else ""
		var hp_d: int = int(d.get("hp_delta", 0))
		var streak: int = int(d.get("streak", 1))
		var bonus: int = int(d.get("streak_bonus", 0))
		var streak_bit: String = ""
		if streak >= 1 and role != "":
			streak_bit = " ×%d" % streak
		if bonus > 0:
			streak_bit += " · streak bonus +%d" % bonus
		lab.text = "%d.  %s    %s%s    HP %+d%s" % [
			int(d.get("place", 0)), str(d.get("name", "?")), role, streak_bit, hp_d, gold_bit]
		lab.add_theme_font_size_override("font_size", 14)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if int(d.get("seat", -1)) == 0:
			lab.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		m.add_child(lab)
		_body.add_child(wrap)

func _fill_actions(ids: Array) -> void:
	for c in _action_row.get_children():
		_action_row.remove_child(c)
		c.queue_free()
	for id in ids:
		var info: Dictionary = ActionDB.get_by_id(str(id))
		var b: Button = Button.new()
		b.text = str(info.get("name", id))
		b.custom_minimum_size = Vector2(0, 44)
		var cap: String = str(id)
		b.pressed.connect(func() -> void: used_action.emit(cap))
		_action_row.add_child(b)

func _on_continue() -> void:
	visible = false
	if _mode == "over":
		rematch.emit()
	else:
		continued.emit()
