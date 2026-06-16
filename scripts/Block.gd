extends Node2D

var grid_pos:       Vector2i
var base_elevation: int = 0

var level: Node = null

func set_grid_pos(pos: Vector2i, base_elev: int) -> void:
	grid_pos       = pos
	base_elevation = base_elev
	position = level.grid_to_screen(pos, base_elev)
	z_index  = pos.x + pos.y + 100

# TEMP calibration aid — marks this node's true logical anchor (where
# grid_to_screen places it). Line up the sprite's ground-contact point
# with this dot, then delete this function.
func _draw() -> void:
	draw_circle(Vector2.ZERO, 3, Color.RED)
