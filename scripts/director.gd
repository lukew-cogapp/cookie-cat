class_name Director
extends Node
## Decides what arrives and when, from the wave table in `Tuning.WAVES`.
##
## The clock is the difficulty curve. There is no other input: no rubber
## banding on how well the player is doing, and no scaling by player level.
## A child who levels fast should feel it, and a wave table is also the one
## kind of difficulty that can be read and retuned without playing.

signal boss_arrived(at: Vector2)
signal rush_arrived(at: Vector2)

var _swarm: Swarm
var _player: Node2D
var _next_spawn := 0.0
## Boss minutes already used, so one boss arrives per minute rather than one
## per frame of that minute.
var _bosses_done: Array[int] = []
## Where the pending boss will walk in, and seconds until it does. Negative
## means none pending: the boss is announced before it exists, so a child is
## never surprise-bitten by the biggest bug in the game.
## The direction a boss is coming from, not the point. The cat walks during the
## telegraph, so a point picked at announce time is `PLAYER_SPEED` times
## `BOSS_TELEGRAPH_TIME` out of date by the time it is used: nearly half the
## spawn ring, which can put the boss on screen or on top of the cat. The rush
## keeps an angle for the same reason.
var _boss_from := 0.0
var _boss_in := -1.0
## Seconds until the next rush, and where the pending one will come from.
## `_rush_in` negative means none pending, the same shape as the boss above:
## a pack of quick bugs is announced before it exists for the same reason the
## boss is.
var _rush_next := 0.0
var _rush_from := Vector2.ZERO
var _rush_in := -1.0
## Fractional spawns owed by the quota top-up, so its rate is independent of
## the frame rate.
var _refill_credit := 0.0
var _rng := RandomNumberGenerator.new()


func setup(swarm: Swarm, player: Node2D) -> void:
	_swarm = swarm
	_player = player
	_rng.seed = Tuning.SWARM_SEED
	_bosses_done.clear()
	_next_spawn = 0.0
	_boss_in = -1.0
	_rush_in = -1.0
	_rush_next = Tuning.RUSH_AFTER + _roll_rush_gap()
	_refill_credit = 0.0


func _physics_process(delta: float) -> void:
	if not Run.alive or _player == null:
		return
	var wave := Tuning.wave_for(Run.clock)
	_check_boss()
	if _boss_in >= 0.0:
		_boss_in -= delta
		if _boss_in < 0.0:
			var at := _player.global_position + Vector2.from_angle(_boss_from) * Tuning.SPAWN_RING
			_swarm.spawn(at, Swarm.Kind.BIG)
	_check_rush(delta)
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


## Rushes are on a rolled countdown from the clock alone. Nothing here reads
## the player's level or how the run is going.
func _check_rush(delta: float) -> void:
	if _rush_in >= 0.0:
		_rush_in -= delta
		if _rush_in < 0.0:
			_spawn_rush()
		return
	if Run.clock < Tuning.RUSH_AFTER or Run.clock < _rush_next:
		return
	_rush_next = Run.clock + _roll_rush_gap()
	_rush_from = _ring_point()
	_rush_in = Tuning.RUSH_TELEGRAPH_TIME
	rush_arrived.emit(_rush_from)


func _roll_rush_gap() -> float:
	return _rng.randf_range(Tuning.RUSH_GAP_MIN, Tuning.RUSH_GAP_MAX)


## The pack, spread over one arc of the ring around the announced spot, so it
## arrives as a crowd from one side with the rest of the compass to run into.
func _spawn_rush() -> void:
	var from := (_rush_from - _player.global_position).angle()
	for _n in Tuning.rush_count(Run.clock):
		var a := from + _rng.randf_range(-Tuning.RUSH_ARC, Tuning.RUSH_ARC) * 0.5
		var r := Tuning.SPAWN_RING + _rng.randf_range(0.0, Tuning.RUSH_RING_JITTER)
		var at := _player.global_position + Vector2.from_angle(a) * r
		_swarm.spawn(at, Tuning.RUSH_KIND, Tuning.RUSH_HURRY)


func _check_boss() -> void:
	var minute := int(Run.clock / 60.0)
	if minute not in Tuning.BOSS_MINUTES or minute in _bosses_done:
		return
	_bosses_done.append(minute)
	_boss_from = _rng.randf() * TAU
	_boss_in = Tuning.BOSS_TELEGRAPH_TIME
	# The telegraph still points at where the boss would arrive right now, which
	# is what the player needs to see; the spawn recomputes it on the frame.
	boss_arrived.emit(
		_player.global_position + Vector2.from_angle(_boss_from) * Tuning.SPAWN_RING
	)
