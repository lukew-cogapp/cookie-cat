extends Node2D
## The gardener. Moves on eight directions and never aims: every weapon picks
## its own targets, which is what makes the genre playable one-handed by a
## child.
##
## Not a CharacterBody2D. There is nothing solid in the garden to collide
## with, and enemy contact is a distance test in `swarm.gd`, so a physics body
## would solve a world with nothing in it.

signal died
signal health_changed(hp: float, max_hp: float)
## Fired before the heart is deducted, so the world can clear space around the
## cat. The player cannot do it itself: it does not know about the swarm.
signal hurt_taken

## How much of its speed the cat keeps, and for how long. Set by the world from
## the webs the spiders leave: a slow that takes control away from a child is
## mild and brief on purpose, since running away must still work.
var _slow := 1.0
var _slow_for := 0.0

var hp := 0.0
var max_hp := 0.0
## Seconds of invulnerability left after a hit. Without it a child standing in
## a crowd loses every heart in under a second and cannot learn why.
var mercy := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _camera: Camera2D = $Camera

var _flash: Tween
## Stand, step, step-other. The cat's own art plus the two shared step frames,
## so a flavour only needs its standing sprite drawn.
var _walk: Array[Texture2D] = []
var _step := 0.0
## The worn hat, a child of the cat sprite: it inherits the scale, the walk
## bob and the hurt flash for free, and only the flip needs mirroring by hand.
var _hat: Sprite2D


func _ready() -> void:
	_camera.zoom = Vector2(Tuning.ZOOM, Tuning.ZOOM)
	# The cat must be the biggest thing on screen; the art is 16px, so it is
	# scaled up here rather than drawn again at a second size.
	var grow := Tuning.PLAYER_DRAW_SIZE / 16.0
	_sprite.scale = Vector2(grow, grow)
	_sprite.texture = load(String(Tuning.CATS[Run.cat]["art"]))
	# Each flavour has its own step frames: sharing the base cat's made Minty
	# flicker pink every other frame while walking.
	var art := String(Tuning.CATS[Run.cat]["art"])
	_walk = [
		_sprite.texture,
		load(art.replace(".png", "_step_a.png")),
		_sprite.texture,
		load(art.replace(".png", "_step_b.png")),
	]
	var hat_art := Tuning.hat_art(Save.hat)
	if hat_art != "":
		_hat = Sprite2D.new()
		_hat.texture = load(hat_art)
		_sprite.add_child(_hat)
	max_hp = Tuning.PLAYER_MAX_HP
	hp = max_hp
	health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if not Run.alive:
		return
	if mercy > 0.0:
		mercy = maxf(mercy - delta, 0.0)
	if _slow_for > 0.0:
		_slow_for = maxf(_slow_for - delta, 0.0)
		if _slow_for <= 0.0:
			_slow = 1.0
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		var speed := Tuning.PLAYER_SPEED * Run.passive("boots") * _slow
		# `dir` keeps the stick's magnitude, so a gentle push walks. Below the
		# floor it is treated as full tilt, or a child pushing softly creeps
		# and cannot get away from anything.
		if dir.length() < Tuning.STICK_WALK_FLOOR:
			dir = dir.normalized() * Tuning.STICK_WALK_FLOOR
		position += dir * speed * delta
		# Face travel by flipping, not rotating: a rotated gardener reads as
		# falling over, and there is only ever left and right art.
		if not is_zero_approx(dir.x):
			_sprite.flip_h = dir.x < 0.0
			# flip_h is a Sprite2D property, not a transform, so a child hat
			# does not inherit it.
			if _hat != null:
				_hat.flip_h = _sprite.flip_h
		# A walk bob, so movement reads even against a flat lawn.
		_sprite.position.y = -absf(sin(Run.clock * Tuning.PLAYER_BOB_RATE)) * Tuning.PLAYER_BOB
		_step += delta * Tuning.PLAYER_STEP_RATE
		var frame := int(_step) % _walk.size()
		if _walk[frame] != null:
			_sprite.texture = _walk[frame]
	else:
		_sprite.position.y = 0.0
		_step = 0.0
		if _walk[0] != null:
			_sprite.texture = _walk[0]
	# The halo pulses, so the marker under the cat needs a redraw per frame.
	queue_redraw()


## A ground shadow and a soft halo, drawn under the cat (a parent draws below
## its children). In a minute-nine crowd the cat's own pixels are covered by
## bugs half the time; the pale pool of light under it is what stays findable,
## and it costs two circles a frame rather than anything per bug.
func _draw() -> void:
	var pulse := 1.0 + Tuning.PLAYER_HALO_PULSE * sin(Run.clock * Tuning.PLAYER_HALO_RATE)
	# Layered translucent discs: alpha stacks towards the centre, faking a
	# radial glow without a texture.
	for n in Tuning.PLAYER_HALO_RINGS:
		var r: float = Tuning.PLAYER_HALO_RADIUS * pulse * (1.0 - float(n) * Tuning.PLAYER_HALO_STEP)
		draw_circle(Vector2.ZERO, r, Tuning.PLAYER_HALO_COLOUR)
	draw_set_transform(
		Vector2(0.0, Tuning.PLAYER_SHADOW_DROP), 0.0, Vector2(1.0, Tuning.PLAYER_SHADOW_SQUASH)
	)
	draw_circle(Vector2.ZERO, Tuning.PLAYER_SHADOW_RADIUS, Tuning.PLAYER_SHADOW_COLOUR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func hurt(amount: float) -> void:
	if not Run.alive or mercy > 0.0:
		return
	mercy = Tuning.PLAYER_MERCY_TIME
	hurt_taken.emit()
	hp = maxf(hp - amount, 0.0)
	health_changed.emit(hp, max_hp)
	Audio.play("hurt")
	_flash_red()
	if hp <= 0.0:
		# Before `finish`, which stops the music and plays the tally cue: the
		# last heart going needs its own moment first.
		Audio.play("death")
		died.emit()
		Run.finish(false)


func heal(amount: float) -> void:
	if not Run.alive:
		return
	hp = minf(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)
	Audio.play("heal")


## How far gems are pulled from, so the pickup layer can ask one thing.
func magnet_radius() -> float:
	return Tuning.MAGNET_RADIUS * Run.passive("magnet")


## Slows the cat, for as long as it keeps being told to. The strongest slow
## wins while it lasts, so stepping from one web to another does not speed up.
func slow_by(factor: float, secs: float) -> void:
	if _slow_for <= 0.0 or factor < _slow:
		_slow = factor
	_slow_for = maxf(_slow_for, secs)


## Which way the cat is looking. The Paw Swipe aims by this, so it reads off
## the sprite rather than the last input: a swipe must match what is drawn.
func facing_left() -> bool:
	return _sprite.flip_h


func _flash_red() -> void:
	if _flash != null and _flash.is_valid():
		_flash.kill()
	_sprite.modulate = Tuning.PLAYER_HURT_COLOUR
	_flash = create_tween()
	_flash.tween_property(_sprite, "modulate", Color.WHITE, Tuning.PLAYER_MERCY_TIME)
