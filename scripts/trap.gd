class_name Trap
extends Node2D
## One hole in the ground. `traps.gd` scatters these and owns the field; a hole
## itself only has to know where it is and how wide it bites.
##
## A node rather than a row in a parallel array, unlike the swarm. The array
## shape exists to keep a few hundred bugs off the physics server, and there are
## forty holes that never move, never take damage and never die: it bought
## nothing here except an index that could go stale.


## Built in code rather than from a scene: a hole is one sprite, and the art
## comes from the map so there is nothing for a `.tscn` to hold.
static func make(art: Texture2D, at: Vector2) -> Trap:
	var t := Trap.new()
	t.position = at
	var s := Sprite2D.new()
	s.texture = art
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The art is 16x16 and drawn at the trap's own size, the same way every other
	# sprite in the game is scaled up from its grid.
	var size := Tuning.TRAP_RADIUS * 2.0
	s.scale = Vector2(size / 16.0, size / 16.0)
	t.add_child(s)
	return t


## Whether a point is far enough in to count as falling in. The sprite's
## outermost ring is its rim, and clipping the rim at a run should cost nothing:
## a child cannot steer precisely.
func bites(point: Vector2) -> bool:
	var r := Tuning.TRAP_RADIUS * Tuning.TRAP_BITE
	return position.distance_squared_to(point) < r * r
