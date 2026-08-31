class_name Props
extends Node2D
## Breakable things scattered on the ground: pots, bushes and boxes in the
## garden; sandcastles, driftwood and buckets on the beach; snowmen, firs and
## ice blocks in the arctic. Which set comes from `Tuning.MAPS[Run.map]`.
##
## They exist to give the ground a reason to be walked across. An empty lawn
## makes every direction identical, so a child has nothing to aim at between
## waves; a pot worth a heart is a small errand.
##
## Each prop is a `Prop` node, not a row in parallel arrays like the swarm. The
## field around them is still the same seeded grid of cells `ground.gd` and
## `traps.gd` use, and for the same reason: the cat is never walled in, so the
## field follows it, and a cell is seeded by its own coordinates so walking back
## finds the same garden.
##
## They are hit by the same weapon queries as before: `world.gd` passes each
## weapon's damage through `damage_near`, so anything that hurts a bug breaks a
## pot without a single weapon knowing props exist.

signal broke(at: Vector2, kind: int)

var _rng := RandomNumberGenerator.new()
## Cells already filled, so a cell is never filled twice.
var _filled: Dictionary = {}
## Where the cat started, kept clear of props.
var _clear_around := Vector2.ZERO
var _player: Node2D
## The map's prop table, read once at load: a map cannot change mid-run.
var _table: Array = []


func _ready() -> void:
	_table = Tuning.map_info(Run.map)["props"]
	_rng.seed = Tuning.PROP_SEED


func set_player(p: Node2D) -> void:
	_player = p


## How many props are standing. Was the high-water mark of an array; now it is
## simply how many children there are, which cannot disagree with the tree.
func count() -> int:
	return get_child_count()


func at(n: int) -> Prop:
	return get_child(n) as Prop


## Fills the garden around a point, and remembers which cells it has filled.
##
## The field is a fixed grid of cells, not a patch that follows the cat: a cell
## is seeded by its own coordinates, so walking into new ground fills it in and
## walking back finds it exactly as it was. The previous version re-scattered
## the WHOLE field every `PROP_REFILL_DISTANCE`, which teleported every pot on
## screen at once and reads to a player as the world jumping.
func scatter(clear_around: Vector2) -> void:
	for c in get_children():
		_drop(c)
	_filled.clear()
	_clear_around = clear_around
	_refill_around(clear_around)


## Fills any cell near `around` that has not been filled yet, and forgets props
## that have fallen far behind so the tree never grows without bound.
func _refill_around(around: Vector2) -> void:
	var cell := Tuning.PROP_CELL
	var reach := int(ceil(Tuning.PROP_REFILL_DISTANCE / cell))
	var here := Vector2i(floori(around.x / cell), floori(around.y / cell))
	_cull_far(around)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := here + Vector2i(dx, dy)
			if _filled.has(c):
				continue
			_filled[c] = true
			_fill_cell(c)


## One cell's worth of props, seeded by the cell so it is always the same.
func _fill_cell(c: Vector2i) -> void:
	_rng.seed = Tuning.PROP_SEED + c.x * 73856093 + c.y * 19349663
	var cell := Tuning.PROP_CELL
	for _n in Tuning.PROP_PER_CELL:
		if count() >= Tuning.PROP_COUNT:
			return
		var p := Vector2(
			(float(c.x) + _rng.randf()) * cell,
			(float(c.y) + _rng.randf()) * cell,
		)
		# Never on top of where the cat starts, or the run opens with a pot in
		# the player's face.
		if p.distance_to(_clear_around) < Tuning.PROP_CLEAR_RADIUS:
			continue
		if _too_close(p):
			continue
		var k := _rng.randi_range(0, _table.size() - 1)
		add_child(Prop.make(k, _table, p))


## Forgets props far enough away to be out of sight, so a long walk cannot grow
## the tree without bound. Their cells are forgotten too, so walking back
## rebuilds them from the same seed and the garden looks unchanged.
##
## Dropped rather than compacted: with nodes there is no index to move, so the
## whole `_dead` and `_compact` dance the swarm needs is gone from here.
func _cull_far(around: Vector2) -> void:
	var far := Tuning.PROP_FORGET_DISTANCE * Tuning.PROP_FORGET_DISTANCE
	for c in get_children():
		if (c as Prop).position.distance_squared_to(around) > far:
			_drop(c)
	var cell := Tuning.PROP_CELL
	var reach := int(ceil(Tuning.PROP_FORGET_DISTANCE / cell))
	var here := Vector2i(floori(around.x / cell), floori(around.y / cell))
	for k: Vector2i in _filled.keys():
		if absi(k.x - here.x) > reach or absi(k.y - here.y) > reach:
			_filled.erase(k)


## Removed as well as freed. `queue_free` leaves the node in the tree until the
## end of the frame, so `count()` would still see it and `_fill_cell`'s cap would
## read stale; removing first keeps the count honest, and the deferred free is
## safe to call from inside a signal handler's call stack where an immediate
## `free()` is not.
func _drop(c: Node) -> void:
	remove_child(c)
	c.queue_free()


## Two props on one spot read as one prop that takes twice the hits.
func _too_close(p: Vector2) -> bool:
	for c in get_children():
		var d := (c as Prop).position.distance_squared_to(p)
		if d < Tuning.PROP_SPACING * Tuning.PROP_SPACING:
			return true
	return false


func _physics_process(delta: float) -> void:
	if not Run.alive:
		return
	_refill_around(_player.global_position)
	for c in get_children():
		(c as Prop).tick(delta)


## The nearest prop, or null. Weapons fall back to this when no bug is in range,
## so a shot in a quiet moment goes into a pot rather than into empty grass.
##
## Returns the prop rather than an index: an index into a list of children is
## only true until one is freed, and the caller used to read a position back out
## of the field with it.
func nearest(point: Vector2, radius: float) -> Prop:
	var best: Prop = null
	var best_d := radius * radius
	for c in get_children():
		var p := c as Prop
		var d := p.position.distance_squared_to(point)
		if d <= best_d:
			best_d = d
			best = p
	return best


## Damages every prop within `radius`. Weapons call this through `world.gd`
## rather than knowing about props, so a new weapon breaks pots for free.
##
## The children are snapshotted before anything is damaged, because `broke` runs
## the world's drop handler synchronously: a handler that added or removed a prop
## would otherwise move the ones this walk has not reached yet.
##
## A broken prop leaves the tree before `broke` is emitted, so nothing the
## handler does can find a half-dead pot, and its position and kind are read out
## first. `Prop.damage` reports the break once and only once, which is what stops
## two overlapping areas of effect paying out one pot twice.
func damage_near(point: Vector2, radius: float, amount: float) -> void:
	var r2 := radius * radius
	var kids := get_children()
	for c in kids:
		var p := c as Prop
		if p.position.distance_squared_to(point) > r2:
			continue
		if not p.damage(amount):
			continue
		var at := p.position
		var kind := p.kind
		_drop(p)
		broke.emit(at, kind)
		Audio.play("pop")


## What a prop drops, as a Gems.Kind. Mostly nothing: a heart from every pot
## would make the hearts meaningless and the run trivial.
func roll_drop(k: int) -> int:
	var d: Dictionary = _table[k]
	var r := _rng.randf()
	if r < float(d["heart_chance"]):
		return Gems.Kind.HEART
	if r < float(d["heart_chance"]) + float(d["cookie_chance"]):
		return Gems.Kind.COOKIE
	return Gems.Kind.GEM


func xp_of(k: int) -> int:
	return int(_table[k]["xp"])
