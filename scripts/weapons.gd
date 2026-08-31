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
var shots := 0
var _shot_dead: Array[int] = []

## Puddles: position, radius, damage per tick, seconds left.
var zone_pos: Array[Vector2] = []
var zone_radius: Array[float] = []
var zone_damage: Array[float] = []
var zone_life: Array[float] = []
var zones := 0
var _zone_dead: Array[int] = []

## Where the orbiting fish are this frame, for the drawing code.
var orbit_angle := 0.0

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
var fx := 0

## Kills this frame, so the world can drop gems and count combos in one place
## rather than every weapon knowing about pickups.
signal killed(at: Vector2, kind: int)


func _ready() -> void:
	shot_pos.resize(SHOT_MAX)
	shot_vel.resize(SHOT_MAX)
	shot_damage.resize(SHOT_MAX)
	shot_pierce.resize(SHOT_MAX)
	shot_life.resize(SHOT_MAX)
	shot_kind.resize(SHOT_MAX)
	zone_pos.resize(SHOT_MAX)
	zone_radius.resize(SHOT_MAX)
	zone_damage.resize(SHOT_MAX)
	zone_life.resize(SHOT_MAX)
	fx_pos.resize(SHOT_MAX)
	fx_to.resize(SHOT_MAX)
	fx_radius.resize(SHOT_MAX)
	fx_life.resize(SHOT_MAX)
	fx_full.resize(SHOT_MAX)
	fx_kind.resize(SHOT_MAX)


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
		"aura", "burst":
			_fire_circle(id, level, at)
		"shot":
			_fire_shot(id, level, at)
		"chaser":
			_fire_chaser(id, level, at)
		"zone":
			_fire_zone(id, level, at)
		"strike":
			_fire_strike(id, level, at)


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
	_add_fx(at, facing, r, Tuning.FX_ARC, Tuning.FX_TIME_ARC)
	if dealt:
		Audio.play("shoot")


## Purr Ring and Sleepy Yawn: everything inside a circle.
func _fire_circle(id: String, level: int, at: Vector2) -> void:
	var r := _radius(id, level)
	_swarm.near(at, r, _hits)
	for i in _hits:
		_hit(i, _damage(id, level), at)
	# The purr ring is drawn every frame as a standing circle, so only the
	# yawn needs a burst of its own.
	if String(Tuning.WEAPONS[id]["kind"]) == "burst":
		_add_fx(at, Vector2.ZERO, r, Tuning.FX_RING, Tuning.FX_TIME_RING)
	if not _hits.is_empty():
		Audio.play("hit")


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
	# Nothing in range: fire ahead anyway, so the weapon never looks broken.
	if fired == 0:
		var dir := Vector2.LEFT if _player.facing_left() else Vector2.RIGHT
		_add_shot(at, dir * speed, id, level)
	Audio.play("shoot")


## Toy Mouse: a slow chaser that keeps going through a crowd. Same array as a
## yarn ball but with far more pierce and a longer life.
func _fire_chaser(id: String, level: int, at: Vector2) -> void:
	var count := int(Tuning.weapon_stat(id, "count", level))
	var speed := float(Tuning.WEAPONS[id]["speed"])
	for n in count:
		var i := _swarm.nearest(at, Tuning.SHOT_SEEK_RANGE)
		var dir := Vector2.from_angle(TAU * float(n) / float(count))
		if i >= 0:
			dir = (_swarm.pos[i] - at).normalized().rotated(0.4 * float(n))
		_add_shot(at, dir * speed, id, level)
	Audio.play("shoot")


## Milk Puddle: drops a lasting circle on the nearest crowd, or underfoot.
func _fire_zone(id: String, level: int, at: Vector2) -> void:
	if zones >= SHOT_MAX:
		return
	var target := at
	var i := _swarm.nearest(at, Tuning.SHOT_SEEK_RANGE)
	if i >= 0:
		target = _swarm.pos[i]
	var z := zones
	zones += 1
	zone_pos[z] = target
	zone_radius[z] = _radius(id, level)
	zone_damage[z] = _damage(id, level)
	zone_life[z] = float(Tuning.WEAPONS[id]["life"])


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
	Audio.play("hit")


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
	shot_kind[s] = Tuning.SHOT_KINDS.find(id)


func _tick_shots(delta: float) -> void:
	for s in shots:
		shot_pos[s] += shot_vel[s] * delta
		shot_life[s] -= delta
		if shot_life[s] <= 0.0:
			_shot_dead.append(s)
			continue
		_swarm.near(shot_pos[s], Tuning.SHOT_HIT_RADIUS, _hits)
		for i in _hits:
			if shot_pierce[s] <= 0:
				break
			shot_pierce[s] -= 1
			_hit(i, shot_damage[s], shot_pos[s])
		if shot_pierce[s] <= 0:
			_shot_dead.append(s)
	_compact_shots()


func _tick_zones(delta: float) -> void:
	for z in zones:
		zone_life[z] -= delta
		if zone_life[z] <= 0.0:
			_zone_dead.append(z)
			continue
		_swarm.near(zone_pos[z], zone_radius[z], _hits)
		for i in _hits:
			_hit(i, zone_damage[z] * delta, zone_pos[z])
	_compact_zones()


## Records an effect to draw. `secs` is how long it stays up: long enough to
## be seen at 60fps, short enough not to smear across the next shot.
func _add_fx(at: Vector2, to: Vector2, radius: float, kind: int, secs: float) -> void:
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
			continue
		f += 1


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
	_zone_dead.clear()


## Weapon effects are drawn, not spawned as nodes: a puddle is a circle and a
## yarn ball is a dot, and `_draw` costs nothing next to a scene per shot.
func _draw() -> void:
	if not Run.alive or _player == null:
		return
	var at := to_local(_player.global_position)
	for z in zones:
		var fade: float = clampf(zone_life[z] / Tuning.ZONE_FADE_TIME, 0.0, 1.0)
		var c := Tuning.ZONE_COLOUR
		draw_circle(to_local(zone_pos[z]), zone_radius[z], Color(c.r, c.g, c.b, c.a * fade))
	if Run.level_of("purr") > 0:
		var r := _radius("purr", Run.level_of("purr"))
		draw_arc(at, r, 0.0, TAU, 48, Tuning.AURA_COLOUR, Tuning.AURA_WIDTH, true)
	if Run.level_of("fish") > 0:
		var level := Run.level_of("fish")
		var count := int(Tuning.weapon_stat("fish", "count", level))
		var r := _radius("fish", level)
		for n in count:
			var a := orbit_angle + TAU * float(n) / float(count)
			draw_circle(at + Vector2.from_angle(a) * r, Tuning.ORBIT_DRAW_RADIUS, Tuning.ORBIT_COLOUR)
	for s in shots:
		draw_circle(to_local(shot_pos[s]), Tuning.SHOT_DRAW_RADIUS, Tuning.SHOT_COLOURS[shot_kind[s]])
	_draw_fx()


## Instant weapons, drawn from the record `_add_fx` left. Each fades over its
## life so a swipe reads as a swipe rather than a flicker.
func _draw_fx() -> void:
	for f in fx:
		var t: float = clampf(fx_life[f] / maxf(fx_full[f], 0.001), 0.0, 1.0)
		var here := to_local(fx_pos[f])
		match fx_kind[f]:
			Tuning.FX_ARC:
				# The wedge the paw actually swept, so what was hit and what
				# was missed is on screen.
				var half: float = float(Tuning.WEAPONS["paw"]["arc"]) * 0.5
				var mid := fx_to[f].angle()
				var c := Tuning.FX_ARC_COLOUR
				draw_arc(
					here,
					fx_radius[f] * (1.0 - 0.15 * (1.0 - t)),
					mid - half,
					mid + half,
					24,
					Color(c.r, c.g, c.b, c.a * t),
					Tuning.FX_ARC_WIDTH * t,
					true,
				)
			Tuning.FX_RING:
				# A yawn: a ring expanding to the radius it hit.
				var c2 := Tuning.FX_RING_COLOUR
				draw_arc(
					here,
					fx_radius[f] * (1.0 - t),
					0.0,
					TAU,
					40,
					Color(c2.r, c2.g, c2.b, c2.a * t),
					Tuning.FX_RING_WIDTH,
					true,
				)
			Tuning.FX_BOLT:
				var c3 := Tuning.FX_BOLT_COLOUR
				draw_line(
					here,
					to_local(fx_to[f]),
					Color(c3.r, c3.g, c3.b, c3.a * t),
					Tuning.FX_BOLT_WIDTH,
					true,
				)
