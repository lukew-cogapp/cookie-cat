class_name Puffs
extends Node2D
## Burst particles and floating reward numbers, pooled.
##
## Same parallel-array + MultiMesh shape as the swarm, for the same reason:
## a good minute of play pops dozens of bugs, and a node per star costs more
## than the star. Everything here is decoration, so a full pool drops the
## burst rather than growing, and nothing is ever queue_freed.

## Indices into Tuning.PUFF_TEXTURES.
enum Kind { STAR, SPARKLE, POOF }

var alive := 0
var pos: Array[Vector2] = []
var vel: Array[Vector2] = []
var life: Array[float] = []
var full: Array[float] = []
var kind: Array[int] = []
var tint: Array[Color] = []

## Floating "+N" texts. A handful at most: only big hauls earn one.
var num_alive := 0
var num_pos: Array[Vector2] = []
var num_text: Array[String] = []
var num_life: Array[float] = []

var _mm: Array[MultiMesh] = []
var _by_kind: Array[Array] = []
var _rng := RandomNumberGenerator.new()
var _font: Font


func _ready() -> void:
	var q := Tuning.sprite_quad()
	for k in Tuning.PUFF_TEXTURES.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = q
		mm.instance_count = Tuning.PUFF_MAX
		mm.visible_instance_count = 0
		var node := MultiMeshInstance2D.new()
		node.multimesh = mm
		node.texture = load(Tuning.PUFF_TEXTURES[k])
		add_child(node)
		_mm.append(mm)
		_by_kind.append([])
	pos.resize(Tuning.PUFF_MAX)
	vel.resize(Tuning.PUFF_MAX)
	life.resize(Tuning.PUFF_MAX)
	full.resize(Tuning.PUFF_MAX)
	kind.resize(Tuning.PUFF_MAX)
	tint.resize(Tuning.PUFF_MAX)
	num_pos.resize(Tuning.NUMBER_MAX)
	num_text.resize(Tuning.NUMBER_MAX)
	num_life.resize(Tuning.NUMBER_MAX)
	_font = ThemeDB.fallback_font


## A spray in random directions. `drift` biases the whole burst, so pickup
## sparkles can rise.
func burst(
	at: Vector2, of_kind: int, count: int, colour: Color, speed: float, drift := Vector2.ZERO
) -> void:
	for _n in count:
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		_spawn(at, of_kind, colour, dir * speed * _rng.randf_range(0.5, 1.0) + drift)


## `count` particles evenly around a circle, moving outward. The celebratory
## shape: combo cheers and the boss telegraph.
func ring(at: Vector2, of_kind: int, count: int, colour: Color, radius: float, speed: float) -> void:
	for n in count:
		var dir := Vector2.from_angle(TAU * float(n) / float(count))
		_spawn(at + dir * radius, of_kind, colour, dir * speed)


func number(at: Vector2, text: String) -> void:
	if num_alive >= Tuning.NUMBER_MAX:
		return
	var i := num_alive
	num_alive += 1
	num_pos[i] = at
	num_text[i] = text
	num_life[i] = Tuning.NUMBER_LIFE


func _spawn(at: Vector2, of_kind: int, colour: Color, velocity: Vector2) -> void:
	if alive >= Tuning.PUFF_MAX:
		return
	var i := alive
	alive += 1
	pos[i] = at
	vel[i] = velocity
	life[i] = Tuning.PUFF_LIFE * _rng.randf_range(0.8, 1.2)
	full[i] = life[i]
	kind[i] = of_kind
	tint[i] = colour


func _physics_process(delta: float) -> void:
	# Swap-remove in place: expiry has no cross-references to keep stable, so
	# no dead list is needed.
	var i := 0
	while i < alive:
		life[i] -= delta
		if life[i] <= 0.0:
			alive -= 1
			if i != alive:
				pos[i] = pos[alive]
				vel[i] = vel[alive]
				life[i] = life[alive]
				full[i] = full[alive]
				kind[i] = kind[alive]
				tint[i] = tint[alive]
			continue
		pos[i] += vel[i] * delta
		vel[i] = vel[i].lerp(Vector2.ZERO, Tuning.PUFF_DAMPING * delta)
		i += 1
	var n := 0
	while n < num_alive:
		num_life[n] -= delta
		if num_life[n] <= 0.0:
			num_alive -= 1
			if n != num_alive:
				num_pos[n] = num_pos[num_alive]
				num_text[n] = num_text[num_alive]
				num_life[n] = num_life[num_alive]
			continue
		num_pos[n] += Vector2(0.0, -Tuning.NUMBER_RISE * delta)
		n += 1
	_redraw()
	queue_redraw()


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
			var t: float = life[i] / maxf(full[i], 0.001)
			# Pop in big, shrink away: the shrink is the fade, so no alpha
			# blend is needed against the busy lawn.
			var s := Tuning.PUFF_SIZE * (0.4 + 0.6 * t)
			mm.set_instance_transform_2d(n, Transform2D(0.0, Vector2(s, s), 0.0, pos[i]))
			mm.set_instance_color(n, tint[i])


## Only the numbers are drawn here; particles are MultiMesh instances.
func _draw() -> void:
	for n in num_alive:
		var t: float = num_life[n] / Tuning.NUMBER_LIFE
		var c := Tuning.NUMBER_COLOUR
		var at := to_local(num_pos[n])
		draw_string_outline(
			_font,
			at,
			num_text[n],
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			Tuning.NUMBER_FONT_SIZE,
			4,
			Color(0.1, 0.05, 0.1, t)
		)
		draw_string(
			_font,
			at,
			num_text[n],
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			Tuning.NUMBER_FONT_SIZE,
			Color(c.r, c.g, c.b, t)
		)
