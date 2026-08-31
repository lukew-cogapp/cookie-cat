extends GutTest
## Properties the numbers in `tuning.gd` must keep, whatever they are retuned
## to. These are the design rather than the values: each is a rule a child
## would feel at once if it broke, and none of them is visible in a diff.


## The rule the whole difficulty rests on: running away must always work. A
## bug faster than the cat cannot be escaped, only outlasted, which for this
## audience is the same as being unfair.
func test_no_bug_outruns_the_cat() -> void:
	for kind in Tuning.ENEMIES.size():
		assert_lt(
			Tuning.enemy_speed(kind),
			Tuning.PLAYER_SPEED,
			"%s is slower than the cat" % Tuning.ENEMIES[kind]["name"],
		)


## Bugs must arrive from off screen. The visible half-diagonal at zoom is what
## the ring has to clear, or a bug appears in front of the cat.
func test_bugs_spawn_off_screen() -> void:
	var half := Vector2(640.0, 360.0) / Tuning.ZOOM
	assert_gt(Tuning.SPAWN_RING, half.length(), "the ring clears the screen corner")


## And they must not be culled before they can walk in.
func test_bugs_are_not_culled_before_they_arrive() -> void:
	assert_gt(
		Tuning.ENEMY_CULL_DISTANCE, Tuning.SPAWN_RING, "a fresh spawn is not culled at once"
	)


## Weapons have to reach across the screen, or a shot fired at a bug walking in
## never connects.
func test_weapons_can_reach_across_the_screen() -> void:
	var half := Vector2(640.0, 360.0) / Tuning.ZOOM
	assert_gt(Tuning.SHOT_SEEK_RANGE, half.x, "a shot can be aimed across the screen")


## Waves must get harder. A flat table is the same minute ten times over.
func test_waves_escalate() -> void:
	for i in range(1, Tuning.WAVES.size()):
		var prev: Dictionary = Tuning.WAVES[i - 1]
		var here: Dictionary = Tuning.WAVES[i]
		assert_gt(
			int(here["min_alive"]),
			int(prev["min_alive"]),
			"minute %d holds more bugs than minute %d" % [i, i - 1],
		)
		assert_lte(
			float(here["interval"]),
			float(prev["interval"]),
			"minute %d spawns no slower than minute %d" % [i, i - 1],
		)


## The peak crowd must fit the rows the swarm allocated, or spawns are dropped
## for the whole last minute and the finale is the quietest part of the run.
func test_the_last_wave_fits_in_the_arrays() -> void:
	var peak := int(Tuning.WAVES[Tuning.WAVES.size() - 1]["min_alive"])
	assert_lt(peak, Tuning.ENEMY_MAX, "the busiest minute still fits")


func test_the_wave_table_covers_the_run() -> void:
	var minutes := int(Tuning.RUN_SECONDS / 60.0)
	assert_gte(Tuning.WAVES.size(), minutes, "every minute of the run has a wave")


## Every wave must name kinds that exist, or a spawn indexes off the end.
func test_waves_only_name_real_kinds() -> void:
	for i in Tuning.WAVES.size():
		for kind: int in Tuning.WAVES[i]["kinds"]:
			assert_lt(kind, Tuning.ENEMIES.size(), "wave %d names a real kind" % i)


func test_bosses_arrive_during_the_run() -> void:
	var minutes := int(Tuning.RUN_SECONDS / 60.0)
	for minute: int in Tuning.BOSS_MINUTES:
		assert_lt(minute, minutes, "the boss at minute %d is reachable" % minute)


## Every weapon needs firing code, or it deals no damage and reads as broken.
func test_every_weapon_has_a_known_kind() -> void:
	var known := ["arc", "shot", "aura", "orbit", "chaser", "zone", "strike", "burst"]
	for id: String in Tuning.WEAPONS:
		assert_true(
			String(Tuning.WEAPONS[id]["kind"]) in known,
			"%s has firing code" % id,
		)


## A weapon that does not improve makes its own upgrade card a wasted pick.
func test_every_weapon_improves_with_level() -> void:
	for id: String in Tuning.WEAPONS:
		var one := Tuning.weapon_stat(id, "damage", 1)
		var top := Tuning.weapon_stat(id, "damage", Tuning.WEAPON_LEVEL_MAX)
		var count_one := Tuning.weapon_stat(id, "count", 1)
		var count_top := Tuning.weapon_stat(id, "count", Tuning.WEAPON_LEVEL_MAX)
		assert_true(top > one or count_top > count_one, "%s gets better" % id)


## A cooldown that reaches zero fires every physics frame.
func test_cooldowns_stay_positive_at_max_level() -> void:
	for id: String in Tuning.WEAPONS:
		var top := Tuning.weapon_stat(id, "cooldown", Tuning.WEAPON_LEVEL_MAX)
		assert_gt(top, 0.0, "%s still waits between shots" % id)


## Every weapon and passive needs a picture: a child picks by picture.
func test_everything_offered_has_art_and_words() -> void:
	for id: String in Tuning.WEAPONS:
		assert_true(Tuning.ICONS.has(id), "%s has an icon" % id)
		assert_true(Tuning.BLURBS.has(id), "%s has a blurb" % id)
	for id: String in Tuning.PASSIVES:
		assert_true(Tuning.ICONS.has(id), "%s has an icon" % id)
		assert_true(Tuning.BLURBS.has(id), "%s has a blurb" % id)
	for id: String in Tuning.CONSUMABLES:
		assert_true(Tuning.ICONS.has(id), "%s has an icon" % id)
		assert_true(Tuning.BLURBS.has(id), "%s has a blurb" % id)


func test_every_icon_file_exists() -> void:
	for id: String in Tuning.ICONS:
		assert_true(ResourceLoader.exists(Tuning.ICONS[id]), "%s art loads" % id)


func test_every_enemy_and_gem_texture_exists() -> void:
	for path: String in Tuning.ENEMY_TEXTURES:
		assert_true(ResourceLoader.exists(path), "%s loads" % path)
	for path: String in Tuning.GEM_TEXTURES:
		assert_true(ResourceLoader.exists(path), "%s loads" % path)


func test_every_cat_has_art_and_a_real_weapon() -> void:
	for id: String in Tuning.CATS:
		var art := String(Tuning.CATS[id]["art"])
		assert_true(ResourceLoader.exists(art), "%s has art" % id)
		assert_true(
			Tuning.WEAPONS.has(String(Tuning.CATS[id]["weapon"])),
			"%s starts with a real weapon" % id,
		)


## There must be a texture per kind, or `_redraw` indexes off the end.
func test_a_texture_per_enemy_kind() -> void:
	assert_eq(Tuning.ENEMY_TEXTURES.size(), Tuning.ENEMIES.size(), "one texture per kind")


func test_a_size_and_texture_per_gem_kind() -> void:
	assert_eq(Tuning.GEM_SIZES.size(), Tuning.GEM_TEXTURES.size(), "sizes match kinds")


## An evolution has to name a weapon and a passive that exist.
func test_evolutions_name_real_things() -> void:
	for id: String in Tuning.EVOLUTIONS:
		assert_true(Tuning.WEAPONS.has(id), "%s is a weapon" % id)
		var needs := String(Tuning.EVOLUTIONS[id]["needs"])
		assert_true(Tuning.PASSIVES.has(needs), "%s needs a real passive" % id)


## Three cards need at least three things in the pool.
func test_there_is_always_something_to_offer() -> void:
	var pool := Tuning.WEAPONS.size() + Tuning.PASSIVES.size()
	assert_gte(pool, Tuning.LEVEL_CHOICES, "enough to fill the cards")


## Slots must not exceed what exists, or the picker runs dry mid-run.
func test_slots_fit_what_exists() -> void:
	assert_lte(Tuning.WEAPON_SLOTS, Tuning.WEAPONS.size(), "weapon slots are fillable")
	assert_lte(Tuning.PASSIVE_SLOTS, Tuning.PASSIVES.size(), "passive slots are fillable")


## The first level must arrive within seconds, or the loop never starts.
func test_the_first_level_is_cheap() -> void:
	assert_lte(Tuning.xp_for_level(1), 6, "a handful of bugs is a level")


## A bug must not outgrow what the starting weapon can do to it.
func test_bugs_stay_killable_at_the_end() -> void:
	var last := Tuning.enemy_hp(0, Tuning.RUN_SECONDS)
	var paw := Tuning.weapon_stat("paw", "damage", Tuning.WEAPON_LEVEL_MAX)
	assert_lt(last, paw * 4.0, "a grub at the end still dies to a few swipes")


## Mercy has to outlast the touch cooldown, or a bug sitting on the cat lands
## its next hit the instant the flashing stops.
func test_mercy_outlasts_a_touch() -> void:
	assert_gte(
		Tuning.PLAYER_MERCY_TIME,
		Tuning.ENEMY_TOUCH_COOLDOWN,
		"a bug cannot hit again the moment mercy ends",
	)


## The magnet must reach further than the grab, or gems are only collected by
## standing exactly on them.
func test_the_magnet_reaches_further_than_the_grab() -> void:
	assert_gt(Tuning.MAGNET_RADIUS, Tuning.GEM_TAKE_RADIUS, "gems fly in")


## Playing well has to pay. Cookies used to come almost entirely from bosses and
## the finish bonus, so a good run and a poor one paid the same and there was no
## reason to fight rather than hide.
func test_playing_well_pays_better() -> void:
	@warning_ignore("integer_division")
	var poor := (200 / Tuning.COOKIE_EVERY) * Tuning.COOKIE_VALUE
	@warning_ignore("integer_division")
	var good := (900 / Tuning.COOKIE_EVERY) * Tuning.COOKIE_VALUE
	var fixed := (
		Tuning.COOKIE_PER_BOSS * Tuning.BOSS_MINUTES.size() * Tuning.COOKIE_VALUE
		+ Tuning.COOKIE_FINISH_BONUS
	)
	assert_gt(
		float(good + fixed) / float(poor + fixed),
		1.4,
		"a strong run pays well over a weak one",
	)


## The first new cat should arrive after about one run, or the shop is a wall
## rather than a reward.
func test_the_first_cat_costs_about_one_run() -> void:
	var cheapest := 999999
	for id: String in Tuning.CATS:
		var cost := int(Tuning.CATS[id]["cost"])
		if cost > 0:
			cheapest = mini(cheapest, cost)
	@warning_ignore("integer_division")
	var a_run := (
		(400 / Tuning.COOKIE_EVERY) * Tuning.COOKIE_VALUE
		+ Tuning.COOKIE_PER_BOSS * Tuning.BOSS_MINUTES.size() * Tuning.COOKIE_VALUE
		+ Tuning.COOKIE_FINISH_BONUS
	)
	assert_lte(cheapest, a_run, "one run buys the first new cat")


## A cat has to be affordable within a few runs, or the shop is decoration.
func test_the_cheapest_cat_is_reachable() -> void:
	var cheapest := 999999
	for id: String in Tuning.CATS:
		var cost := int(Tuning.CATS[id]["cost"])
		if cost > 0:
			cheapest = mini(cheapest, cost)
	var per_run := (
		Tuning.COOKIE_FINISH_BONUS
		+ Tuning.COOKIE_PER_BOSS * Tuning.BOSS_MINUTES.size()
	)
	assert_lt(cheapest, per_run * 3, "a few runs buy the first new cat")
