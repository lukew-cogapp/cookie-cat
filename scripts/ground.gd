class_name Ground
extends Node2D
## Mud, flowers, worn patches and stones scattered across the lawn.
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
var _centre := Vector2.ZERO
var _player: Node2D


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	for k in Tuning.GROUND_ART.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = q
		mm.instance_count = Tuning.GROUND_COUNT
		mm.visible_instance_count = 0
		var node := MultiMeshInstance2D.new()
		node.multimesh = mm
		node.texture = load(String(Tuning.GROUND_ART[k]))
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


## Scatters a field of decals around a point. Seeded off that point, so walking
## back over old ground finds the same mud rather than a fresh roll.
func scatter(around: Vector2) -> void:
	alive = 0
	_centre = around
	_rng.seed = (
		Tuning.GROUND_SEED + int(_centre.x) * 73856093 + int(_centre.y) * 19349663
	)
	for _n in Tuning.GROUND_COUNT:
		var i := alive
		alive += 1
		pos[i] = _centre + Vector2(
			_rng.randf_range(-Tuning.GROUND_FIELD_HALF.x, Tuning.GROUND_FIELD_HALF.x),
			_rng.randf_range(-Tuning.GROUND_FIELD_HALF.y, Tuning.GROUND_FIELD_HALF.y),
		)
		kind[i] = _weighted_kind()
		size[i] = _rng.randf_range(
			Tuning.GROUND_SIZE_MIN, Tuning.GROUND_SIZE_MAX
		) * float(Tuning.GROUND_SCALE[kind[i]])
		# Quarter turns only. A patch rotated off the pixel grid blurs, and the
		# whole look depends on the pixels staying square.
		turn[i] = float(_rng.randi_range(0, 3)) * PI * 0.5
		# A little tone variation per patch, so a field of mud is not one
		# stamp repeated.
		var shade := _rng.randf_range(Tuning.GROUND_SHADE_MIN, 1.0)
		tint[i] = Color(shade, shade, shade, Tuning.GROUND_ALPHA[kind[i]])
	_redraw()


## Mud and worn patches are common, flowers and stones are the treats. A flat
## roll made the lawn read as evenly speckled rather than as a garden with
## features in it.
func _weighted_kind() -> int:
	var roll := _rng.randf()
	var seen := 0.0
	for k in Tuning.GROUND_WEIGHTS.size():
		seen += float(Tuning.GROUND_WEIGHTS[k])
		if roll <= seen:
			return k
	return 0


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	if _player.global_position.distance_to(_centre) > Tuning.GROUND_REFILL_DISTANCE:
		scatter(_player.global_position)


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
