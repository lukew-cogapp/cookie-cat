extends GutTest
## Holes in the ground: the field, and the rules that keep a half-the-bar hazard
## fair.

var _traps: Traps


func before_each() -> void:
	Run.cat = Tuning.STARTER_CAT
	Run.map = Tuning.STARTER_MAP
	Run.start()
	_traps = Traps.new()
	add_child_autofree(_traps)
	await wait_process_frames(1)
	_traps.set_physics_process(false)
	_traps.scatter(Vector2.ZERO)


func after_each() -> void:
	Run.alive = false


## Seeded by cell, so a child who learns where the pond is finds it there again.
func test_the_field_is_the_same_every_run() -> void:
	var first: Array[Vector2] = []
	for i in _traps.alive:
		first.append(_traps.pos[i])
	_traps.scatter(Vector2.ZERO)
	assert_eq(_traps.alive, first.size(), "the same number of holes")
	for i in _traps.alive:
		assert_eq(_traps.pos[i], first[i], "hole %d is where it was" % i)


## The opening seconds must not put half the bar's worth of damage where the
## child is about to walk.
func test_no_trap_opens_under_the_cat() -> void:
	for i in _traps.alive:
		assert_gt(
			_traps.pos[i].distance_to(Vector2.ZERO),
			Tuning.TRAP_CLEAR_RADIUS,
			"hole %d clears the start" % i,
		)


## Two overlapping holes read as one, and the cat has to be able to walk
## between them.
func test_holes_are_far_enough_apart_to_walk_between() -> void:
	for i in _traps.alive:
		for j in range(i + 1, _traps.alive):
			assert_gt(
				_traps.pos[i].distance_to(_traps.pos[j]),
				Tuning.TRAP_SPACING,
				"holes %d and %d are apart" % [i, j],
			)
	# And the gap left over is wider than the cat.
	assert_gt(
		Tuning.TRAP_SPACING - Tuning.TRAP_RADIUS * 2.0,
		Tuning.PLAYER_RADIUS * 2.0,
		"the cat fits between two holes",
	)


## The rim is not the hole. Clipping the edge at a run should cost nothing,
## because a child cannot steer precisely.
func test_the_rim_does_not_bite() -> void:
	assert_lt(Tuning.TRAP_BITE, 1.0, "the biting circle is inside the sprite")
	var at: Vector2 = _traps.pos[0]
	var bite: float = Tuning.TRAP_RADIUS * Tuning.TRAP_BITE
	assert_eq(_traps._at(at), 0, "the middle bites")
	assert_eq(
		_traps._at(at + Vector2(Tuning.TRAP_RADIUS * 0.99, 0.0)),
		-1,
		"the rim does not",
	)
	assert_eq(_traps._at(at + Vector2(bite * 0.5, 0.0)), 0, "well inside still bites")


## Half the bar, and lethal from half health down. This is the whole design of
## the trap, so it is pinned rather than left to the constant.
func test_a_trap_is_half_the_bar_and_lethal_below_half() -> void:
	assert_eq(Tuning.TRAP_DAMAGE, Tuning.PLAYER_MAX_HP * 0.5, "half the bar")
	assert_true(
		Tuning.PLAYER_MAX_HP * 0.5 - Tuning.TRAP_DAMAGE <= 0.0,
		"so entering one at half health empties it",
	)


## One hole cannot land three hits while the cat climbs out of it.
func test_a_hole_cannot_bite_every_frame() -> void:
	assert_gt(Tuning.TRAP_COOLDOWN, 0.0, "a hole waits before biting again")
	assert_gt(
		Tuning.TRAP_COOLDOWN,
		Tuning.PLAYER_MERCY_TIME * 0.5,
		"and the wait is not swallowed by mercy time",
	)


## Sparse enough that every direction is still walkable. A minefield takes away
## the one answer a child has, which is to walk somewhere else.
func test_the_ground_stays_walkable() -> void:
	assert_eq(Tuning.TRAP_PER_CELL, 1, "one hole per cell")
	var cell := Tuning.TRAP_CELL
	var covered := PI * Tuning.TRAP_RADIUS * Tuning.TRAP_RADIUS * float(Tuning.TRAP_PER_CELL)
	assert_lt(covered / (cell * cell), 0.05, "holes cover a twentieth of the ground at most")
	# And at least one is usually in view, or the hazard never teaches anything.
	var seen := (1280.0 / Tuning.ZOOM) * (720.0 / Tuning.ZOOM) / (cell * cell)
	assert_gt(seen, 1.0, "a hole is normally on screen")
	assert_lt(seen, 4.0, "but the screen is not a minefield")


## Every map needs its own hole, or a map loads with no trap art at all.
func test_every_map_has_a_trap() -> void:
	for id: String in Tuning.MAPS:
		var m: Dictionary = Tuning.MAPS[id]
		assert_true(m.has("trap"), "%s names a trap" % id)
		assert_true(
			ResourceLoader.exists(String(m["trap"])),
			"%s's trap art exists" % id,
		)
