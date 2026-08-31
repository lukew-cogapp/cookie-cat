extends GutTest
## The dung beetle's lob and the poop pool: the first enemy projectile, so its
## bookkeeping gets the same pins as the swarm's own rows.


class FakeCat:
	extends Node2D
	var hurts := 0

	func hurt(_amount: float) -> void:
		hurts += 1


var _swarm: Swarm
var _cat: FakeCat


func before_each() -> void:
	_swarm = Swarm.new()
	add_child_autofree(_swarm)
	_cat = FakeCat.new()
	add_child_autofree(_cat)
	await wait_process_frames(1)
	_swarm.set_physics_process(false)
	_swarm.set_player(_cat)


func test_the_pool_caps() -> void:
	for n in Tuning.POOP_MAX + 10:
		_swarm.spawn_poop(Vector2(9000.0, 0.0), Vector2.RIGHT)
	assert_eq(_swarm.poops, Tuning.POOP_MAX, "the cap holds")


func test_an_expired_poop_frees_its_row() -> void:
	for n in 3:
		_swarm.spawn_poop(Vector2(9000.0, float(n)), Vector2.RIGHT)
	_swarm._tick_poops(Tuning.POOP_LIFE + 0.1)
	assert_eq(_swarm.poops, 0, "every row came back to the pool")


func test_a_poop_hurts_the_cat_and_splats() -> void:
	_cat.position = Vector2.ZERO
	_swarm.spawn_poop(Vector2.ZERO, Vector2.ZERO)
	_swarm._tick_poops(0.016)
	assert_eq(_cat.hurts, 1, "the hit went through hurt()")
	assert_eq(_swarm.poops, 0, "and the ball splatted")


func test_a_poop_misses_a_cat_far_away() -> void:
	_cat.position = Vector2(500.0, 0.0)
	_swarm.spawn_poop(Vector2.ZERO, Vector2.RIGHT * 10.0)
	_swarm._tick_poops(0.016)
	assert_eq(_cat.hurts, 0, "nothing landed")
	assert_eq(_swarm.poops, 1, "and the ball flies on")


## Dodgeable means never homing: the velocity set at the lob is the velocity
## it splats with.
func test_a_poop_never_turns() -> void:
	_cat.position = Vector2(300.0, 300.0)
	_swarm.spawn_poop(Vector2.ZERO, Vector2(0.0, 50.0))
	for n in 10:
		_swarm._tick_poops(0.05)
	assert_eq(_swarm.poop_vel[0], Vector2(0.0, 50.0), "still flying as thrown")


func test_compact_skips_a_row_queued_twice() -> void:
	_swarm.spawn_poop(Vector2(9000.0, 0.0), Vector2.RIGHT)
	_swarm.spawn_poop(Vector2(9000.0, 1.0), Vector2.RIGHT)
	_swarm._poop_dead.append(0)
	_swarm._poop_dead.append(0)
	_swarm._compact_poops()
	assert_eq(_swarm.poops, 1, "queued twice, removed once")


func test_a_beetle_in_range_counts_down_and_lobs() -> void:
	_swarm.spawn(Vector2(100.0, 0.0), Swarm.Kind.DUNG)
	_swarm.aim[0] = 0.05
	_swarm._dung_attack(0, 100.0, Vector2.ZERO, 0.1)
	assert_eq(_swarm.poops, 1, "the lob went out")
	assert_eq(_swarm.aim[0], Tuning.DUNG_FIRE_COOLDOWN, "and the countdown reset")
	var vel: Vector2 = _swarm.poop_vel[0]
	assert_almost_eq(vel.length(), Tuning.POOP_SPEED, 0.01, "at poop speed")
	assert_lt(vel.x, 0.0, "towards the cat")


## A beetle walking into range must still show the full wind-up: a stale
## countdown would let it fire the frame it arrives.
func test_entering_range_never_fires_at_once() -> void:
	_swarm.spawn(Vector2(500.0, 0.0), Swarm.Kind.DUNG)
	_swarm.aim[0] = 0.01
	_swarm._dung_attack(0, 500.0, Vector2.ZERO, 0.016)
	assert_eq(_swarm.poops, 0, "nothing flew from out of range")
	assert_eq(_swarm.aim[0], Tuning.DUNG_TELEGRAPH, "the wind-up was restored")


# --- Properties the numbers must keep, whatever they are retuned to ---


func test_the_poop_is_slower_than_the_cat() -> void:
	assert_lt(Tuning.POOP_SPEED, Tuning.PLAYER_SPEED, "walking away always works")


func test_a_lob_can_reach_the_cat_from_the_fire_range() -> void:
	assert_gt(
		Tuning.POOP_SPEED * Tuning.POOP_LIFE,
		Tuning.DUNG_FIRE_RANGE,
		"a ball fired at the edge of range does not fall short",
	)


func test_one_beetle_cannot_chain_hits_through_mercy() -> void:
	assert_gt(
		Tuning.DUNG_FIRE_COOLDOWN,
		Tuning.PLAYER_MERCY_TIME,
		"the next lob waits for mercy to end",
	)


func test_the_wind_up_is_real_and_shorter_than_the_cooldown() -> void:
	assert_gt(Tuning.DUNG_TELEGRAPH, 0.0, "there is a wind-up")
	assert_lt(Tuning.DUNG_TELEGRAPH, Tuning.DUNG_FIRE_COOLDOWN, "and it fits the cycle")


func test_the_beetle_stands_off_inside_its_fire_range() -> void:
	assert_lt(Tuning.DUNG_STAND_RANGE, Tuning.DUNG_FIRE_RANGE, "it stops where it can shoot")


func test_the_poop_art_exists() -> void:
	assert_true(ResourceLoader.exists(Tuning.POOP_ART), "poop art loads")


func test_every_enemy_rolls_gem_tiers() -> void:
	for row: Dictionary in Tuning.ENEMIES:
		assert_true(row.has("gem_up"), "%s has a gem_up" % row["name"])
