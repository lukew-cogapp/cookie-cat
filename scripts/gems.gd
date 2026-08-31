class_name Gems
extends Node2D
## Dropped XP, and the pickups that come with it, in one MultiMesh.
##
## Same shape as `swarm.gd` and for the same reason: a kill drops a gem, so
## there are as many of these as there are enemies, and a scene per gem costs
## more than the gem is worth. Rows here are simpler than a swarm row because
## a gem does nothing but sit still and then fly at the player.

## Three xp tiers, then the pickups. GEM is what most bugs drop; the better
## tiers are rolled from the bug's own `gem_up` chance.
enum Kind { GEM, GEM_GREEN, GEM_RED, HEART, COOKIE }

## Fired on collect, so the world can sparkle and show numbers without this
## layer knowing what a particle is.
signal collected(at: Vector2, of_kind: int, worth: int)

var alive := 0
var pos: Array[Vector2] = []
var kind: Array[int] = []
var value: Array[int] = []
## Set once the magnet has claimed a gem. A claimed gem accelerates at the
## player and never un-claims, so a child who backs off still gets it.
var flying: Array[bool] = []
var speed: Array[float] = []

var _mm: Array[MultiMesh] = []
var _player: Node2D
var _dead: Array[int] = []
var _by_kind: Array[Array] = []
## Consecutive pickups inside GEM_STREAK_GAP; steps the chime up in pitch.
var _streak := 0
var _streak_until := 0.0


func _ready() -> void:
	var q := Tuning.sprite_quad()
	for k in Tuning.GEM_ORDER.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.mesh = q
		mm.instance_count = Tuning.GEM_MAX
		mm.visible_instance_count = 0
		var node := MultiMeshInstance2D.new()
		node.multimesh = mm
		node.texture = load(Tuning.pickup_art(Tuning.GEM_ORDER[k]))
		add_child(node)
		_mm.append(mm)
		_by_kind.append([])
	pos.resize(Tuning.GEM_MAX)
	kind.resize(Tuning.GEM_MAX)
	value.resize(Tuning.GEM_MAX)
	flying.resize(Tuning.GEM_MAX)
	speed.resize(Tuning.GEM_MAX)


func set_player(p: Node2D) -> void:
	_player = p


func drop(at: Vector2, of_kind: int, worth: int) -> void:
	# The oldest gem goes rather than the new drop being lost: the field only
	# fills up during a big fight, which is exactly when the player is earning.
	if alive >= Tuning.GEM_MAX:
		_dead.append(0)
		_compact()
	var i := alive
	alive += 1
	pos[i] = at
	kind[i] = of_kind
	value[i] = worth
	flying[i] = false
	speed[i] = 0.0


func _physics_process(delta: float) -> void:
	if not Run.alive or _player == null:
		return
	var target := _player.global_position
	var pull: float = _player.magnet_radius()
	var pull2 := pull * pull
	var take2 := Tuning.GEM_TAKE_RADIUS * Tuning.GEM_TAKE_RADIUS
	for i in alive:
		var to := target - pos[i]
		var d2 := to.length_squared()
		if not flying[i] and d2 <= pull2:
			flying[i] = true
			# The VS wiggle: a claimed gem darts away first (negative speed on
			# the homing line), then the acceleration hauls it in.
			speed[i] = -Tuning.GEM_DART_SPEED
		if flying[i]:
			speed[i] += Tuning.GEM_FLY_ACCEL * delta
			pos[i] += to.normalized() * speed[i] * delta
			if d2 <= take2 and speed[i] > 0.0:
				_collect(i)
				_dead.append(i)
	_compact()
	_redraw()


func _collect(i: int) -> void:
	if Run.clock > _streak_until:
		_streak = 0
	_streak_until = Run.clock + Tuning.GEM_STREAK_GAP
	_streak += 1
	match kind[i]:
		Kind.GEM:
			Run.add_xp(value[i])
			# Each pickup in a streak chimes a semitone higher: the classic
			# coin-run reward, and it tells a child the streak is a thing.
			var step := mini(_streak - 1, Tuning.GEM_STREAK_CAP)
			Audio.play("pickup", pow(2.0, float(step) * Tuning.GEM_STREAK_SEMITONES / 12.0))
		Kind.HEART:
			_player.heal(float(value[i]))
		Kind.COOKIE:
			# Cookies buy cats between runs; they are banked when the run ends.
			Run.cookies += value[i]
			Audio.play("chest")
	collected.emit(pos[i], kind[i], value[i])


func _compact() -> void:
	if _dead.is_empty():
		return
	_dead.sort()
	_dead.reverse()
	var last := -1
	for i in _dead:
		if i == last:
			continue
		last = i
		alive -= 1
		if i != alive:
			pos[i] = pos[alive]
			kind[i] = kind[alive]
			value[i] = value[alive]
			flying[i] = flying[alive]
			speed[i] = speed[alive]
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
		var s: float = Tuning.pickup_size(Tuning.GEM_ORDER[k])
		for n in rows.size():
			var i: int = rows[n]
			# A slow bob rather than a spin: a spinning heart reads as damage,
			# and a flat sprite turned edge-on disappears.
			var lift := sin(Run.clock * Tuning.GEM_BOB_RATE + float(i)) * Tuning.GEM_BOB
			mm.set_instance_transform_2d(
				n, Transform2D(0.0, Vector2(s, s), 0.0, pos[i] + Vector2(0.0, lift))
			)
