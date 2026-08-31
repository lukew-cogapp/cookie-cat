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


## A card drawn off the edge is a choice the child cannot see. The hat strip was
## hand-placed for the 1280 design and the Crown card fell off the right of a
## 4:3 window, which no test noticed and a screenshot did.
##
## `_relayout` takes the width, so both a phone's 1600 units and a 4:3 window's
## 960 are checked here rather than only whatever size the harness happens to
## run at.
func test_every_card_is_on_screen_at_any_width() -> void:
	for width: float in [1680.0, 1600.0, 1280.0, 960.0, 900.0]:
		_start._relayout(width)
		await wait_process_frames(2)
		# The strip only. Everything else is centre-anchored against the real
		# viewport, so a hypothetical width says nothing about where it sits: a
		# cat card measured at 1280 is not off screen because 960 was asked
		# about. The strip is the thing `_relayout` actually places.
		var centre := get_viewport().get_visible_rect().size.x * 0.5
		for group: String in ["Maps", "Hats"]:
			var g: Control = _start.get_node(group)
			for b: Node in g.get_children():
				var r := (b as Control).get_global_rect()
				# Back to strip coordinates: measured from the screen centre,
				# which is what the container is anchored to.
				var from_centre := r.position.x - centre
				assert_gte(
					from_centre, -width * 0.5,
					"%s's card starts on screen at %d wide" % [group, width],
				)
				assert_lte(
					from_centre + r.size.x, width * 0.5,
					"%s's card ends on screen at %d wide" % [group, width],
				)


## The two groups must not run into each other either, or the strip reads as one
## row of eight rather than two things to choose from.
func test_the_map_and_hat_groups_stay_apart() -> void:
	for width: float in [1600.0, 1280.0, 960.0]:
		_start._relayout(width)
		await wait_process_frames(2)
		# The last map card against the first hat card, not the containers: a
		# container keeps the width the scene gave it and only its children are
		# where the cards actually are.
		var maps: Control = _start.get_node("Maps")
		var hats: Control = _start.get_node("Hats")
		var last_map: Control = maps.get_child(maps.get_child_count() - 1)
		var first_hat: Control = hats.get_child(0)
		assert_lte(
			last_map.get_global_rect().end.x,
			first_hat.get_global_rect().position.x,
			"the groups do not overlap at %d wide" % width,
		)


func _focusable(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button and (child as Button).visible:
			out.append(child as Button)
		out.append_array(_focusable(child))
	return out
