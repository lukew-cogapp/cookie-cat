extends Node
## Every number worth fiddling with lives here, so playtesting means editing
## one file. Autoloaded as `Tuning`, and GDScript hot-reloads, so these can
## change while the game runs.

# --- The run ---
## Ten minutes. Long enough to earn an evolution, short enough that a child
## finishes one rather than abandoning it.
const RUN_SECONDS := 600.0
## How far props are scattered from the origin. There is no wall: the cat is
## never clamped, because being cornered against an invisible edge with bugs
## closing in is the one situation a child cannot escape, and the whole
## difficulty rests on running away always working. The lawn tiles and the props
## wrap around the cat instead, so walking in one direction forever is fine.
## Props are scattered on a fixed grid of cells this wide, seeded per cell, so
## walking into new ground fills it in rather than re-rolling the whole field.
## The field-follows-the-cat version teleported every pot on screen at once.
const PROP_CELL := 400.0
const PROP_PER_CELL := 5
## Props further than this are forgotten, and their cells with them, so a long
## walk cannot overflow the arrays. Walking back rebuilds the same garden.
const PROP_FORGET_DISTANCE := 1500.0
## Props are re-scattered ahead of the cat once it walks this far from the
## middle of the current field, so the garden never runs out.
const PROP_REFILL_DISTANCE := 1100.0
## The camera zoom. Art is 16x16, so at 2.5 a bug is 40 screen pixels and the
## cat 64: big enough to read at a glance. Rendered at 1.0 the cat was a speck
## and no weapon effect could be made out at all.
const ZOOM := 2.5

# --- Player ---
## Hearts, not a health bar: big icons a five-year-old can count. Five, not
## three, so a bad minute is a setback rather than the end of the run.
const PLAYER_MAX_HP := 5.0
const PLAYER_SPEED := 118.0
## Every enemy is slower than this. A child who runs away must always escape;
## the genre's tension comes from being surrounded, not from being outrun.
const PLAYER_RADIUS := 15.0
## The cat is drawn this many world units across. It must be the biggest thing
## in the garden: rendered at the sprite's own 16 it was smaller than every bug
## and hard to find in a crowd.
const PLAYER_DRAW_SIZE := 30.0
## A long blink after a hit. Standing in a crowd otherwise costs all three
## hearts in a second, which teaches nothing.
const PLAYER_MERCY_TIME := 1.6
## A hit also shoves every bug off the cat. Mercy time alone is not enough:
## a cat standing in a crowd loses the next heart the frame mercy ends, which
## measured as all three hearts in 3.7 seconds. Clearing space is what gives a
## child the chance to walk out.
const PLAYER_HIT_PUSH_RADIUS := 100.0
const PLAYER_HIT_PUSH := 200.0
const PLAYER_HURT_COLOUR := Color(1.0, 0.45, 0.45)
const PLAYER_BOB := 1.5
const PLAYER_BOB_RATE := 11.0
## Walk frames per second. Each cat has its own step frames, generated from its
## standing sprite by `make_art.py`.
const PLAYER_STEP_RATE := 8.0
## The slowest a stick push may move the cat, as a fraction of full speed.
## Keyboard input is always 1.0; this only floors a light analogue push. It has
## to clear the fastest bug: at 0.55 a gentle push gave 65 against a wasp's 104,
## so a child who was moving still got caught.
const STICK_WALK_FLOOR := 0.95
const CAT_STEP_A := "res://assets/cat_step_a.png"
const CAT_STEP_B := "res://assets/cat_step_b.png"

# --- Levelling ---
## First level inside about fifteen seconds, then a widening gap. VS adds a
## flat increment per level; this is the same shape with smaller numbers,
## since a ten-minute run reaches level 25 or so rather than 100.
const XP_BASE := 4
const XP_STEP := 5
const LEVEL_CHOICES := 3
const WEAPON_SLOTS := 5
const PASSIVE_SLOTS := 4
const WEAPON_LEVEL_MAX := 6
const PASSIVE_LEVEL_MAX := 5

# --- Cats ---
## Every cat is free, and each opens with a different weapon: that is the whole
## difference between them, and a starting weapon changes how a run has to be
## played from the first second where a stat bonus is a number a child cannot
## see. Choosing one is the first decision of a run, not a reward to grind for.
##
## `cost` stays in the table at zero rather than being removed, so the shop and
## the save's unlocked list keep working. Cookies are for cosmetics instead:
## hats and the like, which change nothing about how a run plays. Gating a
## weapon behind a grind punishes the child who most needs the help.
## Picks that are used at once rather than levelled. `Run.take` applies them
## and they never appear in `weapons` or `passives`, so a snack cannot be
## "levelled" and cannot fill a slot.
const CONSUMABLES := {
	"snack": {"name": "Tasty Snack", "heals": 1.0},
}

const STARTER_CAT := "cookie"
const CATS := {
	"cookie": {"name": "Cookie Cat", "weapon": "paw", "cost": 0, "art": "res://assets/cat.png"},
	"mint": {"name": "Minty", "weapon": "yarn", "cost": 0, "art": "res://assets/cat_mint.png"},
	"berry": {"name": "Berry", "weapon": "fish", "cost": 0, "art": "res://assets/cat_berry.png"},
	"choc": {"name": "Choccy", "weapon": "purr", "cost": 0, "art": "res://assets/cat_choc.png"},
	"lion": {"name": "Lion", "weapon": "zap", "cost": 0, "art": "res://assets/cat_lion.png"},
}

## Cookies are the currency between runs. Bugs drop them rarely; a boss always
## does, so a child who reaches one is paid for it.
const COOKIE_EVERY := 12
const COOKIE_PER_BOSS := 10
const COOKIE_VALUE := 1
## Paid at the end for surviving, so a full run is worth more than quitting at
## nine minutes with the same kills.
const COOKIE_FINISH_BONUS := 30
## Cookies from a boss are scattered rather than stacked, so they read as a
## pile to walk through and not as one pickup.
const BOSS_DROP_SPREAD := 20.0


func xp_for_level(level: int) -> int:
	return XP_BASE + XP_STEP * (level - 1)


# --- Weapons ---
## `kind` picks the firing code in weapons.gd; everything else is numbers it
## reads. Damage and cooldown are per level 1 and scale by the `_gain` keys.
## Cat-themed, and each one a different shape of attack, because two weapons
## that both throw a thing at the nearest enemy read as one weapon.
const WEAPONS := {
	"paw":
	{
		"name": "Paw Swipe",
		## A full circle, not a wedge. A wedge only defends the way the cat
		## faces, and a child under pressure runs away: a probe fleeing a crowd
		## for thirty seconds landed ONE kill, swiping at empty grass the whole
		## time while bugs ate it from behind. The starting weapon has to
		## protect a retreating player, so it swipes all round.
		"kind": "sweep",
		"damage": 5.0,
		"cooldown": 0.95,
		"radius": 52.0,
		"damage_gain": 2.5,
		"cooldown_gain": -0.07,
		"radius_gain": 5.0,
	},
	"yarn":
	{
		"name": "Yarn Ball",
		"kind": "shot",
		"damage": 5.0,
		"cooldown": 1.0,
		"speed": 340.0,
		"pierce": 1,
		"count": 1,
		"damage_gain": 3.0,
		"cooldown_gain": -0.07,
		"count_gain": 0.4,
	},
	"purr":
	{
		"name": "Purr Ring",
		"kind": "aura",
		"damage": 2.0,
		"cooldown": 0.5,
		"radius": 62.0,
		"damage_gain": 1.2,
		"radius_gain": 9.0,
	},
	"fish":
	{
		"name": "Fish Friends",
		"kind": "orbit",
		"damage": 5.0,
		"cooldown": 0.35,
		"radius": 64.0,
		"count": 2,
		"spin": 2.2,
		"damage_gain": 2.0,
		"count_gain": 0.6,
	},
	"mouse":
	{
		"name": "Toy Mouse",
		"kind": "chaser",
		"damage": 7.0,
		"cooldown": 1.7,
		"speed": 260.0,
		"radius": 24.0,
		"count": 1,
		"damage_gain": 4.0,
		"count_gain": 0.4,
	},
	"milk":
	{
		"name": "Milk Puddle",
		"kind": "zone",
		"damage": 2.5,
		"cooldown": 2.2,
		"radius": 44.0,
		"life": 3.2,
		## Bugs in the puddle walk at this fraction of their speed. The puddle
		## is the only crowd control in the game, and without it milk was a
		## second purr ring: damage over an area, which already exists.
		"slow": 0.45,
		"damage_gain": 1.4,
		"radius_gain": 6.0,
	},
	"zap":
	{
		"name": "Static Fur",
		"kind": "strike",
		"damage": 9.0,
		"cooldown": 1.6,
		"radius": 260.0,
		"count": 1,
		"damage_gain": 5.0,
		"count_gain": 0.5,
	},
	"boomer":
	{
		"name": "Feather Wand",
		## Out and back on its string, hitting on both legs. The only weapon
		## that rewards letting a bug approach: it is worth twice as much on
		## the way home.
		"kind": "boomer",
		"damage": 6.0,
		"cooldown": 1.5,
		"speed": 300.0,
		"range": 150.0,
		"count": 1,
		"damage_gain": 3.0,
		"cooldown_gain": -0.09,
		"count_gain": 0.4,
	},
	"trail":
	{
		"name": "Crumb Trail",
		## Crumbs dropped as the cat walks, which burst when a bug reaches them.
		## The one weapon that pays for running away, and it does nothing at all
		## standing still: that is the point, since fleeing is the whole tactic
		## a child has.
		"kind": "trail",
		"damage": 7.0,
		"cooldown": 0.42,
		"radius": 30.0,
		"life": 4.0,
		"damage_gain": 3.5,
		"radius_gain": 4.0,
	},
	"nap":
	{
		"name": "Sleepy Yawn",
		"kind": "burst",
		"damage": 6.0,
		"cooldown": 3.0,
		"radius": 105.0,
		"damage_gain": 3.5,
		"radius_gain": 14.0,
	},
}

## Passives multiply, so `per_level` is a fraction. `Run.passive(id)` returns
## `1 + per_level * level`, which is 1.0 for anything never picked.
const PASSIVES := {
	"boots": {"name": "Quick Paws", "per_level": 0.09},
	"claw": {"name": "Sharp Claws", "per_level": 0.13},
	"bell": {"name": "Jingle Bell", "per_level": -0.09},
	"magnet": {"name": "Whisker Sense", "per_level": 0.32},
	"bowl": {"name": "Big Bowl", "per_level": 0.11},
}

## Weapon at max level plus this passive, once a present is opened, becomes
## the evolution. One per weapon at most, and two are enough for a ten-minute
## run: a third has never been reached in a playtest.
const EVOLUTIONS := {
	"paw": {"needs": "claw", "into": "Tiger Swipe", "damage": 3.0, "radius": 1.6},
	"yarn": {"needs": "bell", "into": "Yarn Storm", "damage": 2.2, "count": 3.0},
	"purr": {"needs": "bowl", "into": "Big Purr", "damage": 2.4, "radius": 1.7},
	"fish": {"needs": "boots", "into": "Fish Parade", "damage": 2.0, "count": 2.0},
}

# --- Weapon effects ---
## No cooldown may go below this however many bells are picked, or a weapon
## fires every physics frame and the sound becomes a buzz.
const WEAPON_COOLDOWN_FLOOR := 0.12
## How far a weapon looks for something to aim at. Beyond the screen edge, so
## a shot can be fired at a bug arriving rather than one already in reach.
const SHOT_SEEK_RANGE := 300.0
const SHOT_LIFE := 2.4
const SHOT_HIT_RADIUS := 14.0
## Index order for shot_kind, which picks the draw colour.
const SHOT_KINDS := ["yarn", "mouse", "boomer"]
## Shots are drawn as their own art, in SHOT_KINDS order.
const SHOT_ART := [
	"res://assets/yarn.png",
	"res://assets/mouse.png",
	"res://assets/boomer.png",
]
const SHOT_DRAW_SIZE := 20.0
## Yarn tumbles as it flies; the mouse points along its travel instead.
const SHOT_SPIN := 7.0
## A short streak behind a shot, so a fast ball reads as thrown rather than as
## a dot teleporting between frames.
const SHOT_TRAIL := 16.0
const SHOT_TRAIL_WIDTH := 4.0
const SHOT_TRAIL_COLOUR := Color(1.0, 0.85, 0.92, 0.4)
## Per-kind trail tints, in SHOT_KINDS order, so a grey mouse does not fly a
## pink streak. The boomerang overrides these per leg (BOOMER_TRAIL_*).
const SHOT_TRAIL_COLOURS := [
	Color(1.0, 0.85, 0.92, 0.4),
	Color(0.9, 0.9, 0.95, 0.35),
	Color(0.65, 0.9, 1.0, 0.45),
]
## A boomerang within this of the cat has been caught.
const BOOMER_CATCH_RADIUS := 22.0
## Crumbs hurt over time like a puddle, so their listed damage is a rate.
const TRAIL_DAMAGE_RATE := 0.9
## Orbiting fish sweep every frame rather than on a cooldown, so their listed
## damage is scaled down to a per-second rate.
const ORBIT_DAMAGE_RATE := 0.12
const ORBIT_HIT_RADIUS := 18.0
const ORBIT_DRAW_SIZE := 22.0
## Fish are drawn as fish. A blue circle orbiting the cat read as a bubble.
const ORBIT_ART := "res://assets/fish.png"
const AURA_COLOUR := Color(1.0, 0.72, 0.84, 0.85)
const AURA_WIDTH := 2.0
## The purr ring is a turning circle of pips, not a thin outline: an outline
## reads as a UI element drawn over the game.
const AURA_PIPS := 14
const AURA_SPIN := 0.9
const AURA_PIP_SIZE := 4.0
## Each pip breathes on its own phase, so the ring shimmers rather than
## pulsing as one solid band.
const AURA_PIP_BREATHE := 0.3
const AURA_PIP_RATE := 4.0
const ZONE_COLOUR := Color(0.95, 0.95, 1.0, 0.5)
## A rim on the puddle, so the edge of the slow is visible rather than a soft
## blob with no boundary.
const ZONE_RIM_COLOUR := Color(0.75, 0.9, 1.0, 0.8)
const ZONE_RIM_WIDTH := 3.0
## A puddle fades over its last seconds rather than blinking out.
const ZONE_FADE_TIME := 1.0
## How long a bug keeps walking slowly after leaving a puddle. Long enough that
## the slow does not flicker as it crosses the edge.
const SLOW_LINGER := 0.35

# --- Enemies ---
## Rows in swarm.gd read these by Kind. Speed is always under PLAYER_SPEED.
## HP is flat per kind and grows with the clock, not with player level: a
## child who levels fast should feel stronger, not meet tougher bugs.
const ENEMIES := [
	{"name": "Grub", "hp": 6.0, "speed": 46.0, "damage": 1.0, "radius": 9.0, "xp": 1, "gem_up": 0.02, "knock": 46.0},
	{"name": "Beetle", "hp": 14.0, "speed": 62.0, "damage": 1.0, "radius": 10.0, "xp": 2, "gem_up": 0.06, "knock": 38.0},
	{"name": "Snail", "hp": 34.0, "speed": 28.0, "damage": 1.0, "radius": 12.0, "xp": 4, "gem_up": 0.14, "knock": 22.0},
	{"name": "Wasp", "hp": 10.0, "speed": 104.0, "damage": 1.0, "radius": 8.5, "xp": 3, "gem_up": 0.1, "knock": 60.0},
	{"name": "Slime", "hp": 22.0, "speed": 52.0, "damage": 1.0, "radius": 11.0, "xp": 3, "gem_up": 0.12, "knock": 34.0},
	{"name": "Big Bug", "hp": 340.0, "speed": 44.0, "damage": 1.0, "radius": 26.0, "xp": 60, "gem_up": 0.8, "knock": 6.0},
	{"name": "Spider", "hp": 12.0, "speed": 92.0, "damage": 1.0, "radius": 9.0, "xp": 3, "gem_up": 0.1, "knock": 42.0},
	{"name": "Dung Beetle", "hp": 26.0, "speed": 40.0, "damage": 1.0, "radius": 11.0, "xp": 5, "gem_up": 0.16, "knock": 18.0},
]
const ENEMY_MAX := 220
## Past this from the player an enemy is forgotten. Over a screen and a half,
## so nothing vanishes while it is being looked at.
const ENEMY_CULL_DISTANCE := 700.0
const ENEMY_TOUCH_COOLDOWN := 0.9
## Enemy HP doubles over a full run. Applied at spawn and fixed thereafter.
const ENEMY_HP_RAMP := 1.0
## One texture per kind, in Kind order. Each is its own MultiMesh, so a run
## costs six draw calls for any number of bugs.
const ENEMY_TEXTURES := [
	"res://assets/grub.png",
	"res://assets/beetle.png",
	"res://assets/snail.png",
	"res://assets/wasp.png",
	"res://assets/slime.png",
	"res://assets/big.png",
	"res://assets/spider.png",
	"res://assets/dung.png",
]
const SWARM_SEED := 20260831

# --- Spider and dung beetle ---
## The spider scuttles: full speed in bursts, near-still between them. The
## listed speed is the burst, so the no-bug-outruns-the-cat rule still holds.
const SPIDER_SCUTTLE_CYCLE := 1.1
## Fraction of each cycle spent moving.
const SPIDER_SCUTTLE_DUTY := 0.45
## Pace between bursts. Not zero: a bug frozen mid-walk reads as a hang.
const SPIDER_PAUSE_PACE := 0.12

## The dung beetle is the first bug that hurts the cat without touching it, so
## every number here is about being dodgeable: it stands off, shivers in plain
## view before each lob, and the ball flies slower than the cat walks.
const DUNG_FIRE_RANGE := 240.0
## It stops closing here, so it reads as a thrower rather than a biter.
const DUNG_STAND_RANGE := 150.0
## Longer than mercy time, so one beetle cannot chain hits.
const DUNG_FIRE_COOLDOWN := 2.8
## The wind-up shiver before each lob. A five-year-old cannot dodge a shot
## that appears from nothing.
const DUNG_TELEGRAPH := 0.7
const DUNG_WOBBLE := 0.22
const DUNG_WOBBLE_RATE := 26.0

## Poop balls: pooled rows in swarm.gd, drawn by one MultiMesh, like the bugs.
const POOP_MAX := 64
const POOP_SPEED := 88.0
const POOP_DAMAGE := 1.0
const POOP_HIT_RADIUS := 8.0
## Long enough to reach the cat from the far edge of the fire range.
const POOP_LIFE := 3.2
const POOP_DRAW_SIZE := 14.0
const POOP_SPIN := 6.0
const POOP_ART := "res://assets/poop.png"


## The spider's speed multiplier at time `t`, one burst per cycle.
func spider_pace(t: float) -> float:
	var phase := fmod(t, SPIDER_SCUTTLE_CYCLE)
	if phase < SPIDER_SCUTTLE_CYCLE * SPIDER_SCUTTLE_DUTY:
		return 1.0
	return SPIDER_PAUSE_PACE

# --- Waves ---
## One entry per minute of the run: which kinds spawn, how often, and how many
## must be alive. The quota is what makes the screen fill up; the interval only
## decides how lumpy the filling is. Peaks at 150, not VS's 300: a child needs
## to see their cat.
const WAVES := [
	{"kinds": [0], "interval": 1.6, "min_alive": 6},
	{"kinds": [0], "interval": 1.4, "min_alive": 11},
	{"kinds": [0, 1], "interval": 1.2, "min_alive": 17},
	{"kinds": [0, 1], "interval": 1.0, "min_alive": 25},
	{"kinds": [1, 3], "interval": 0.9, "min_alive": 34},
	{"kinds": [1, 2, 3], "interval": 0.8, "min_alive": 46},
	{"kinds": [0, 3, 4, 6], "interval": 0.7, "min_alive": 60},
	{"kinds": [1, 2, 4, 7], "interval": 0.65, "min_alive": 78},
	{"kinds": [1, 2, 3, 4, 6, 7], "interval": 0.6, "min_alive": 98},
	{"kinds": [0, 1, 2, 3, 4, 6, 7], "interval": 0.55, "min_alive": 124},
]
## Spawns land on a ring just off screen. Slightly wider than the corner of a
## 1280x720 viewport, so nothing appears in front of the player.
const SPAWN_RING := 330.0
## How many the quota top-up may add in one physics frame. A whole quota at
## once on the first frame of a minute arrives as a visible wall.
const SPAWN_BURST_MAX := 1
const SPAWN_PER_TICK := 1
## And how fast the quota may refill, in bugs per second. Without this the
## quota replaces every kill instantly, so a child mowing a crowd sees no
## reward for it and the screen stays exactly as full. A probe died at 32
## seconds against an unthrottled quota.
const SPAWN_REFILL_RATE := 3.0
## Minutes at which one Big Bug arrives. Each drops a present.
const BOSS_MINUTES := [4, 7, 9]

# --- Pickups ---
const GEM_MAX := 300
## Pickups, keyed by name. `GEM_ORDER` is what fixes them to the indices in
## `Gems.Kind`, so the enum and this table cannot drift: a positional lookup
## here silently became the red xp gem the moment the xp tiers were added, and
## the cat shop started pricing cats in gems.
const PICKUPS := {
	"gem": {"art": "res://assets/gem.png", "size": 12.0, "worth": 1.0},
	"gem_green": {"art": "res://assets/gem_green.png", "size": 14.0, "worth": 3.0},
	"gem_red": {"art": "res://assets/gem_red.png", "size": 16.0, "worth": 9.0},
	"heart": {"art": "res://assets/heart.png", "size": 15.0},
	"cookie": {"art": "res://assets/cookie.png", "size": 17.0},
}
## The order `Gems.Kind` numbers them in. `test/tuning_test.gd` asserts the two
## agree, so adding a pickup in the wrong place fails a test rather than
## redrawing something else with nothing to show for it.
const GEM_ORDER := ["gem", "gem_green", "gem_red", "heart", "cookie"]

## One pickup's art or size, by name. Nothing outside `gems.gd` should index
## `GEM_ORDER`: ask for what you want.
func pickup_art(name: String) -> String:
	return String(PICKUPS[name]["art"])


func pickup_size(name: String) -> float:
	return float(PICKUPS[name]["size"])


## What an xp tier is worth, as a multiple of the bug's own xp. A red gem has
## to be worth crossing the screen for.
func gem_worth(tier: int) -> float:
	return float(PICKUPS[GEM_ORDER[tier]]["worth"])


## A bob, not a spin: a flat sprite turned edge-on vanishes.
const GEM_BOB := 2.5
const GEM_BOB_RATE := 3.0
const MAGNET_RADIUS := 62.0
const GEM_TAKE_RADIUS := 14.0
const GEM_FLY_SPEED := 200.0
const GEM_FLY_ACCEL := 700.0
## A heart every so many kills, so a child who is struggling gets one and a
## child who is winning barely notices them.
const HEART_EVERY := 90
const HEART_HEAL := 1.0

# --- Feel ---
const HIT_FLASH_TIME := 0.08
## Bugs are drawn white-tinted for this long after a hit. The art carries the
## colour now, so a hit replaces it rather than blending towards white.
const HIT_FLASH_COLOUR := Color(3.0, 3.0, 3.0)
## Below this the walk direction is too vertical to flip on, so a bug walking
## straight down does not shimmer between facings.
const ENEMY_FLIP_DEADZONE := 4.0
const KNOCKBACK_DECAY := 9.0
## Shake is for bosses and evolutions only. Constant shake on every kill is
## unpleasant for the audience this is built for.
const SHAKE_AMPLITUDE := 2.0
const SHAKE_TIME := 0.15

# --- Attack effects ---
## Every weapon must be visible: a bug dying with nothing on screen reads as
## the game killing it rather than the cat. Instant weapons leave one of these
## shapes for a fraction of a second.
const FX_ARC := 0
const FX_RING := 1
const FX_BOLT := 2
const FX_TIME_ARC := 0.16
const FX_TIME_RING := 0.28
const FX_TIME_BOLT := 0.12
const FX_ARC_COLOUR := Color(1.0, 0.98, 0.82, 0.9)
const FX_ARC_WIDTH := 6.0
## The swipe is several tapering crescents, each trailing the one in front, so
## it reads as a paw sweeping rather than a shape appearing all at once.
const FX_ARC_BANDS := 3
const FX_ARC_BAND_LAG := 0.12
const FX_ARC_BAND_STEP := 0.13
const FX_ARC_SPARKS := 4
const FX_ARC_SPARK_SPREAD := 0.5
const FX_ARC_SPARK_SIZE := 4.0
## Each sweep starts this far round from the last, so repeated swipes read as
## the cat batting round itself rather than one animation restarting.
const FX_ARC_TURN := 1.9
const FX_RING_COLOUR := Color(0.72, 0.92, 1.0, 0.85)
const FX_RING_WIDTH := 5.0
## The second ring of a yawn trails the first by this much of its life.
const FX_RING_LAG := 0.35
const FX_BOLT_COLOUR := Color(1.0, 0.94, 0.5, 0.95)
const FX_BOLT_WIDTH := 3.0
## A straight line between cat and bug reads as a tether, so the bolt zigzags.
const FX_BOLT_STEPS := 6
const FX_BOLT_JAG := 11.0
const FX_BOLT_FLASH := 9.0
## Second-pass effects: an impact star where a hit lands, the boomerang's
## turn, and the catch as it comes home.
const FX_HIT := 3
const FX_TWIRL := 4
const FX_CATCH := 5
const FX_TIME_HIT := 0.14
const FX_TIME_TWIRL := 0.22
const FX_TIME_CATCH := 0.28
## The impact star: short spokes flaring out of the hit point, tinted per
## weapon, so different toys connecting read as different touches.
const HIT_FX_SIZE := 9.0
const HIT_FX_SPOKES := 4
const HIT_FX_WIDTH := 2.0
## A swipe through a crowd caps its stars, or one paw fills the fx pool.
const HIT_FX_PER_SWIPE := 3
const HIT_TINTS := {
	"paw": Color(1.0, 0.95, 0.7),
	"yarn": Color(1.0, 0.72, 0.85),
	"mouse": Color(0.88, 0.86, 0.92),
	"boomer": Color(0.65, 0.9, 1.0),
}
## Popped bugs within this window count towards the cheer.
const COMBO_WINDOW := 4.0
const COMBO_EVERY := 25

# --- Juice ---
## Burst particles (puffs.gd): pooled rows drawn by one MultiMesh per shape,
## like the swarm. Decorative only, so a full pool drops the burst rather
## than growing.
const PUFF_MAX := 240
## In Puffs.Kind order: star, sparkle, poof.
const PUFF_TEXTURES := [
	"res://assets/star.png",
	"res://assets/sparkle.png",
	"res://assets/poof.png",
]
const PUFF_LIFE := 0.45
## Velocity halves roughly every 1/damping seconds, so a burst blooms and
## settles rather than flying off screen.
const PUFF_DAMPING := 5.0
const PUFF_SIZE := 11.0
## A kill bursts into this many stars; the boss gets a bigger send-off.
const PUFF_KILL_COUNT := 5
const PUFF_KILL_SPEED := 120.0
const PUFF_BOSS_COUNT := 16
## Pickup sparkles rise a little, like the collect was worth something.
const PUFF_PICKUP_COUNT := 3
const PUFF_PICKUP_SPEED := 55.0
const PUFF_PICKUP_DRIFT := Vector2(0.0, -40.0)
## Instance tints over the white sparkle art.
const PUFF_GOLD := Color(1.0, 0.85, 0.4)
const PUFF_PINK := Color(1.0, 0.6, 0.75)
const PUFF_MINT := Color(0.6, 1.0, 0.9)
const PUFF_WHITE := Color(1.0, 1.0, 1.0)

## Floating reward numbers: only for hauls a child would ask about. Small
## gems stay wordless sparkles.
const NUMBER_MAX := 12
const NUMBER_MIN_WORTH := 4
const NUMBER_LIFE := 0.9
const NUMBER_RISE := 42.0
const NUMBER_FONT_SIZE := 20
const NUMBER_COLOUR := Color(1.0, 0.95, 0.55)

## A claimed gem darts away before homing, so the magnet reads as a grab
## rather than a teleport. Negative initial speed on the same homing line.
const GEM_DART_SPEED := 140.0
## Consecutive pickups step the pickup chime up in pitch; the streak resets
## after this long without one.
const GEM_STREAK_GAP := 1.0
const GEM_STREAK_SEMITONES := 1.0
const GEM_STREAK_CAP := 12

## Hit squash: bugs flatten by this fraction while the white flash runs.
const HIT_SQUASH := 0.3
## Spawns scale in over this long, so nothing appears at full size and bites.
const SPAWN_GROW_TIME := 0.35

## Pick cards pop in one after another.
const CARD_POP_FROM := 0.5
const CARD_STAGGER := 0.09
const CARD_POP_TIME := 0.22

## The boss is announced this long before it walks in, with a poof ring at
## the spot it will arrive.
const BOSS_TELEGRAPH_TIME := 1.2
const BOSS_RING_COUNT := 12
const BOSS_RING_RADIUS := 30.0
const BOSS_RING_SPEED := 60.0

## The combo cheer: a ring of gold stars around the cat.
const COMBO_STARS := 12
const COMBO_RING_RADIUS := 34.0
const COMBO_RING_SPEED := 110.0


# --- Boomerang feel ---
## The fish tumbles as it flies: below about 12 rad/s a 16px sprite at 60fps
## reads as wobbling, not spinning.
const BOOMER_SPIN := 16.0
## A longer streak than other shots, and a different tint per leg: cool going
## out, gold coming home, because the return is the leg that pays twice.
const BOOMER_TRAIL := 26.0
const BOOMER_TRAIL_OUT := Color(0.65, 0.9, 1.0, 0.45)
const BOOMER_TRAIL_BACK := Color(1.0, 0.85, 0.45, 0.6)
## A small flash where the fish turns, so the far point of the throw reads.
const TWIRL_RADIUS := 16.0
## The catch ring closes onto the cat rather than expanding, which is what
## makes it read as caught rather than as another blast.
const CATCH_RADIUS := 24.0
const CATCH_PUFFS := 4

# --- Crumb trail look ---
const ZONE_MILK := 0
const ZONE_CRUMB := 1
## Biscuit tones from the cat's own sandwich, so crumbs read as food.
const CRUMB_COLOUR := Color(0.77, 0.55, 0.36)
const CRUMB_LIGHT := Color(0.91, 0.72, 0.52)
const CRUMB_OUTLINE := Color(0.23, 0.16, 0.23, 0.85)
## Crumbs per drop. They vanish one by one as the drop's life runs out, so a
## trail being eaten empties visibly.
const CRUMB_COUNT := 5
const CRUMB_SIZE := 3.2
## How far crumbs scatter, as a fraction of the zone radius.
const CRUMB_SPREAD := 0.6
## A bitten pile jiggles this long, which is the "being eaten" read.
const CRUMB_BITE_TIME := 0.3
const CRUMB_JIGGLE := 1.6
const CRUMB_JIGGLE_RATE := 34.0
const CRUMB_PUFF_COUNT := 3
const CRUMB_PUFF_SPEED := 45.0
## Minimum seconds between nibble puffs, or a crowd on a trail is a blizzard.
const CRUMB_PUFF_GAP := 0.35

# --- Finding the cat ---
## At minute eight the screen holds a hundred bugs, and the cat has to stay
## findable without per-bug cost: a ground shadow and a soft halo under the
## cat, and one modulate on each enemy MultiMesh node.
const PLAYER_SHADOW_COLOUR := Color(0.1, 0.08, 0.12, 0.3)
const PLAYER_SHADOW_RADIUS := 12.0
const PLAYER_SHADOW_SQUASH := 0.38
const PLAYER_SHADOW_DROP := 14.0
## Layered translucent discs fake a glow; alpha stacks towards the centre.
const PLAYER_HALO_COLOUR := Color(1.0, 0.97, 0.75, 0.13)
const PLAYER_HALO_RINGS := 3
const PLAYER_HALO_RADIUS := 26.0
const PLAYER_HALO_STEP := 0.3
const PLAYER_HALO_PULSE := 0.07
const PLAYER_HALO_RATE := 2.6
## Enough to hand the cat the brightest pixels on screen, not enough to mud
## the bug art. The hit flash still blows past it to white.
const ENEMY_DIM := Color(0.88, 0.88, 0.93)

# --- Audio feel ---
## Random pitch spread on the spammy cues. Identical samples at ten a second
## machine-gun; jingles (level up, chest) stay fixed on purpose, like an alarm.
const AUDIO_VARY := 0.07
## While a big cue plays, the spammy cues drop by this much, so a level-up is
## heard over a hundred pops.
const AUDIO_DUCK_DB := -8.0
const AUDIO_DUCK_TIME := 0.5
const AUDIO_BIG_CUES := ["level_up", "hurt", "heal", "chest", "boss", "win", "run_over", "pop_big"]
## Pops the throttle swallowed are banked; every so many earn one deep pop
## that cuts through, so mowing a crowd sounds bigger rather than busier.
const POP_BIG_EVERY := 8
const POP_BIG_GAP := 0.8
## Per-weapon pitch over the shared shoot and hit cues, so ten toys are not
## one click. Big and slow sits low; small and quick sits high.
const WEAPON_VOICE := {
	"paw": 0.9,
	"yarn": 1.25,
	"purr": 1.0,
	"fish": 1.0,
	"mouse": 0.75,
	"milk": 0.85,
	"zap": 1.4,
	"boomer": 0.65,
	"trail": 1.1,
	"nap": 0.55,
}

# --- Touch ---
## The on-screen thumbstick, for phones and tablets. It appears wherever the
## finger lands rather than sitting in a corner: a small thumb cannot find a
## fixed pad without looking, and looking away from the cat loses the run.
const TOUCH_RADIUS := 90.0
const TOUCH_DEADZONE := 12.0
const TOUCH_KNOB_RADIUS := 34.0
const TOUCH_BASE_COLOUR := Color(1.0, 1.0, 1.0, 0.14)
const TOUCH_RING_COLOUR := Color(1.0, 1.0, 1.0, 0.4)
const TOUCH_KNOB_COLOUR := Color(1.0, 0.72, 0.82, 0.75)

# --- HUD ---
const BANNER_TIME := 1.6
const CARD_SIZE := Vector2(200, 250)
## The loadout list, top right. Pips rather than a number: a level is a
## quantity a child reads by counting.
const LOADOUT_ICON_SIZE := Vector2(26, 26)
const LOADOUT_PIP_SIZE := 15
const LOADOUT_PIP_COLOUR := Color(1.0, 0.86, 0.42)
## Card art, by weapon or passive id. A missing entry draws no picture rather
## than erroring, so a new weapon works before its icon is drawn.
const ICONS := {
	"paw": "res://assets/icon_paw.png",
	"yarn": "res://assets/yarn.png",
	"purr": "res://assets/icon_purr.png",
	"fish": "res://assets/fish.png",
	"mouse": "res://assets/mouse.png",
	"milk": "res://assets/icon_milk.png",
	"zap": "res://assets/icon_zap.png",
	"nap": "res://assets/icon_nap.png",
	"boomer": "res://assets/icon_boomer.png",
	"trail": "res://assets/icon_trail.png",
	"boots": "res://assets/icon_boots.png",
	"claw": "res://assets/icon_claw.png",
	"bell": "res://assets/icon_bell.png",
	"magnet": "res://assets/icon_magnet.png",
	"snack": "res://assets/icon_vest.png",
	"bowl": "res://assets/icon_bowl.png",
}
## What each toy and helper does, in words for the adult reading over a
## shoulder. The icon is what the child picks by.
const BLURBS := {
	"paw": "Swipes all around you",
	"yarn": "Throws yarn at bugs",
	"purr": "Hurts bugs that come close",
	"fish": "Fish circle around you",
	"mouse": "A mouse chases bugs",
	"milk": "Milk puddles slow bugs down",
	"zap": "Zaps far away bugs",
	"nap": "A big sleepy blast",
	"boomer": "Flies out and comes back",
	"trail": "Drops crumbs as you run",
	"boots": "Run faster",
	"claw": "Hit harder",
	"bell": "Attack more often",
	"magnet": "Pick things up further away",
	"snack": "Get a heart back",
	"bowl": "Everything gets bigger",
}
## The card art is 16x16, so it is drawn at this size with no filtering.
const CARD_ICON_SIZE := Vector2(96, 96)
const CARD_NEW_COLOUR := Color(1.0, 0.86, 0.36)
const CARD_UP_COLOUR := Color(0.72, 0.92, 1.0)
const CARD_BLURB_COLOUR := Color(0.78, 0.74, 0.82)
## The pick panel pops from this fraction of full size.
const MODAL_POP_FROM := 0.75
const MODAL_POP_TIME := 0.28

# --- Start screen ---
## Five cards plus gaps must fit a 1280 design width.
const START_CARD_SIZE := Vector2(168, 212)
## All 16x16 art, scaled by whole numbers so the pixels stay square: the cat
## at 6x, weapon and cost icons at 2x, the cookie counter and bugs at 3x.
const START_CAT_SIZE := Vector2(96, 96)
const START_ICON_SIZE := Vector2(32, 32)
const START_COOKIE_SIZE := Vector2(48, 48)
const START_BUG_SIZE := Vector2(48, 48)
## A locked cat is a shadow of itself; the price stays bright so it reads.
const START_LOCKED_TINT := Color(0.42, 0.4, 0.5)
const START_COST_COLOUR := Color(1.0, 0.84, 0.36)
## Idle life on the lawn. Slow enough to be scenery, not a chase.
const START_BUG_COUNT := 6
const START_BUG_TIME_MIN := 16.0
const START_BUG_TIME_MAX := 30.0
const START_BUG_ALPHA := 0.9
const START_TITLE_BOB := 6.0
const START_TITLE_BOB_TIME := 1.3
const START_PLAY_PULSE := 1.05
const START_PLAY_PULSE_TIME := 0.7
## The chosen cat hops once, so the pick reads without words.
const START_HOP := 10.0
const START_HOP_TIME := 0.3
## A card the player cannot afford shakes its head.
const START_WOBBLE := 7.0
const START_WOBBLE_TIME := 0.07


# --- Ground decals ---
## Mud, worn grass, flowers and stones, scattered under everything. Decoration
## only: nothing here is collided with or broken.
##
## The cat is pinned to the middle of the screen, so the ground is the only
## thing that shows the garden going past. A flat green field gave no sense of
## moving and no sense of having been anywhere.
const GROUND_ART := [
	"res://assets/ground_mud.png",
	"res://assets/ground_patch.png",
	"res://assets/ground_flowers.png",
	"res://assets/ground_stones.png",
]
## Per kind, in GROUND_ART order. Mud and worn patches are the common ground;
## flowers and stones are the treats. A flat roll read as even speckling rather
## than a garden with features in it.
const GROUND_WEIGHTS := [0.22, 0.36, 0.28, 0.14]
## Mud reads as a puddle, so it is drawn bigger than a clump of flowers.
const GROUND_SCALE := [1.7, 1.5, 0.9, 0.55]
## Patches are translucent, so the lawn shows through and nothing on the ground
## competes with the bugs standing on it.
const GROUND_ALPHA := [0.82, 0.45, 1.0, 0.9]
const GROUND_COUNT := 460
const GROUND_SIZE_MIN := 44.0
const GROUND_SIZE_MAX := 84.0
## A little tone variation per patch, so a field of mud is not one stamp
## repeated across the screen.
const GROUND_SHADE_MIN := 0.82
const GROUND_SEED := 20260902
## Same fixed-cell scheme as the props.
const GROUND_CELL := 300.0
const GROUND_PER_CELL := 7
const GROUND_FORGET_DISTANCE := 1400.0
const GROUND_REFILL_DISTANCE := 1100.0

# --- Breakable props ---
## Things on the lawn to knock over. An empty lawn makes every direction
## identical, so between waves a child has nothing to walk towards; a pot worth
## a heart is a small errand.
##
## Drops are deliberately stingy. A heart from every pot would make hearts
## meaningless and the run trivial, so most give the xp gem a bug would.
const PROPS := [
	{
		"name": "Flower Pot",
		"art": "res://assets/prop_pot.png",
		"hp": 12.0,
		"radius": 13.0,
		"heart_chance": 0.14,
		"cookie_chance": 0.10,
		"xp": 3,
	},
	{
		"name": "Berry Bush",
		"art": "res://assets/prop_bush.png",
		"hp": 20.0,
		"radius": 15.0,
		"heart_chance": 0.22,
		"cookie_chance": 0.08,
		"xp": 5,
	},
	{
		"name": "Cookie Box",
		"art": "res://assets/prop_box.png",
		"hp": 34.0,
		"radius": 14.0,
		"heart_chance": 0.10,
		"cookie_chance": 0.40,
		"xp": 8,
	},
]
const PROP_COUNT := 120
## Seeded, so the garden is the same every run: a child who learns where the
## pots are should find them there again.
const PROP_SEED := 20260901
## Nothing spawns within this of the cat's starting spot, or the run opens with
## a pot in the player's face.
const PROP_CLEAR_RADIUS := 90.0
const PROP_SPACING := 78.0


# --- Maps ---
## Where a run happens. A map swaps the floor, the decals and the props, and
## nothing else: the bugs, the toys and the waves are identical everywhere, so
## a bought map is scenery rather than an advantage a child has to grind for.
##
## The garden is free; the others cost cookies, which is what cookies are for
## now the cats are. Each map's tables have the garden's shape, so `ground.gd`
## and `props.gd` read whichever set `Run.map` names and change nothing else.
## Weights, scales and alphas follow the garden's rules: the big patches stay
## translucent so nothing on the ground competes with the bugs standing on it.
const STARTER_MAP := "garden"
## Every map is free, like every cat. `cost` stays in the table at zero so the
## picker and the save's unlocked list keep working, and a price could return
## without a save-format change. Cookies buy cosmetics instead.
const MAPS := {
	"garden":
	{
		"name": "Garden",
		"cost": 0,
		"art": "res://assets/map_garden.png",
		"lawn": "res://assets/lawn.png",
		"ground_art": GROUND_ART,
		"ground_weights": GROUND_WEIGHTS,
		"ground_scale": GROUND_SCALE,
		"ground_alpha": GROUND_ALPHA,
		"props": PROPS,
	},
	"beach":
	{
		"name": "Beach",
		"cost": 0,
		"art": "res://assets/map_beach.png",
		"lawn": "res://assets/lawn_beach.png",
		## Wet sand and tide pools are the common ground; shells and seaweed
		## are the treats, like the garden's flowers and stones.
		"ground_art":
		[
			"res://assets/ground_wet.png",
			"res://assets/ground_pool.png",
			"res://assets/ground_seaweed.png",
			"res://assets/ground_shells.png",
		],
		"ground_weights": [0.38, 0.20, 0.26, 0.16],
		"ground_scale": [1.6, 1.5, 0.9, 0.55],
		"ground_alpha": [0.5, 0.6, 0.8, 0.9],
		## The garden's prop numbers with beach art, so no map is easier.
		"props":
		[
			{
				"name": "Sandcastle",
				"art": "res://assets/prop_sandcastle.png",
				"hp": 12.0,
				"radius": 13.0,
				"heart_chance": 0.14,
				"cookie_chance": 0.10,
				"xp": 3,
			},
			{
				"name": "Driftwood",
				"art": "res://assets/prop_driftwood.png",
				"hp": 20.0,
				"radius": 15.0,
				"heart_chance": 0.22,
				"cookie_chance": 0.08,
				"xp": 5,
			},
			{
				"name": "Beach Bucket",
				"art": "res://assets/prop_bucket.png",
				"hp": 34.0,
				"radius": 14.0,
				"heart_chance": 0.10,
				"cookie_chance": 0.40,
				"xp": 8,
			},
		],
	},
	"arctic":
	{
		"name": "Arctic",
		"cost": 0,
		"art": "res://assets/map_arctic.png",
		"lawn": "res://assets/lawn_arctic.png",
		## Ice sheets and drifts are the common ground; cracks and rocks are
		## the treats.
		"ground_art":
		[
			"res://assets/ground_ice.png",
			"res://assets/ground_drift.png",
			"res://assets/ground_cracks.png",
			## The garden's stones as they are: grey reads as rock on snow,
			## where a darker recolour read as a bug at a glance.
			"res://assets/ground_stones.png",
		],
		"ground_weights": [0.30, 0.32, 0.22, 0.16],
		"ground_scale": [1.7, 1.5, 0.9, 0.55],
		"ground_alpha": [0.55, 0.6, 0.8, 0.9],
		"props":
		[
			{
				"name": "Snowman",
				"art": "res://assets/prop_snowman.png",
				"hp": 12.0,
				"radius": 13.0,
				"heart_chance": 0.14,
				"cookie_chance": 0.10,
				"xp": 3,
			},
			{
				"name": "Little Fir",
				"art": "res://assets/prop_sapling.png",
				"hp": 20.0,
				"radius": 15.0,
				"heart_chance": 0.22,
				"cookie_chance": 0.08,
				"xp": 5,
			},
			{
				"name": "Ice Block",
				"art": "res://assets/prop_iceblock.png",
				"hp": 34.0,
				"radius": 14.0,
				"heart_chance": 0.10,
				"cookie_chance": 0.40,
				"xp": 8,
			},
		],
	},
}
## Map cards sit under the cat row: smaller, since three must read at once,
## with the postcard art at a whole 4x so the pixels stay square.
const START_MAP_CARD_SIZE := Vector2(148, 122)
const START_MAP_ART_SIZE := Vector2(64, 64)


# --- Hats ---
## The only thing cookies buy. Every cat and map is free, deliberately, so
## nothing that changes how a run plays sits behind a grind: a hat changes no
## number in the game. "none" is a real entry rather than a hidden state, so
## taking a hat off is a card a child can press.
##
## A run pays roughly 76 to 135 cookies, so the party hat is one run away and
## the crown three or four: something to want without a wall to hit.
const STARTER_HAT := "none"
const HATS := {
	"none": {"name": "No Hat", "art": "", "cost": 0},
	"party": {"name": "Party Hat", "art": "res://assets/hat_party.png", "cost": 60},
	"bow": {"name": "Big Bow", "art": "res://assets/hat_bow.png", "cost": 110},
	"cap": {"name": "Cool Cap", "art": "res://assets/hat_cap.png", "cost": 180},
	"crown": {"name": "Crown", "art": "res://assets/hat_crown.png", "cost": 300},
}
## Hat cards share the band with the map row, so five must fit half a screen.
## The hat art is 16x16 drawn at a whole 3x.
const START_HAT_CARD_SIZE := Vector2(104, 122)
const START_HAT_ART_SIZE := Vector2(48, 48)
const START_HAT_COOKIE_SIZE := Vector2(24, 24)


## A hat's texture path, empty for "none" or anything unknown, so callers draw
## nothing rather than crash on an edited save.
func hat_art(id: String) -> String:
	return String(HATS[id]["art"]) if HATS.has(id) else ""


## The tables `ground.gd` and `props.gd` swap by map. Read through here so an
## unknown id falls back to the garden rather than crashing mid-load.
func map_info(id: String) -> Dictionary:
	return MAPS[id] if MAPS.has(id) else MAPS[STARTER_MAP]


# --- Lookups the swarm calls every frame ---
func enemy_hp(kind: int, clock: float) -> float:
	var ramp := 1.0 + ENEMY_HP_RAMP * (clock / RUN_SECONDS)
	return float(ENEMIES[kind]["hp"]) * ramp


func enemy_speed(kind: int) -> float:
	return float(ENEMIES[kind]["speed"])


func enemy_damage(kind: int) -> float:
	return float(ENEMIES[kind]["damage"])


func enemy_radius(kind: int) -> float:
	return float(ENEMIES[kind]["radius"])


func enemy_knockback(kind: int) -> float:
	return float(ENEMIES[kind]["knock"])


func enemy_xp(kind: int) -> int:
	return int(ENEMIES[kind]["xp"])


## A weapon's stat at its current level. Every weapon reads its numbers
## through here, so a missing `_gain` key means "does not grow" rather than an
## error, and adding growth to a weapon is one key.
func weapon_stat(id: String, key: String, level: int) -> float:
	var w: Dictionary = WEAPONS[id]
	var base := float(w.get(key, 0.0))
	var gain := float(w.get(key + "_gain", 0.0))
	return base + gain * float(level - 1)


func wave_for(clock: float) -> Dictionary:
	var minute := int(clock / 60.0)
	return WAVES[clampi(minute, 0, WAVES.size() - 1)]
