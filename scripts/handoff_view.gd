class_name HandoffView
extends PanelContainer

## Full-screen "pass the device" gate so the next human does not see the last hand.

signal confirmed

var _body: Label
var _btn: Button
var _waiting: bool = false

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(0.04, 0.05, 0.10, 0.96)
	psb.border_color = Color(0.85, 0.70, 0.28)
	psb.set_border_width_all(0)
	add_theme_stylebox_override("panel", psb)
	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 24)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	m.add_child(v)
	var kicker: Label = Label.new()
	kicker.text = "PASS THE DEVICE"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 14)
	kicker.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35))
	v.add_child(kicker)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 26)
	_body.add_theme_color_override("font_color", Color(0.96, 0.93, 0.82))
	v.add_child(_body)
	_btn = Button.new()
	_btn.custom_minimum_size = Vector2(0, 56)
	_btn.pressed.connect(func() -> void:
		visible = false
		_waiting = false
		confirmed.emit()
	)
	v.add_child(_btn)

func ask(player_name: String) -> void:
	_body.text = "Hand the cabinet to\n%s" % player_name
	_btn.text = "I’m %s" % player_name
	visible = true
	_waiting = true
