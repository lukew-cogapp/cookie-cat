class_name Weapons
extends Node2D
## Every weapon the cat owns, fired on its own cooldown, aimed by itself.
##
## The player never aims and never fires. That is the genre, and it is also
## what makes this playable with one hand by someone who cannot yet read: the
## only decision is where to stand.
##
## All eight live in one node rather than one scene each. A weapon is a
## cooldown, a shape, and a rule for which rows in the swarm it hits, and
## `swarm.near` already answers the only question any of them asks. Scenes
## would add eight files and a node per shot for no gain.

## Live projectiles, for the kinds that have travel time. Same parallel-array
## shape as the swarm, and pre-sized, so a full screen of yarn allocates
## nothing.
const SHOT_MAX := 120

var _swarm: Swarm
var _gems: Gems
var _player: Node2D
var _props: Props

## Weapon id -> seconds until it fires again.
var _ready_in: Dictionary = {}
## Reused by every query. One array, cleared per call, never reallocated.
var _hits: Array[int] = []

var shot_pos: Array[Vector2] = []
var shot_vel: Array[Vector2] = []
var shot_damage: Array[float] = []
var shot_pierce: Array[int] = []
var shot_life: Array[float] = []
var shot_kind: Array[int] = []
## For a boomerang, how much further it may fly before turning round. Zero on
## an ordinary shot, which never turns.
var shot_out: Array[float] = []
## Set once a boomerang has turned, so it homes rather than flying on.
var shot_return: Array[bool] = []
var shots := 0
var _shot_dead: Array[int] = []

## Puddles: position, radius, damage per tick, seconds left.
var zone_pos: Array[Vector2] = []
var zone_radius: Array[float] = []
var zone_damage: Array[float] = []
var zone_life: Array[float] = []
var zone_slow: Array[float] = []
## Tuning.ZONE_MILK or ZONE_CRUMB: a puddle and a crumb pile share the tick
## but must not share a look.
var zone_kind: Array[int] = []
## Seconds of nibble jiggle left on a crumb pile, set while a bug is on it.
var zone_bite: Array[float] = []
var zones := 0
var _zone_dead: Array[int] = []
## Cools between nibble puffs, or a crowd on a trail is a blizzard.
var _crumb_puff_in := 0.0

## Where the orbiting fish are this frame, for the drawing code.
var orbit_angle := 0.0

## Loaded once in `_ready`: a load() per shot per frame would hit the cache and
## still cost a lookup for every ball on screen.
## Where the next paw sweep begins, so consecutive swipes do not restart from
## the same angle.
var _paw_from := 0.0
var _fish_art: Texture2D
var _shot_art: Array[Texture2D] = []

## Effects with no travel time still have to be seen, or a weapon that fires
## reads as the world dealing damage by itself. A swipe, a yawn and a zap each
## leave a shape here for a fraction of a second. `kind` indexes
## Tuning.FX_SHAPES.
var fx_pos: Array[Vector2] = []
var fx_to: Array[Vector2] = []
var fx_radius: Array[float] = []
var fx_life: Array[float] = []
var fx_full: Array[float] = []
var fx_kind: Array[int] = []
var fx_tint: Array[Color] = []
var fx := 0

## Set by the world so hits can throw pooled particles. Optional: tests build
## a Weapons with no puff layer, and everything here degrades to no sparkle.
var _puffs: Puffs

## Kills this frame, so the world can drop gems and count combos in one place
## rather than every weapon knowing about pickups.
signal killed(at: Vector2, kind: int)


func _ready() -> void:
	_fish_art = load(Tuning.ORBIT_ART)
	for path: String in Tuning.SHOT_ART:
		_shot_art.append(load(path))
	shot_pos.resize(SHOT_MAX)
	shot_vel.resize(SHOT_MAX)
	shot_damage.resize(SHOT_MAX)
	shot_pierce.resize(SHOT_MAX)
	shot_life.resize(SHOT_MAX)
	shot_kind.resize(SHOT_MAX)
	shot_out.resize(SHOT_MAX)
	shot_return.resize(SHOT_MAX)
	zone_pos.resize(SHOT_MAX)
	zone_radius.resize(SHOT_MAX)
	zone_damage.resize(SHOT_MAX)
	zone_life.resize(SHOT_MAX)
	zone_slow.resize(SHOT_MAX)
	zone_kind.resize(SHOT_MAX)
	zone_bite.resize(SHOT_MAX)
	fx_pos.resize(SHOT_MAX)
	fx_to.resize(SHOT_MAX)
	fx_radius.resize(SHOT_MAX)
	fx_life.resize(SHOT_MAX)
	fx_full.resize(SHOT_MAX)
	fx_kind.resize(SHOT_MAX)
	fx_tint.resize(SHOT_MAX)


func set_props(props: Props) -> void:
	_props = props


func set_puffs(puffs: Puffs) -> void:
	_puffs = puffs


func setup(swarm: Swarm, gems: Gems, player: Node2D) -> void:
	_swarm = swarm
	_gems = gems
	_player = player


func _physics_process(delta: float) -> void:
	if not Run.alive or _player == null:
		return
	orbit_angle += Tuning.WEAPONS["fish"]["spin"] * delta
	_tick_shots(delta)
	_tick_zones(delta)
	_tick_fx(delta)
	for id: String in Run.weapons:
		var level := int(Run.weapons[id])
		if level <= 0:
			continue
		var left := float(_ready_in.get(id, 0.0)) - delta
		if left > 0.0:
			_ready_in[id] = left
			continue
		_ready_in[id] = _cooldown(id, level)
		_fire(id, level)
	# Orbiting fish are always out, so they are not fired: they sweep every
	# frame regardless of any cooldown.
	if Run.level_of("fish") > 0:
		_sweep_orbit(Run.level_of("fish"))
	queue_redraw()


func _cooldown(id: String, level: int) -> float:
	var base := Tuning.weapon_stat(id, "cooldown", level)
	# The bell shortens every cooldown, which is why its per_level is negative.
	return maxf(base * Run.passive("bell"), Tuning.WEAPON_COOLDOWN_FLOOR)


func _damage(id: String, level: int) -> float:
	return Tuning.weapon_stat(id, "damage", level) * Run.passive("claw")


func _radius(id: String, level: int) -> float:
	return Tuning.weapon_stat(id, "radius", level) * Run.passive("bowl")


func _fire(id: String, level: int) -> void:
	var at := _player.global_position
	match String(Tuning.WEAPONS[id]["kind"]):
		"arc":
			_fire_arc(id, level, at)
		"aura", "burst", "sweep":
			_fire_circle(id, level, at)
		"shot":
			_fire_shot(id, level, at)
		"chaser":
			_fire_chaser(id, level, at)
		"zone":
			_fire_zone(id, level, at)
		"strike":
			_fire_strike(id, level, at)
		"boomer":
			_fire_boomer(id, level, at)
		"trail":
			_fire_trail(id, level, at)


## Paw Swipe: a wedge in front of the cat. The one weapon that cares which way
## the player faces, which is what makes standing still feel different from
## walking into a crowd.
func _fire_arc(id: String, level: int, at: Vector2) -> void:
	var r := _radius(id, level)
	var facing := Vector2.LEFT if _player.facing_left() else Vector2.RIGHT
	var half: float = float(Tuning.WEAPONS[id]["arc"]) * 0.5
	_swarm.near(at, r, _hits)
	var dealt := false
	for i in _hits:
		if absf(facing.angle_to(_swarm.pos[i] - at)) <= half:
			_hit(i, _damage(id, level), at)
			dealt = true
	_break_props(at, r, _damage(id, level))
	_add_fx(at, facing, r, Tuning.FX_ARC, Tuning.FX_TIME_ARC)
	if dealt:
		Audio.play("shoot", _voice(id))


## Purr Ring and Sleepy Yawn: everything inside a circle.
func _fire_circle(id: String, level: int, at: Vector2) -> void:
	var r := _radius(id, level)
	var sweep := String(Tuning.WEAPONS[id]["kind"]) == "sweep"
	_swarm.near(at, r, _hits)
	var stars := 0
	for i in _hits:
		# A star where the paw lands, capped so a crowd cannot flood the pool.
		if sweep and stars < Tuning.HIT_FX_PER_SWIPE:
			stars += 1
			_add_fx(
				_swarm.pos[i],
				Vector2.ZERO,
				Tuning.HIT_FX_SIZE,
				Tuning.FX_HIT,
				Tuning.FX_TIME_HIT,
				Tuning.HIT_TINTS["paw"],
			)
		_hit(i, _damage(id, level), at)
	# The purr ring is drawn every frame as a standing circle, so only the
	# yawn needs a burst of its own.
	_break_props(at, r, _damage(id, level))
	# The paw sweeps; the yawn bursts. Both are circles, and this is what tells
	# them apart on screen.
	if String(Tuning.WEAPONS[id]["kind"]) == "sweep":
		# Each swipe starts where the last finished, so repeated swipes read as
		# the cat batting round itself rather than one animation restarting.
		_paw_from = wrapf(_paw_from + Tuning.FX_ARC_TURN, 0.0, TAU)
		_add_fx(at, Vector2.from_angle(_paw_from), r, Tuning.FX_ARC, Tuning.FX_TIME_ARC)
	elif String(Tuning.WEAPONS[id]["kind"]) == "burst":
		_add_fx(at, Vector2.ZERO, r, Tuning.FX_RING, Tuning.FX_TIME_RING)
	if not _hits.is_empty():
		Audio.play("hit", _voice(id))


## Yarn Ball: one shot per `count` at the nearest enemies, so two yarn balls
## never chase the same bug.
func _fire_shot(id: String, level: int, at: Vector2) -> void:
	var count := int(Tuning.weapon_stat(id, "count", level))
	var speed := float(Tuning.WEAPONS[id]["speed"])
	var fired := 0
	_swarm.near(at, Tuning.SHOT_SEEK_RANGE, _hits)
	# Nearest first, so a single yarn ball goes at the closest threat.
	_hits.sort_custom(
		func(a: int, b: int) -> bool:
			return (
				_swarm.pos[a].distance_squared_to(at)
				< _swarm.pos[b].distance_squared_to(at)
			)
	)
	for i in _hits:
		if fired >= count:
			break
		_add_shot(at, (_swarm.pos[i] - at).normalized() * speed, id, level)
		fired += 1
	# Nothing to shoot at: aim for a pot instead, and only fire blind if there is
	# no target of any kind.
	if fired == 0:
		var target := _aim_at(at)
		var dir := Vector2.LEFT if _player.facing_left() else Vector2.RIGHT
		if target != at:
			dir = (target - at).normalized()
		_add_shot(at, dir * speed, id, level)
	Audio.play("shoot", _voice(id))


## Toy Mouse: a slow chaser that keeps going through a crowd. Same array as a
## yarn ball but with far more pierce and a longer life.
func _fire_chaser(id: String, level: int, at: Vector2) -> void:
	var count := int(Tuning.weapon_stat(id, "count", level))
	var speed := float(Tuning.WEAPONS[id]["speed"])
	for n in count:
		var target := _aim_at(at)
		var dir := Vector2.from_angle(TAU * float(n) / float(count))
		if target != at:
			dir = (target - at).normalized().rotated(0.4 * float(n))
		_add_shot(at, dir * speed, id, level)
	Audio.play("shoot", _voice(id))


## Boomerang Fish: out to `range`, then back to the cat, hitting on both legs.
## `shot_turn` is how far it has left to fly out; past that it homes back.
func _fire_boomer(id: String, level: int, at: Vector2) -> void:
	var count := int(Tuning.weapon_stat(id, "count", level))
	var speed := float(Tuning.WEAPONS[id]["speed"])
	_swarm.near(at, Tuning.SHOT_SEEK_RANGE, _hits)
	var fallback := _aim_at(at)
	for n in count:
		var dir := Vector2.from_angle(TAU * float(n) / float(count))
		if n < _hits.size():
			dir = (_swarm.pos[_hits[n]] - at).normalized()
		elif fallback != at:
			dir = (fallback - at).normalized().rotated(0.5 * float(n))
		_add_shot(at, dir * speed, id, level)
		# Marked as a returner, with the distance it may travel before turning.
		shot_out[shots - 1] = float(Tuning.WEAPONS[id]["range"])
	Audio.play("shoot", _voice(id))


## Crumb Trail: a crumb dropped where the cat is standing, which waits for a
## bug rather than chasing one. Does nothing while standing still, on purpose.
func _fire_trail(id: String, level: int, at: Vector2) -> void:
	if zones >= SHOT_MAX:
		return
	var z := zones
	zones += 1
	zone_pos[z] = at
	zone_radius[z] = _radius(id, level)
	zone_damage[z] = _damage(id, level) * Tuning.TRAIL_DAMAGE_RATE
	zone_life[z] = float(Tuning.WEAPONS[id]["life"])
	zone_slow[z] = 1.0
	zone_kind[z] = Tuning.ZONE_CRUMB
	zone_bite[z] = 0.0


## Milk Puddle: drops a lasting circle on the nearest crowd, or underfoot.
func _fire_zone(id: String, level: int, at: Vector2) -> void:
	if zones >= SHOT_MAX:
		return
	var target := _aim_at(at)
	var z := zones
	zones += 1
	zone_pos[z] = target
	zone_radius[z] = _radius(id, level)
	zone_damage[z] = _damage(id, level)
	zone_life[z] = float(Tuning.WEAPONS[id]["life"])
	zone_slow[z] = float(Tuning.WEAPONS[id].get("slow", 1.0))
	zone_kind[z] = Tuning.ZONE_MILK
	zone_bite[z] = 0.0


## Static Fur: hits `count` bugs anywhere on screen at once, no travel. The
## only weapon that reaches a bug the cat cannot see coming.
func _fire_strike(id: String, level: int, at: Vector2) -> void:
	var count := int(Tuning.weapon_stat(id, "count", level))
	_swarm.near(at, _radius(id, level), _hits)
	if _hits.is_empty():
		return
	_hits.shuffle()
	for n in mini(count, _hits.size()):
		var i: int = _hits[n]
		# A bolt from the cat to the bug, so a hit across the screen is not a
		# bug dying for no visible reason.
		_add_fx(at, _swarm.pos[i], 0.0, Tuning.FX_BOLT, Tuning.FX_TIME_BOLT)
		_hit(i, _damage(id, level), _swarm.pos[i])
	Audio.play("hit", _voice(id))


## Fish Friends: `count` fish on a ring, sweeping whatever they pass through.
## Damage is applied per frame at a reduced rate rather than on a cooldown, so
## walking a fish through a crowd feels continuous.
func _sweep_orbit(level: int) -> void:
	var at := _player.global_position
	var count := int(Tuning.weapon_stat("fish", "count", level))
	var r := _radius("fish", level)
	var dmg := _damage("fish", level) * Tuning.ORBIT_DAMAGE_RATE
	for n in count:
		var a := orbit_angle + TAU * float(n) / float(count)
		var p := at + Vector2.from_angle(a) * r
		_swarm.near(p, Tuning.ORBIT_HIT_RADIUS, _hits)
		for i in _hits:
			_hit(i, dmg, p)


func _add_shot(at: Vector2, vel: Vector2, id: String, level: int) -> void:
	if shots >= SHOT_MAX:
		return
	var s := shots
	shots += 1
	shot_pos[s] = at
	shot_vel[s] = vel
	shot_damage[s] = _damage(id, level)
	shot_pierce[s] = int(Tuning.WEAPONS[id].get("pierce", 1)) + level - 1
	shot_life[s] = Tuning.SHOT_LIFE
	shot_kind[s] = maxi(Tuning.SHOT_KINDS.find(id), 0)
	shot_out[s] = 0.0
	shot_return[s] = false


func _tick_shots(delta: float) -> void:
	for s in shots:
		var step := shot_vel[s] * delta
		if shot_out[s] > 0.0:
			# Still flying out. Once it has gone its distance it turns and
			# homes back at the cat, which is what makes it hit twice.
			shot_out[s] -= step.length()
			if shot_out[s] <= 0.0:
				shot_out[s] = 0.0
				shot_return[s] = true
				# A bloom at the far point, so the turn reads as deliberate.
				_add_fx(
					shot_pos[s],
					Vector2.ZERO,
					Tuning.TWIRL_RADIUS,
					Tuning.FX_TWIRL,
					Tuning.FX_TIME_TWIRL,
				)
		elif shot_return[s] and _player != null:
			var home := _player.global_position - shot_pos[s]
			# Caught. A boomerang that reaches the cat has done its work.
			if home.length() < Tuning.BOOMER_CATCH_RADIUS:
				_catch()
				_shot_dead.append(s)
				continue
			shot_vel[s] = home.normalized() * shot_vel[s].length()
			step = shot_vel[s] * delta
		shot_pos[s] += step
		shot_life[s] -= delta
		if shot_life[s] <= 0.0:
			_shot_dead.append(s)
			continue
		_swarm.near(shot_pos[s], Tuning.SHOT_HIT_RADIUS, _hits)
		var landed := false
		for i in _hits:
			if shot_pierce[s] <= 0:
				break
			shot_pierce[s] -= 1
			# One impact star per shot per frame: the touch reads without a
			# pierce through a crowd flooding the fx pool.
			if not landed:
				landed = true
				_add_fx(
					_swarm.pos[i],
					Vector2.ZERO,
					Tuning.HIT_FX_SIZE,
					Tuning.FX_HIT,
					Tuning.FX_TIME_HIT,
					_shot_tint(s),
				)
			_hit(i, shot_damage[s], shot_pos[s])
		_break_props(shot_pos[s], Tuning.SHOT_HIT_RADIUS, shot_damage[s])
		if shot_pierce[s] <= 0:
			_shot_dead.append(s)
	_compact_shots()


func _tick_zones(delta: float) -> void:
	_crumb_puff_in = maxf(_crumb_puff_in - delta, 0.0)
	for z in zones:
		zone_life[z] -= delta
		if zone_life[z] <= 0.0:
			_zone_dead.append(z)
			continue
		if zone_bite[z] > 0.0:
			zone_bite[z] = maxf(zone_bite[z] - delta, 0.0)
		_swarm.near(zone_pos[z], zone_radius[z], _hits)
		_break_props(zone_pos[z], zone_radius[z], zone_damage[z] * delta)
		if zone_kind[z] == Tuning.ZONE_CRUMB and not _hits.is_empty():
			_nibble(z)
		for i in _hits:
			_swarm.slow(i, zone_slow[z], Tuning.SLOW_LINGER)
			_hit(i, zone_damage[z] * delta, zone_pos[z])
	_compact_zones()


## A bug on a crumb pile: the pile jiggles, and now and then throws biscuit
## specks and a soft nibble. The puff is throttled across every pile at once.
func _nibble(z: int) -> void:
	zone_bite[z] = Tuning.CRUMB_BITE_TIME
	if _crumb_puff_in > 0.0:
		return
	_crumb_puff_in = Tuning.CRUMB_PUFF_GAP
	if _puffs != null:
		_puffs.burst(
			zone_pos[z],
			Puffs.Kind.POOF,
			Tuning.CRUMB_PUFF_COUNT,
			Tuning.CRUMB_COLOUR,
			Tuning.CRUMB_PUFF_SPEED,
		)
	Audio.play("crumb")


## The boomerang comes home: a gold ring closes onto the cat, a sparkle, and
## a soft thwip. Without these the fish blinked out and the catch read as a
## miss.
func _catch() -> void:
	var at := _player.global_position
	_add_fx(at, Vector2.ZERO, Tuning.CATCH_RADIUS, Tuning.FX_CATCH, Tuning.FX_TIME_CATCH)
	if _puffs != null:
		_puffs.burst(
			at,
			Puffs.Kind.SPARKLE,
			Tuning.CATCH_PUFFS,
			Tuning.PUFF_GOLD,
			Tuning.PUFF_PICKUP_SPEED,
		)
	Audio.play("catch")


## The weapon's pitch over the shared cues, so ten toys are not one click.
func _voice(id: String) -> float:
	return float(Tuning.WEAPON_VOICE.get(id, 1.0))


## The impact-star tint for a live shot, from the weapon it came from.
func _shot_tint(s: int) -> Color:
	var id: String = Tuning.SHOT_KINDS[shot_kind[s]]
	var tint: Color = Tuning.HIT_TINTS.get(id, Color.WHITE)
	return tint


## Records an effect to draw. `secs` is how long it stays up: long enough to
## be seen at 60fps, short enough not to smear across the next shot.
func _add_fx(at: Vector2, to: Vector2, radius: float, kind: int, secs: float, tint := Color.WHITE) -> void:
	if fx >= SHOT_MAX:
		return
	var f := fx
	fx += 1
	fx_pos[f] = at
	fx_to[f] = to
	fx_radius[f] = radius
	fx_life[f] = secs
	fx_full[f] = secs
	fx_kind[f] = kind
	fx_tint[f] = tint


func _tick_fx(delta: float) -> void:
	var f := 0
	while f < fx:
		fx_life[f] -= delta
		if fx_life[f] <= 0.0:
			fx -= 1
			if f != fx:
				fx_pos[f] = fx_pos[fx]
				fx_to[f] = fx_to[fx]
				fx_radius[f] = fx_radius[fx]
				fx_life[f] = fx_life[fx]
				fx_full[f] = fx_full[fx]
				fx_kind[f] = fx_kind[fx]
				fx_tint[f] = fx_tint[fx]
			continue
		f += 1


## Where a weapon that needs a target should aim. Bugs first, then props, then
## nothing: a shot fired at empty grass while a pot stands beside the cat reads
## as the weapon being broken.
func _aim_at(from: Vector2) -> Vector2:
	var i := _swarm.nearest(from, Tuning.SHOT_SEEK_RANGE)
	if i >= 0:
		return _swarm.pos[i]
	if _props != null:
		var p := _props.nearest(from, Tuning.SHOT_SEEK_RANGE)
		if p >= 0:
			return _props.pos[p]
	return from


func _break_props(at: Vector2, radius: float, amount: float) -> void:
	if _props != null:
		_props.damage_near(at, radius, amount)


## The one place damage is dealt, so a kill is counted once however it died.
func _hit(i: int, amount: float, from: Vector2) -> void:
	var at := _swarm.pos[i]
	var kind := _swarm.kind[i]
	if _swarm.damage(i, amount, from):
		killed.emit(at, kind)


func _compact_shots() -> void:
	if _shot_dead.is_empty():
		return
	_shot_dead.sort()
	_shot_dead.reverse()
	var last := -1
	for s in _shot_dead:
		if s == last:
			continue
		last = s
		shots -= 1
		if s != shots:
			shot_pos[s] = shot_pos[shots]
			shot_vel[s] = shot_vel[shots]
			shot_damage[s] = shot_damage[shots]
			shot_pierce[s] = shot_pierce[shots]
			shot_life[s] = shot_life[shots]
			shot_kind[s] = shot_kind[shots]
			shot_out[s] = shot_out[shots]
			shot_return[s] = shot_return[shots]
	_shot_dead.clear()


func _compact_zones() -> void:
	if _zone_dead.is_empty():
		return
	_zone_dead.sort()
	_zone_dead.reverse()
	var last := -1
	for z in _zone_dead:
		if z == last:
			continue
		last = z
		zones -= 1
		if z != zones:
			zone_pos[z] = zone_pos[zones]
			zone_radius[z] = zone_radius[zones]
			zone_damage[z] = zone_damage[zones]
			zone_life[z] = zone_life[zones]
			zone_slow[z] = zone_slow[zones]
			zone_kind[z] = zone_kind[zones]
			zone_bite[z] = zone_bite[zones]
	_zone_dead.clear()


## Weapon effects are drawn here rather than spawned as nodes: a scene per
## yarn ball would cost more than the ball.
##
## Every toy is drawn as its own sprite, not as a coloured dot. A fish drawn as
## a blue circle reads as a bubble, and eight weapons drawn as primitives read
## as one weapon with different colours. `_sprite` rotates the art to face its
## travel, so a fish swims round the cat and a mouse points where it is going.
func _draw() -> void:
	if not Run.alive or _player == null:
		return
	var at := to_local(_player.global_position)

	# Puddles and crumb piles first: everything else stands on top of them.
	for z in zones:
		var here := to_local(zone_pos[z])
		if zone_kind[z] == Tuning.ZONE_CRUMB:
			_draw_crumbs(z, here)
			continue
		var fade: float = clampf(zone_life[z] / Tuning.ZONE_FADE_TIME, 0.0, 1.0)
		var c := Tuning.ZONE_COLOUR
		draw_circle(here, zone_radius[z], Color(c.r, c.g, c.b, c.a * fade))
		# A rim, so the edge of the slow is visible rather than a soft blob.
		var rim: Color = Tuning.ZONE_RIM_COLOUR
		draw_arc(
			here,
			zone_radius[z],
			0.0,
			TAU,
			32,
			Color(rim.r, rim.g, rim.b, rim.a * fade),
			Tuning.ZONE_RIM_WIDTH,
			true,
		)

	if Run.level_of("purr") > 0:
		_draw_purr(at, _radius("purr", Run.level_of("purr")))

	if Run.level_of("fish") > 0:
		var level := Run.level_of("fish")
		var count := int(Tuning.weapon_stat("fish", "count", level))
		var r := _radius("fish", level)
		for n in count:
			var a := orbit_angle + TAU * float(n) / float(count)
			var here := at + Vector2.from_angle(a) * r
			# A fish swims nose-first along the ring, so it faces the tangent,
			# not the radius. The art points +x, and the fish travels
			# anticlockwise as `orbit_angle` grows, so the heading is a quarter
			# turn PAST its position; drawn a quarter turn back it swam
			# backwards through the whole orbit.
			var heading := a + PI * 0.5
			# Sprites are drawn upright, so a fish on the left half would be
			# upside down. Mirroring vertically there keeps it belly-down all
			# the way round, which is what `_sprite`'s flip argument is for.
			var upside_down := absf(wrapf(heading, -PI, PI)) > PI * 0.5
			_sprite(
				_fish_art,
				here,
				heading,
				Tuning.ORBIT_DRAW_SIZE,
				Color.WHITE,
				upside_down,
			)

	for s in shots:
		var here := to_local(shot_pos[s])
		var art: Texture2D = _shot_art[shot_kind[s]]
		# A short trail, so a fast yarn ball reads as thrown rather than as a
		# dot that teleports between frames. The boomerang's is longer, and
		# warms to gold on the return: that is the leg that pays twice.
		var length: float = Tuning.SHOT_TRAIL
		var t: Color = Tuning.SHOT_TRAIL_COLOURS[shot_kind[s]]
		if shot_kind[s] == 2:
			length = Tuning.BOOMER_TRAIL
			t = Tuning.BOOMER_TRAIL_BACK if shot_return[s] else Tuning.BOOMER_TRAIL_OUT
		var back: Vector2 = here - shot_vel[s].normalized() * length
		draw_line(back, here, t, Tuning.SHOT_TRAIL_WIDTH, true)
		# Yarn tumbles as it flies; the boomerang spins hard, each on its own
		# phase; the mouse points where it is running.
		var spin: float = shot_vel[s].angle()
		if shot_kind[s] == 0:
			spin = Run.clock * Tuning.SHOT_SPIN
		elif shot_kind[s] == 2:
			spin = Run.clock * Tuning.BOOMER_SPIN + float(s)
		_sprite(art, here, spin, Tuning.SHOT_DRAW_SIZE, Color.WHITE)

	_draw_fx(at)


## The purr ring: a dotted circle of paw-pink pips that turns, rather than a
## thin outline. A static arc read as a UI element drawn over the game.
func _draw_purr(at: Vector2, r: float) -> void:
	var pips: int = Tuning.AURA_PIPS
	var turn: float = Run.clock * Tuning.AURA_SPIN
	var c: Color = Tuning.AURA_COLOUR
	draw_arc(at, r, 0.0, TAU, 48, Color(c.r, c.g, c.b, c.a * 0.5), Tuning.AURA_WIDTH, true)
	for n in pips:
		var a := turn + TAU * float(n) / float(pips)
		# Each pip breathes on its own phase, so the ring shimmers instead of
		# pulsing as one solid band.
		var size: float = Tuning.AURA_PIP_SIZE * (
			1.0 + Tuning.AURA_PIP_BREATHE * sin(Run.clock * Tuning.AURA_PIP_RATE + float(n))
		)
		draw_circle(at + Vector2.from_angle(a) * r, size, c)


## One sprite, centred, rotated, at a size in world units. Drawing a texture
## takes a rect rather than a centre, so this is the only place that maths
## lives.
func _sprite(
	art: Texture2D,
	centre: Vector2,
	turn: float,
	size: float,
	tint: Color,
	flip_v := false,
) -> void:
	if art == null:
		return
	# A negative y scale mirrors about the sprite's own axis, which is what
	# keeps a rotated fish belly-down rather than rolling over.
	draw_set_transform(centre, turn, Vector2(1.0, -1.0 if flip_v else 1.0))
	draw_texture_rect(art, Rect2(-size * 0.5, -size * 0.5, size, size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Instant weapons, drawn from the record `_add_fx` left. Each fades over its
## life so a swipe reads as a swipe rather than a flicker. `cat` is the
## player's local position: the catch ring tracks the cat, not where it was.
func _draw_fx(cat: Vector2) -> void:
	for f in fx:
		var t: float = clampf(fx_life[f] / maxf(fx_full[f], 0.001), 0.0, 1.0)
		var here := to_local(fx_pos[f])
		match fx_kind[f]:
			Tuning.FX_ARC:
				_draw_swipe(here, fx_to[f].angle(), fx_radius[f], t)
			Tuning.FX_RING:
				_draw_yawn(here, fx_radius[f], t)
			Tuning.FX_BOLT:
				_draw_bolt(here, to_local(fx_to[f]), t)
			Tuning.FX_HIT:
				_draw_hit_star(here, fx_radius[f], t, fx_tint[f])
			Tuning.FX_TWIRL:
				_draw_twirl(here, fx_radius[f], t)
			Tuning.FX_CATCH:
				_draw_catch(cat, t)


## An impact star: short spokes flaring out of the hit point in the weapon's
## own tint, so each toy connecting reads as its own touch.
func _draw_hit_star(at: Vector2, size: float, t: float, tint: Color) -> void:
	var reach: float = size * (1.4 - 0.4 * t)
	var c := Color(tint.r, tint.g, tint.b, t)
	for n in Tuning.HIT_FX_SPOKES:
		var dir := Vector2.from_angle(TAU * float(n) / float(Tuning.HIT_FX_SPOKES) + 0.5)
		draw_line(at + dir * size * 0.3, at + dir * reach, c, Tuning.HIT_FX_WIDTH, true)
	draw_circle(at, size * 0.35 * t, Color(1.0, 1.0, 1.0, t))


## The boomerang's turn: a ring blooming at the far point of the throw.
func _draw_twirl(at: Vector2, r: float, t: float) -> void:
	var c := Tuning.BOOMER_TRAIL_OUT
	draw_arc(at, r * (1.0 - t), 0.0, TAU, 20, Color(c.r, c.g, c.b, t), Tuning.FX_RING_WIDTH, true)


## The catch: a gold ring closing onto the cat wherever it now stands, so it
## reads as taken into the paw rather than as another blast.
func _draw_catch(at: Vector2, t: float) -> void:
	var c := Tuning.BOOMER_TRAIL_BACK
	var alpha: float = 1.0 - t * 0.5
	draw_arc(at, Tuning.CATCH_RADIUS * t, 0.0, TAU, 24, Color(c.r, c.g, c.b, alpha), Tuning.FX_RING_WIDTH, true)


## A crumb pile: a handful of biscuit specks rather than a puddle. Crumbs
## vanish one by one as the drop's life runs out, and the pile jiggles while
## a bug is eating it.
func _draw_crumbs(z: int, here: Vector2) -> void:
	var frac: float = clampf(zone_life[z] / float(Tuning.WEAPONS["trail"]["life"]), 0.0, 1.0)
	var shown := int(ceilf(frac * float(Tuning.CRUMB_COUNT)))
	# Offsets are hashed off the drop's own position: stable for its life, no
	# per-crumb state, and swap-removal cannot shuffle them.
	var salt: float = zone_pos[z].x * 12.9898 + zone_pos[z].y * 78.233
	for n in shown:
		var a: float = salt + float(n) * 2.4
		var d: float = (
			zone_radius[z] * Tuning.CRUMB_SPREAD * (0.25 + 0.75 * absf(sin(salt + float(n) * 1.7)))
		)
		var p := here + Vector2.from_angle(a) * d
		if zone_bite[z] > 0.0:
			p.y += sin(Run.clock * Tuning.CRUMB_JIGGLE_RATE + float(n) * 2.0) * Tuning.CRUMB_JIGGLE
		var size: float = Tuning.CRUMB_SIZE * (0.8 + 0.4 * absf(cos(salt + float(n))))
		draw_circle(p, size + 1.2, Tuning.CRUMB_OUTLINE)
		draw_circle(p, size, Tuning.CRUMB_COLOUR)
		draw_circle(p + Vector2(-size, -size) * 0.35, size * 0.4, Tuning.CRUMB_LIGHT)


## The paw swipe: three tapering crescents sweeping through the wedge that was
## hit, brightest at the leading edge. A single thin arc read as a UI outline
## and gave no sense of a paw moving through anything.
func _draw_swipe(at: Vector2, facing: float, r: float, t: float) -> void:
	var c: Color = Tuning.FX_ARC_COLOUR
	for n in Tuning.FX_ARC_BANDS:
		# Each band trails the one in front, so the swipe reads as sweeping
		# round rather than as a ring appearing all at once.
		var lag := float(n) * Tuning.FX_ARC_BAND_LAG
		var swept: float = clampf(1.0 - t - lag, 0.0, 1.0)
		if swept <= 0.0:
			continue
		var band_r: float = r * (1.0 - float(n) * Tuning.FX_ARC_BAND_STEP)
		draw_arc(
			at,
			band_r,
			facing,
			facing + TAU * swept,
			32,
			Color(c.r, c.g, c.b, c.a * t),
			Tuning.FX_ARC_WIDTH * (1.0 - float(n) * 0.25),
			true,
		)
	# Sparks at the leading edge, so the tip of the sweep has weight.
	var tip: float = facing + TAU * clampf(1.0 - t, 0.0, 1.0)
	for n in Tuning.FX_ARC_SPARKS:
		var spread: float = (
			(float(n) / float(Tuning.FX_ARC_SPARKS) - 0.5) * Tuning.FX_ARC_SPARK_SPREAD
		)
		var p := at + Vector2.from_angle(tip + spread) * r
		draw_circle(p, Tuning.FX_ARC_SPARK_SIZE * t, Color(1.0, 1.0, 1.0, t))


## The sleepy yawn: two rings expanding out of the cat at different rates, so
## the blast has depth rather than being one hoop.
func _draw_yawn(at: Vector2, r: float, t: float) -> void:
	var c: Color = Tuning.FX_RING_COLOUR
	for n in 2:
		var lead: float = 1.0 - t + float(n) * Tuning.FX_RING_LAG
		if lead <= 0.0 or lead > 1.0:
			continue
		draw_arc(
			at,
			r * lead,
			0.0,
			TAU,
			40,
			Color(c.r, c.g, c.b, c.a * t * (1.0 - float(n) * 0.4)),
			Tuning.FX_RING_WIDTH,
			true,
		)


## Static fur: a jagged bolt rather than a straight line, because a straight
## line between the cat and a bug reads as a tether.
func _draw_bolt(from: Vector2, to: Vector2, t: float) -> void:
	var c: Color = Tuning.FX_BOLT_COLOUR
	var alpha := Color(c.r, c.g, c.b, c.a * t)
	var span := to - from
	var side := span.orthogonal().normalized()
	var last := from
	for n in range(1, Tuning.FX_BOLT_STEPS + 1):
		var along: float = float(n) / float(Tuning.FX_BOLT_STEPS)
		var next := from + span * along
		# Zigzag, pinched to nothing at both ends so the bolt still starts at
		# the cat and lands on the bug.
		if n < Tuning.FX_BOLT_STEPS:
			var wobble: float = sin(along * PI) * Tuning.FX_BOLT_JAG
			next += side * wobble * (1.0 if n % 2 == 0 else -1.0)
		draw_line(last, next, alpha, Tuning.FX_BOLT_WIDTH, true)
		last = next
	# A flash where it lands, so the hit is where the eye goes.
	draw_circle(to, Tuning.FX_BOLT_FLASH * t, Color(1.0, 1.0, 1.0, t))
