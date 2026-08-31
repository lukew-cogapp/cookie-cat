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


## A prop on the starting spot would open the run in the player's face.
func test_nothing_spawns_on_the_cat() -> void:
	for i in _props.alive:
		assert_gt(
			_props.pos[i].length(),
			Tuning.PROP_CLEAR_RADIUS,
			"prop %d is clear of the start" % i,
		)


func test_props_stay_inside_the_world() -> void:
	for i in _props.alive:
		assert_lte(absf(_props.pos[i].x), Tuning.WORLD_HALF.x, "inside on x")
		assert_lte(absf(_props.pos[i].y), Tuning.WORLD_HALF.y, "inside on y")


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
