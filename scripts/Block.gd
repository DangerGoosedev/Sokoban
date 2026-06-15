extends Node2D

const TILE_W := 32.0
const TILE_H := 16.0
const ELEV_H := 12.0

const C_TOP   := Color(0.35, 0.52, 0.78)
const C_LEFT  := Color(0.22, 0.36, 0.56)
const C_RIGHT := Color(0.28, 0.44, 0.67)

var grid_pos:       Vector2i
var base_elevation: int = 0

var level:         Node = null
var tile_registry          = null  # set by Level.gd before add_child

func _ready() -> void:
	_build_visual()

func set_grid_pos(pos: Vector2i, base_elev: int) -> void:
	grid_pos       = pos
	base_elevation = base_elev
	position = level.grid_to_screen(pos, base_elev)
	z_index  = (pos.x + pos.y) * 10 + base_elev * 5 + 3

func _build_visual() -> void:
	var hw := TILE_W * 0.5   # 16
	var hh := TILE_H * 0.5   #  8
	var bh := ELEV_H          # 12 — cube height

	# --- Sprite top face (if TileRegistry is assigned) ---
	if tile_registry != null:
		var sprite := tile_registry.make_sprite("block_top")
		if sprite != null:
			# Position sprite so its centre sits at the top face's diamond centre (y = -bh)
			sprite.position = Vector2(0, -bh)
			add_child(sprite)
			_add_side_faces(hw, hh, bh)
			return

	# --- Polygon fallback: full isometric cube ---
	var top_face := Polygon2D.new()
	add_child(top_face)
	top_face.polygon = PackedVector2Array([
		Vector2(  0, -hh - bh),
		Vector2( hw,      -bh),
		Vector2(  0,  hh - bh),
		Vector2(-hw,      -bh),
	])
	top_face.color = C_TOP
	_add_side_faces(hw, hh, bh)

func _add_side_faces(hw: float, hh: float, bh: float) -> void:
	var left_face := Polygon2D.new()
	add_child(left_face)
	left_face.polygon = PackedVector2Array([
		Vector2(-hw,     -bh),
		Vector2(  0, hh - bh),
		Vector2(  0,      hh),
		Vector2(-hw,       0),
	])
	left_face.color = C_LEFT

	var right_face := Polygon2D.new()
	add_child(right_face)
	right_face.polygon = PackedVector2Array([
		Vector2( 0, hh - bh),
		Vector2(hw,     -bh),
		Vector2(hw,       0),
		Vector2( 0,      hh),
	])
	right_face.color = C_RIGHT
