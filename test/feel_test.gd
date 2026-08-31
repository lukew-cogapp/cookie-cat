extends GutTest
## Pins the second juice pass: the boomerang's turn and catch, crumb piles
## that read as being eaten, per-weapon audio voices, and the pop escalation.


class StubPlayer:
	extends Node2D

	func facing_left() -> bool:
		return false

	func hurt(_amount: float) -> void:
		pass


var _weapons: Weapons
var _swarm: Swarm
var _player: StubPlayer


func before_each() -> void:
	Run.start()
	_swarm = Swarm.new()
	add_child_autofree(_swarm)
	_player = StubPlayer.new()
	add_child_autofree(_player)
	_player.global_position = Vector2.ZERO
	_swarm.set_player(_player)
	_weapons = Weapons.new()
	add_child_autofree(_weapons)
	_weapons.setup(_swarm, null, _player)
	Audio.played.clear()


func test_big_cue_ducks_the_spammy_ones() -> void:
	Audio.play("level_up")
	var voice: int = Audio._next
	Audio.play("shoot")
	assert_has(Audio.played, "shoot")
	assert_eq(
		Audio._players[voice].volume_db,
		Tuning.AUDIO_DUCK_DB,
		"the shoot right after a fanfare plays quietly"
	)


func test_boomerang_turns_visibly_and_the_catch_reads() -> void:
	_weapons._fire_boomer("boomer", 1, Vector2.ZERO)
	assert_gt(_weapons.shots, 0, "a boomerang went out")
	assert_gt(_weapons.shot_out[0], 0.0, "flying out, not homing yet")
	var saw_twirl := false
	var caught := false
	for _i in 300:
		_weapons._tick_shots(1.0 / 60.0)
		for f in _weapons.fx:
			if _weapons.fx_kind[f] == Tuning.FX_TWIRL:
				saw_twirl = true
		_weapons._tick_fx(1.0 / 60.0)
		if _weapons.shots == 0:
			caught = true
			break
	assert_true(saw_twirl, "the turn leaves a bloom at the far point")
	assert_true(caught, "it comes home inside five seconds")
	assert_has(Audio.played, "catch")


## `_last_crumb` starts at the origin and `_fire_trail` refuses a crumb within
## `TRAIL_MIN_STEP` of the last one, so dropping at `Vector2.ZERO` makes no
## crumb at all. Both of these tests did that and had been failing since they
## were written, unnoticed while the whole suite was timing out.
const CRUMB_AT := Vector2(200, 0)


func test_crumbs_and_milk_are_different_zones() -> void:
	_weapons._fire_trail("trail", 1, CRUMB_AT)
	_weapons._fire_zone("milk", 1, Vector2(500, 0))
	assert_eq(_weapons.zones, 2, "both zones were laid")
	assert_eq(_weapons.zone_kind[0], Tuning.ZONE_CRUMB)
	assert_eq(_weapons.zone_kind[1], Tuning.ZONE_MILK)


func test_a_bitten_crumb_pile_jiggles_and_squeaks() -> void:
	_weapons._fire_trail("trail", 1, CRUMB_AT)
	assert_eq(_weapons.zones, 1, "the crumb was laid")
	_swarm.spawn(CRUMB_AT, Swarm.Kind.SNAIL)
	_weapons._tick_zones(1.0 / 60.0)
	assert_gt(_weapons.zone_bite[0], 0.0, "a bug on the pile starts the jiggle")
	assert_has(Audio.played, "crumb")


func test_a_shot_landing_leaves_an_impact_star() -> void:
	# A snail: tanky enough to survive the hit, so the star is a hit star and
	# not a kill pop.
	_swarm.spawn(Vector2(40, 0), Swarm.Kind.SNAIL)
	_weapons._fire_shot("yarn", 1, Vector2.ZERO)
	var saw := false
	for _i in 30:
		_weapons._tick_shots(1.0 / 60.0)
		for f in _weapons.fx:
			if _weapons.fx_kind[f] == Tuning.FX_HIT:
				saw = true
	assert_true(saw, "the ball connecting is marked where it landed")


func test_swallowed_pops_bank_into_one_big_pop() -> void:
	for _i in Tuning.POP_BIG_EVERY * 3:
		Audio.play("pop")
	assert_has(Audio.played, "pop_big")


func test_every_weapon_has_a_voice() -> void:
	for id: String in Tuning.WEAPONS:
		assert_true(Tuning.WEAPON_VOICE.has(id), id + " has a pitch identity")


func test_enemy_dim_keeps_bugs_visible() -> void:
	for ch: float in [Tuning.ENEMY_DIM.r, Tuning.ENEMY_DIM.g, Tuning.ENEMY_DIM.b]:
		assert_between(ch, 0.7, 1.0, "a dim, not a blackout")
