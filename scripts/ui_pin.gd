class_name UiPin
extends Object

## Pin a Control to its parent’s full rect. `set_anchors_preset(FULL_RECT)`
## alone leaves a code-created Control at min-size, so the title menu was
## only as big as its buttons and the table showed through.

static func full_rect(c: Control) -> void:
	if c == null:
		return
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
