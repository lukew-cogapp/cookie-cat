class_name Traps
extends Node2D
## Holes in the ground: a pond in the garden, a dug pit on the beach, a hole in
## the ice in the arctic. Which one comes from `Tuning.MAPS[Run.map]`.
##
## They are the only thing in the game that hurts the cat without being alive,
## and they hurt hard: `TRAP_DAMAGE` is half the bar, so walking into one at
## half health or less ends the run. That is deliberate. Every other threat
## chases, which a child answers by walking away; a trap sits still and is
## answered by looking. It is the one hazard that rewards reading the ground.
##
## Bugs ignore them. A trap the swarm could fall into would turn into a weapon,
## and the point is that the ground itself is not always safe.
##
## Each hole is a `Trap` node, not a row in parallel arrays like the swarm. The
## field around it is still the same seeded grid of cells `ground.gd` and
## `props.gd` use, and for the same reason: the cat is never walled in, so the
## field follows it, and a cell is seeded by its own coordinates so walking back
## finds the same pond.

signal fell_in(at: Vector2)

var _art: Texture2D
var _rng := RandomNumberGenerator.new()
## Cells already filled, so a cell is never filled twice.
var _filled: Dictionary[Vector2i, bool] = {}
## Where the cat started, kept clear of holes.
## Where the cat started, so no hole opens under it. Fixed for the whole run:
## moving it would reject every candidate near wherever the cat last crossed a
## refill boundary, and those cells are marked filled and never reconsidered, so
## the ground ahead quietly runs out of holes.
var _clear_around := Vector2.ZERO
## Where the field was last topped up, which is what does move with the cat.
var _last_refill := Vector2.ZERO
var _player: Node2D
## Seconds until any trap can bite again. One hole cannot chain-hit across the
## frames the cat spends climbing out of it.
var _cooldown := 0.0


func _ready() -> void:
	_art = load(String(Tuning.map_info(Run.map)["trap"]))


func set_player(p: Node2D) -> void:
	_player = p


## How many holes are in the field. Was the high-water mark of an array; now it
## is simply how many children there are, which cannot disagree with the tree.
func count() -> int:
	return get_child_count()


func at(n: int) -> Trap:
	return get_child(n) as Trap


func scatter(clear_around: Vector2) -> void:
	for c in get_children():
		_drop(c)
	_filled.clear()
	_clear_around = clear_around
	_last_refill = clear_around
	_refill_around(clear_around)


func _refill_around(around: Vector2) -> void:
	var cell := Tuning.TRAP_CELL
	var reach := int(ceil(Tuning.TRAP_REFILL_DISTANCE / cell))
	var here := Vector2i(floori(around.x / cell), floori(around.y / cell))
	_cull_far(around)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := here + Vector2i(dx, dy)
			if _filled.has(c):
				continue
			_filled[c] = true
			_fill_cell(c)


## One cell's worth, seeded by the cell so it is always the same field.
func _fill_cell(c: Vector2i) -> void:
	_rng.seed = Tuning.TRAP_SEED + c.x * 73856093 + c.y * 19349663
	var cell := Tuning.TRAP_CELL
	for _n in Tuning.TRAP_PER_CELL:
		if count() >= Tuning.TRAP_COUNT:
			return
		var p := Vector2(
			(float(c.x) + _rng.randf()) * cell,
			(float(c.y) + _rng.randf()) * cell,
		)
		# A trap the cat is standing on when the run opens would take half the
		# bar before the child had touched a key.
		if p.distance_to(_clear_around) < Tuning.TRAP_CLEAR_RADIUS:
			continue
		if _too_close(p):
			continue
		add_child(Trap.make(_art, p))


## Forgets holes far enough away to be out of sight, so a long walk cannot grow
## the tree without bound. Their cells are forgotten too, so walking back
## rebuilds them from the same seed and the ground looks unchanged.
##
## Freed rather than compacted: with nodes there is no index to move, so the
## whole `_dead` and `_compact` dance the swarm needs is gone from here.
func _cull_far(around: Vector2) -> void:
	var far := Tuning.TRAP_FORGET_DISTANCE * Tuning.TRAP_FORGET_DISTANCE
	for c in get_children():
		if (c as Trap).position.distance_squared_to(around) > far:
			_drop(c)
	var cell := Tuning.TRAP_CELL
	var reach := int(ceil(Tuning.TRAP_FORGET_DISTANCE / cell))
	var here := Vector2i(floori(around.x / cell), floori(around.y / cell))
	for k: Vector2i in _filled.keys():
		if absi(k.x - here.x) > reach or absi(k.y - here.y) > reach:
			_filled.erase(k)


## Removed as well as freed. `queue_free` leaves the node in the tree until the
## end of the frame, so `count()` would still include it and `_fill_cell` would
## refuse to refill against a cap that is already wrong.
func _drop(c: Node) -> void:
	remove_child(c)
	c.queue_free()


## Traps are spaced further apart than props: two overlapping holes read as one
## big one, and the cat could not walk between them.
func _too_close(p: Vector2) -> bool:
	for c in get_children():
		var d := (c as Trap).position.distance_squared_to(p)
		if d < Tuning.TRAP_SPACING * Tuning.TRAP_SPACING:
			return true
	return false


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _player == null or not Run.alive:
		return
	var here: Vector2 = _player.global_position
	if here.distance_to(_last_refill) > Tuning.TRAP_REFILL_DISTANCE:
		_last_refill = here
		_refill_around(here)
	if _cooldown > 0.0:
		return
	var fell := _hole_at(here)
	if fell != null:
		_cooldown = Tuning.TRAP_COOLDOWN
		fell_in.emit(fell.position)


## Which hole the cat is in, or null. Returns the hole rather than an index,
## because an index into a list of children is only true until one is freed.
func _hole_at(point: Vector2) -> Trap:
	for i in get_child_count():
		var t := get_child(i) as Trap
		if t.bites(point):
			return t
	return null
