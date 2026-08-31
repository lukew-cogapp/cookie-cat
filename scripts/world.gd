extends Node2D
## Wires the run together and owns the rules that need two systems to agree:
## a kill becomes a gem here, not in the swarm, because the swarm does not
## know what a gem is.

@onready var _player: Node2D = $Player
@onready var _swarm: Swarm = $Swarm
@onready var _gems: Gems = $Gems
@onready var _weapons: Weapons = $Weapons
@onready var _director: Director = $Director
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
	_weapons.killed.connect(_on_killed)
	_director.boss_arrived.connect(_on_boss)
	_player.health_changed.connect(_hud.set_health)
	_player.died.connect(_on_died)
	_player.hurt_taken.connect(_on_hurt)
	_hud.set_health(_player.hp, _player.max_hp)
	Audio.play_music("music")


func _physics_process(delta: float) -> void:
	Run.tick(delta)
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
	var worth := Tuning.enemy_xp(kind)
	# Bigger bugs drop a bigger gem, so the field reads as where the good
	# fighting was without any number on screen.
	_gems.drop(at, Gems.Kind.GEM, worth)
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


## A hit shoves the crowd off the cat, so a surrounded child can get out.
func _on_hurt() -> void:
	_swarm.push_from(
		_player.global_position, Tuning.PLAYER_HIT_PUSH_RADIUS, Tuning.PLAYER_HIT_PUSH
	)
	_shake = Tuning.SHAKE_TIME


func _on_boss() -> void:
	_hud.flash("A big one!")
	_shake = Tuning.SHAKE_TIME


func _on_died() -> void:
	_shake = Tuning.SHAKE_TIME
