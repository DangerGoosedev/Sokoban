extends Node2D

# --- Isometric constants (must match Level.gd / Player.gd) ---
const TILE_W := 32.0
const TILE_H := 16.0
const ELEV_H := 12.0   # pixels per elevation level

# Block face colors
const C_TOP   := Color(0.35, 0.52, 0.78)
const C_LEFT  := Color(0.22, 0.36, 0.56)
const C_RIGHT := Color(0.28, 0.44, 0.67)

var grid_pos:       Vector2i
var base_elevation: int = 0

# Set by Level.gd after instantiation
var level: Node = null

func _ready() -> void:
	_build_visual()

# Called by Level.gd whenever the block is placed or moves
func set_grid_pos(pos: Vector2i, base_elev: int) -> void:
	grid_pos       = pos
	base_elevation = base_elev
	position = level.grid_to_screen(pos, base_elev)
	# Draw in front of floor tiles at the same depth
	z_index = (pos.x + pos.y) * 10 + base_elev * 5 + 3

func _build_visual() -> void:
	var hw := TILE_W * 0.5   # 16  — half tile width
	var hh := TILE_H * 0.5   #  8  — half tile height
	var bh := ELEV_H          # 12  — cube height in pixels

	# The block sits ON the tile surface.
	# y = 0 is the tile surface; negative y goes upward on screen.
	#
	# Top face diamond — shifted up by bh so the cube bottom is at y=0:
	#   top    (  0, -hh - bh )
	#   right  ( hw,      -bh )
	#   bottom (  0,  hh - bh )
	#   left   (-hw,      -bh )

	var top_face := Polygon2D.new()
	add_child(top_face)
	top_face.polygon = PackedVector2Array([
		Vector2(  0, -hh - bh),
		Vector2( hw,      -bh),
		Vector2(  0,  hh - bh),
		Vector2(-hw,      -bh),
	])
	top_face.color = C_TOP

	# Left side face (bottom-left in screen space)
	var left_face := Polygon2D.new()
	add_child(left_face)
	left_face.polygon = PackedVector2Array([
		Vector2(-hw,     -bh),
		Vector2(  0, hh - bh),
		Vector2(  0,      hh),
		Vector2(-hw,       0),
	])
	left_face.color = C_LEFT

	# Right side face (bottom-right in screen space)
	var right_face := Polygon2D.new()
	add_child(right_face)
	right_face.polygon = PackedVector2Array([
		Vector2( 0, hh - bh),
		Vector2(hw,     -bh),
		Vector2(hw,       0),
		Vector2( 0,      hh),
	])
	right_face.color = C_RIGHT
