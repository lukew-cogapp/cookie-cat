extends Node2D
## Wires the run together and owns the rules that need two systems to agree:
## a kill becomes a gem here, not in the swarm, because the swarm does not
## know what a gem is.

@onready var _player: Node2D = $Player
@onready var _swarm: Swarm = $Swarm
@onready var _gems: Gems = $Gems
@onready var _weapons: Weapons = $Weapons
@onready var _director: Director = $Director
@onready var _puffs: Puffs = $Puffs
@onready var _props: Props = $Props
@onready var _lawn: Sprite2D = $Lawn
@onready var _ground: Ground = $Ground
@onready var _camera: Camera2D = $Player/Camera
@onready var _hud: CanvasLayer = $Hud

## Kills inside the combo window, and when the window opened.
var _combo := 0
var _combo_until := 0.0
var _shake := 0.0


func _ready() -> void:
	Run.start()
	_swarm.set_player(_player)
	_gems.set_player(_player)
	_weapons.setup(_swarm, _gems, _player)
	_director.setup(_swarm, _player)
	_props.set_player(_player)
	_props.scatter(_player.global_position)
	_ground.set_player(_player)
	_ground.scatter(_player.global_position)
	_props.broke.connect(_on_prop_broke)
	_weapons.set_props(_props)
	_weapons.killed.connect(_on_killed)
	_gems.collected.connect(_on_collected)
	_director.boss_arrived.connect(_on_boss)
	_player.health_changed.connect(_hud.set_health)
	_player.health_changed.connect(_on_health)
	Run.consumed.connect(_on_consumed)
	_player.died.connect(_on_died)
	_player.hurt_taken.connect(_on_hurt)
	_hud.set_health(_player.hp, _player.max_hp)
	Audio.play_music("music")


func _physics_process(delta: float) -> void:
	Run.tick(delta)
	_follow_lawn()
	if Run.clock > _combo_until:
		_combo = 0
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		_camera.offset = Vector2(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
		) * Tuning.SHAKE_AMPLITUDE * (_shake / Tuning.SHAKE_TIME)
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


## Every kill: a gem, sometimes a heart, and a cheer on every 25th in a row.
func _on_killed(at: Vector2, kind: int) -> void:
	Run.kills += 1
	var tier := _gem_tier(kind)
	var worth := int(round(Tuning.enemy_xp(kind) * Tuning.gem_worth(tier)))
	# The kill pop. A bug bursting into stars is the whole reward loop made
	# visible; the boss gets a send-off worth the fight.
	var stars := Tuning.PUFF_BOSS_COUNT if kind == Swarm.Kind.BIG else Tuning.PUFF_KILL_COUNT
	_puffs.burst(at, Puffs.Kind.STAR, stars, Tuning.PUFF_GOLD, Tuning.PUFF_KILL_SPEED)
	if worth >= Tuning.NUMBER_MIN_WORTH:
		_puffs.number(at, "+%d" % worth)
	# Bigger bugs drop a bigger gem, so the field reads as where the good
	# fighting was without any number on screen.
	_gems.drop(at, tier, worth)
	# A boss always pays cookies, so reaching one is worth something even in a
	# run that ends badly straight after.
	if kind == Swarm.Kind.BIG:
		for n in Tuning.COOKIE_PER_BOSS:
			var spread := Vector2.from_angle(TAU * float(n) / float(Tuning.COOKIE_PER_BOSS))
			_gems.drop(at + spread * Tuning.BOSS_DROP_SPREAD, Gems.Kind.COOKIE, Tuning.COOKIE_VALUE)
	if Run.kills % Tuning.HEART_EVERY == 0:
		_gems.drop(at, Gems.Kind.HEART, int(Tuning.HEART_HEAL))
	if Run.kills % Tuning.COOKIE_EVERY == 0:
		_gems.drop(at, Gems.Kind.COOKIE, Tuning.COOKIE_VALUE)
	_combo += 1
	_combo_until = Run.clock + Tuning.COMBO_WINDOW
	if _combo >= Tuning.COMBO_EVERY:
		_combo = 0
		_hud.flash("Nice one!")
		Audio.play("choose")
		_puffs.ring(
			_player.global_position,
			Puffs.Kind.STAR,
			Tuning.COMBO_STARS,
			Tuning.PUFF_GOLD,
			Tuning.COMBO_RING_RADIUS,
			Tuning.COMBO_RING_SPEED
		)


## A hit shoves the crowd off the cat, so a surrounded child can get out.
func _on_hurt() -> void:
	_swarm.push_from(
		_player.global_position, Tuning.PLAYER_HIT_PUSH_RADIUS, Tuning.PLAYER_HIT_PUSH
	)
	_shake = Tuning.SHAKE_TIME


## The lawn is one tiling sprite that snaps along with the cat in whole tiles.
## There is no wall in this garden, so a fixed sprite would eventually be walked
## off the edge of; snapping by the tile size means the seam never shows.
func _follow_lawn() -> void:
	# The sprite stays on the camera and its REGION scrolls, rather than the
	# sprite moving and being snapped to a tile. Snapping the position was the
	# "teleport": the region is drawn at the sprite's scale, so a snap of one
	# texture tile is not a whole tile on screen, and the ground jumped by the
	# remainder every time it crossed a boundary.
	var at := _player.global_position
	_lawn.position = at
	var r := _lawn.region_rect
	_lawn.region_rect = Rect2(at / _lawn.scale, r.size)


## Which xp gem a bug leaves. Rolled twice off the bug's own chance, so a grub
## almost always drops blue and never red, while a boss usually drops red: the
## tier is the reward for taking on something harder.
func _gem_tier(kind: int) -> int:
	var up := float(Tuning.ENEMIES[kind]["gem_up"])
	var tier := 0
	for _roll in 2:
		if randf() < up:
			tier += 1
	return mini(tier, Gems.Kind.GEM_RED)


## `Run` decides what to offer and cannot reach the player, so whether a heart
## is missing is pushed to it here.
func _on_health(hp: float, max_hp: float) -> void:
	Run.hurt = hp < max_hp


## A snack heals on the spot rather than being levelled.
func _on_consumed(id: String) -> void:
	var heals := float(Tuning.CONSUMABLES[id].get("heals", 0.0))
	if heals > 0.0:
		_player.heal(heals)


## A broken prop drops what it rolled: usually the xp a bug would give,
## sometimes a heart, sometimes cookies.
func _on_prop_broke(at: Vector2, kind: int) -> void:
	var drop := _props.roll_drop(kind)
	var worth := int(Tuning.PROPS[kind]["xp"])
	if drop == Gems.Kind.HEART:
		worth = int(Tuning.HEART_HEAL)
	elif drop == Gems.Kind.COOKIE:
		worth = Tuning.COOKIE_VALUE
	_gems.drop(at, drop, worth)


## A sparkle where the pickup was collected; hearts sparkle pink so healing
## reads as its own kind of good news.
func _on_collected(at: Vector2, kind: int, _worth: int) -> void:
	var tint: Color = Tuning.PUFF_MINT
	if kind == Gems.Kind.HEART:
		tint = Tuning.PUFF_PINK
	elif kind == Gems.Kind.COOKIE:
		tint = Tuning.PUFF_GOLD
	_puffs.burst(
		at,
		Puffs.Kind.SPARKLE,
		Tuning.PUFF_PICKUP_COUNT,
		tint,
		Tuning.PUFF_PICKUP_SPEED,
		Tuning.PUFF_PICKUP_DRIFT
	)


func _on_boss(at: Vector2) -> void:
	_hud.flash("A big one!")
	Audio.play("boss")
	_puffs.ring(
		at,
		Puffs.Kind.POOF,
		Tuning.BOSS_RING_COUNT,
		Tuning.PUFF_WHITE,
		Tuning.BOSS_RING_RADIUS,
		Tuning.BOSS_RING_SPEED
	)
	_shake = Tuning.SHAKE_TIME


func _on_died() -> void:
	_shake = Tuning.SHAKE_TIME
