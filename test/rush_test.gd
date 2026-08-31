extends GutTest
## The rush: a pack of the weakest bug, hurrying in from one side.
##
## Like `tuning_test.gd`, most of these pin properties rather than values. A
## rush is the one thing in the game that spawns a crowd at once and moves it
## faster than its kind walks, so the rules it must not break are the two the
## whole difficulty rests on: nothing outruns the cat, and nothing arrives
## unannounced.

var _swarm: Swarm
var _director: Director
var _player: Node2D
var _run: Node


func before_each() -> void:
	_run = get_tree().get_root().get_node("Run")
	_swarm = Swarm.new()
	add_child_autofree(_swarm)
	_player = Node2D.new()
	add_child_autofree(_player)
	_director = Director.new()
	add_child_autofree(_director)
	await wait_process_frames(1)
	# Both are driven by hand here, or every step happens twice.
	_swarm.set_physics_process(false)
	_director.set_physics_process(false)
	_swarm.set_player(_player)
	_director.setup(_swarm, _player)
	_run.start()


func after_each() -> void:
	_run.clock = 0.0


## Runs the director for `secs` of clock at 60Hz, collecting the spots it
## announces rushes at. Stops once `stop_after` packs have landed, so a test
## reading positions sees one pack and not three overlaid.
func _run_clock(secs: float, announced: Array, stop_after := 0) -> void:
	var delta := 1.0 / 60.0
	_director.rush_arrived.connect(func(at: Vector2) -> void: announced.append(at))
	var steps := int(secs / delta)
	for _n in steps:
		_run.clock += delta
		_director._physics_process(delta)
		if stop_after > 0 and announced.size() >= stop_after and _director._rush_in < 0.0:
			return


## The rule everything else rests on. A rusher walks its kind's speed times the
## hurry, so it is the product that has to stay under the cat.
func test_a_rush_cannot_outrun_the_cat() -> void:
	var rushing := Tuning.enemy_speed(Tuning.RUSH_KIND) * Tuning.RUSH_HURRY
	assert_lt(rushing, Tuning.PLAYER_SPEED, "a hurrying bug is still slower than the cat")


## And a light analogue push has to clear it too, or a child who is moving is
## caught anyway.
func test_the_slowest_walk_still_escapes_a_rush() -> void:
	var rushing := Tuning.enemy_speed(Tuning.RUSH_KIND) * Tuning.RUSH_HURRY
	assert_lt(
		rushing,
		Tuning.PLAYER_SPEED * Tuning.STICK_WALK_FLOOR,
		"the floored stick walk outpaces a rush",
	)


## A rush is only a rush if it is quicker than the same bug arriving normally.
func test_a_rush_is_faster_than_the_same_bug_walking_in() -> void:
	assert_gt(Tuning.RUSH_HURRY, 1.0, "the pack hurries")


## The weakest kind, because the threat is the shape it arrives in and not the
## bug. Anything tougher would be a wave, or a boss.
func test_a_rush_is_made_of_the_weakest_bug() -> void:
	for kind in Tuning.ENEMIES.size():
		assert_lte(
			float(Tuning.ENEMIES[Tuning.RUSH_KIND]["hp"]),
			float(Tuning.ENEMIES[kind]["hp"]),
			"nothing is weaker than a %s" % Tuning.ENEMIES[Tuning.RUSH_KIND]["name"],
		)


## The biggest pack has to fit on top of the busiest minute, or the last wave
## spends itself on rushers and the finale thins out.
func test_the_biggest_pack_fits_on_top_of_the_last_wave() -> void:
	var peak := int(Tuning.WAVES[Tuning.WAVES.size() - 1]["min_alive"])
	assert_lt(
		peak + Tuning.rush_count(Tuning.RUN_SECONDS), Tuning.ENEMY_MAX, "both fit in the rows"
	)


## Size comes off the clock, and only off the clock.
func test_packs_grow_over_the_run() -> void:
	assert_gt(
		Tuning.rush_count(Tuning.RUN_SECONDS),
		Tuning.rush_count(Tuning.RUSH_AFTER),
		"the last pack is bigger than the first",
	)
	assert_gte(Tuning.rush_count(0.0), Tuning.RUSH_COUNT_MIN, "and never smaller than the floor")
	assert_lte(
		Tuning.rush_count(Tuning.RUN_SECONDS * 2.0),
		Tuning.RUSH_COUNT_MAX,
		"nor bigger than the ceiling",
	)


## The gaps must be a range, or "sometimes" is a metronome.
func test_rushes_are_not_on_a_fixed_beat() -> void:
	assert_gt(Tuning.RUSH_GAP_MAX, Tuning.RUSH_GAP_MIN, "the gap is rolled, not fixed")
	assert_gt(Tuning.RUSH_GAP_MIN, Tuning.RUSH_TELEGRAPH_TIME, "one is over before the next")


## One side of the compass, not all of it: a pack sprinkled round the ring is
## the normal spawn pattern and cannot be run away from.
func test_a_pack_comes_from_one_side() -> void:
	assert_lt(Tuning.RUSH_ARC, TAU * 0.5, "the pack leaves somewhere to run")


## Nothing rushes early. Three minutes of the wave table first, so a child has
## met a grub and learned to walk away from one.
func test_nothing_rushes_in_the_opening_minutes() -> void:
	var seen: Array = []
	_run_clock(Tuning.RUSH_AFTER - 1.0, seen)
	assert_eq(seen.size(), 0, "the opening minutes hold no rush")
	for i in _swarm.alive:
		assert_eq(_swarm.hurry[i], 1.0, "every bug so far walks its own speed")


## And one does arrive after the gate, announced before it lands: the pack is
## on screen only after the warning, like the boss.
func test_a_rush_is_announced_before_it_lands() -> void:
	var seen: Array = []
	_run_clock(Tuning.RUSH_AFTER + Tuning.RUSH_GAP_MAX + 1.0, seen, 1)
	assert_gt(seen.size(), 0, "a rush was announced")
	assert_gt(_swarm.alive, 0, "and arrived")
	var hurried := 0
	for i in _swarm.alive:
		if _swarm.hurry[i] > 1.0:
			hurried += 1
			assert_eq(_swarm.kind[i], Tuning.RUSH_KIND, "a hurrying row is a rusher")
	assert_gte(hurried, Tuning.RUSH_COUNT_MIN, "the whole pack arrived hurrying")


## The telegraph names the side the pack comes from, so the warning is worth
## reading: every rusher lands within the arc of the announced spot.
func test_the_pack_arrives_where_it_was_announced() -> void:
	var seen: Array = []
	_run_clock(Tuning.RUSH_AFTER + Tuning.RUSH_GAP_MAX + 1.0, seen, 1)
	var from: Vector2 = seen[0] - _player.global_position
	for i in _swarm.alive:
		if _swarm.hurry[i] <= 1.0:
			continue
		var to: Vector2 = _swarm.pos[i] - _player.global_position
		assert_lte(
			absf(angle_difference(from.angle(), to.angle())),
			Tuning.RUSH_ARC * 0.5 + 0.01,
			"a rusher landed inside the announced arc",
		)


## Ordinary spawns are never hurried, or the whole crowd creeps up in speed.
func test_ordinary_spawns_do_not_hurry() -> void:
	_swarm.spawn(Vector2.ZERO, Swarm.Kind.GRUB)
	assert_eq(_swarm.hurry[0], 1.0, "a normal spawn walks its own speed")


## The hurry column is swap-removed with its row, like every other column: a
## dead rusher must not leave its speed behind on the bug that takes its index.
func test_the_hurry_column_follows_its_row() -> void:
	_swarm.spawn(Vector2.ZERO, Swarm.Kind.GRUB)
	_swarm.spawn(Vector2(30.0, 0.0), Tuning.RUSH_KIND, Tuning.RUSH_HURRY)
	_swarm.damage(0, 9999.0, Vector2.ZERO)
	_swarm._compact()
	assert_eq(_swarm.alive, 1, "one row is left")
	assert_eq(_swarm.hurry[0], Tuning.RUSH_HURRY, "and it kept its own hurry")
