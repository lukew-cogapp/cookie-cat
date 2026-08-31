extends GutTest
## The front door. Mostly pictures, so what is worth pinning is the wiring:
## which buttons exist, and that a gamepad can reach all of them.

var _start: Control


func before_each() -> void:
	Run.cat = Tuning.STARTER_CAT
	Run.map = Tuning.STARTER_MAP
	_start = load("res://scenes/start_screen.tscn").instantiate()
	add_child_autofree(_start)
	await wait_process_frames(2)


## A desktop player needs a way out that is not the window's close box, and it
## has to be able to hold focus like everything else on this screen.
func test_the_quit_button_is_there_and_reachable() -> void:
	var quit: Button = _start.get_node("Quit")
	assert_not_null(quit, "the start screen has a quit button")
	assert_eq(quit.visible, OS.get_name() != "Web", "shown everywhere but the web")
	if quit.visible:
		assert_ne(quit.focus_mode, Control.FOCUS_NONE, "and it can take focus")


## Every focus neighbour has to land on something a player can actually focus.
## A neighbour pointing at a hidden button is the dead end `_wire_focus` exists
## to prevent, and hiding Quit on the web is exactly how one could appear.
func test_no_focus_neighbour_is_a_dead_end() -> void:
	for b: Button in _focusable(_start):
		for path: NodePath in [
			b.focus_neighbor_top,
			b.focus_neighbor_bottom,
			b.focus_neighbor_left,
			b.focus_neighbor_right,
		]:
			if path.is_empty():
				continue
			var target: Node = b.get_node_or_null(path)
			assert_not_null(target, "%s's neighbour %s exists" % [b.name, path])
			if target is Control:
				assert_true(
					(target as Control).visible,
					"%s's neighbour %s is visible" % [b.name, path],
				)


## Play must hold focus from the first frame, so one confirm press starts a run
## without a child having to aim at anything.
func test_play_holds_focus_from_the_start() -> void:
	var play: Button = _start.get_node("Play")
	assert_true(play.has_focus(), "Play is focused when the screen opens")


func _focusable(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button and (child as Button).visible:
			out.append(child as Button)
		out.append_array(_focusable(child))
	return out
