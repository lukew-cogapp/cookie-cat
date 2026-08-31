class_name Eclipse
extends Node2D
## Night at the halfway mark: a warm lamp of light stays on the cat while the
## garden dims to a starry blue, with a moon and fireflies. A wonder, not a
## threat: the dark is see-through, and the director holds its rushes while it
## lasts.
##
## The whole night is one radial gradient texture, clear in the middle, warm
## at the lamp's rim, night blue beyond, drawn centred on the cat. The camera
## is pinned to the cat, so the lamp is also the middle of the screen and one
## draw covers any viewport. No Light2D and no shader, so there is nothing to
## disagree with gl_compatibility about on web or Android.

var _player: Node2D
## How far into the night this is, 0 (day) to 1 (full dark), eased towards
## `_want` so the dark creeps in and out rather than switching.
var _dark := 0.0
var _want := 0.0
var _shade: GradientTexture2D
var _stars: Array[Vector2] = []
var _star_size: Array[float] = []
## A star's share of the local darkness: stars near the lamp stay dim, so
## none sits bright inside the lit circle.
var _star_dim: Array[float] = []
var _star_phase: Array[float] = []
var _fly_phase: Array[float] = []
var _fly_speed: Array[float] = []
var _fly_bob: Array[float] = []
var _fly_pulse: Array[float] = []


func _ready() -> void:
	visible = false
	# The project default is nearest, for the pixel art. The shade is a smooth
	# gradient, which nearest turns into visible rings.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shade = _build_shade()
	var rng := RandomNumberGenerator.new()
	rng.seed = Tuning.ECLIPSE_SEED
	_scatter_stars(rng)
	for _n in Tuning.ECLIPSE_FIREFLIES:
		_fly_phase.append(rng.randf() * TAU)
		_fly_speed.append(
			rng.randf_range(Tuning.ECLIPSE_FLY_SPEED_MIN, Tuning.ECLIPSE_FLY_SPEED_MAX)
		)
		_fly_bob.append(rng.randf() * TAU)
		_fly_pulse.append(rng.randf() * TAU)


func set_player(player: Node2D) -> void:
	_player = player


func begin() -> void:
	_want = 1.0
	visible = true


func finish() -> void:
	_want = 0.0


## How dark the world currently is, for the tests.
func dark() -> float:
	return _dark


func _physics_process(delta: float) -> void:
	_dark = move_toward(_dark, _want, delta / Tuning.ECLIPSE_FADE)
	if _dark <= 0.0 and _want <= 0.0:
		visible = false
		return
	if _player != null:
		global_position = _player.global_position
	queue_redraw()


## Clear centre, warm rim, night beyond. Offsets are world radii over the
## texture's half-width, since the radial fill runs 0..1 across half of it.
func _build_shade() -> GradientTexture2D:
	var half := Tuning.ECLIPSE_COVER * 0.5
	var clear := Color(Tuning.ECLIPSE_NIGHT, 0.0)
	var rim_r := Tuning.ECLIPSE_SPOT_RADIUS + Tuning.ECLIPSE_SPOT_FADE * Tuning.ECLIPSE_RIM_AT
	var night_r := Tuning.ECLIPSE_SPOT_RADIUS + Tuning.ECLIPSE_SPOT_FADE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(
		[0.0, Tuning.ECLIPSE_SPOT_RADIUS / half, rim_r / half, night_r / half, 1.0]
	)
	g.colors = PackedColorArray(
		[clear, clear, Tuning.ECLIPSE_RIM_COLOUR, Tuning.ECLIPSE_NIGHT, Tuning.ECLIPSE_NIGHT]
	)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = Tuning.ECLIPSE_SHADE_RES
	tex.height = Tuning.ECLIPSE_SHADE_RES
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _scatter_stars(rng: RandomNumberGenerator) -> void:
	for _n in Tuning.ECLIPSE_STARS:
		# Square-root mix of the radii, so the ring is evenly filled rather
		# than crowded at its inner edge.
		var near := Tuning.ECLIPSE_STAR_NEAR * Tuning.ECLIPSE_STAR_NEAR
		var far := Tuning.ECLIPSE_STAR_FAR * Tuning.ECLIPSE_STAR_FAR
		var r := sqrt(lerpf(near, far, rng.randf()))
		_stars.append(Vector2.from_angle(rng.randf() * TAU) * r)
		_star_size.append(
			rng.randf_range(Tuning.ECLIPSE_STAR_SIZE_MIN, Tuning.ECLIPSE_STAR_SIZE_MAX)
		)
		_star_dim.append(
			clampf((r - Tuning.ECLIPSE_SPOT_RADIUS) / Tuning.ECLIPSE_SPOT_FADE, 0.0, 1.0)
		)
		_star_phase.append(rng.randf() * TAU)


func _draw() -> void:
	if _dark <= 0.0:
		return
	var half := Tuning.ECLIPSE_COVER * 0.5
	draw_texture_rect(
		_shade,
		Rect2(-half, -half, Tuning.ECLIPSE_COVER, Tuning.ECLIPSE_COVER),
		false,
		Color(1.0, 1.0, 1.0, _dark)
	)
	_draw_stars()
	_draw_moon()
	_draw_fireflies()


func _draw_stars() -> void:
	for n in _stars.size():
		var wave := 0.5 + 0.5 * sin(Run.clock * Tuning.ECLIPSE_TWINKLE_RATE + _star_phase[n])
		var a: float = _dark * _star_dim[n] * (1.0 - Tuning.ECLIPSE_TWINKLE * wave)
		if a <= 0.0:
			continue
		draw_circle(_stars[n], _star_size[n], Color(Tuning.ECLIPSE_STAR_COLOUR, a))


func _draw_moon() -> void:
	var at := Tuning.ECLIPSE_MOON_AT
	for n in Tuning.ECLIPSE_MOON_GLOW_RINGS:
		var r := Tuning.ECLIPSE_MOON_RADIUS * (
			1.0 + Tuning.ECLIPSE_MOON_GLOW_STEP * float(Tuning.ECLIPSE_MOON_GLOW_RINGS - n)
		)
		var glow := Tuning.ECLIPSE_MOON_GLOW_COLOUR
		draw_circle(at, r, Color(glow, glow.a * _dark))
	draw_circle(at, Tuning.ECLIPSE_MOON_RADIUS, Color(Tuning.ECLIPSE_MOON_COLOUR, _dark))
	for c: Vector3 in Tuning.ECLIPSE_MOON_CRATERS:
		draw_circle(at + Vector2(c.x, c.y), c.z, Color(Tuning.ECLIPSE_MOON_CRATER_COLOUR, _dark))


func _draw_fireflies() -> void:
	var t: float = Run.clock
	for n in Tuning.ECLIPSE_FIREFLIES:
		var ang: float = _fly_phase[n] + t * _fly_speed[n]
		var r: float = (
			Tuning.ECLIPSE_FLY_RADIUS
			+ Tuning.ECLIPSE_FLY_WOBBLE * sin(t * Tuning.ECLIPSE_FLY_BOB_RATE + _fly_bob[n])
		)
		var at := Vector2.from_angle(ang) * r
		var floor_a := Tuning.ECLIPSE_FLY_PULSE_FLOOR
		var wave := 0.5 + 0.5 * sin(t * Tuning.ECLIPSE_FLY_PULSE_RATE + _fly_pulse[n])
		var pulse := floor_a + (1.0 - floor_a) * wave
		var tint := Tuning.ECLIPSE_FLY_COLOUR
		draw_circle(
			at,
			Tuning.ECLIPSE_FLY_GLOW_SIZE,
			Color(tint, Tuning.ECLIPSE_FLY_GLOW_ALPHA * pulse * _dark)
		)
		draw_circle(at, Tuning.ECLIPSE_FLY_SIZE, Color(tint, pulse * _dark))
