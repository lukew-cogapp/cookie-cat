extends GutTest
## Pins the juice layer's pooling: puffs never exceed their cap or leak rows,
## claimed gems dart away before homing, and spawns scale in.


class StubPlayer:
	extends Node2D

	func magnet_radius() -> float:
		return Tuning.MAGNET_RADIUS

	func heal(_amount: float) -> void:
		pass

	func hurt(_amount: float) -> void:
		pass


var _puffs: Puffs


func before_each() -> void:
	Run.start()
	_puffs = Puffs.new()
	add_child_autofree(_puffs)


func test_burst_never_exceeds_cap() -> void:
	_puffs.burst(Vector2.ZERO, Puffs.Kind.STAR, Tuning.PUFF_MAX * 2, Tuning.PUFF_GOLD, 100.0)
	assert_eq(_puffs.alive, Tuning.PUFF_MAX)
	# A full pool drops the burst rather than erroring.
	_puffs.burst(Vector2.ZERO, Puffs.Kind.SPARKLE, 10, Tuning.PUFF_PINK, 50.0)
	assert_eq(_puffs.alive, Tuning.PUFF_MAX)


func test_puffs_expire_and_pool_drains() -> void:
	_puffs.burst(Vector2.ZERO, Puffs.Kind.STAR, 40, Tuning.PUFF_GOLD, 100.0)
	_puffs.ring(Vector2.ZERO, Puffs.Kind.POOF, 12, Tuning.PUFF_WHITE, 30.0, 60.0)
	assert_eq(_puffs.alive, 52)
	# Lives are randomised up to 1.2x PUFF_LIFE, so tick well past that.
	for _i in 60:
		_puffs._physics_process(0.05)
	assert_eq(_puffs.alive, 0, "every row expires; none leak")


func test_numbers_capped_and_expire() -> void:
	for n in Tuning.NUMBER_MAX * 2:
		_puffs.number(Vector2.ZERO, "+%d" % n)
	assert_eq(_puffs.num_alive, Tuning.NUMBER_MAX)
	for _i in 40:
		_puffs._physics_process(0.05)
	assert_eq(_puffs.num_alive, 0)


func test_claimed_gem_darts_away_then_collects() -> void:
	var gems := Gems.new()
	add_child_autofree(gems)
	var player := StubPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2.ZERO
	gems.set_player(player)
	gems.drop(Vector2(40, 0), Gems.Kind.GEM, 2)
	gems._physics_process(1.0 / 60.0)
	assert_true(gems.flying[0], "inside the magnet radius, so claimed")
	assert_lt(gems.speed[0], 0.0, "starts moving away")
	var start := gems.pos[0].x
	for _i in 6:
		gems._physics_process(1.0 / 60.0)
	assert_gt(gems.pos[0].x, start, "the dart moved it away from the player")
	var xp := Run.xp
	for _i in 240:
		gems._physics_process(1.0 / 60.0)
	assert_eq(gems.alive, 0, "the acceleration hauls it in")
	assert_eq(Run.xp, xp + 2, "collected as XP")


## Every tier pays. `_collect` matched the plain gem alone, so a green or a red
## one was picked up, sparkled, and gave nothing: a boss rolls a tier gem four
## times in five, which made the biggest reward in the game free. Only the plain
## gem had ever been collected in a test, which is why it went unnoticed.
func test_every_gem_tier_pays_its_worth() -> void:
	for tier: int in [Gems.Kind.GEM, Gems.Kind.GEM_GREEN, Gems.Kind.GEM_RED]:
		# A fresh run per tier: `add_xp` levels up and resets `Run.xp`, so a
		# running total across the three would prove nothing.
		Run.cat = Tuning.STARTER_CAT
		Run.start()
		var gems := Gems.new()
		add_child_autofree(gems)
		var player := StubPlayer.new()
		add_child_autofree(player)
		player.global_position = Vector2.ZERO
		gems.set_player(player)
		gems.drop(Vector2(20, 0), tier, 3)
		# Worth 3, and a level needs 4 at level one, so no level-up intervenes
		# and the bar simply moves by the gem's worth.
		assert_gt(Run.xp_needed, 3, "the fixture does not cross a level")
		var before := Run.xp
		for _i in 300:
			gems._physics_process(1.0 / 60.0)
		assert_eq(gems.alive, 0, "tier %d was collected" % tier)
		assert_eq(Run.xp, before + 3, "tier %d paid its worth" % tier)


func test_spawn_scales_in() -> void:
	var swarm := Swarm.new()
	add_child_autofree(swarm)
	var player := StubPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2.ZERO
	swarm.set_player(player)
	swarm.spawn(Vector2(400, 0), Swarm.Kind.GRUB)
	assert_eq(swarm.grow[0], Tuning.SPAWN_GROW_TIME, "spawns start scaled to nothing")
	for _i in 30:
		swarm._physics_process(1.0 / 60.0)
	assert_eq(swarm.grow[0], 0.0, "and reach full size")
