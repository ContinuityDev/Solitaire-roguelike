class_name Shop
extends PanelContainer

## Between-rounds reward screen: pick 1 of 3 upgrades (or skip).
## Pure presentation: Main asks UpgradeDB for choices and handles the result.

signal choice_made(upgrade: Dictionary)
signal skipped

var _choices: Array = []
var _box: VBoxContainer = null
var _title: Label = null

func _ready() -> void:
	visible = false
	var panel_sb: StyleBoxFlat = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.13, 0.08, 0.30)
	panel_sb.border_color = Color(0.85, 0.65, 0.20)
	panel_sb.set_border_width_all(3)
	panel_sb.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", panel_sb)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	margin.add_child(_box)
	_title = Label.new()
	_title.text = "The Prop Table - the trick is done! Choose one prop:"
	_title.add_theme_color_override("font_color", Color(0.92, 0.74, 0.32))
	_title.add_theme_font_size_override("font_size", 24)
	_box.add_child(_title)

func present(choices: Array, context_text: String = "") -> void:
	_title.add_theme_font_size_override("font_size", 19 if get_viewport_rect().size.x < 500.0 else 24)
	_choices = choices
	# Remove old option buttons (keep the title at index 0).
	while _box.get_child_count() > 1:
		var child: Node = _box.get_child(1)
		_box.remove_child(child)
		child.queue_free()
	if context_text != "":
		var ctx: Label = Label.new()
		ctx.text = context_text
		ctx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(ctx)
	var btn_w: float = minf(520.0, maxf(260.0, get_viewport_rect().size.x - 48.0))
	for choice in choices:
		var b: Button = Button.new()
		b.text = "%s  %s\n%s" % [str(choice.get("icon", "")), str(choice.get("name", "?")), str(choice.get("desc", ""))]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(btn_w, 84)
		var captured: Dictionary = choice
		b.pressed.connect(func() -> void: _on_choice(captured))
		_box.add_child(b)
	var skip: Button = Button.new()
	skip.custom_minimum_size = Vector2(btn_w, 48)
	skip.text = "Skip (leave the prop table empty-handed)"
	skip.pressed.connect(func() -> void: visible = false; skipped.emit())
	_box.add_child(skip)
	visible = true

func _on_choice(choice: Dictionary) -> void:
	visible = false
	choice_made.emit(choice)
