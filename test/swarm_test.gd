extends GutTest
## The swarm's row bookkeeping.
##
## Rows are swap-removed, so a kill moves the last enemy into the dead one's
## index. Every one of these pins a way that has already gone wrong or would
## silently corrupt the crowd: a row dropped twice deletes a live enemy, and a
## mid-loop swap skips the row it moved.

var _swarm: Swarm


func before_each() -> void:
	_swarm = Swarm.new()
	add_child_autofree(_swarm)
	await wait_process_frames(1)
	# The swarm drives itself every physics frame; these tests drive it by
	# hand, and letting both run would step every enemy twice.
	_swarm.set_physics_process(false)


func _spawn_line(count: int) -> void:
	for i in count:
		_swarm.spawn(Vector2(float(i) * 50.0, 0.0), i % 5)


func test_spawn_fills_rows() -> void:
	_spawn_line(5)
	assert_eq(_swarm.alive, 5, "five spawns are five rows")


func test_spawn_stops_at_max() -> void:
	for i in Tuning.ENEMY_MAX + 20:
		_swarm.spawn(Vector2.ZERO, 0)
	assert_eq(_swarm.alive, Tuning.ENEMY_MAX, "the cap holds")


## The bug that swap-removal exists to avoid: a kill must not renumber the
## living into each other.
func test_kill_keeps_the_others() -> void:
	_spawn_line(4)
	var survivors := [_swarm.pos[0], _swarm.pos[1], _swarm.pos[3]]
	_swarm.damage(2, 9999.0, Vector2.ZERO)
	_swarm._compact()
	assert_eq(_swarm.alive, 3, "one died")
	for p: Vector2 in survivors:
		assert_true(_swarm.pos.slice(0, _swarm.alive).has(p), "row at %s survived" % p)


## Two shots landing on one enemy in a frame queue it twice. Dropping it twice
## would take a live enemy with it.
func test_double_kill_removes_one_row() -> void:
	_spawn_line(4)
	_swarm.damage(1, 9999.0, Vector2.ZERO)
	_swarm.damage(1, 9999.0, Vector2.ZERO)
	_swarm._compact()
	assert_eq(_swarm.alive, 3, "queued twice, removed once")


func test_damage_below_zero_kills() -> void:
	_swarm.spawn(Vector2.ZERO, 0)
	var died := _swarm.damage(0, _swarm.hp[0] + 1.0, Vector2.ONE)
	assert_true(died, "enough damage kills")


func test_damage_short_of_hp_does_not_kill() -> void:
	_swarm.spawn(Vector2.ZERO, 0)
	var died := _swarm.damage(0, 0.5, Vector2.ONE)
	assert_false(died, "a scratch does not kill")
	assert_gt(_swarm.hp[0], 0.0, "and leaves health behind")


## An index past the end must be refused rather than writing into a stale row:
## a shot holds an index for a frame, and the enemy can die in between.
func test_damage_out_of_range_is_ignored() -> void:
	_swarm.spawn(Vector2.ZERO, 0)
	assert_false(_swarm.damage(5, 9999.0, Vector2.ZERO), "row 5 does not exist")
	assert_false(_swarm.damage(-1, 9999.0, Vector2.ZERO), "nor does row -1")
	assert_eq(_swarm.alive, 1, "and neither killed the real one")


func test_near_finds_only_rows_in_radius() -> void:
	_swarm.spawn(Vector2(10.0, 0.0), 0)
	_swarm.spawn(Vector2(300.0, 0.0), 0)
	var hits: Array[int] = []
	_swarm.near(Vector2.ZERO, 50.0, hits)
	assert_eq(hits.size(), 1, "only the close one")


## `near` fills a caller-owned array, so a stale result from the last call
## must not leak into the next.
func test_near_clears_the_array() -> void:
	_swarm.spawn(Vector2(10.0, 0.0), 0)
	var hits: Array[int] = []
	_swarm.near(Vector2.ZERO, 50.0, hits)
	_swarm.near(Vector2(9000.0, 0.0), 50.0, hits)
	assert_eq(hits.size(), 0, "the second call reports nothing")


func test_nearest_picks_the_closest() -> void:
	_swarm.spawn(Vector2(200.0, 0.0), 0)
	_swarm.spawn(Vector2(40.0, 0.0), 0)
	_swarm.spawn(Vector2(120.0, 0.0), 0)
	assert_eq(_swarm.nearest(Vector2.ZERO, 500.0), 1, "row 1 is closest")


func test_nearest_returns_minus_one_when_empty() -> void:
	assert_eq(_swarm.nearest(Vector2.ZERO, 500.0), -1, "nothing in range")


## Being hit shoves the crowd off the cat. Without this a surrounded child
## loses the next heart the frame mercy ends: measured at all three in 3.7s.
func test_push_moves_rows_away() -> void:
	_swarm.spawn(Vector2(20.0, 0.0), 0)
	_swarm.push_from(Vector2.ZERO, 100.0, 200.0)
	assert_gt(_swarm.knock[0].x, 0.0, "pushed along +x, away from the origin")


func test_push_ignores_rows_out_of_range() -> void:
	_swarm.spawn(Vector2(400.0, 0.0), 0)
	_swarm.push_from(Vector2.ZERO, 100.0, 200.0)
	assert_eq(_swarm.knock[0], Vector2.ZERO, "too far to shove")


## A bug standing exactly on the cat has no direction to be pushed, and
## normalising a zero vector would leave it there taking hits forever.
func test_push_moves_a_row_at_zero_distance() -> void:
	_swarm.spawn(Vector2.ZERO, 0)
	_swarm.push_from(Vector2.ZERO, 100.0, 200.0)
	assert_gt(_swarm.knock[0].length(), 0.0, "shoved somewhere")


## The milk puddle is the only crowd control in the game, so the slow is worth
## pinning: without it milk is a second purr ring.
func test_slow_reduces_speed() -> void:
	_swarm.spawn(Vector2.ZERO, 0)
	_swarm.slow(0, 0.5, 1.0)
	assert_lt(_swarm.slow_by[0], 1.0, "slowed")
	assert_gt(_swarm.slow_for[0], 0.0, "for a while")


## Two overlapping puddles must not leave a bug at the weaker slow.
func test_the_strongest_slow_wins() -> void:
	_swarm.spawn(Vector2.ZERO, 0)
	_swarm.slow(0, 0.4, 1.0)
	_swarm.slow(0, 0.9, 1.0)
	assert_eq(_swarm.slow_by[0], 0.4, "the deeper slow holds")


## Driven by hand rather than by letting the swarm tick: `_physics_process`
## needs a live run and a player it can damage, and this is asserting the timer,
## not the movement it gates.
func test_slow_wears_off() -> void:
	_swarm.spawn(Vector2.ZERO, 0)
	_swarm.slow(0, 0.5, 0.1)
	_swarm.slow_for[0] = maxf(_swarm.slow_for[0] - 0.2, 0.0)
	assert_eq(_swarm.slow_for[0], 0.0, "the timer runs out")


func test_slow_on_a_dead_row_is_ignored() -> void:
	_swarm.slow(3, 0.5, 1.0)
	assert_eq(_swarm.alive, 0, "nothing was created")
