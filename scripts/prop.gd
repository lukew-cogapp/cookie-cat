class_name Prop
extends Node2D
## One breakable thing: a pot, a berry bush, a cookie box, or whichever of those
## three the map swaps them for. `props.gd` scatters these and owns the field; a
## prop itself knows its own kind, what health it has left, and whether it is
## mid-flash.
##
## A node rather than a row in parallel arrays, unlike the swarm. The array shape
## exists to keep a few hundred bugs off the physics server; a hundred and twenty
## pots that never move and never chase cost nothing either way, and the index it
## bought went stale the moment one broke.

## Which row of the map's prop table this is. `broke` reports it, so the world
## can look up the drop and the xp without knowing what a pot is.
var kind := 0
var hp := 0.0
## Seconds of hit flash left, counting on down through `HIT_FLASH_GAP` as a
## negative. An aura damages every frame, so the gap has to be an enforced quiet
## period: merely refusing to refresh a running flash still left a pot white
## about half the time, which reads as solid white.
var flash := 0.0
## Set on the hit that breaks it, and never unset. Every weapon's area of effect
## goes through `damage_near`, so two of them reaching one pot in a frame is the
## normal case; without this the second would break it again and drop its reward
## twice.
var broken := false

var _sprite: Sprite2D


## Built in code rather than from a scene: a prop is one sprite, and both the art
## and the size come from the map's table, so there is nothing for a `.tscn` to
## hold.
static func make(k: int, table: Array, at: Vector2) -> Prop:
	var p := Prop.new()
	p.position = at
	p.kind = k
	var d: Dictionary = table[k]
	p.hp = float(d["hp"])
	var s := Sprite2D.new()
	s.texture = load(String(d["art"]))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The art is 16x16 and drawn at the prop's own size, the same way every other
	# sprite in the game is scaled up from its grid.
	var size := float(d["radius"]) * 2.0
	s.scale = Vector2(size / 16.0, size / 16.0)
	p.add_child(s)
	p._sprite = s
	return p


## Takes a hit. Returns true on the hit that breaks it, and on no other, so the
## caller can emit `broke` once without checking anything itself.
func damage(amount: float) -> bool:
	if broken:
		return false
	hp -= amount
	if flash <= -Tuning.HIT_FLASH_GAP:
		flash = Tuning.HIT_FLASH_TIME
		_sprite.modulate = Tuning.HIT_FLASH_COLOUR
	if hp <= 0.0:
		broken = true
		return true
	return false


## Runs the flash down. Driven by the field's one loop rather than by a
## `_physics_process` per prop, which is the only thing the array version was
## really buying.
func tick(delta: float) -> void:
	if flash <= -Tuning.HIT_FLASH_GAP:
		return
	var lit := flash > 0.0
	flash = maxf(flash - delta, -Tuning.HIT_FLASH_GAP)
	if lit and flash <= 0.0:
		_sprite.modulate = Color.WHITE
