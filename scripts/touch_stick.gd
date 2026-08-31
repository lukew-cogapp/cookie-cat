extends Control
## A thumbstick for phones and tablets.
##
## Godot ships no virtual joystick, so this is one: touch anywhere, drag, and
## the cat walks that way. It is not a fixed pad in a corner, because a small
## thumb cannot find a fixed pad without looking, and looking away from the
## cat is what kills the run. The stick appears wherever the finger lands.
##
## Reported through `Input.action_press` rather than read by the player, so the
## cat's movement code stays one `get_vector` call and knows nothing about
## touch. That also means the keyboard and pad keep working while a finger is
## down, which matters on a tablet with a case keyboard.

## The four actions this drives, and the axis sign each one means.
const AXES := {
	"move_left": Vector2.LEFT,
	"move_right": Vector2.RIGHT,
	"move_up": Vector2.UP,
	"move_down": Vector2.DOWN,
}

## Which touch is steering. Godot reports every finger with an index, and a
## second finger must not steal the stick from the first.
var _finger := -1
var _origin := Vector2.ZERO
var _at := Vector2.ZERO
var _held := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Armed, but drawn nothing until a finger actually arrives.
	#
	# `is_touchscreen_available()` is not enough on its own: it reports true on
	# desktops with no touchscreen at all (godot#84235), so gating visibility on
	# it would put a thumbstick on a machine that can only use a keyboard. It is
	# also true on a touch-capable laptop whose owner is using the trackpad.
	#
	# So nothing is drawn until `InputEventScreenTouch` proves a real finger,
	# and `_draw` returns early while `_held` is false. A desktop player never
	# sees it; a tablet player sees it the moment they touch the screen. That
	# needs no platform check at all.
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1:
			_finger = touch.index
			_origin = touch.position
			_at = touch.position
			_held = true
			queue_redraw()
		elif not touch.pressed and touch.index == _finger:
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger:
			_at = drag.position
			queue_redraw()


## Runs while the tree is paused (`process_mode` in `world.tscn`), because a
## paused node stops processing with its actions still pressed and the cat would
## walk off on its own the moment the picker closed.
func _process(_delta: float) -> void:
	if get_tree().paused:
		if _held:
			_release()
		return
	if not _held:
		return
	var off := _at - _origin
	# A dead zone, or resting a thumb still counts as a direction.
	if off.length() < Tuning.TOUCH_DEADZONE:
		_clear_actions()
		return
	# Clamped to the stick's radius, then floored the same way the analogue
	# stick is: a short drag should walk at a useful speed, not creep.
	var dir: Vector2 = off.limit_length(Tuning.TOUCH_RADIUS) / Tuning.TOUCH_RADIUS
	if dir.length() < Tuning.STICK_WALK_FLOOR:
		dir = dir.normalized() * Tuning.STICK_WALK_FLOOR
	for action: String in AXES:
		var strength: float = dir.dot(AXES[action])
		if strength > 0.0:
			Input.action_press(action, strength)
		else:
			Input.action_release(action)


func _release() -> void:
	_finger = -1
	_held = false
	_clear_actions()
	queue_redraw()


func _clear_actions() -> void:
	for action: String in AXES:
		Input.action_release(action)


func _draw() -> void:
	if not _held:
		return
	var off := (_at - _origin).limit_length(Tuning.TOUCH_RADIUS)
	draw_circle(_origin, Tuning.TOUCH_RADIUS, Tuning.TOUCH_BASE_COLOUR)
	draw_circle(_origin, Tuning.TOUCH_RADIUS, Tuning.TOUCH_RING_COLOUR, false, 3.0, true)
	draw_circle(_origin + off, Tuning.TOUCH_KNOB_RADIUS, Tuning.TOUCH_KNOB_COLOUR)
