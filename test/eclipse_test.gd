extends GutTest
## The eclipse: night falls once at the halfway mark, lifts on its own, and
## changes nothing about what is trying to reach the cat. These pin the
## schedule and the promise that the dark can neither ambush nor stick.

var _swarm: Swarm
var _director: Director
var _player: Node2D
var _run: Node


func before_each() -> void:
	_run = get_tree().get_root().get_node("Run")
	_swarm = Swarm.new()
	add_child_autofree(_swarm)
	_player = Node2D.new()
	add_child_autofree(_player)
	_director = Director.new()
	add_child_autofree(_director)
	await wait_process_frames(1)
	# Both are driven by hand here, or every step happens twice.
	_swarm.set_physics_process(false)
	_director.set_physics_process(false)
	_swarm.set_player(_player)
	_director.setup(_swarm, _player)
	_run.start()


func after_each() -> void:
	_run.clock = 0.0


## Steps the director at 60Hz from wherever the clock is now.
func _run_clock(secs: float) -> void:
	var delta := 1.0 / 60.0
	for _n in int(secs / delta):
		_run.clock += delta
		_director._physics_process(delta)


func test_night_falls_once_and_the_sun_comes_back() -> void:
	var started: Array = []
	var ended: Array = []
	_director.eclipse_started.connect(func() -> void: started.append(_run.clock))
	_director.eclipse_ended.connect(func() -> void: ended.append(_run.clock))
	_run.clock = Tuning.ECLIPSE_AT - 1.0
	_run_clock(2.0)
	assert_eq(started.size(), 1, "night falls at the appointed moment")
	assert_eq(ended.size(), 0, "and holds")
	assert_true(_director.eclipse_active(), "the director knows it is dark")
	_run_clock(Tuning.ECLIPSE_TIME + 1.0)
	assert_eq(ended.size(), 1, "the sun comes back on its own")
	assert_false(_director.eclipse_active(), "and the director knows that too")
	_run_clock(60.0)
	assert_eq(started.size(), 1, "night falls once a run")


func test_a_fresh_run_gets_its_night_back() -> void:
	_run.clock = Tuning.ECLIPSE_AT
	_run_clock(1.0)
	assert_true(_director.eclipse_active(), "this run's night happened")
	_director.setup(_swarm, _player)
	assert_false(_director.eclipse_active(), "setup clears a night in progress")
	_run.clock = Tuning.ECLIPSE_AT
	_run_clock(1.0)
	assert_true(_director.eclipse_active(), "and the next run gets its own")


## The generous half: no pack is announced while it is dark, so nothing ever
## charges out of the gloom, and the first pack after dawn keeps its distance.
func test_no_rush_is_announced_in_the_dark() -> void:
	var rushed: Array = []
	var started: Array = []
	var ended: Array = []
	_director.rush_arrived.connect(func(_at: Vector2) -> void: rushed.append(_run.clock))
	_director.eclipse_started.connect(func() -> void: started.append(_run.clock))
	_director.eclipse_ended.connect(func() -> void: ended.append(_run.clock))
	_run.clock = Tuning.ECLIPSE_AT - 60.0
	_run_clock(60.0 + Tuning.ECLIPSE_TIME + Tuning.RUSH_GAP_MIN + Tuning.RUSH_GAP_MAX)
	assert_eq(started.size(), 1, "the night happened inside the window")
	assert_gt(rushed.size(), 0, "rushes still happen around it")
	for at: float in rushed:
		var in_the_dark: bool = at >= started[0] and at <= ended[0]
		assert_false(in_the_dark, "no rush was announced while it was dark")
	var after: Array = rushed.filter(func(at: float) -> bool: return at > ended[0])
	if after.size() > 0:
		assert_gte(
			after[0] - ended[0],
			Tuning.RUSH_GAP_MIN - 0.1,
			"the first pack after dawn is not waiting on the doorstep",
		)


## The overlay itself: the dark creeps in, tops out, and always lifts again.
## `finish()` back to zero is what makes a permanently dark world impossible.
func test_the_dark_creeps_in_and_always_lifts() -> void:
	var night := Eclipse.new()
	add_child_autofree(night)
	await wait_process_frames(1)
	night.set_physics_process(false)
	var delta := 1.0 / 60.0
	night.begin()
	night._physics_process(delta)
	assert_between(night.dark(), 0.001, 0.5, "dusk is gradual, not a light switch")
	assert_true(night.visible, "and already on screen")
	for _n in int(Tuning.ECLIPSE_FADE / delta) + 5:
		night._physics_process(delta)
	assert_eq(night.dark(), 1.0, "full night arrives")
	night.finish()
	for _n in int(Tuning.ECLIPSE_FADE / delta) + 5:
		night._physics_process(delta)
	assert_eq(night.dark(), 0.0, "daylight comes all the way back")
	assert_false(night.visible, "and the finished night hides itself")


## The numbers must keep the night gentle, whatever they are retuned to.
func test_the_dark_is_see_through() -> void:
	assert_lt(Tuning.ECLIPSE_NIGHT.a, 1.0, "a bug in the dark is dimmed, never hidden")


func test_the_lamp_covers_the_starting_toy() -> void:
	assert_gt(
		Tuning.ECLIPSE_SPOT_RADIUS,
		Tuning.weapon_stat("paw", "radius", Tuning.WEAPON_LEVEL_MAX),
		"the paw's whole reach stays in the light",
	)


func test_the_night_stays_clear_of_the_bosses() -> void:
	var dusk := int(Tuning.ECLIPSE_AT / 60.0)
	var dawn := int((Tuning.ECLIPSE_AT + Tuning.ECLIPSE_TIME) / 60.0)
	for minute: int in Tuning.BOSS_MINUTES:
		assert_true(minute < dusk or minute > dawn, "no boss walks in during the dark")


func test_the_night_ends_well_before_the_run_does() -> void:
	assert_lt(
		Tuning.ECLIPSE_AT + Tuning.ECLIPSE_TIME + Tuning.ECLIPSE_FADE,
		Tuning.RUN_SECONDS - 60.0,
		"the last minute is played in daylight",
	)


func test_dusk_and_dawn_both_fit_inside_the_night() -> void:
	assert_lt(Tuning.ECLIPSE_FADE * 2.0, Tuning.ECLIPSE_TIME, "full dark is reached and enjoyed")


## `aspect=expand` shows more world on a wide phone, so the shade has to reach
## past the corner of a 20:9 view or those corners stay daylight.
func test_the_shade_reaches_the_widest_corner() -> void:
	var phone_half := Vector2(720.0 * 20.0 / 9.0, 720.0) / (2.0 * Tuning.ZOOM)
	assert_gt(Tuning.ECLIPSE_COVER * 0.5, phone_half.length(), "the corners go dark too")
