extends GutTest
## The spider's burst-and-pause scuttle, and the row columns that carry it.

var _swarm: Swarm


func before_each() -> void:
	_swarm = Swarm.new()
	add_child_autofree(_swarm)
	await wait_process_frames(1)
	_swarm.set_physics_process(false)


## The pace can only slow the listed speed, so the burst never breaks the rule
## that no bug outruns the cat.
func test_the_scuttle_never_beats_the_listed_speed() -> void:
	for n in 40:
		var t := float(n) * 0.07
		assert_lte(Tuning.spider_pace(t), 1.0, "pace at %.2f stays capped" % t)


func test_the_scuttle_bursts_and_pauses() -> void:
	var lo := 1.0
	var hi := 0.0
	for n in 40:
		var pace := Tuning.spider_pace(float(n) * 0.07)
		lo = minf(lo, pace)
		hi = maxf(hi, pace)
	assert_eq(hi, 1.0, "it reaches full speed")
	assert_lt(lo, 0.5, "and near-stops between bursts")


## Phases are scattered at spawn, or a pack freezes and lunges in unison.
func test_spawned_spiders_are_out_of_step() -> void:
	for n in 8:
		_swarm.spawn(Vector2(float(n) * 40.0, 0.0), Swarm.Kind.SPIDER)
	var seen := {}
	for i in _swarm.alive:
		assert_between(
			_swarm.gait[i], 0.0, Tuning.SPIDER_SCUTTLE_CYCLE, "phase sits inside one cycle"
		)
		seen[_swarm.gait[i]] = true
	assert_gt(seen.size(), 1, "not every spider shares a phase")


## Swap-removal must carry the new columns, or a survivor inherits a dead
## spider's phase and a dead beetle's countdown.
func test_compact_moves_gait_and_aim() -> void:
	for n in 3:
		_swarm.spawn(Vector2(float(n) * 40.0, 0.0), Swarm.Kind.SPIDER)
	_swarm.gait[2] = 0.77
	_swarm.aim[2] = 1.23
	_swarm.damage(0, 9999.0, Vector2.ZERO)
	_swarm._compact()
	assert_eq(_swarm.gait[0], 0.77, "the last row's phase moved down")
	assert_eq(_swarm.aim[0], 1.23, "and its countdown with it")


## New bugs arrive late: the opening minutes stay the kinds a beginner has
## already met. A first appearance of -1 means the kind never spawns at all.
func test_the_new_kinds_wait_for_the_later_minutes() -> void:
	var first_spider := -1
	var first_dung := -1
	for i in Tuning.WAVES.size():
		var kinds: Array = Tuning.WAVES[i]["kinds"]
		if first_spider < 0 and Swarm.Kind.SPIDER in kinds:
			first_spider = i
		if first_dung < 0 and Swarm.Kind.DUNG in kinds:
			first_dung = i
	assert_gt(first_spider, 3, "the spider sits out the opening minutes")
	assert_gt(first_dung, 3, "so does the dung beetle")
