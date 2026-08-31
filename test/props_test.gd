extends GutTest
## Breakable props: the seeded field, the drops, and the once-only break.
##
## Props are `Prop` nodes now, so there is no row bookkeeping left to pin. What
## replaces it is the thing that bookkeeping kept getting wrong: a pot reached by
## two weapons in one frame has to pay out exactly once.

var _props: Props


func before_each() -> void:
	Run.cat = Tuning.STARTER_CAT
	Run.map = Tuning.STARTER_MAP
	Run.start()
	_props = Props.new()
	add_child_autofree(_props)
	await wait_process_frames(1)
	_props.set_physics_process(false)
	_props.scatter(Vector2.ZERO)


func after_each() -> void:
	Run.alive = false


func _spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for n in _props.count():
		out.append(_props.at(n).position)
	return out


func test_scatter_fills_the_lawn() -> void:
	# Populated and under the ceiling, not exactly at it. How many pots land
	# depends on how far the scatter reaches, and PROP_COUNT is the limit a long
	# walk cannot exceed rather than a quota the field fills.
	assert_gt(_props.count(), 0, "the lawn has pots on it")
	assert_lte(_props.count(), Tuning.PROP_COUNT, "and never more than the cap")


## Seeded, so a child who learns where the pots are finds them there again. The
## kinds have to match too: the same spot growing a bush where the box was is the
## same broken promise as the spot moving.
func test_the_garden_is_the_same_every_run() -> void:
	var first := _spots()
	var kinds: Array[int] = []
	for n in _props.count():
		kinds.append(_props.at(n).kind)
	_props.scatter(Vector2.ZERO)
	assert_eq(_props.count(), first.size(), "the same number of props")
	assert_eq(_spots(), first, "the same layout")
	for n in _props.count():
		assert_eq(_props.at(n).kind, kinds[n], "prop %d is the same thing" % n)


## Walking away and back finds the same garden, which is the whole point of
## seeding a cell by its own coordinates. The re-scatter above never leaves the
## origin, so it passed while this did not: the count cap used to be checked
## inside the per-cell loop, and how much of a cell survived depended on how
## many cells had been filled before it.
func test_walking_away_and_back_finds_the_same_garden() -> void:
	var here := Vector2.ZERO
	# Compared as a set of positions: culling and refilling brings the same pots
	# back in a different tree order, and what must not change is which pots
	# exist, not the order the tree happens to hold them in.
	var before := {}
	for p: Vector2 in _spots():
		before[p] = true
	# Far enough to refill several times over, and back by a different route.
	for step in [Vector2(2600, 0), Vector2(0, 2600), Vector2(-2600, 0), Vector2(0, -2600)]:
		here += step
		_props._refill_around(here)
	var missing := 0
	for p: Vector2 in _spots():
		if not before.has(p):
			missing += 1
	assert_eq(missing, 0, "every pot is one that was there before")


## The cat is never walled in: being cornered against an invisible edge with
## bugs closing in is the one situation a child cannot escape.
func test_there_is_no_wall() -> void:
	assert_false(
		"WORLD_HALF" in Tuning,
		"nothing clamps the cat any more",
	)


## A prop on the starting spot would open the run in the player's face.
func test_nothing_spawns_on_the_cat() -> void:
	for n in _props.count():
		assert_gt(
			_props.at(n).position.length(),
			Tuning.PROP_CLEAR_RADIUS,
			"prop %d is clear of the start" % n,
		)


## Props are laid out on a fixed grid of cells, not a field that follows the
## cat, so scattering around a point fills the ground near it.
func test_props_land_near_the_cat() -> void:
	var here := Vector2(5000.0, -3000.0)
	_props.scatter(here)
	assert_gt(_props.count(), 0, "the ground around the cat was filled")
	var near := 0
	for n in _props.count():
		if _props.at(n).position.distance_to(here) < Tuning.PROP_REFILL_DISTANCE * 2.0:
			near += 1
	assert_eq(near, _props.count(), "and everything placed is within reach")


## Walking back over old ground must find the same garden, not a fresh roll.
func test_the_same_spot_gives_the_same_garden() -> void:
	var here := Vector2(2400.0, 800.0)
	_props.scatter(here)
	var first := _spots()
	_props.scatter(Vector2(-9000.0, 9000.0))
	_props.scatter(here)
	assert_eq(_spots(), first, "the same layout came back")


## And walking back without a fresh `scatter` in between, which is what actually
## happens in a run: the field refills around the cat every frame, and the cells
## it forgot on the way out have to come back the same.
func test_walking_out_and_back_finds_the_same_garden() -> void:
	var here := Vector2.ZERO
	var first := _spots()
	var away := Vector2(Tuning.PROP_FORGET_DISTANCE * 4.0, 0.0)
	_props._refill_around(away)
	assert_gt(_props.count(), 0, "there is garden out there too")
	_props._refill_around(here)
	assert_eq(_spots(), first, "and the old garden is unchanged")


## The one thing the removed wall was hiding: walking in one direction forever
## has to keep finding garden.
func test_the_field_refills_as_the_cat_walks() -> void:
	_props.scatter(Vector2.ZERO)
	var near_edge := Vector2(Tuning.PROP_REFILL_DISTANCE + 200.0, 0.0)
	_props.scatter(near_edge)
	var ahead := 0
	for n in _props.count():
		if _props.at(n).position.x > near_edge.x:
			ahead += 1
	assert_gt(ahead, 0, "there is garden ahead of the cat")


## A long walk must not grow the tree without bound: the cap is what the array
## version's `PROP_COUNT` was for, and nodes still have to honour it.
func test_a_long_walk_never_outgrows_the_cap() -> void:
	for step in 30:
		_props._refill_around(Vector2(float(step) * Tuning.PROP_CELL, 0.0))
		assert_lte(_props.count(), Tuning.PROP_COUNT, "step %d held the cap" % step)


## Props behind the cat are dropped from the tree, not merely left off screen, or
## a walk across the map leaks a node per pot.
##
## The bound is the cell reach, not `PROP_FORGET_DISTANCE`: `_cull_far` runs
## before the fill, so a prop placed in a corner cell this frame is further out
## than the forget distance and goes on the next refill. What must hold is that
## nothing survives from where the cat used to be.
func test_the_field_forgets_what_is_far_behind() -> void:
	var start := _spots()
	var away := Vector2(Tuning.PROP_FORGET_DISTANCE * 5.0, 0.0)
	_props._refill_around(away)
	for n in _props.count():
		assert_false(
			_props.at(n).position in start,
			"prop %d is not one the cat walked away from" % n,
		)
	var reach := ceil(Tuning.PROP_REFILL_DISTANCE / Tuning.PROP_CELL) + 1.0
	var bound := reach * Tuning.PROP_CELL * sqrt(2.0)
	for n in _props.count():
		assert_lte(
			_props.at(n).position.distance_to(away),
			bound,
			"prop %d is within a refill of the cat" % n,
		)


## Two props on one spot read as one prop that takes twice the hits.
func test_props_are_spaced_apart() -> void:
	for i in _props.count():
		for j in range(i + 1, _props.count()):
			assert_gte(
				_props.at(i).position.distance_to(_props.at(j).position),
				Tuning.PROP_SPACING,
				"props %d and %d are apart" % [i, j],
			)


func test_damage_breaks_a_prop() -> void:
	var at := _props.at(0).position
	var before := _props.count()
	_props.damage_near(at, 5.0, 9999.0)
	assert_eq(_props.count(), before - 1, "one broke")


func test_a_scratch_does_not_break_it() -> void:
	var before := _props.count()
	_props.damage_near(_props.at(0).position, 5.0, 0.5)
	assert_eq(_props.count(), before, "still standing")


## The bug this refactor was for. Two weapons landing on one prop in a frame both
## reach it, and the second must find nothing left to break: the array version
## kept the row until `_compact` ran, so it broke it twice and dropped its reward
## twice.
func test_a_prop_reached_twice_breaks_once() -> void:
	var seen: Array[Vector2] = []
	_props.broke.connect(func(at: Vector2, _k: int) -> void: seen.append(at))
	var at := _props.at(0).position
	var before := _props.count()
	_props.damage_near(at, 5.0, 9999.0)
	_props.damage_near(at, 5.0, 9999.0)
	assert_eq(_props.count(), before - 1, "hit twice, gone once")
	assert_eq(seen.size(), 1, "and it paid out once")


## The same again with the two hits inside ONE call, which is what an area of
## effect wide enough to cover two pots does: every prop in reach still gets
## exactly one break each, and none is skipped because an earlier one was freed.
func test_one_wide_hit_breaks_everything_in_reach_once_each() -> void:
	var seen: Array[Vector2] = []
	_props.broke.connect(func(at: Vector2, _k: int) -> void: seen.append(at))
	var here := _props.at(0).position
	var reach := Tuning.PROP_SPACING * 3.0
	var expected := 0
	for n in _props.count():
		if _props.at(n).position.distance_to(here) <= reach:
			expected += 1
	assert_gt(expected, 1, "the hit covers more than one prop")
	var before := _props.count()
	_props.damage_near(here, reach, 9999.0)
	assert_eq(seen.size(), expected, "every prop in reach paid out once")
	assert_eq(_props.count(), before - expected, "and every one of them is gone")


func test_breaking_reports_where_and_what() -> void:
	var seen: Array[Vector2] = []
	var kinds: Array[int] = []
	_props.broke.connect(
		func(at: Vector2, k: int) -> void:
			seen.append(at)
			kinds.append(k)
	)
	var prop := _props.at(0)
	var at := prop.position
	var kind := prop.kind
	_props.damage_near(at, 5.0, 9999.0)
	assert_eq(seen, [at], "reported once, at the prop")
	assert_eq(kinds, [kind], "and said which kind it was")


func test_damage_misses_props_out_of_range() -> void:
	var before := _props.count()
	_props.damage_near(Vector2(99999.0, 99999.0), 5.0, 9999.0)
	assert_eq(_props.count(), before, "nothing near, nothing broken")


## Weapons fall back to the nearest prop when no bug is in range, and get the
## prop itself: an index into a list of children stops being true the moment one
## is freed.
func test_nearest_hands_back_the_prop_itself() -> void:
	var prop := _props.at(0)
	var found := _props.nearest(prop.position, Tuning.PROP_SPACING * 0.5)
	assert_eq(found, prop, "the prop beside the point")


func test_nearest_finds_nothing_in_empty_grass() -> void:
	var found := _props.nearest(Vector2(99999.0, 99999.0), 20.0)
	assert_null(found, "no pot out there to aim at")


## Drops must stay stingy: a heart from every prop makes hearts meaningless.
func test_most_props_drop_only_xp() -> void:
	for d: Dictionary in _props._table:
		var special := float(d["heart_chance"]) + float(d["cookie_chance"])
		assert_lt(special, 0.6, "%s usually drops plain xp" % d["name"])


func test_roll_drop_only_returns_real_kinds() -> void:
	for k in _props._table.size():
		for _i in 40:
			var drop := _props.roll_drop(k)
			assert_true(
				drop in [Gems.Kind.GEM, Gems.Kind.HEART, Gems.Kind.COOKIE],
				"a real pickup kind",
			)


## Every prop needs art, or its sprite draws nothing at all.
func test_every_prop_has_art() -> void:
	for d: Dictionary in _props._table:
		assert_true(ResourceLoader.exists(String(d["art"])), "art loads")


## A prop must take more than one hit of the opening weapon, or the lawn is
## cleared before the first wave lands.
func test_props_take_a_few_hits() -> void:
	var paw := Tuning.weapon_stat("paw", "damage", 1)
	for d: Dictionary in _props._table:
		assert_gt(float(d["hp"]), paw, "%s survives one swipe" % d["name"])


## Continuous damage must not pin a prop white. An aura or a puddle hits every
## frame, and refreshing the flash each time held a pot permanently white: bugs
## never showed it because they die in a second, but a pot outlives its own flash
## many times over.
func test_continuous_damage_does_not_pin_the_flash() -> void:
	var prop := _props.at(0)
	prop.hp = 9999.0
	prop.flash = -Tuning.HIT_FLASH_GAP
	_props.damage_near(prop.position, 6.0, 0.1)
	assert_gt(prop.flash, 0.0, "the first hit flashes")
	# Damage first, then run the timer down, which is the real frame order: the
	# guard only refuses a re-flash while one is still running.
	var lit := 0
	var frames := 40
	for _frame in frames:
		_props.damage_near(prop.position, 6.0, 0.1)
		prop.tick(0.02)
		if prop.flash > 0.0:
			lit += 1
	assert_lt(lit, frames, "the flash is allowed to end")
	# And the quiet gap is long enough to be seen as a gap, not a flicker: a pot
	# lit most of the time reads as solid white, which is the bug.
	assert_lt(
		float(lit) / float(frames),
		0.5,
		"it is dark more of the time than it is lit",
	)


## The gap is enforced, not merely a refusal to refresh a running flash. A hit
## landing the frame after one ends must not re-light it.
func test_the_flash_gap_is_enforced() -> void:
	var prop := _props.at(0)
	prop.hp = 9999.0
	prop.flash = -Tuning.HIT_FLASH_GAP
	assert_false(prop.damage(0.1), "a scratch does not break it")
	assert_gt(prop.flash, 0.0, "and it flashes")
	# Run just past the end of the flash, still inside the gap.
	prop.tick(Tuning.HIT_FLASH_TIME + Tuning.HIT_FLASH_GAP * 0.5)
	assert_lt(prop.flash, 0.0, "the flash is over")
	prop.damage(0.1)
	assert_lt(prop.flash, 0.0, "and the next hit does not re-light it")
	# Past the whole gap it may flash again, or a pot under a puddle never
	# flashes at all.
	prop.tick(Tuning.HIT_FLASH_GAP)
	prop.damage(0.1)
	assert_gt(prop.flash, 0.0, "past the gap it flashes again")


## `Prop.damage` reports the break once and only once, whoever asks again.
func test_a_broken_prop_cannot_be_broken_again() -> void:
	var prop := _props.at(0)
	assert_true(prop.damage(9999.0), "the hit that broke it said so")
	assert_false(prop.damage(9999.0), "and the next one did not")
