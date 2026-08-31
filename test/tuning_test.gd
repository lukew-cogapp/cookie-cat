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
	var known := [
		"sweep", "shot", "aura", "orbit", "chaser", "zone", "strike", "burst",
		"boomer", "trail",
	]
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
	for name: String in Tuning.PICKUPS:
		assert_true(
			ResourceLoader.exists(Tuning.pickup_art(name)), "%s art loads" % name
		)


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


## The enum and the table must agree, in order. They are two lists of the same
## thing, and when they drifted the cat shop priced cats in red xp gems.
func test_the_pickup_order_matches_the_enum() -> void:
	assert_eq(Tuning.GEM_ORDER.size(), Tuning.PICKUPS.size(), "every pickup is ordered")
	assert_eq(Tuning.GEM_ORDER[Gems.Kind.GEM], "gem", "gem is first")
	assert_eq(Tuning.GEM_ORDER[Gems.Kind.GEM_GREEN], "gem_green", "then green")
	assert_eq(Tuning.GEM_ORDER[Gems.Kind.GEM_RED], "gem_red", "then red")
	assert_eq(Tuning.GEM_ORDER[Gems.Kind.HEART], "heart", "then the heart")
	assert_eq(Tuning.GEM_ORDER[Gems.Kind.COOKIE], "cookie", "then the cookie")


func test_every_ordered_pickup_is_in_the_table() -> void:
	for name: String in Tuning.GEM_ORDER:
		assert_true(Tuning.PICKUPS.has(name), "%s is a real pickup" % name)
		assert_gt(Tuning.pickup_size(name), 0.0, "%s has a size" % name)


## Each xp tier must be worth more than the one below, or a better gem is a
## worse pickup and the colours lie about the reward.
func test_the_xp_tiers_are_worth_more_going_up() -> void:
	var last := 0.0
	for tier in 3:
		var worth := Tuning.gem_worth(tier)
		assert_gt(worth, last, "tier %d beats the one below" % tier)
		last = worth


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


## Cookies must be worth earning: they are the hat shop's currency, and a run
## that pays nothing makes the counter on the start screen a decoration.
func test_a_run_pays_cookies() -> void:
	var a_run := (
		Tuning.COOKIE_PER_BOSS * Tuning.BOSS_MINUTES.size() * Tuning.COOKIE_VALUE
		+ Tuning.COOKIE_FINISH_BONUS
	)
	assert_gt(a_run, 0, "finishing a run pays something")
	assert_gt(Tuning.COOKIE_EVERY, 0, "and so does killing bugs")


## An upgrade card has to say what the level gives. "Fish Friends" twice tells
## a child nothing about which card to take.
func test_every_upgrade_says_what_it_gives() -> void:
	for id: String in Tuning.WEAPONS:
		for level in range(1, Tuning.WEAPON_LEVEL_MAX):
			assert_ne(
				Tuning.upgrade_blurb(id, level),
				"",
				"%s at level %d says what it gives" % [id, level],
			)
	for id: String in Tuning.PASSIVES:
		assert_ne(Tuning.upgrade_blurb(id, 1), "", "%s says what it gives" % id)


## And it has to be true: the words come from the numbers, so a retune cannot
## leave the card lying.
func test_a_count_upgrade_is_reported_when_it_happens() -> void:
	for id: String in Tuning.WEAPONS:
		for level in range(1, Tuning.WEAPON_LEVEL_MAX):
			var was := int(Tuning.weapon_stat(id, "count", level))
			var now := int(Tuning.weapon_stat(id, "count", level + 1))
			var says := Tuning.upgrade_blurb(id, level)
			if now > was:
				assert_true(
					"%d of them" % now in says,
					"%s level %d adds one and says so: %s" % [id, level, says],
				)


## Fish Friends is the clearest example: every level should put another fish
## on the ring, or the card is a wasted pick.
func test_every_fish_level_adds_a_fish() -> void:
	for level in range(1, Tuning.WEAPON_LEVEL_MAX):
		var was := int(Tuning.weapon_stat("fish", "count", level))
		var now := int(Tuning.weapon_stat("fish", "count", level + 1))
		assert_eq(now, was + 1, "fish level %d adds one" % (level + 1))


## Mercy caps hits at one per `PLAYER_MERCY_TIME` however many bugs are
## touching, so damage per hit is the ONLY lever on how fast a run can end.
## At 4 damage a grub swarm took forty seconds to finish the cat and the bar
## looked stuck; standing in a crowd has to cost something a child notices.
func test_standing_in_a_crowd_kills_you() -> void:
	for kind in Tuning.ENEMIES.size():
		var hits := Tuning.PLAYER_MAX_HP / Tuning.enemy_damage(kind)
		var seconds := hits * Tuning.PLAYER_MERCY_TIME
		assert_lt(
			seconds,
			25.0,
			"%s kills a standing cat in %.0fs" % [Tuning.ENEMIES[kind]["name"], seconds],
		)


## And a boss must hurt more than a first-minute bug, which is the whole point
## of per-kind damage: they all dealt exactly 1.0 before.
func test_a_boss_hits_harder_than_a_grub() -> void:
	var grub := Tuning.enemy_damage(0)
	var boss := Tuning.enemy_damage(5)
	assert_gt(boss, grub * 3.0, "a boss hit is worth several grub hits")


## But nothing may one-shot a full-health cat: a run that ends in a single
## touch reads as the game cheating.
func test_nothing_one_shots_the_cat() -> void:
	for kind in Tuning.ENEMIES.size():
		assert_lt(
			Tuning.enemy_damage(kind),
			Tuning.PLAYER_MAX_HP,
			"%s does not end a run in one touch" % Tuning.ENEMIES[kind]["name"],
		)


## Big Bowl says every toy gets bigger, so every toy has to have something for
## it to enlarge. Yarn Ball and the Feather Wand have no radius of their own
## and were getting nothing at all while the card promised otherwise.
func test_every_weapon_can_be_made_bigger() -> void:
	for id: String in Tuning.WEAPONS:
		var w: Dictionary = Tuning.WEAPONS[id]
		var travels := String(w["kind"]) in ["shot", "chaser", "boomer"]
		assert_true(
			w.has("radius") or travels,
			"%s has a radius, or is a shot whose sweep the bowl widens" % id,
		)


## Every map's dominant floor tones, as 8-bit triples from the palette in
## `scripts/tools/make_art.py`: lawn greens, sand, then snow and ice. `Color8`
## is a function rather than a constant expression, so these stay as ints.
const FLOOR_TONES := [
	[126, 186, 108],
	[134, 194, 116],
	[116, 176, 100],
	[233, 209, 156],
	[247, 229, 182],
	[208, 178, 128],
	[226, 238, 248],
	[242, 248, 255],
	[198, 216, 234],
	[140, 192, 232],
	[196, 228, 248],
]
## The art's outline, which is what gives a flashing bug its rim.
const OUTLINE_TONE := [58, 42, 58]


## CIE Lab dE76 between two colours, which counts hue as well as lightness. A
## luminance ratio alone calls amber on snow invisible while the blue channel
## differs by 220 levels, which is the difference the eye reads first.
func _difference(a: Color, b: Color) -> float:
	var la := _lab(a)
	var lb := _lab(b)
	return (la - lb).length()


func _lab(c: Color) -> Vector3:
	var r := c.srgb_to_linear()
	var x := (0.4124 * r.r + 0.3576 * r.g + 0.1805 * r.b) / 0.95047
	var y := 0.2126 * r.r + 0.7152 * r.g + 0.0722 * r.b
	var z := (0.0193 * r.r + 0.1192 * r.g + 0.9505 * r.b) / 1.08883
	return Vector3(
		116.0 * _lab_f(y) - 16.0,
		500.0 * (_lab_f(x) - _lab_f(y)),
		200.0 * (_lab_f(y) - _lab_f(z)),
	)


func _lab_f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


## An 8-bit triple from the art palette as a Color.
func _tone(rgb: Array) -> Color:
	return Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))


## What a bug's pixel becomes while flashing: the per-instance flash colour
## times the per-kind dim, clipped, as the MultiMesh does it.
func _flashed(texel: Color) -> Color:
	var f := Tuning.HIT_FLASH_COLOUR
	var d := Tuning.ENEMY_DIM
	return Color(
		minf(1.0, texel.r * f.r * d.r),
		minf(1.0, texel.g * f.g * d.g),
		minf(1.0, texel.b * f.b * d.b),
	)


## A hit has to be visible on every map, and the palest bug on the palest floor
## is the case that decides it. A flat white flash sat 5 dE from the arctic's
## snow, so on that map the child could not see their toy working at all.
func test_the_hit_flash_reads_on_every_map() -> void:
	var body := _flashed(Color.WHITE)
	for tone: Array in FLOOR_TONES:
		assert_gt(
			_difference(body, _tone(tone)),
			40.0,
			"a flashing bug separates from floor %s" % [tone],
		)


## And the outline has to survive the flash, or a pale bug loses the dark rim
## that holds its shape against pale ground. Raising every channel washed it
## out to grey.
func test_the_hit_flash_keeps_the_dark_outline() -> void:
	assert_gt(
		_difference(_flashed(Color.WHITE), _flashed(_tone(OUTLINE_TONE))),
		45.0,
		"a flashing bug keeps a rim",
	)
