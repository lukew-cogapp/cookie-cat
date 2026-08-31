extends Node
## Every number worth fiddling with lives here, so playtesting means editing
## one file. Autoloaded as `Tuning`, and GDScript hot-reloads, so these can
## change while the game runs.

# --- The run ---
## Ten minutes. Long enough to earn an evolution, short enough that a child
## finishes one rather than abandoning it.
const RUN_SECONDS := 600.0
const WORLD_HALF := Vector2(900, 900)
## The camera zoom. Art is 16x16, so at 2.5 a bug is 40 screen pixels and the
## cat 64: big enough to read at a glance. Rendered at 1.0 the cat was a speck
## and no weapon effect could be made out at all.
const ZOOM := 2.5

# --- Player ---
## Hearts, not a health bar: three big icons a five-year-old can count.
const PLAYER_MAX_HP := 3.0
const PLAYER_SPEED := 118.0
## Every enemy is slower than this. A child who runs away must always escape;
## the genre's tension comes from being surrounded, not from being outrun.
const PLAYER_RADIUS := 15.0
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
## Walk frames per second. The step frames are shared by every flavour, so a
## new cat is one sprite rather than three.
const PLAYER_STEP_RATE := 8.0
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
## One cat to start; the rest are bought with cookies earned by playing. Each
## opens with a different weapon, which is the whole difference between them:
## a starting weapon changes how a run has to be played from the first second,
## where a stat bonus is a number a child cannot see.
const STARTER_CAT := "cookie"
const CATS := {
	"cookie": {"name": "Cookie Cat", "weapon": "paw", "cost": 0, "art": "res://assets/cat.png"},
	"mint": {"name": "Minty", "weapon": "yarn", "cost": 30, "art": "res://assets/cat_mint.png"},
	"berry": {"name": "Berry", "weapon": "fish", "cost": 60, "art": "res://assets/cat_berry.png"},
	"choc": {"name": "Choccy", "weapon": "purr", "cost": 100, "art": "res://assets/cat_choc.png"},
	"lion": {"name": "Lion", "weapon": "zap", "cost": 150, "art": "res://assets/cat_lion.png"},
}

## Cookies are the currency between runs. Bugs drop them rarely; a boss always
## does, so a child who reaches one is paid for it.
const COOKIE_EVERY := 140
const COOKIE_PER_BOSS := 8
const COOKIE_VALUE := 1
## Paid at the end for surviving, so a full run is worth more than quitting at
## nine minutes with the same kills.
const COOKIE_FINISH_BONUS := 15
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
		"kind": "arc",
		"damage": 5.0,
		"cooldown": 0.7,
		"radius": 74.0,
		## Two and a half radians, a bit over 140 degrees, so a bug anywhere in
		## front is hit. A narrow arc asks a child to aim, and they cannot: the
		## first playtest of a 1.5 arc killed the cat with three kills in twenty
		## seconds because bugs walked in at 45 degrees untouched.
		"arc": 2.5,
		"damage_gain": 2.5,
		"cooldown_gain": -0.06,
		"radius_gain": 6.0,
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
	"vest": {"name": "Extra Snack", "per_level": 0.34},
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
const SHOT_DRAW_RADIUS := 8.0
## Index order for shot_kind, which picks the draw colour.
const SHOT_KINDS := ["yarn", "mouse"]
const SHOT_COLOURS := [Color(1.0, 0.62, 0.75), Color(0.72, 0.66, 0.6)]
## Orbiting fish sweep every frame rather than on a cooldown, so their listed
## damage is scaled down to a per-second rate.
const ORBIT_DAMAGE_RATE := 0.12
const ORBIT_HIT_RADIUS := 18.0
const ORBIT_DRAW_RADIUS := 10.0
const ORBIT_COLOUR := Color(0.62, 0.84, 1.0)
const AURA_COLOUR := Color(1.0, 0.85, 0.5, 0.55)
const AURA_WIDTH := 3.0
const ZONE_COLOUR := Color(0.95, 0.95, 1.0, 0.5)
## A puddle fades over its last seconds rather than blinking out.
const ZONE_FADE_TIME := 1.0

# --- Enemies ---
## Rows in swarm.gd read these by Kind. Speed is always under PLAYER_SPEED.
## HP is flat per kind and grows with the clock, not with player level: a
## child who levels fast should feel stronger, not meet tougher bugs.
const ENEMIES := [
	{"name": "Grub", "hp": 6.0, "speed": 46.0, "damage": 1.0, "radius": 15.0, "xp": 1, "knock": 46.0},
	{"name": "Beetle", "hp": 14.0, "speed": 62.0, "damage": 1.0, "radius": 17.0, "xp": 2, "knock": 38.0},
	{"name": "Snail", "hp": 34.0, "speed": 28.0, "damage": 1.0, "radius": 20.0, "xp": 4, "knock": 22.0},
	{"name": "Wasp", "hp": 10.0, "speed": 104.0, "damage": 1.0, "radius": 14.0, "xp": 3, "knock": 60.0},
	{"name": "Slime", "hp": 22.0, "speed": 52.0, "damage": 1.0, "radius": 19.0, "xp": 3, "knock": 34.0},
	{"name": "Big Bug", "hp": 340.0, "speed": 44.0, "damage": 1.0, "radius": 46.0, "xp": 60, "knock": 6.0},
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
]
const SWARM_SEED := 20260831

# --- Waves ---
## One entry per minute of the run: which kinds spawn, how often, and how many
## must be alive. The quota is what makes the screen fill up; the interval only
## decides how lumpy the filling is. Peaks at 150, not VS's 300: a child needs
## to see their cat.
const WAVES := [
	{"kinds": [0], "interval": 1.1, "min_alive": 12},
	{"kinds": [0, 1], "interval": 1.0, "min_alive": 22},
	{"kinds": [0, 1], "interval": 0.9, "min_alive": 34},
	{"kinds": [1, 3], "interval": 0.85, "min_alive": 46},
	{"kinds": [1, 2, 3], "interval": 0.8, "min_alive": 58},
	{"kinds": [0, 3, 4], "interval": 0.7, "min_alive": 72},
	{"kinds": [1, 2, 4], "interval": 0.65, "min_alive": 88},
	{"kinds": [3, 4], "interval": 0.6, "min_alive": 104},
	{"kinds": [1, 2, 3, 4], "interval": 0.55, "min_alive": 122},
	{"kinds": [0, 1, 2, 3, 4], "interval": 0.5, "min_alive": 150},
]
## Spawns land on a ring just off screen. Slightly wider than the corner of a
## 1280x720 viewport, so nothing appears in front of the player.
const SPAWN_RING := 330.0
## How many the quota top-up may add in one physics frame. A whole quota at
## once on the first frame of a minute arrives as a visible wall.
const SPAWN_BURST_MAX := 4
const SPAWN_PER_TICK := 2
## Minutes at which one Big Bug arrives. Each drops a present.
const BOSS_MINUTES := [4, 7, 9]

# --- Pickups ---
const GEM_MAX := 300
## In Gems.Kind order: xp gem, heart, cookie.
const GEM_TEXTURES := [
	"res://assets/gem.png",
	"res://assets/heart.png",
	"res://assets/cookie.png",
]
const GEM_SIZES := [16.0, 20.0, 22.0]
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
const FX_ARC_WIDTH := 5.0
const FX_RING_COLOUR := Color(0.72, 0.92, 1.0, 0.85)
const FX_RING_WIDTH := 4.0
const FX_BOLT_COLOUR := Color(1.0, 0.94, 0.5, 0.95)
const FX_BOLT_WIDTH := 2.5
## Popped bugs within this window count towards the cheer.
const COMBO_WINDOW := 4.0
const COMBO_EVERY := 25


# --- HUD ---
const BANNER_TIME := 1.6
const CARD_SIZE := Vector2(200, 250)
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
	"boots": "res://assets/icon_boots.png",
	"claw": "res://assets/icon_claw.png",
	"bell": "res://assets/icon_bell.png",
	"magnet": "res://assets/icon_magnet.png",
	"vest": "res://assets/icon_vest.png",
	"bowl": "res://assets/icon_bowl.png",
}
## What each toy and helper does, in words for the adult reading over a
## shoulder. The icon is what the child picks by.
const BLURBS := {
	"paw": "Swipe in front of you",
	"yarn": "Throws yarn at bugs",
	"purr": "Hurts bugs that come close",
	"fish": "Fish circle around you",
	"mouse": "A mouse chases bugs",
	"milk": "Leaves milk puddles",
	"zap": "Zaps far away bugs",
	"nap": "A big sleepy blast",
	"boots": "Run faster",
	"claw": "Hit harder",
	"bell": "Attack more often",
	"magnet": "Pick things up further away",
	"vest": "One more heart",
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
