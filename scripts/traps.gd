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
## Same seeded-cell field as `ground.gd` and `props.gd`, and for the same
## reason: the cat is never walled in, so the field follows it, and a cell is
## seeded by its own coordinates so walking back finds the same pond.

signal fell_in(at: Vector2)

var alive := 0
var pos: Array[Vector2] = []

var _mm: MultiMesh
var _rng := RandomNumberGenerator.new()
var _filled: Dictionary = {}
var _clear_around := Vector2.ZERO
var _player: Node2D
var _dead: Array[int] = []
## Seconds until this trap can bite again. One trap cannot chain-hit across
## frames while the cat is climbing out of it.
var _cooldown := 0.0


func _ready() -> void:
	var art := String(Tuning.map_info(Run.map)["trap"])
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.mesh = Tuning.sprite_quad()
	_mm.instance_count = Tuning.TRAP_COUNT
	_mm.visible_instance_count = 0
	var node := MultiMeshInstance2D.new()
	node.multimesh = _mm
	node.texture = load(art)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(node)
	pos.resize(Tuning.TRAP_COUNT)


func set_player(p: Node2D) -> void:
	_player = p


func scatter(clear_around: Vector2) -> void:
	alive = 0
	_dead.clear()
	_filled.clear()
	_clear_around = clear_around
	_refill_around(clear_around)


func _refill_around(at: Vector2) -> void:
	var cell := Tuning.TRAP_CELL
	var reach := int(ceil(Tuning.TRAP_REFILL_DISTANCE / cell))
	var here := Vector2i(floori(at.x / cell), floori(at.y / cell))
	_cull_far(at)
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
		if alive >= Tuning.TRAP_COUNT:
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
		pos[alive] = p
		alive += 1
	_redraw()


func _cull_far(at: Vector2) -> void:
	var far := Tuning.TRAP_FORGET_DISTANCE * Tuning.TRAP_FORGET_DISTANCE
	for i in range(alive - 1, -1, -1):
		if pos[i].distance_squared_to(at) > far:
			_dead.append(i)
	_compact()
	var cell := Tuning.TRAP_CELL
	var reach := int(ceil(Tuning.TRAP_FORGET_DISTANCE / cell))
	var here := Vector2i(floori(at.x / cell), floori(at.y / cell))
	for c: Vector2i in _filled.keys():
		if absi(c.x - here.x) > reach or absi(c.y - here.y) > reach:
			_filled.erase(c)


## Traps are spaced further apart than props: two overlapping holes read as one
## big one, and the cat could not walk between them.
func _too_close(p: Vector2) -> bool:
	for i in alive:
		if pos[i].distance_squared_to(p) < Tuning.TRAP_SPACING * Tuning.TRAP_SPACING:
			return true
	return false


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _player == null or not Run.alive:
		return
	var at: Vector2 = _player.global_position
	if at.distance_to(_clear_around) > Tuning.TRAP_REFILL_DISTANCE:
		_clear_around = at
		_refill_around(at)
	if _cooldown > 0.0:
		return
	var i := _at(at)
	if i != -1:
		_cooldown = Tuning.TRAP_COOLDOWN
		fell_in.emit(pos[i])


## Which trap the cat is in, or -1. Only the middle counts: the sprite's outline
## is its rim, and standing on the rim is not falling in.
func _at(point: Vector2) -> int:
	var r := Tuning.TRAP_RADIUS * Tuning.TRAP_BITE
	for i in alive:
		if pos[i].distance_squared_to(point) < r * r:
			return i
	return -1


func _compact() -> void:
	_dead.sort()
	_dead.reverse()
	var last := -1
	for i in _dead:
		if i == last:
			continue
		last = i
		if i >= alive:
			continue
		alive -= 1
		pos[i] = pos[alive]
	_dead.clear()
	_redraw()


func _redraw() -> void:
	_mm.visible_instance_count = alive
	var s := Tuning.TRAP_RADIUS * 2.0
	for i in alive:
		_mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(s, s), 0.0, pos[i]))
		_mm.set_instance_color(i, Color.WHITE)
