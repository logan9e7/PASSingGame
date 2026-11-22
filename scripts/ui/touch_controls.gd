class_name TouchControls
extends Control

signal look_drag(relative: Vector2)
var direction := Vector2.ZERO
var enabled := false
var stick_id := -1
var look_id := -1
var center := Vector2.ZERO
var knob := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	var viewport_size := get_viewport_rect().size
	center = Vector2(110, viewport_size.y - 115)
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(center) < 90 and stick_id == -1:
				stick_id = event.index
				_update_stick(event.position)
				get_viewport().set_input_as_handled()
			elif event.position.x > viewport_size.x * 0.5 and event.position.y < viewport_size.y - 150 and look_id == -1:
				look_id = event.index
		else:
			if event.index == stick_id:
				stick_id = -1
				direction = Vector2.ZERO
				knob = Vector2.ZERO
			if event.index == look_id:
				look_id = -1
	if event is InputEventScreenDrag:
		if event.index == stick_id:
			_update_stick(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == look_id:
			look_drag.emit(event.relative)
			get_viewport().set_input_as_handled()
	queue_redraw()

func reset() -> void:
	direction = Vector2.ZERO
	knob = Vector2.ZERO
	stick_id = -1
	look_id = -1
	queue_redraw()

func _update_stick(at: Vector2) -> void:
	knob = (at - center).limit_length(58)
	direction = knob / 58.0

func _draw() -> void:
	if not enabled or not (DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")):
		return
	center = Vector2(110, get_viewport_rect().size.y - 115)
	draw_circle(center, 76, Color(0.08, 0.17, 0.17, 0.45))
	draw_arc(center, 76, 0, TAU, 48, Color(0.9, 0.96, 0.85, 0.6), 2, true)
	draw_circle(center + knob, 28, Color(0.9, 0.98, 0.72, 0.85))
