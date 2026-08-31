extends GutTest
## Breakable props: the scatter, the drops, and the same row bookkeeping the
## swarm needs.

var _props: Props


func before_each() -> void:
	_props = Props.new()
	add_child_autofree(_props)
	await wait_process_frames(1)
	_props.set_physics_process(false)
	_props.scatter(Vector2.ZERO)


func test_scatter_fills_the_lawn() -> void:
	assert_eq(_props.alive, Tuning.PROP_COUNT, "every prop was placed")


## Seeded, so a child who learns where the pots are finds them there again.
func test_the_garden_is_the_same_every_run() -> void:
	var first := _props.pos.slice(0, _props.alive)
	_props.scatter(Vector2.ZERO)
	assert_eq(_props.pos.slice(0, _props.alive), first, "the same layout")


## The cat is never walled in: being cornered against an invisible edge with
## bugs closing in is the one situation a child cannot escape.
func test_there_is_no_wall() -> void:
	assert_false(
		"WORLD_HALF" in Tuning,
		"nothing clamps the cat any more",
	)


## A prop on the starting spot would open the run in the player's face.
func test_nothing_spawns_on_the_cat() -> void:
	for i in _props.alive:
		assert_gt(
			_props.pos[i].length(),
			Tuning.PROP_CLEAR_RADIUS,
			"prop %d is clear of the start" % i,
		)


## The field is scattered around wherever the cat is, not around the origin,
## because there is no wall to bound it.
func test_props_land_in_the_field_around_the_cat() -> void:
	var here := Vector2(5000.0, -3000.0)
	_props.scatter(here)
	for i in _props.alive:
		var off := _props.pos[i] - here
		assert_lte(absf(off.x), Tuning.PROP_FIELD_HALF.x, "inside the field on x")
		assert_lte(absf(off.y), Tuning.PROP_FIELD_HALF.y, "inside the field on y")


## Walking back over old ground must find the same garden, not a fresh roll.
func test_the_same_spot_gives_the_same_garden() -> void:
	var here := Vector2(2400.0, 800.0)
	_props.scatter(here)
	var first := _props.pos.slice(0, _props.alive)
	_props.scatter(Vector2(-9000.0, 9000.0))
	_props.scatter(here)
	assert_eq(_props.pos.slice(0, _props.alive), first, "the same layout came back")


## The one thing the removed wall was hiding: walking in one direction forever
## has to keep finding garden.
func test_the_field_refills_as_the_cat_walks() -> void:
	_props.scatter(Vector2.ZERO)
	var near_edge := Vector2(Tuning.PROP_REFILL_DISTANCE + 200.0, 0.0)
	_props.scatter(near_edge)
	var ahead := 0
	for i in _props.alive:
		if _props.pos[i].x > near_edge.x:
			ahead += 1
	assert_gt(ahead, 0, "there is garden ahead of the cat")


## Two props on one spot read as one prop that takes twice the hits.
func test_props_are_spaced_apart() -> void:
	for i in _props.alive:
		for j in range(i + 1, _props.alive):
			assert_gte(
				_props.pos[i].distance_to(_props.pos[j]),
				Tuning.PROP_SPACING,
				"props %d and %d are apart" % [i, j],
			)


func test_damage_breaks_a_prop() -> void:
	var at := _props.pos[0]
	var before := _props.alive
	_props.damage_near(at, 5.0, 9999.0)
	_props._compact()
	assert_eq(_props.alive, before - 1, "one broke")


func test_a_scratch_does_not_break_it() -> void:
	var before := _props.alive
	_props.damage_near(_props.pos[0], 5.0, 0.5)
	_props._compact()
	assert_eq(_props.alive, before, "still standing")


## Two weapons landing on one prop in a frame queue it twice, and dropping it
## twice would delete a standing one.
func test_a_prop_queued_twice_removes_one_row() -> void:
	var at := _props.pos[0]
	var before := _props.alive
	_props.damage_near(at, 5.0, 9999.0)
	_props.damage_near(at, 5.0, 9999.0)
	_props._compact()
	assert_eq(_props.alive, before - 1, "queued twice, removed once")


func test_breaking_reports_where_and_what() -> void:
	var seen: Array[Vector2] = []
	_props.broke.connect(func(at: Vector2, _k: int) -> void: seen.append(at))
	var at := _props.pos[0]
	_props.damage_near(at, 5.0, 9999.0)
	assert_eq(seen, [at], "reported once, at the prop")


func test_damage_misses_props_out_of_range() -> void:
	var before := _props.alive
	_props.damage_near(Vector2(99999.0, 99999.0), 5.0, 9999.0)
	_props._compact()
	assert_eq(_props.alive, before, "nothing near, nothing broken")


## Drops must stay stingy: a heart from every prop makes hearts meaningless.
func test_most_props_drop_only_xp() -> void:
	for k in Tuning.PROPS.size():
		var d: Dictionary = Tuning.PROPS[k]
		var special := float(d["heart_chance"]) + float(d["cookie_chance"])
		assert_lt(special, 0.6, "%s usually drops plain xp" % d["name"])


func test_roll_drop_only_returns_real_kinds() -> void:
	for k in Tuning.PROPS.size():
		for _i in 40:
			var drop := _props.roll_drop(k)
			assert_true(
				drop in [Gems.Kind.GEM, Gems.Kind.HEART, Gems.Kind.COOKIE],
				"a real pickup kind",
			)


## Every prop needs art, or its MultiMesh draws nothing at all.
func test_every_prop_has_art() -> void:
	for k in Tuning.PROPS.size():
		assert_true(ResourceLoader.exists(String(Tuning.PROPS[k]["art"])), "art loads")


## A prop must take more than one hit of the opening weapon, or the lawn is
## cleared before the first wave lands.
func test_props_take_a_few_hits() -> void:
	var paw := Tuning.weapon_stat("paw", "damage", 1)
	for k in Tuning.PROPS.size():
		assert_gt(
			float(Tuning.PROPS[k]["hp"]),
			paw,
			"%s survives one swipe" % Tuning.PROPS[k]["name"],
		)
