extends GutTest
## The bindings a child actually reaches for.
##
## A pad with a dead D-pad is indistinguishable from a broken game to a
## five-year-old, and an input map is one of the few things in a Godot project
## that can be wrong without anything failing to load.

const DPAD := {"move_up": 11, "move_down": 12, "move_left": 13, "move_right": 14}


func _events(action: String) -> Array[InputEvent]:
	return InputMap.action_get_events(action)


func _has_button(action: String, index: int) -> bool:
	for e: InputEvent in _events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == index:
			return true
	return false


func _has_axis(action: String, axis: int, sign_of: float) -> bool:
	for e: InputEvent in _events(action):
		if e is InputEventJoypadMotion:
			var m := e as InputEventJoypadMotion
			if m.axis == axis and signf(m.axis_value) == sign_of:
				return true
	return false


func _has_key(action: String) -> bool:
	for e: InputEvent in _events(action):
		if e is InputEventKey:
			return true
	return false


func test_every_action_exists() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "confirm", "cancel", "pause"]:
		assert_true(InputMap.has_action(action), "%s is bound" % action)


func test_moving_works_on_the_dpad() -> void:
	for action: String in DPAD:
		assert_true(_has_button(action, DPAD[action]), "%s is on the D-pad" % action)


func test_moving_works_on_the_stick() -> void:
	assert_true(_has_axis("move_left", JOY_AXIS_LEFT_X, -1.0), "left")
	assert_true(_has_axis("move_right", JOY_AXIS_LEFT_X, 1.0), "right")
	assert_true(_has_axis("move_up", JOY_AXIS_LEFT_Y, -1.0), "up")
	assert_true(_has_axis("move_down", JOY_AXIS_LEFT_Y, 1.0), "down")


func test_moving_works_on_the_keyboard() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		assert_true(_has_key(action), "%s has a key" % action)


## A is confirm and B is cancel, the way every other console game does it: a
## child who has used one pad already knows this.
func test_confirm_and_cancel_are_a_and_b() -> void:
	assert_true(_has_button("confirm", JOY_BUTTON_A), "A confirms")
	assert_true(_has_button("cancel", JOY_BUTTON_B), "B cancels")


func test_pause_is_on_start() -> void:
	assert_true(_has_button("pause", JOY_BUTTON_START), "Start pauses")


## Confirm has to work from the keyboard too, since the picker's default focus
## is what makes mashing one key enough to play.
func test_confirm_has_a_key() -> void:
	assert_true(_has_key("confirm"), "space or enter confirms")


## Half the stick's travel doing nothing is the default, and it feels broken to
## a thumb that cannot push far.
func test_the_stick_deadzone_is_small() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		assert_lte(
			InputMap.action_get_deadzone(action),
			0.25,
			"%s responds to a light push" % action,
		)


## A light push must still outrun every bug, or walking gently is a trap.
func test_the_slowest_walk_still_escapes() -> void:
	var slowest := Tuning.PLAYER_SPEED * Tuning.STICK_WALK_FLOOR
	for kind in Tuning.ENEMIES.size():
		assert_lt(
			Tuning.enemy_speed(kind),
			slowest,
			"a gentle push outruns the %s" % Tuning.ENEMIES[kind]["name"],
		)


## Menus must answer to the same keys the cat does. Declaring a `ui_*` action
## REPLACES Godot's built-in events rather than adding to them, so the arrows,
## the stick and the D-pad all have to be restated or they stop working the
## moment WASD is added.
func test_menus_take_wasd_and_everything_else() -> void:
	var letters := {"ui_left": KEY_A, "ui_right": KEY_D, "ui_up": KEY_W, "ui_down": KEY_S}
	var arrows := {
		"ui_left": KEY_LEFT, "ui_right": KEY_RIGHT, "ui_up": KEY_UP, "ui_down": KEY_DOWN,
	}
	var pad := {
		"ui_left": JOY_BUTTON_DPAD_LEFT,
		"ui_right": JOY_BUTTON_DPAD_RIGHT,
		"ui_up": JOY_BUTTON_DPAD_UP,
		"ui_down": JOY_BUTTON_DPAD_DOWN,
	}
	for action: String in letters:
		assert_true(_has_physical_key(action, letters[action]), "%s takes its letter" % action)
		assert_true(_has_physical_key(action, arrows[action]), "%s takes its arrow" % action)
		assert_true(_has_button(action, pad[action]), "%s takes the D-pad" % action)
		var sticks := 0
		for e: InputEvent in _events(action):
			if e is InputEventJoypadMotion:
				sticks += 1
		assert_gt(sticks, 0, "%s takes the stick" % action)


func _has_physical_key(action: String, code: int) -> bool:
	for e: InputEvent in _events(action):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == code:
			return true
	return false
