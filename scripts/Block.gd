extends Node2D

var grid_pos:       Vector2i
var base_elevation: int = 0

var level: Node = null

func set_grid_pos(pos: Vector2i, base_elev: int) -> void:
	grid_pos       = pos
	base_elevation = base_elev
	global_position = level.to_global(level.grid_to_screen(pos, base_elev))
