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
var _rng := RandomNumberGenerator.new()

signal boss_arrived


func setup(swarm: Swarm, player: Node2D) -> void:
	_swarm = swarm
	_player = player
	_rng.seed = Tuning.SWARM_SEED
	_bosses_done.clear()
	_next_spawn = 0.0


func _physics_process(delta: float) -> void:
	if not Run.alive or _player == null:
		return
	var wave := Tuning.wave_for(Run.clock)
	_check_boss()
	# Top up to the quota first: the quota is what fills the screen, and the
	# interval only decides how lumpy the filling looks.
	var quota := int(wave["min_alive"]) - _swarm.alive
	if quota > 0:
		for _i in mini(quota, Tuning.SPAWN_BURST_MAX):
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
	_swarm.spawn(_ring_point(), Swarm.Kind.BIG)
	boss_arrived.emit()
