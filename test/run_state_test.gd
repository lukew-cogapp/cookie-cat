extends GutTest
## Levelling, picks, and what a run pays out.
##
## `Run` is an autoload, so these assert on the live singleton and reset it
## with `start()` each time rather than building one.

func before_each() -> void:
	Run.cat = Tuning.STARTER_CAT
	# `start` sets alive; a previous test's `finish` would otherwise leave the
	# run over, and `add_xp` refuses to do anything then.
	Run.start()
	assert_true(Run.alive, "the run is live before the test body")


func after_all() -> void:
	# The next suite gets a run that is over, not one mid-flight.
	Run.alive = false


func test_start_gives_the_cat_its_weapon() -> void:
	var expected := String(Tuning.CATS[Tuning.STARTER_CAT]["weapon"])
	assert_eq(Run.weapons.keys(), [expected], "only the starter, at level 1")
	assert_eq(Run.level_of(expected), 1, "level 1")


## The whole reason to unlock a cat: it changes how the run opens.
func test_each_cat_starts_with_its_own_weapon() -> void:
	for id: String in Tuning.CATS:
		Run.cat = id
		Run.start()
		var want := String(Tuning.CATS[id]["weapon"])
		assert_eq(Run.level_of(want), 1, "%s opens with %s" % [id, want])


func test_start_clears_the_last_run() -> void:
	Run.take("boots")
	Run.kills = 40
	Run.cookies = 9
	Run.start()
	assert_eq(Run.level_of("boots"), 0, "picks are gone")
	assert_eq(Run.kills, 0, "kills are gone")
	assert_eq(Run.cookies, 0, "cookies are gone")


func test_xp_levels_up() -> void:
	Run.add_xp(Tuning.xp_for_level(1))
	assert_eq(Run.level, 2, "one level")


## A big gem can cross two levels at once, and each owes the player a pick.
func test_one_gem_can_cross_two_levels() -> void:
	var seen: Array[int] = []
	var count := func(_c: Array) -> void: seen.append(1)
	Run.levelled.connect(count)
	Run.add_xp(Tuning.xp_for_level(1) + Tuning.xp_for_level(2))
	Run.levelled.disconnect(count)
	assert_eq(Run.level, 3, "two levels")
	assert_eq(seen.size(), 2, "and a pick offered for each")


func test_levels_get_more_expensive() -> void:
	var last := 0
	for level in range(1, 12):
		var need := Tuning.xp_for_level(level)
		assert_gt(need, last, "level %d costs more than the one before" % level)
		last = need


func test_take_adds_then_levels() -> void:
	Run.take("yarn")
	assert_eq(Run.level_of("yarn"), 1, "added")
	Run.take("yarn")
	assert_eq(Run.level_of("yarn"), 2, "levelled")


## Passives multiply and must read 1.0 when never picked, or every weapon that
## scales by one would deal no damage at all.
func test_unpicked_passive_is_neutral() -> void:
	assert_eq(Run.passive("claw"), 1.0, "no claws, no change")


func test_passive_grows_with_level() -> void:
	Run.take("claw")
	var one := Run.passive("claw")
	Run.take("claw")
	assert_gt(Run.passive("claw"), one, "two claws beat one")


## The bell shortens cooldowns, so its multiplier has to fall below 1.
func test_bell_shortens() -> void:
	Run.take("bell")
	assert_lt(Run.passive("bell"), 1.0, "a bell cuts the wait")


func test_weapon_slots_stop_new_weapons() -> void:
	var ids: Array = Tuning.WEAPONS.keys()
	for i in Tuning.WEAPON_SLOTS:
		Run.weapons[ids[i]] = 1
	var offered: Array = Run._choices()
	for id: String in offered:
		if Tuning.PASSIVES.has(id):
			continue
		assert_true(Run.level_of(id) > 0, "%s is one already owned" % id)


func test_maxed_things_are_not_offered() -> void:
	for id: String in Tuning.WEAPONS:
		Run.weapons[id] = Tuning.WEAPON_LEVEL_MAX
	for id: String in Tuning.PASSIVES:
		Run.passives[id] = Tuning.PASSIVE_LEVEL_MAX
	assert_eq(Run._choices(), [], "nothing left to pick")


func test_choices_never_exceed_the_card_count() -> void:
	assert_lte(Run._choices().size(), Tuning.LEVEL_CHOICES, "at most three cards")


func test_surviving_pays_the_bonus() -> void:
	Run.cookies = 0
	Run.finish(true)
	assert_gte(Run.cookies, Tuning.COOKIE_FINISH_BONUS, "the bonus was paid")


func test_losing_pays_no_bonus() -> void:
	Run.cookies = 3
	Run.finish(false)
	assert_eq(Run.cookies, 3, "no bonus for a run that ended early")


## `finish` banks the run, so calling it twice would pay twice.
func test_finish_only_counts_once() -> void:
	var runs := Save.runs
	Run.finish(false)
	Run.finish(false)
	assert_eq(Save.runs, runs + 1, "one run recorded")


func test_the_clock_ends_the_run() -> void:
	Run.tick(Tuning.RUN_SECONDS + 1.0)
	assert_false(Run.alive, "time is up")
	assert_true(Run.won, "and surviving it is a win")


## A snack heals rather than levelling, and is a wasted card at full health, so
## it is only offered while the bar is not full.
func test_a_snack_is_only_offered_when_hurt() -> void:
	Run.hurt = false
	for _i in 30:
		for id: String in Run._choices():
			assert_false(Tuning.CONSUMABLES.has(id), "no snack at full health")
	Run.hurt = true
	var seen := false
	for _i in 60:
		for id: String in Run._choices():
			if Tuning.CONSUMABLES.has(id):
				seen = true
	assert_true(seen, "a snack is offered once the bar is not full")


## Taking one must not put it in a pool: a snack cannot be levelled and must
## not fill a passive slot.
func test_a_snack_is_never_owned() -> void:
	var told: Array[String] = []
	var watch := func(id: String) -> void: told.append(id)
	Run.consumed.connect(watch)
	Run.take("snack")
	Run.consumed.disconnect(watch)
	assert_eq(told, ["snack"], "the world was told to apply it")
	assert_false("snack" in Run.passives, "not in passives")
	assert_false("snack" in Run.weapons, "not in weapons")
	assert_eq(Run.level_of("snack"), 0, "and owns none of it")
