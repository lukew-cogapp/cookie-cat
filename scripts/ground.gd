class_name Ground
extends Node2D
## Decals scattered across the floor: mud and flowers in the garden, shells
## and tide pools on the beach, ice and drifts in the arctic. Which set is
## drawn comes from `Tuning.MAPS[Run.map]`.
##
## Decoration only: nothing here is walked around, damaged or picked up. It
## exists because a flat green field gives no sense of moving, and no sense of
## having been anywhere: with the cat pinned to the middle of the screen, the
## ground is the only thing that shows the garden going past.
##
## Same field-follows-the-cat trick as `props.gd`, since there is no wall to
## bound the garden, and the same array plus MultiMesh shape so a few hundred
## patches cost four draw calls and no per-frame work at all. Unlike the swarm
## these never move, so there is no `_physics_process` beyond the refill check.

var alive := 0
var pos: Array[Vector2] = []
var kind: Array[int] = []
var size: Array[float] = []
var turn: Array[float] = []
var tint: Array[Color] = []

var _mm: Array[MultiMesh] = []
var _by_kind: Array[Array] = []
var _rng := RandomNumberGenerator.new()
## Cells already filled, so a cell is never filled twice.
var _filled: Dictionary[Vector2i, bool] = {}
var _player: Node2D

## The map's decal tables, read once at load: a map cannot change mid-run.
var _art: Array = []
var _weights: Array = []
var _scale: Array = []
var _alpha: Array = []


func _ready() -> void:
	var m := Tuning.map_info(Run.map)
	_art = m["ground_art"]
	_weights = m["ground_weights"]
	_scale = m["ground_scale"]
	_alpha = m["ground_alpha"]
	var q := Tuning.sprite_quad()
	for k in _art.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = q
		mm.instance_count = Tuning.GROUND_COUNT
		mm.visible_instance_count = 0
		var node := MultiMeshInstance2D.new()
		node.multimesh = mm
		node.texture = load(String(_art[k]))
		add_child(node)
		_mm.append(mm)
		_by_kind.append([])
	pos.resize(Tuning.GROUND_COUNT)
	kind.resize(Tuning.GROUND_COUNT)
	size.resize(Tuning.GROUND_COUNT)
	turn.resize(Tuning.GROUND_COUNT)
	tint.resize(Tuning.GROUND_COUNT)


func set_player(p: Node2D) -> void:
	_player = p


## Fills the ground around a point, on a fixed grid of cells.
##
## Same shape as `props.gd`, and for the same reason: a field that follows the
## cat has to re-roll everything at once, which teleported the whole garden and
## reads as the world jumping. A cell is seeded by its own coordinates, so
## walking back over old ground finds the same mud.
func scatter(around: Vector2) -> void:
	alive = 0
	_filled.clear()
	_refill_around(around)


func _refill_around(at: Vector2) -> void:
	var cell := Tuning.GROUND_CELL
	var reach := int(ceil(Tuning.GROUND_REFILL_DISTANCE / cell))
	var here := Vector2i(floori(at.x / cell), floori(at.y / cell))
	_cull_far(at)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := here + Vector2i(dx, dy)
			if _filled.has(c):
				continue
			_filled[c] = true
			_fill_cell(c)


func _fill_cell(c: Vector2i) -> void:
	_rng.seed = Tuning.GROUND_SEED + c.x * 73856093 + c.y * 19349663
	var cell := Tuning.GROUND_CELL
	for _n in Tuning.GROUND_PER_CELL:
		if alive >= Tuning.GROUND_COUNT:
			return
		var i := alive
		alive += 1
		pos[i] = Vector2(
			(float(c.x) + _rng.randf()) * cell,
			(float(c.y) + _rng.randf()) * cell,
		)
		kind[i] = _weighted_kind()
		size[i] = _rng.randf_range(
			Tuning.GROUND_SIZE_MIN, Tuning.GROUND_SIZE_MAX
		) * float(_scale[kind[i]])
		# Quarter turns only. A patch rotated off the pixel grid blurs, and the
		# whole look depends on the pixels staying square.
		turn[i] = float(_rng.randi_range(0, 3)) * PI * 0.5
		var shade := _rng.randf_range(Tuning.GROUND_SHADE_MIN, 1.0)
		tint[i] = Color(shade, shade, shade, float(_alpha[kind[i]]))
	_redraw()


## Forgets decals out of sight, so a long walk cannot fill the arrays.
func _cull_far(at: Vector2) -> void:
	var far := Tuning.GROUND_FORGET_DISTANCE * Tuning.GROUND_FORGET_DISTANCE
	var kept := 0
	for i in alive:
		if pos[i].distance_squared_to(at) <= far:
			pos[kept] = pos[i]
			kind[kept] = kind[i]
			size[kept] = size[i]
			turn[kept] = turn[i]
			tint[kept] = tint[i]
			kept += 1
	alive = kept
	var cell := Tuning.GROUND_CELL
	var reach := int(ceil(Tuning.GROUND_FORGET_DISTANCE / cell))
	var here := Vector2i(floori(at.x / cell), floori(at.y / cell))
	for c: Vector2i in _filled.keys():
		if absi(c.x - here.x) > reach or absi(c.y - here.y) > reach:
			_filled.erase(c)


## Mud and worn patches are common, flowers and stones are the treats. A flat
## roll made the lawn read as evenly speckled rather than as a garden with
## features in it.
func _weighted_kind() -> int:
	var roll := _rng.randf()
	var seen := 0.0
	for k in _weights.size():
		seen += float(_weights[k])
		if roll <= seen:
			return k
	return 0


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	_refill_around(_player.global_position)


func _redraw() -> void:
	for k in _by_kind.size():
		_by_kind[k].clear()
	for i in alive:
		_by_kind[kind[i]].append(i)
	for k in _mm.size():
		var rows: Array = _by_kind[k]
		var mm := _mm[k]
		mm.visible_instance_count = rows.size()
		for n in rows.size():
			var i: int = rows[n]
			mm.set_instance_transform_2d(
				n, Transform2D(turn[i], Vector2(size[i], size[i]), 0.0, pos[i])
			)
			mm.set_instance_color(n, tint[i])
