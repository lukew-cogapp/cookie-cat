class_name Director
extends Node
## Decides what arrives and when, from the wave table in `Tuning.WAVES`.
##
## The clock is the difficulty curve. There is no other input: no rubber
## banding on how well the player is doing, and no scaling by player level.
## A child who levels fast should feel it, and a wave table is also the one
## kind of difficulty that can be read and retuned without playing.

var _swarm: Swarm
var _player: Node2D
var _next_spawn := 0.0
## Boss minutes already used, so one boss arrives per minute rather than one
## per frame of that minute.
var _bosses_done: Array[int] = []
## Where the pending boss will walk in, and seconds until it does. Negative
## means none pending: the boss is announced before it exists, so a child is
## never surprise-bitten by the biggest bug in the game.
var _boss_pos := Vector2.ZERO
var _boss_in := -1.0
## Fractional spawns owed by the quota top-up, so its rate is independent of
## the frame rate.
var _refill_credit := 0.0
var _rng := RandomNumberGenerator.new()

signal boss_arrived(at: Vector2)


func setup(swarm: Swarm, player: Node2D) -> void:
	_swarm = swarm
	_player = player
	_rng.seed = Tuning.SWARM_SEED
	_bosses_done.clear()
	_next_spawn = 0.0
	_boss_in = -1.0
	_refill_credit = 0.0


func _physics_process(delta: float) -> void:
	if not Run.alive or _player == null:
		return
	var wave := Tuning.wave_for(Run.clock)
	_check_boss()
	if _boss_in >= 0.0:
		_boss_in -= delta
		if _boss_in < 0.0:
			_swarm.spawn(_boss_pos, Swarm.Kind.BIG)
	# Top up towards the quota, but at a limited rate. The quota is what fills
	# the screen; unthrottled it also refills every kill in the same frame, so
	# clearing a crowd changed nothing and the pressure only ever rose. A probe
	# fleeing an unthrottled quota died at 32 seconds.
	_refill_credit = minf(
		_refill_credit + Tuning.SPAWN_REFILL_RATE * delta, float(Tuning.SPAWN_BURST_MAX)
	)
	var quota := int(wave["min_alive"]) - _swarm.alive
	while quota > 0 and _refill_credit >= 1.0:
		_refill_credit -= 1.0
		quota -= 1
		_spawn_one(wave)
	_next_spawn -= delta
	if _next_spawn <= 0.0:
		_next_spawn = float(wave["interval"])
		for _i in Tuning.SPAWN_PER_TICK:
			_spawn_one(wave)


func _spawn_one(wave: Dictionary) -> void:
	var kinds: Array = wave["kinds"]
	var kind: int = kinds[_rng.randi_range(0, kinds.size() - 1)]
	_swarm.spawn(_ring_point(), kind)


## A point on a ring just off screen, so nothing appears in front of the cat.
func _ring_point() -> Vector2:
	var a := _rng.randf() * TAU
	return _player.global_position + Vector2.from_angle(a) * Tuning.SPAWN_RING


func _check_boss() -> void:
	var minute := int(Run.clock / 60.0)
	if minute not in Tuning.BOSS_MINUTES or minute in _bosses_done:
		return
	_bosses_done.append(minute)
	_boss_pos = _ring_point()
	_boss_in = Tuning.BOSS_TELEGRAPH_TIME
	boss_arrived.emit(_boss_pos)
