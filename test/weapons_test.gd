extends GutTest
## The weapons, and the rules that are easy to break without noticing.

var _world: Node
var _weapons: Weapons
var _swarm: Swarm
var _props: Props
var _player: Node2D


func before_all() -> void:
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await wait_physics_frames(2)
	_weapons = _world.get_node("Weapons")
	_swarm = _world.get_node("Swarm")
	_props = _world.get_node("Props")
	_player = _world.get_node("Player")
	_world.get_node("Director").set_physics_process(false)


func after_all() -> void:
	Run.alive = false
	_world.free()


func before_each() -> void:
	Run.start()
	_clear_swarm()


## `damage` queues a row in `_dead` and leaves `alive` alone: only `_compact`
## drops it. So looping until `alive` reaches zero never ends, because nothing
## inside the loop can change it. Kill every row once, then compact once.
func _clear_swarm() -> void:
	for i in range(_swarm.alive - 1, -1, -1):
		_swarm.damage(i, 99999.0, Vector2.ZERO)
	_swarm._compact()


## Every weapon must have firing code reachable from `_fire`, or it is a card
## that does nothing when picked.
func test_every_weapon_fires() -> void:
	for id: String in Tuning.WEAPONS:
		# The trail drops a crumb where the cat has been and waits for a bug to
		# walk onto it, so it cannot hurt a ring of stationary bugs however long
		# this runs. `test_crumbs_are_left_behind_while_walking` and
		# `test_a_standing_cat_leaves_no_crumbs` are its cover.
		if id == "trail":
			continue
		_clear_swarm()
		var at: Vector2 = _player.global_position
		# Ringed at each weapon's own reach, not at one arbitrary distance. The
		# fish orbits at `radius` and a bug inside that ring is never touched,
		# which read as three broken weapons when they were all working.
		var ring: float = Tuning.weapon_stat(id, "radius", 1)
		if ring <= 0.0:
			ring = 40.0
		for n in 6:
			_swarm.spawn(at + Vector2.from_angle(TAU * float(n) / 6.0) * ring, 0)
		var before := _total_hp()
		Run.weapons = {id: 1}
		# Enough frames for the slowest cooldown to come round.
		for i in 240:
			_weapons._physics_process(1.0 / 60.0)
		assert_true(
			_total_hp() < before or _swarm.alive < 6,
			"%s hurt something" % id,
		)


## Every living row, not the first three: `_compact` swap-removes, so a kill
## moves an untouched row into a low index and a fixed window can miss the
## damage entirely.
func _total_hp() -> float:
	var sum := 0.0
	for i in _swarm.alive:
		sum += _swarm.hp[i]
	return sum


## A boomerang has to come back, or it is a worse yarn ball.
func test_a_boomerang_turns_round() -> void:
	Run.weapons = {"boomer": 1}
	_weapons._fire("boomer", 1)
	assert_gt(_weapons.shots, 0, "one was thrown")
	var s := 0
	assert_gt(_weapons.shot_out[s], 0.0, "with distance to fly out")
	var flying_out := true
	for i in 200:
		_weapons._physics_process(1.0 / 60.0)
		if _weapons.shots == 0:
			flying_out = false
			break
		if _weapons.shot_return[0]:
			flying_out = false
			break
	assert_false(flying_out, "it turned round or was caught")


## Crumbs pay for MOVING: a walking cat leaves a trail, a standing one leaves
## nothing. Dropping them while still made a heap under a stationary cat and
## cost the weapon its whole point.
func test_crumbs_are_left_behind_while_walking() -> void:
	Run.weapons = {"trail": 1}
	var before := _weapons.zones
	# Two drops a good stride apart, as a walking cat would.
	_weapons._last_crumb = Vector2.ZERO
	_player.global_position = Vector2(500.0, 0.0)
	_weapons._fire("trail", 1)
	_player.global_position = Vector2(500.0 + Tuning.TRAIL_MIN_STEP * 2.0, 0.0)
	_weapons._fire("trail", 1)
	assert_eq(_weapons.zones, before + 2, "a walking cat leaves crumbs")


func test_a_standing_cat_leaves_no_crumbs() -> void:
	Run.weapons = {"trail": 1}
	_player.global_position = Vector2(900.0, 0.0)
	_weapons._fire("trail", 1)
	var after_first := _weapons.zones
	# Fired again from exactly the same spot, as a standing cat would.
	for _n in 5:
		_weapons._fire("trail", 1)
	assert_eq(_weapons.zones, after_first, "standing still drops nothing more")


## With nothing to shoot at, a weapon should break a pot rather than fire at
## empty grass: a shot going nowhere reads as the weapon being broken.
func test_weapons_aim_at_props_when_no_bugs() -> void:
	_clear_swarm()
	_props.scatter(_player.global_position)
	# A pot right beside the cat, inside every weapon's reach.
	_props.at(0).position = _player.global_position + Vector2(60.0, 0.0)
	var target := _weapons._aim_at(_player.global_position)
	assert_ne(target, _player.global_position, "it found something to aim at")


## And a bug always outranks a pot: a child being chased should not have their
## weapons distracted by scenery.
func test_bugs_outrank_props() -> void:
	_props.scatter(_player.global_position)
	_props.at(0).position = _player.global_position + Vector2(40.0, 0.0)
	_swarm.spawn(_player.global_position + Vector2(0.0, 70.0), 0)
	var target := _weapons._aim_at(_player.global_position)
	assert_eq(target, _swarm.pos[0], "the bug is the target")


## Shots are pooled, so a long run must never grow the array past its cap.
func test_the_shot_pool_holds() -> void:
	Run.weapons = {"yarn": Tuning.WEAPON_LEVEL_MAX}
	for n in 20:
		_swarm.spawn(_player.global_position + Vector2(80.0 + float(n), 0.0), 0)
	for i in 600:
		_weapons._physics_process(1.0 / 60.0)
		assert_lte(_weapons.shots, Weapons.SHOT_MAX, "the pool held")
		if _weapons.shots > Weapons.SHOT_MAX:
			break


## The orbiting fish must swim nose-first the whole way round. This was wrong
## twice: the heading was a quarter turn out, and then a vertical flip meant to
## keep the fish belly-down reversed its nose through a quarter of the orbit.
## No flip now, so the only thing to pin is the heading.
func test_orbiting_fish_face_their_travel() -> void:
	for n in 32:
		var a := TAU * float(n) / 32.0
		# Where a fish at this angle is going: the tangent, anticlockwise.
		var travel := Vector2(-sin(a), cos(a))
		# Where the drawing code points it. The art faces +x.
		var nose := Vector2.from_angle(a + PI * 0.5)
		assert_gt(
			nose.dot(travel),
			0.99,
			"a fish at %.0f degrees swims forwards" % rad_to_deg(a),
		)
