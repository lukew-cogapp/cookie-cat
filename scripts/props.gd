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
## Same parallel-array and MultiMesh shape as `swarm.gd`, for the same reason,
## and they are hit by the same weapon queries: `world.gd` passes each weapon's
## damage through `damage_near`, so anything that hurts a bug breaks a pot
## without a single weapon knowing props exist.

signal broke(at: Vector2, kind: int)

var alive := 0
var pos: Array[Vector2] = []
var hp: Array[float] = []
var kind: Array[int] = []
var flash: Array[float] = []

var _mm: Array[MultiMesh] = []
var _by_kind: Array[Array] = []
var _dead: Array[int] = []
var _rng := RandomNumberGenerator.new()
## Reused by `damage_near`, so a weapon firing every frame allocates nothing.
var _hits: Array[int] = []
## Middle of the currently scattered field. The cat is never walled in, so the
## field is re-scattered around it once it walks far enough from this.
var _centre := Vector2.ZERO
var _player: Node2D
## The map's prop table, read once at load: a map cannot change mid-run.
var _table: Array = []


func _ready() -> void:
	_table = Tuning.map_info(Run.map)["props"]
	_rng.seed = Tuning.PROP_SEED
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	for k in _table.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = q
		mm.instance_count = Tuning.PROP_COUNT
		mm.visible_instance_count = 0
		var node := MultiMeshInstance2D.new()
		node.multimesh = mm
		node.texture = load(String(_table[k]["art"]))
		add_child(node)
		_mm.append(mm)
		_by_kind.append([])
	pos.resize(Tuning.PROP_COUNT)
	hp.resize(Tuning.PROP_COUNT)
	kind.resize(Tuning.PROP_COUNT)
	flash.resize(Tuning.PROP_COUNT)


## Scatters the lawn. Seeded, so the garden is the same every run: a child who
## learns where the pots are should find them there again.
func scatter(clear_around: Vector2) -> void:
	alive = 0
	_dead.clear()
	_centre = clear_around
	# Seeded off the field's position, so walking back over old ground finds
	# the same garden rather than a freshly rolled one.
	_rng.seed = Tuning.PROP_SEED + int(_centre.x) * 73856093 + int(_centre.y) * 19349663
	var tries := 0
	while alive < Tuning.PROP_COUNT and tries < Tuning.PROP_COUNT * 20:
		tries += 1
		var p := _centre + Vector2(
			_rng.randf_range(-Tuning.PROP_FIELD_HALF.x, Tuning.PROP_FIELD_HALF.x),
			_rng.randf_range(-Tuning.PROP_FIELD_HALF.y, Tuning.PROP_FIELD_HALF.y),
		)
		# Never on top of where the cat starts, or the run opens with a pot in
		# the player's face.
		if p.distance_to(clear_around) < Tuning.PROP_CLEAR_RADIUS:
			continue
		if _too_close(p):
			continue
		var k := _rng.randi_range(0, _table.size() - 1)
		var i := alive
		alive += 1
		pos[i] = p
		kind[i] = k
		hp[i] = float(_table[k]["hp"])
		flash[i] = 0.0
	_redraw()


func set_player(p: Node2D) -> void:
	_player = p


func _too_close(p: Vector2) -> bool:
	for i in alive:
		if pos[i].distance_squared_to(p) < Tuning.PROP_SPACING * Tuning.PROP_SPACING:
			return true
	return false


func _physics_process(delta: float) -> void:
	if not Run.alive:
		return
	if _player != null and _player.global_position.distance_to(_centre) > Tuning.PROP_REFILL_DISTANCE:
		scatter(_player.global_position)
		return
	var faded := false
	for i in alive:
		if flash[i] > 0.0:
			flash[i] = maxf(flash[i] - delta, 0.0)
			faded = true
	if faded or not _dead.is_empty():
		_compact()
		_redraw()


## The nearest prop, or -1. Weapons fall back to this when no bug is in range,
## so a shot in a quiet moment goes into a pot rather than into empty grass.
func nearest(point: Vector2, radius: float) -> int:
	var best := -1
	var best_d := radius * radius
	for i in alive:
		var d := pos[i].distance_squared_to(point)
		if d <= best_d:
			best_d = d
			best = i
	return best


## Damages every prop within `radius`. Weapons call this through `world.gd`
## rather than knowing about props, so a new weapon breaks pots for free.
func damage_near(point: Vector2, radius: float, amount: float) -> void:
	if alive == 0:
		return
	var r2 := radius * radius
	_hits.clear()
	for i in alive:
		if pos[i].distance_squared_to(point) <= r2:
			_hits.append(i)
	for i in _hits:
		hp[i] -= amount
		flash[i] = Tuning.HIT_FLASH_TIME
		if hp[i] <= 0.0:
			_dead.append(i)
			broke.emit(pos[i], kind[i])
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


func radius_of(k: int) -> float:
	return float(_table[k]["radius"])


func xp_of(k: int) -> int:
	return int(_table[k]["xp"])


func _compact() -> void:
	if _dead.is_empty():
		return
	_dead.sort()
	_dead.reverse()
	var last := -1
	for i in _dead:
		# One prop can be queued twice by two weapons in a frame; dropping it
		# twice would delete a standing one.
		if i == last:
			continue
		last = i
		alive -= 1
		if i != alive:
			pos[i] = pos[alive]
			hp[i] = hp[alive]
			kind[i] = kind[alive]
			flash[i] = flash[alive]
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
		var s := radius_of(k) * 2.0
		for n in rows.size():
			var i: int = rows[n]
			mm.set_instance_transform_2d(n, Transform2D(0.0, Vector2(s, s), 0.0, pos[i]))
			mm.set_instance_color(n, Tuning.HIT_FLASH_COLOUR if flash[i] > 0.0 else Color.WHITE)
