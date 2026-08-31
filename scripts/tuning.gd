class_name Tuning
extends RefCounted
## Every number worth fiddling with lives here, so playtesting means editing
## one file. GDScript hot-reloads, so these can change while the game runs.
##
## A named class of constants and `static func`s rather than an autoload: it
## holds no state, has no signals and never touches the tree, which is the shape
## Godot's own "autoloads versus regular nodes" page says to spell this way. It
## is also what lets a `-s` script name it: an autoload cannot be named at
## compile time, so `shots.gd` and `compile_check.gd` had to reach it through
## `get_root().get_node("Tuning")`.

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
## A bar, not a row of hearts. Hearts could only show five states, so a grub and a boss
## both took exactly one however hard they hit; with a bar the difference is
## visible. 100 so the numbers below read as percentages.
const PLAYER_MAX_HP := 100.0
const PLAYER_SPEED := 118.0
## Every enemy is slower than this. A child who runs away must always escape;
## the genre's tension comes from being surrounded, not from being outrun.
const PLAYER_RADIUS := 15.0
## The cat is drawn this many world units across. It must be the biggest thing
## in the garden: rendered at the sprite's own 16 it was smaller than every bug
## and hard to find in a crowd.
const PLAYER_DRAW_SIZE := 30.0
## A long blink after a hit. Standing in a crowd otherwise costs all three
## of the bar in a second, which teaches nothing.
const PLAYER_MERCY_TIME := 1.6
## A hit also shoves every bug off the cat. Mercy time alone is not enough:
## a cat standing in a crowd takes the next hit the frame mercy ends, which
## measured as the whole bar in 3.7 seconds. Clearing space is what gives a
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
## The hard ceiling on how fast any bug can ever move, whatever the table says
## and whatever multipliers have stacked on it. `swarm.gd` clamps to this after
## `hurry` and the spider's gait, because those are per-row and neither is
## bounded by the enemy table: a rush aimed at the wasp works out at 156 against
## a floored walk of 112. Just under the floored walk, so a child who is moving
## at all is never caught from behind.
const ENEMY_SPEED_CEILING := PLAYER_SPEED * STICK_WALK_FLOOR - 2.0
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
	"snack": {"name": "Tasty Snack", "heals": 40.0},
}

const STARTER_CAT := "cookie"
const CATS := {
	"cookie": {"name": "Cookie", "weapon": "paw", "cost": 0, "art": "res://assets/cat.png"},
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


static func xp_for_level(level: int) -> int:
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
		## A whole fish per level, so every pick shows up on the ring. At 0.6
		## a level, levels 2 and 4 added nothing visible and read as a wasted
		## card.
		"count_gain": 1.0,
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
		"cooldown": 1.1,
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

## NOT BUILT YET. A design, kept because the pairings are the thought-out part:
## a weapon at max level plus the named passive would become the evolution. One
## per weapon at most.
##
## Nothing in `scripts/` reads this. There are no presents either, despite what
## `BOSS_MINUTES` says below: a boss drops cookies. Only `tuning_test` touches
## the table, and it checks the shape rather than any behaviour, so do not read
## a passing suite as evidence that any of this works.
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
## The mouse's index in that list, named because `_tick_shots` steers it and
## comparing against a bare 1 is how the start screen ended up letting the boss
## onto its lawn.
const SHOT_MOUSE := 1
## How sharply the mouse turns towards whatever it is chasing, as a share of the
## remaining angle per second. Gentle on purpose: a shot that snaps onto its
## target cannot miss and stops reading as a mouse hunting.
const MOUSE_TURN := 3.0
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
## How far the cat must walk between crumbs. Standing still drops none.
const TRAIL_MIN_STEP := 26.0
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
const ZONE_COLOUR := Color(0.93, 0.95, 1.0, 0.34)
## A rim on the puddle, so the edge of the slow is visible rather than a soft
## blob with no boundary.
## A puddle is drawn as overlapping blobs, not a disc: a rimmed circle read as
## a coloured plate rather than something spilt.
## A puddle is ONE polygon with a wobbly edge. Clusters of circles were tried
## three ways and all read as clouds from above.
const ZONE_EDGE_POINTS := 16
const ZONE_EDGE_MIN := 0.72
## Flattened vertically, so a spill lies on the grass. Round puffs read as
## clouds floating over it.
const ZONE_SQUASH := 0.55
## The wet-looking fleck, off centre the way liquid catches light.
const ZONE_GLEAM := 0.16
const ZONE_GLEAM_COLOUR := Color(1.0, 1.0, 1.0, 0.35)
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
	{"name": "Grub", "hp": 6.0, "speed": 46.0, "damage": 9.0, "radius": 9.0, "xp": 1, "gem_up": 0.02, "knock": 46.0},
	{"name": "Beetle", "hp": 14.0, "speed": 62.0, "damage": 13.0, "radius": 10.0, "xp": 2, "gem_up": 0.06, "knock": 38.0},
	{"name": "Snail", "hp": 34.0, "speed": 28.0, "damage": 20.0, "radius": 12.0, "xp": 4, "gem_up": 0.14, "knock": 22.0},
	{"name": "Wasp", "hp": 10.0, "speed": 104.0, "damage": 15.0, "radius": 8.5, "xp": 3, "gem_up": 0.1, "knock": 60.0},
	{"name": "Slime", "hp": 22.0, "speed": 52.0, "damage": 16.0, "radius": 11.0, "xp": 3, "gem_up": 0.12, "knock": 34.0},
	{"name": "Big Bug", "hp": 340.0, "speed": 44.0, "damage": 45.0, "radius": 26.0, "xp": 60, "gem_up": 0.8, "knock": 6.0},
	{"name": "Spider", "hp": 12.0, "speed": 92.0, "damage": 15.0, "radius": 9.0, "xp": 3, "gem_up": 0.1, "knock": 42.0},
	{"name": "Dung Beetle", "hp": 26.0, "speed": 40.0, "damage": 18.0, "radius": 11.0, "xp": 5, "gem_up": 0.16, "knock": 18.0},
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

## Webs. The spider drops one as it scuttles, and the cat slows crossing it.
## This is what the spider is FOR: without it, it is a fast bug and nothing
## more, and speed alone is already the wasp's job.
##
## The slow is the one thing in the game that takes control away from a child,
## so it is deliberately mild and short. Running away must still work.
const WEB_ART := "res://assets/web.png"
const WEB_MAX := 60
## Seconds between one spider laying a web. Slow enough that a crowd of them
## does not carpet the ground.
const WEB_EVERY := 2.4
## A web fades after this, so an old fight cannot leave the garden sticky. Ten
## seconds is the cap the design asks for.
const WEB_LIFE := 10.0
## The last of that life spent fading, so a web thins out rather than blinking.
const WEB_FADE := 2.0
const WEB_RADIUS := 26.0
const WEB_DRAW_SIZE := 40.0
## How much of the cat's speed a web leaves it. Not a stop: a cornered child
## who cannot move cannot escape, which is the one thing that must never
## happen.
const WEB_SLOW := 0.55
## And how long the slow lingers after stepping out, so crossing the edge does
## not flicker.
const WEB_LINGER := 1.0

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
static func spider_pace(t: float) -> float:
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
## Minutes at which one Big Bug arrives. Each drops a pile of cookies.
const BOSS_MINUTES := [4, 7, 9]

# --- Rushes ---
## A pack of the weakest bug, arriving from one side at a hurry, so the child
## has something to run away from that is not a boss and not the steady drip of
## the wave table.
##
## Nothing rushes for the first three minutes, and every other number here is
## read off the clock: a rush is a wave-table entry in all but name, and no part
## of it looks at how well the player is doing or what level they have reached.
## Three minutes is two full waves of learning to walk away from a grub before
## the first pack asks for it.
const RUSH_AFTER := 180.0
## The kind a rush is made of. The weakest bug in the table, because the whole
## threat of a rush is the shape it arrives in.
const RUSH_KIND := 0
## The gap between rushes, rolled between these. Random rather than a fixed
## period: a pack on a timer is a metronome a child learns to stand still for.
const RUSH_GAP_MIN := 22.0
const RUSH_GAP_MAX := 38.0
## How many arrive, at the first minute a rush can happen and at the last. The
## clock interpolates between them, the same input the wave table uses.
const RUSH_COUNT_MIN := 8
const RUSH_COUNT_MAX := 20
## How much of the ring the pack is spread over, in radians. Narrow, because a
## pack sprinkled all round is the normal spawn pattern and reads as a wave, not
## a charge: at a third of a turn it arrives as one crowd with three quarters of
## the compass left to run into.
const RUSH_ARC := TAU / 3.0
## A little depth, so the pack reads as a group with a front and a back rather
## than as beads threaded on the spawn ring.
const RUSH_RING_JITTER := 40.0
## What the hurry multiplies a rusher's walk by. Faster than its own kind and
## still under the cat: a grub at 46 comes in at 69, which leaves 49 of headroom
## against PLAYER_SPEED and stays under a wasp's 104, so `STICK_WALK_FLOOR` is
## still floored above the fastest bug in the game.
const RUSH_HURRY := 1.5
## The same warning the boss gets. A pack of quick bugs is the second thing in
## the game that can end a run in a few seconds, so it is announced at the spot
## it will come from and a child gets to be somewhere else.
const RUSH_TELEGRAPH_TIME := 1.3
const RUSH_RING_COUNT := 8
const RUSH_RING_RADIUS := 26.0
const RUSH_RING_SPEED := 70.0


## How many bugs a rush holds at clock `t`. Linear across the run, so the pack
## grows for the same reason everything else does.
static func rush_count(t: float) -> int:
	var f := clampf(t / RUN_SECONDS, 0.0, 1.0)
	return int(round(lerpf(float(RUSH_COUNT_MIN), float(RUSH_COUNT_MAX), f)))


# --- The eclipse ---
## Once a run, at the halfway mark: the sky dims to a starry night and a warm
## lamp of light stays on the cat. Scenery on a timer, never a difficulty: the
## dark is see-through, no number here feeds a bug, and the director holds its
## rushes while it lasts so nothing charges out of the gloom.
const ECLIPSE_AT := 300.0
## Half a minute. Long enough to notice the moon and the fireflies, short
## enough that a child who is unsure about the dark is out of it quickly.
const ECLIPSE_TIME := 30.0
## Dusk and dawn, not a light switch. The fade is also the telegraph: the
## banner lands as the first shade appears, and nothing else happens at all.
const ECLIPSE_FADE := 2.5
## See-through on purpose. Every bug stays visible in the dim, because a dark
## screen with unseen things in it is the definition of scary at five.
const ECLIPSE_NIGHT := Color(0.09, 0.10, 0.27, 0.70)
## The fully lit circle around the cat. Past the paw's full-grown reach, so
## the starting toy always works in the light.
const ECLIPSE_SPOT_RADIUS := 100.0
## How far the light falls off to night beyond the lit circle.
const ECLIPSE_SPOT_FADE := 90.0
## A warm ring where the lamp meets the night, which is what makes it read as
## lamplight rather than a hole in the dark.
const ECLIPSE_RIM_COLOUR := Color(1.0, 0.78, 0.42, 0.22)
## How far across the falloff the warm ring sits, as a fraction of the fade.
const ECLIPSE_RIM_AT := 0.35
## The shade texture's width in world units, centred on the cat. It has to
## out-reach the corner of the widest view (about 350 world units at `ZOOM`
## on a 20:9 handset), or the corners stay daylight.
const ECLIPSE_COVER := 820.0
const ECLIPSE_SHADE_RES := 256
## The sky. Star radii sit outside the lamp and inside the widest view; stars
## near the lamp dim with the light, so none sits bright in the lit circle.
const ECLIPSE_STARS := 80
const ECLIPSE_STAR_NEAR := 150.0
const ECLIPSE_STAR_FAR := 340.0
const ECLIPSE_STAR_COLOUR := Color(1.0, 0.97, 0.88)
const ECLIPSE_STAR_SIZE_MIN := 1.2
const ECLIPSE_STAR_SIZE_MAX := 2.6
## How much of a star's light the twinkle takes, and how fast.
const ECLIPSE_TWINKLE := 0.45
const ECLIPSE_TWINKLE_RATE := 2.2
## Screen-space, since the overlay rides the camera: up and left of the cat,
## outside the lamp, under the health bar and clear of the loadout list, which
## owns the top-right corner.
const ECLIPSE_MOON_AT := Vector2(-185, -80)
const ECLIPSE_MOON_RADIUS := 20.0
const ECLIPSE_MOON_COLOUR := Color(0.99, 0.96, 0.82)
const ECLIPSE_MOON_CRATER_COLOUR := Color(0.9, 0.85, 0.68)
## x, y, radius per crater, in moon-local units.
const ECLIPSE_MOON_CRATERS := [Vector3(-6.0, -3.0, 4.5), Vector3(5.0, 6.0, 3.2), Vector3(7.0, -7.0, 2.4)]
const ECLIPSE_MOON_GLOW_COLOUR := Color(1.0, 0.97, 0.8, 0.08)
const ECLIPSE_MOON_GLOW_RINGS := 3
const ECLIPSE_MOON_GLOW_STEP := 0.35
## Fireflies drift around the lamp's rim, so the edge of the light is alive
## rather than a boundary.
const ECLIPSE_FIREFLIES := 6
const ECLIPSE_FLY_RADIUS := 130.0
const ECLIPSE_FLY_WOBBLE := 26.0
const ECLIPSE_FLY_BOB_RATE := 0.7
## Radians per second around the lamp, rolled per fly so they never bunch.
const ECLIPSE_FLY_SPEED_MIN := 0.25
const ECLIPSE_FLY_SPEED_MAX := 0.5
const ECLIPSE_FLY_PULSE_RATE := 2.6
## A firefly never quite goes out; below this floor the blink reads as one
## vanishing rather than breathing.
const ECLIPSE_FLY_PULSE_FLOOR := 0.45
const ECLIPSE_FLY_COLOUR := Color(1.0, 0.9, 0.45)
const ECLIPSE_FLY_SIZE := 2.4
const ECLIPSE_FLY_GLOW_SIZE := 7.0
const ECLIPSE_FLY_GLOW_ALPHA := 0.22
const ECLIPSE_SEED := 20260904

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
static func pickup_art(name: String) -> String:
	return String(PICKUPS[name]["art"])


static func pickup_size(name: String) -> float:
	return float(PICKUPS[name]["size"])


## What an xp tier is worth, as a multiple of the bug's own xp. A red gem has
## to be worth crossing the screen for.
static func gem_worth(tier: int) -> float:
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
## A dropped heart is worth a quarter of the bar.
const HEART_HEAL := 25.0

# --- Feel ---
const HIT_FLASH_TIME := 0.08
## The quiet gap after a flash before another may start. Longer than the flash,
## or a thing under continuous damage is white more often than not.
const HIT_FLASH_GAP := 0.22
## What a hit tints a bug to. Amber, not white, and the blue channel is crushed
## rather than raised: a flat white flash was 5 dE from the arctic's snow and 27
## from the beach's sand, so on a pale map the child could not see their toy
## working, and multiplying every channel up washed the dark outline out to
## grey. Crushing blue clips the body to saturated amber and holds the outline
## dark, which is the rim that keeps a pale bug readable on pale ground.
## `test_the_hit_flash_reads_on_every_map` pins both.
const HIT_FLASH_COLOUR := Color(2.6, 1.5, 0.15)
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

## Hit squash: bugs flatten by this fraction while the hit flash runs.
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
## the bug art. The hit flash still blows past it.
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
## The health bar. Green while healthy, amber, then red: a colour a child reads
## without counting, which is what a row of hearts was for.
const HEALTH_GOOD := Color(0.42, 0.85, 0.42)
const HEALTH_FAIR := Color(1.0, 0.78, 0.3)
const HEALTH_LOW := Color(0.95, 0.36, 0.4)
const HEALTH_FAIR_BELOW := 0.6
const HEALTH_LOW_BELOW := 0.3

const BANNER_TIME := 1.6
## Tall enough for a three-line blurb. At 250 the longest two ("Pick things up
## further away", "Milk puddles slow bugs down") wrapped to three lines and the
## last one spilled through the bottom border.
const CARD_SIZE := Vector2(200, 300)

# --- Text sizes ---
## Sized for a phone first, which is where this is actually played, and where
## the numbers are unforgiving: `aspect=expand` maps the design's 720 units of
## height onto about 360 real pixels on a 20:9 handset, so everything on screen
## is drawn at roughly half size. A 14px blurb landed at 7 real pixels, which a
## child cannot read and an adult squints at.
##
## These are the sizes that put the smallest text at about 14 real pixels there.
## They look large on a desktop, and that is the right way round: the audience
## is five, the words are few, and nothing here is dense enough to crowd.
##
## Scaling the whole canvas instead was tried and reverted. `content_scale_factor`
## enlarges the layout about a fixed origin, so the title went behind the cards
## and Play fell off the bottom: the text has to grow without the layout moving.
const TEXT_TINY := 22
const TEXT_SMALL := 26
const TEXT_BODY := 30
## The pause screen's tally. A picture per line, because the point of pausing
## mid-run is to see how it is going and the audience cannot read a label.
const PAUSE_ICON_SIZE := Vector2(34, 34)
const PAUSE_STAT_SIZE := 30
## Wide enough for the biggest number a run produces, so a 3-digit kill count
## and a 1-digit cookie count still share a left edge.
const PAUSE_VALUE_WIDTH := 96.0
## The bug stands for kills and the cookie for cookies. Both are things the
## child has already seen hundreds of by the time they pause.
const PAUSE_KILL_ICON := "res://assets/grub.png"
const PAUSE_COOKIE_ICON := "res://assets/cookie.png"
## The time left. A bare number is the one stat a child who cannot read has no
## way into, and every other line on that screen already has a picture.
const PAUSE_CLOCK_ICON := "res://assets/clock.png"
## The loadout list, top right. Pips rather than a number: a level is a
## quantity a child reads by counting.
const LOADOUT_ICON_SIZE := Vector2(26, 26)
const LOADOUT_PIP_SIZE := Vector2(8, 8)
const LOADOUT_PIP_GAP := 3
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
	"purr": "Buzzes bugs that come close",
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
	"snack": "Get some health back",
	"bowl": "All your toys get bigger",
}
## The card art is 16x16, so it is drawn at this size with no filtering.
## Inset from a card's border. Without it a wrapped blurb touches the outline.
const CARD_PAD := 12
## Breathing room under a card's last line of text.
const CARD_TAIL := 6

const CARD_ICON_SIZE := Vector2(96, 96)
const CARD_NEW_COLOUR := Color(1.0, 0.86, 0.36)
const CARD_UP_COLOUR := Color(0.72, 0.92, 1.0)
## An upgrade card counts its new level in pips, sized to read across the room
## at the card's 22px heading rather than the loadout's 8px.
const CARD_PIP_SIZE := Vector2(16, 16)
const CARD_PIP_GAP := 5
const CARD_BLURB_COLOUR := Color(0.78, 0.74, 0.82)
## The pick panel pops from this fraction of full size.
const MODAL_POP_FROM := 0.75
const MODAL_POP_TIME := 0.28

# --- Start screen ---
## Five cards plus gaps must fit a 1280 design width.
## A switched-off audio button is dimmed rather than relabelled: the label has
## to stay readable to someone who cannot read it.
const START_AUDIO_OFF_ALPHA := 0.4

## Android asks for 48dp on anything tappable, and a five-year-old's aim is
## worse than the adult that number was written for. The design height is 720,
## so on a 720-tall phone at 320dpi one dp is two design units: 96 covers the
## smallest screen this will meet, and is generous on anything larger.
const MIN_TOUCH := 96.0

## Wide enough for "Fish Friends" beside its icon with room to spare. At 168 it
## fitted only exactly, and the next longer weapon name would have wrapped to a
## second line and pushed the card taller than its neighbours.
const START_CARD_SIZE := Vector2(190, 222)
## Keeps the contents off the card's outline, as `CARD_PAD` does on the pick
## screen.
const START_CARD_PAD := 8
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
## The map row and the hat row sit side by side in one strip, and between them
## they are about 1170 design units of small cards. That was hand-placed for the
## 1280 design and overflows anything narrower: at a 4:3 window's 960 units the
## last hat card is drawn off the right edge.
##
## So the strip is placed against the width the screen actually has rather than
## the width it was drawn for. `aspect=expand` maps HEIGHT to 720 units always,
## which means a wider screen reveals MORE horizontal units: a 20:9 phone in
## landscape reports about 1600, the design reports 1280, and a 4:3 tablet
## reports 960. Reads backwards until that sinks in.
##
## Kept clear at each end of the strip, so the outermost card is never against
## the edge of the screen. Generous, because Godot rounds each control's width
## up to whole pixels and eight cards of rounding add up: the strip always comes
## out a little wider than the arithmetic in `_relayout` predicts, and this
## swallows the difference rather than chasing it.
const START_BAND_MARGIN := 90.0
## Between cards within each group. These mirror the separations set on the two
## containers in `start_screen.tscn`, because the strip's width has to be known
## before the layout pass runs and a container's own `size` is only correct
## after it.
const START_MAP_SEPARATION := 16.0
const START_HAT_SEPARATION := 8.0
## And between the map group and the hat group, so they read as two things to
## choose from rather than one row of eight.
const START_BAND_GAP := 56.0
## The inset the start screen's corner controls already sit at in the scene.
const START_EDGE_PAD := 18.0
## The engine credit along the bottom of the start screen, which is also how
## the licence is reached. Deliberately quiet: it has to be findable, not seen.
## The lawn's small controls: the same warm off-white the run stats use, rather
## than the default white, which is brighter than anything else on the screen.
const START_CHIP_TEXT := Color(1.0, 0.97, 0.9, 1.0)
const START_CREDIT_SIZE := 15
const START_CREDIT_WIDTH := 260.0
## Shorter than MIN_TOUCH: this is a credit that happens to be tappable, not a
## control a child is meant to find, and a 96-tall strip here would sit under
## the Play button's reach.
const START_CREDIT_HEIGHT := 30.0
const START_CREDIT_COLOUR := Color(1.0, 0.97, 0.9, 0.7)
## Matching the run stats, which sit on the same lawn.
const START_STAT_OUTLINE := Color(0.18, 0.32, 0.12, 1.0)
const START_STAT_OUTLINE_SIZE := 5

## The HUD's own geometry, matching what `hud.tscn` sets, so the safe-area
## inset has something to add to rather than a literal in two places.
const DESIGN_WIDTH := 1280.0
const HUD_EDGE_PAD := 18.0
const HUD_TOP := 32.0
const HUD_BAR_HEIGHT := 52.0
## The floor on that shrinking. Below this the cards are too small to tap on a
## phone, and a strip that will not fit is better cropped than unusable: the
## widths in play only reach here on a window nobody plays on.
const START_BAND_MIN_SCALE := 0.6

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
## Above what the cull radius holds (~480), for the reason `PROP_COUNT` gives.
## This one also sizes the MultiMesh and its arrays, so it is the only one of
## the three that costs memory rather than nodes.
const GROUND_COUNT := 640
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
		"name": "Biscuit Bowl",
		"art": "res://assets/prop_bowl_food.png",
		"hp": 12.0,
		"radius": 13.0,
		"heart_chance": 0.14,
		"cookie_chance": 0.10,
		"xp": 3,
	},
	{
		"name": "Milk Bowl",
		"art": "res://assets/prop_bowl_milk.png",
		"hp": 20.0,
		"radius": 15.0,
		"heart_chance": 0.22,
		"cookie_chance": 0.08,
		"xp": 5,
	},
	{
		"name": "Fish Bowl",
		"art": "res://assets/prop_bowl_fish.png",
		"hp": 34.0,
		"radius": 14.0,
		"heart_chance": 0.10,
		"cookie_chance": 0.40,
		"xp": 8,
	},
]
# --- Traps ---
## Holes in the ground. The only hazard that is not alive, and the only one that
## does not chase: a trap is answered by looking where you are going, which is
## the one thing a child can do that is not walking away.
## Half the bar, so entering one below half health ends the run. Every other
## threat is survivable by leaving; this one is not, which is what makes the
## ground worth reading.
const TRAP_DAMAGE := PLAYER_MAX_HP * 0.5
## Drawn a little wider than a prop. A hazard that costs half the bar has to be
## visible from further away than a pot worth a heart.
const TRAP_RADIUS := 26.0
## Only the middle bites. The sprite's outermost ring is its rim, and clipping
## the rim while running past should not cost half the bar.
const TRAP_BITE := 0.62
## Long enough to walk out of. Without it the same hole bites every frame the
## cat is inside it, which is three hits before a child can react.
const TRAP_COOLDOWN := 1.4
## Sparse, but not so sparse the child never meets one. The camera shows
## 512x288 world units at `ZOOM`, so a 520 cell put a hole on screen only half
## the time and a hazard nobody sees teaches nothing; 300 averages between one
## and two in view. Five per cell like the props would be a minefield, and the
## ground has to stay walkable in every direction.
const TRAP_PER_CELL := 1
const TRAP_CELL := 300.0
## Above what the cull radius holds (~80), for the reason `PROP_COUNT` gives.
const TRAP_COUNT := 160
const TRAP_SEED := 20260903
## Two overlapping holes read as one, and the gap between them has to be wider
## than the cat. Kept under `TRAP_CELL` or nearly every placement is rejected.
const TRAP_SPACING := 150.0
## Bigger than the prop clearance, so the run does not open with half the bar
## sitting under the cat, and small enough that the first hole is still on
## screen to be learned from.
const TRAP_CLEAR_RADIUS := 170.0
const TRAP_REFILL_DISTANCE := 1100.0
const TRAP_FORGET_DISTANCE := 1500.0
## The splash out of the hole. Pale blue reads as water on all three maps: the
## pond and the ice hole are water, and wet sand is darker than dry.
const TRAP_SPLASH_COUNT := 10
const TRAP_SPLASH_SPEED := 96.0
const TRAP_SPLASH_COLOUR := Color(0.78, 0.9, 1.0)

## A ceiling a long walk cannot reach, not a budget the field spends. It has to
## sit above what the cull radius actually holds (~220 at `PROP_PER_CELL` over
## `PROP_FORGET_DISTANCE`), because the cap is checked inside `_fill_cell`: if
## it can fire mid-cell then how much of a cell survives depends on how many
## cells came before it, and the seeded garden stops being the same garden.
const PROP_COUNT := 320
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
		"trap": "res://assets/trap_pond.png",
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
		"trap": "res://assets/trap_sandpit.png",
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
		"trap": "res://assets/trap_icehole.png",
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
## One size for both the map and hat rows, so the strip under the cats reads as
## one band rather than two of slightly different widths. Sized by "Party Hat",
## the longest label either row carries.
const START_MAP_CARD_SIZE := Vector2(140, 134)
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
## Hats are drawn rows 0-4 of their 16x16 frame and the cat's head starts at
## row 1, so an origin-aligned overlay lands the brim on the eyes. Lifting it
## three rows rests the brim on the top of the head instead.
const HAT_LIFT := -3.0
const START_HAT_CARD_SIZE := START_MAP_CARD_SIZE
const START_HAT_ART_SIZE := Vector2(48, 48)
const START_HAT_COOKIE_SIZE := Vector2(24, 24)


## A hat's texture path, empty for "none" or anything unknown, so callers draw
## nothing rather than crash on an edited save.
static func hat_art(id: String) -> String:
	return String(HATS[id]["art"]) if HATS.has(id) else ""


## The tables `ground.gd` and `props.gd` swap by map. Read through here so an
## unknown id falls back to the garden rather than crashing mid-load.
static func map_info(id: String) -> Dictionary:
	return MAPS[id] if MAPS.has(id) else MAPS[STARTER_MAP]


# --- Lookups the swarm calls every frame ---
static func enemy_hp(kind: int, clock: float) -> float:
	var ramp := 1.0 + ENEMY_HP_RAMP * (clock / RUN_SECONDS)
	return float(ENEMIES[kind]["hp"]) * ramp


static func enemy_speed(kind: int) -> float:
	return float(ENEMIES[kind]["speed"])


static func enemy_damage(kind: int) -> float:
	return float(ENEMIES[kind]["damage"])


static func enemy_radius(kind: int) -> float:
	return float(ENEMIES[kind]["radius"])


static func enemy_knockback(kind: int) -> float:
	return float(ENEMIES[kind]["knock"])


static func enemy_xp(kind: int) -> int:
	return int(ENEMIES[kind]["xp"])


## A weapon's stat at its current level. Every weapon reads its numbers
## through here, so a missing `_gain` key means "does not grow" rather than an
## error, and adding growth to a weapon is one key.
static func weapon_stat(id: String, key: String, level: int) -> float:
	var w: Dictionary = WEAPONS[id]
	var base := float(w.get(key, 0.0))
	var gain := float(w.get(key + "_gain", 0.0))
	return base + gain * float(level - 1)


## What one more level of `id` actually gives, in the fewest words that say it.
##
## Derived from the numbers rather than written per weapon, so retuning a
## `_gain` cannot leave the card lying. A child cannot read a stat block, but
## "4 of them" or "bigger" tells them which card is the one they want.
## The unit quad every MultiMesh in the game draws through.
##
## A default QuadMesh maps uv.y=0, the TOP of the texture, to y=+0.5, which in
## Godot 2D is DOWN the screen: every sprite drawn through one comes out
## vertically mirrored. It went unnoticed for a long time because most of the
## art is roughly symmetric, and because the start screen uses TextureRect,
## which is correct, so the same sprite looked right in the menu and wrong in
## the game. Flipping the mesh here fixes every layer at once.
static func sprite_quad() -> ArrayMesh:
	var verts := PackedVector3Array([
		Vector3(-0.5, -0.5, 0.0),
		Vector3(0.5, -0.5, 0.0),
		Vector3(0.5, 0.5, 0.0),
		Vector3(-0.5, 0.5, 0.0),
	])
	# uv.y=0 on the TOP edge (y=-0.5), which is what a QuadMesh gets backwards.
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	var idx := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m



static func upgrade_blurb(id: String, level: int) -> String:
	if PASSIVES.has(id):
		# Words, not the number. A percentage is the one thing on any card a
		# child who cannot read or count could not act on, and every weapon
		# card already says "hits harder" rather than by how much.
		return "less waiting" if float(PASSIVES[id]["per_level"]) < 0.0 else "better"
	if not WEAPONS.has(id):
		return ""
	var parts: Array[String] = []
	# Count first: another fish on the ring is the most visible upgrade there
	# is, so it is what the card should lead with.
	var was_count := int(weapon_stat(id, "count", level))
	var now_count := int(weapon_stat(id, "count", level + 1))
	if now_count > was_count:
		parts.append("%d of them" % now_count)
	if weapon_stat(id, "damage", level + 1) > weapon_stat(id, "damage", level):
		parts.append("hits harder")
	if weapon_stat(id, "radius", level + 1) > weapon_stat(id, "radius", level):
		parts.append("bigger")
	if weapon_stat(id, "cooldown", level + 1) < weapon_stat(id, "cooldown", level):
		parts.append("faster")
	return ", ".join(parts)



static func wave_for(clock: float) -> Dictionary:
	var minute := int(clock / 60.0)
	return WAVES[clampi(minute, 0, WAVES.size() - 1)]
