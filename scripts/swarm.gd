class_name Swarm
extends Node2D
## Every enemy in the run, drawn and moved by this one node.
##
## Hundreds of enemies as hundreds of CharacterBody2Ds is what kills this
## genre in Godot: each one costs a node, a script instance, a physics body
## the server solves, and a `_physics_process` call. None of that buys
## anything here, because enemies do not need to collide with each other or
## with the world. They walk at the player through empty grass.
##
## So an enemy is a row in parallel arrays, moved in one loop, drawn with one
## `MultiMesh` in one draw call, and collided by distance checks against the
## handful of things that actually matter: the player, and the shots.
## `_draw` is not used; a MultiMesh survives a moving camera without redrawing.

## Enemy kinds, indices into Tuning.ENEMIES.
enum Kind { GRUB, BEETLE, SNAIL, WASP, SLIME, BIG, SPIDER, DUNG }

var alive := 0
var pos: Array[Vector2] = []
var hp: Array[float] = []
var kind: Array[int] = []
## Seconds left of the hit flash, and of being knocked back.
var flash: Array[float] = []
var knock: Array[Vector2] = []
## When each row may next touch the player. Contact damage is on a per-enemy
## cooldown, not a global one, or standing in a crowd is survivable.
var touch: Array[float] = []
## Seconds of scale-in left after spawning, so nothing appears at full size.
var grow: Array[float] = []
var _facing_left: Array[bool] = []
## Seconds left of walking slowly, and how slowly. Set by the milk puddle; kept
## per row rather than recomputed, so a bug that leaves the puddle slows back up
## over SLOW_LINGER instead of snapping to full speed at the edge.
var slow_for: Array[float] = []
var slow_by: Array[float] = []
## Per-row phase for the spider's scuttle, so a pack does not stop and start
## in unison.
var gait: Array[float] = []
## Seconds until a dung beetle's next lob. Meaningless on other kinds.
var aim: Array[float] = []
## A permanent walk multiplier per row, 1.0 for anything spawned normally. The
## director sets it above 1.0 for a rush, and it multiplies the kind's listed
## speed rather than replacing it, so the no-bug-outruns-the-cat rule is one
## check on the product and not one per spawner.
var hurry: Array[float] = []

## Poop balls in flight, pooled like the rows above. The dung beetle is the
## first enemy that hurts the cat without touching it, so its shots live here
## rather than growing a node apiece.
var poop_pos: Array[Vector2] = []
var poop_vel: Array[Vector2] = []
var poop_life: Array[float] = []
var poops := 0
var _poop_dead: Array[int] = []
var _poop_mm: MultiMesh

## Webs the spiders have left. Pooled rows drawn by one MultiMesh, like the
## poop: a web is a position and a countdown, and nothing else.
var web_pos: Array[Vector2] = []
var web_life: Array[float] = []
var webs := 0
var _web_dead: Array[int] = []
var _web_mm: MultiMesh

## One MultiMesh per kind, so each kind draws its own texture in its own
## draw call. Six calls for any number of bugs, and a kind is told apart by
## its art rather than by a tint over one shared sprite.
var _mm: Array[MultiMesh] = []
var _player: Node2D
## Row indices per kind, refilled each frame by `_redraw`. Kept as members so
## a frame allocates nothing.
var _by_kind: Array[Array] = []
var _rng := RandomNumberGenerator.new()
## Rows to remove after a pass. Collected and applied by `_compact` rather
## than removed mid-loop, which would renumber every row a shot is holding.
var _dead: Array[int] = []


func _ready() -> void:
	_rng.seed = Tuning.SWARM_SEED
	var quad := _quad()
	for k in Tuning.ENEMY_TEXTURES.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = quad
		mm.instance_count = Tuning.ENEMY_MAX
		mm.visible_instance_count = 0
		var node := MultiMeshInstance2D.new()
		node.multimesh = mm
		node.texture = load(Tuning.ENEMY_TEXTURES[k])
		# One property per kind, not per bug: the cat keeps the brightest pixels
		# on screen. The hit flash still blows past this.
		node.modulate = Tuning.ENEMY_DIM
		add_child(node)
		_mm.append(mm)
		_by_kind.append([])
	_grow(Tuning.ENEMY_MAX)
	# The poop pool: one more MultiMesh, sized once like the rows.
	_poop_mm = MultiMesh.new()
	_poop_mm.transform_format = MultiMesh.TRANSFORM_2D
	_poop_mm.mesh = quad
	_poop_mm.instance_count = Tuning.POOP_MAX
	_poop_mm.visible_instance_count = 0
	var poop_node := MultiMeshInstance2D.new()
	poop_node.multimesh = _poop_mm
	poop_node.texture = load(Tuning.POOP_ART)
	add_child(poop_node)
	# The web pool, the same shape again.
	_web_mm = MultiMesh.new()
	_web_mm.transform_format = MultiMesh.TRANSFORM_2D
	_web_mm.use_colors = true
	_web_mm.mesh = quad
	_web_mm.instance_count = Tuning.WEB_MAX
	_web_mm.visible_instance_count = 0
	var web_node := MultiMeshInstance2D.new()
	web_node.multimesh = _web_mm
	web_node.texture = load(Tuning.WEB_ART)
	# Under the bugs: a web is ground, not an actor.
	add_child(web_node)
	move_child(web_node, 0)
	web_pos.resize(Tuning.WEB_MAX)
	web_life.resize(Tuning.WEB_MAX)

	poop_pos.resize(Tuning.POOP_MAX)
	poop_vel.resize(Tuning.POOP_MAX)
	poop_life.resize(Tuning.POOP_MAX)


## The arrays are sized once and reused for the whole run: a spawn writes into
## a row rather than appending, so a wave of fifty allocates nothing.
func _grow(to: int) -> void:
	pos.resize(to)
	hp.resize(to)
	kind.resize(to)
	flash.resize(to)
	knock.resize(to)
	touch.resize(to)
	grow.resize(to)
	_facing_left.resize(to)
	slow_for.resize(to)
	slow_by.resize(to)
	gait.resize(to)
	aim.resize(to)
	hurry.resize(to)


func set_player(p: Node2D) -> void:
	_player = p


func spawn(at: Vector2, of_kind: int, at_pace := 1.0) -> void:
	if alive >= Tuning.ENEMY_MAX:
		return
	var i := alive
	alive += 1
	pos[i] = at
	kind[i] = of_kind
	hp[i] = Tuning.enemy_hp(of_kind, Run.clock)
	flash[i] = 0.0
	knock[i] = Vector2.ZERO
	touch[i] = 0.0
	grow[i] = Tuning.SPAWN_GROW_TIME
	_facing_left[i] = false
	slow_for[i] = 0.0
	slow_by[i] = 1.0
	gait[i] = _rng.randf() * Tuning.SPIDER_SCUTTLE_CYCLE
	aim[i] = Tuning.DUNG_FIRE_COOLDOWN
	hurry[i] = at_pace


func _physics_process(delta: float) -> void:
	if not Run.alive or _player == null:
		return
	var target := _player.global_position
	var cull := Tuning.ENEMY_CULL_DISTANCE * Tuning.ENEMY_CULL_DISTANCE
	for i in alive:
		var k := kind[i]
		var to := target - pos[i]
		var d := to.length()
		# Walked off the far side of the world. Nothing sees it again, and a
		# row spent tracking it is a row a spawn cannot use.
		if d * d > cull:
			_dead.append(i)
			continue
		var speed := Tuning.enemy_speed(k) * hurry[i]
		# The two flavoured walkers. The spider advances in bursts; the dung
		# beetle stands off and lobs. Both still obey knockback and slows.
		if k == Kind.SPIDER:
			speed *= Tuning.spider_pace(Run.clock + gait[i])
			# A web every so often as it goes. `aim` is the per-row timer the
			# dung beetle fires on, and a spider never fires, so it is free.
			aim[i] -= delta
			if aim[i] <= 0.0:
				aim[i] = Tuning.WEB_EVERY
				_lay_web(pos[i])
		elif k == Kind.DUNG:
			if d < Tuning.DUNG_STAND_RANGE:
				speed = 0.0
			_dung_attack(i, d, target, delta)
		if slow_for[i] > 0.0:
			slow_for[i] = maxf(slow_for[i] - delta, 0.0)
			speed *= slow_by[i]
		var step := to / maxf(d, 0.001) * speed
		if knock[i] != Vector2.ZERO:
			step += knock[i]
			knock[i] = knock[i].lerp(Vector2.ZERO, Tuning.KNOCKBACK_DECAY * delta)
			if knock[i].length_squared() < 1.0:
				knock[i] = Vector2.ZERO
		pos[i] += step * delta
		if absf(to.x) > Tuning.ENEMY_FLIP_DEADZONE:
			_facing_left[i] = to.x < 0.0
		if flash[i] > -Tuning.HIT_FLASH_GAP:
			flash[i] = maxf(flash[i] - delta, -Tuning.HIT_FLASH_GAP)
		if touch[i] > 0.0:
			touch[i] = maxf(touch[i] - delta, 0.0)
		if grow[i] > 0.0:
			grow[i] = maxf(grow[i] - delta, 0.0)
		# Contact. The player's own radius is folded into the constant, so
		# this is one distance test rather than a physics query.
		if d < Tuning.enemy_radius(k) + Tuning.PLAYER_RADIUS and touch[i] <= 0.0:
			touch[i] = Tuning.ENEMY_TOUCH_COOLDOWN
			_player.hurt(Tuning.enemy_damage(k))
	_tick_poops(delta)
	_tick_webs(delta)
	_compact()
	_redraw()


## Damage one row. Returns true if it died, so a shot can count its kill.
func damage(i: int, amount: float, from: Vector2) -> bool:
	if i < 0 or i >= alive:
		return false
	hp[i] -= amount
	# Only re-flash once the last one has finished. A puddle or an aura damages
	# every frame, and refreshing the timer each time held a tanky bug solid
	# white for as long as it stood there, which loses the silhouette that
	# tells the kinds apart.
	var fresh := flash[i] <= -Tuning.HIT_FLASH_GAP
	if fresh:
		flash[i] = Tuning.HIT_FLASH_TIME
	var away := (pos[i] - from).normalized()
	knock[i] = away * Tuning.enemy_knockback(kind[i])
	if hp[i] > 0.0:
		# Only on a fresh flash: a bug sitting in a puddle is damaged every
		# frame, and a cue per frame per bug is a drone.
		if fresh:
			Audio.play("hit")
		return false
	Audio.play("pop")
	_dead.append(i)
	return true


## Shoves everything near a point away from it. Called when the cat is hit,
## so the hit itself buys room to escape rather than only invulnerability.
func push_from(point: Vector2, radius: float, force: float) -> void:
	var r2 := radius * radius
	for i in alive:
		var off := pos[i] - point
		var d2 := off.length_squared()
		if d2 > r2:
			continue
		# A bug exactly on the cat has no direction to be pushed; pick one.
		var dir := off.normalized() if d2 > 0.01 else Vector2.from_angle(float(i))
		knock[i] = dir * force
		# It may not touch again until it has been pushed clear, or it lands a
		# second hit the moment mercy ends and the push bought nothing.
		touch[i] = Tuning.ENEMY_TOUCH_COOLDOWN


## One dung beetle's countdown to a lob. Out of range the timer is held at the
## wind-up, so walking into range always shows a full telegraph before
## anything flies.
func _dung_attack(i: int, d: float, target: Vector2, delta: float) -> void:
	if d > Tuning.DUNG_FIRE_RANGE:
		aim[i] = maxf(aim[i], Tuning.DUNG_TELEGRAPH)
		return
	aim[i] -= delta
	if aim[i] > 0.0:
		return
	aim[i] = Tuning.DUNG_FIRE_COOLDOWN
	spawn_poop(pos[i], (target - pos[i]).normalized() * Tuning.POOP_SPEED)


## Fired at where the cat was, never homing: a ball that turns cannot be
## dodged by walking, and walking away is the one skill the game asks for.
func spawn_poop(at: Vector2, vel: Vector2) -> void:
	if poops >= Tuning.POOP_MAX:
		return
	var p := poops
	poops += 1
	poop_pos[p] = at
	poop_vel[p] = vel
	poop_life[p] = Tuning.POOP_LIFE


## Drops a web where a spider is standing, on its own cooldown.
func _lay_web(at: Vector2) -> void:
	if webs >= Tuning.WEB_MAX:
		return
	var w := webs
	webs += 1
	web_pos[w] = at
	web_life[w] = Tuning.WEB_LIFE


## How much of its speed the cat keeps at this point, and for how long. The
## world asks; the swarm owns the webs.
func web_slow_at(point: Vector2) -> float:
	var r2 := Tuning.WEB_RADIUS * Tuning.WEB_RADIUS
	for w in webs:
		if web_pos[w].distance_squared_to(point) <= r2:
			return Tuning.WEB_SLOW
	return 1.0


func _tick_webs(delta: float) -> void:
	for w in webs:
		web_life[w] -= delta
		if web_life[w] <= 0.0:
			_web_dead.append(w)
	if not _web_dead.is_empty():
		_web_dead.sort()
		_web_dead.reverse()
		var last := -1
		for w in _web_dead:
			if w == last:
				continue
			last = w
			webs -= 1
			if w != webs:
				web_pos[w] = web_pos[webs]
				web_life[w] = web_life[webs]
		_web_dead.clear()
	_web_mm.visible_instance_count = webs
	for w in webs:
		var fade: float = clampf(web_life[w] / Tuning.WEB_FADE, 0.0, 1.0)
		_web_mm.set_instance_transform_2d(
			w,
			Transform2D(
				0.0, Vector2(Tuning.WEB_DRAW_SIZE, Tuning.WEB_DRAW_SIZE), 0.0, web_pos[w]
			)
		)
		_web_mm.set_instance_color(w, Color(1.0, 1.0, 1.0, fade))


func _tick_poops(delta: float) -> void:
	for p in poops:
		poop_pos[p] += poop_vel[p] * delta
		poop_life[p] -= delta
		if poop_life[p] <= 0.0:
			_poop_dead.append(p)
			continue
		# A hit goes through `hurt`, so mercy time gates it like a touch. The
		# ball still splats either way: one that sails through a blinking cat
		# would read as a miss the game refused to count.
		if (
			_player != null
			and poop_pos[p].distance_to(_player.global_position)
			< Tuning.POOP_HIT_RADIUS + Tuning.PLAYER_RADIUS
		):
			_player.hurt(Tuning.POOP_DAMAGE)
			_poop_dead.append(p)
	_compact_poops()


## Swap-removal, under the same two rules as `_compact`.
func _compact_poops() -> void:
	if _poop_dead.is_empty():
		return
	_poop_dead.sort()
	_poop_dead.reverse()
	var last := -1
	for p in _poop_dead:
		if p == last:
			continue
		last = p
		poops -= 1
		if p != poops:
			poop_pos[p] = poop_pos[poops]
			poop_vel[p] = poop_vel[poops]
			poop_life[p] = poop_life[poops]
	_poop_dead.clear()


## Slows one row, for as long as the puddle keeps refreshing it. The strongest
## slow wins while two puddles overlap, rather than the last one applied.
func slow(i: int, by: float, secs: float) -> void:
	if i < 0 or i >= alive:
		return
	if slow_for[i] <= 0.0 or by < slow_by[i]:
		slow_by[i] = by
	slow_for[i] = maxf(slow_for[i], secs)


## Rows within `radius` of a point, nearest first. The one query weapons use.
## Fills a caller-owned array so a weapon firing every frame allocates nothing.
func near(point: Vector2, radius: float, out: Array[int]) -> void:
	out.clear()
	var r2 := radius * radius
	for i in alive:
		if pos[i].distance_squared_to(point) <= r2:
			out.append(i)


## The nearest row, or -1. Weapons that fire one shot want this, not a list.
func nearest(point: Vector2, radius: float) -> int:
	var best := -1
	var best_d := radius * radius
	for i in alive:
		var d := pos[i].distance_squared_to(point)
		if d <= best_d:
			best_d = d
			best = i
	return best


## Swap-removes every dead row. Called once per pass, after the loop, because
## a swap moves the last row into the hole and a mid-loop swap would skip it.
func _compact() -> void:
	if _dead.is_empty():
		return
	# Descending, so each swap only ever moves rows this pass has finished
	# with. Ascending would move a row that is itself still queued to die.
	_dead.sort()
	_dead.reverse()
	var last := -1
	for i in _dead:
		# One row can be queued twice: killed by two shots in a frame, or
		# killed and culled. Dropping it twice would delete a live enemy.
		if i == last:
			continue
		last = i
		alive -= 1
		if i != alive:
			pos[i] = pos[alive]
			hp[i] = hp[alive]
			kind[i] = kind[alive]
			flash[i] = flash[alive]
			knock[i] = knock[alive]
			touch[i] = touch[alive]
			grow[i] = grow[alive]
			_facing_left[i] = _facing_left[alive]
			slow_for[i] = slow_for[alive]
			slow_by[i] = slow_by[alive]
			gait[i] = gait[alive]
			aim[i] = aim[alive]
			hurry[i] = hurry[alive]
	_dead.clear()


func _redraw() -> void:
	for k in _by_kind.size():
		_by_kind[k].clear()
	for i in alive:
		_by_kind[kind[i]].append(i)
	for k in _mm.size():
		var rows: Array = _by_kind[k]
		var mm := _mm[k]
		mm.visible_instance_count = rows.size()
		var s := Tuning.enemy_radius(k) * 2.0
		# The art is square, so one scale keeps every bug's own proportions;
		# scaling x and y apart stretched the snail, whose drawing is wider
		# than it is tall inside the same 16x16 grid.
		for n in rows.size():
			var i: int = rows[n]
			# Bugs face the way they walk, like the cat: art is drawn facing
			# right, so a bug heading left is mirrored by a negative x scale.
			var face := -1.0 if _facing_left[i] else 1.0
			# A tint plus a squash while flashing: the flash says hit, the
			# squash says hit HARD, and both cost only this transform.
			var c := Color.WHITE
			var squash := 0.0
			if flash[i] > 0.0:
				c = Tuning.HIT_FLASH_COLOUR
				squash = flash[i] / Tuning.HIT_FLASH_TIME * Tuning.HIT_SQUASH
			elif k == Kind.DUNG and aim[i] < Tuning.DUNG_TELEGRAPH:
				# The wind-up shiver: the lob is announced before anything
				# flies, because a child cannot dodge a surprise.
				squash = sin(Run.clock * Tuning.DUNG_WOBBLE_RATE) * Tuning.DUNG_WOBBLE
			var g := 1.0 - grow[i] / Tuning.SPAWN_GROW_TIME
			mm.set_instance_transform_2d(
				n,
				Transform2D(
					0.0, Vector2(s * face * (1.0 + squash) * g, s * (1.0 - squash) * g), 0.0, pos[i]
				)
			)
			mm.set_instance_color(n, c)
	_poop_mm.visible_instance_count = poops
	for p in poops:
		# Rolls along its direction of travel, so the ball reads as bowled.
		var roll := (Tuning.POOP_LIFE - poop_life[p]) * Tuning.POOP_SPIN
		if poop_vel[p].x < 0.0:
			roll = -roll
		_poop_mm.set_instance_transform_2d(
			p,
			Transform2D(
				roll,
				Vector2(Tuning.POOP_DRAW_SIZE, Tuning.POOP_DRAW_SIZE),
				0.0,
				poop_pos[p]
			)
		)


## A unit quad centred on the origin. The texture supplies the shape; every
## enemy is the same mesh so they can share one draw call.
func _quad() -> ArrayMesh:
	return Tuning.sprite_quad()
