extends Node2D

# --- Isometric constants (shared with Player.gd / Block.gd) ---
const TILE_W := 32.0
const TILE_H := 16.0
const ELEV_H := 12.0

# Grid direction vectors
const DIR_RIGHT := Vector2i( 1,  0)
const DIR_LEFT  := Vector2i(-1,  0)
const DIR_UP    := Vector2i( 0, -1)
const DIR_DOWN  := Vector2i( 0,  1)

# Tile colors
const C_TILE_TOP   := Color(0.55, 0.47, 0.36)
const C_TILE_LEFT  := Color(0.38, 0.33, 0.25)
const C_TILE_RIGHT := Color(0.46, 0.40, 0.30)
const C_HIGH_TOP   := Color(0.68, 0.60, 0.50)
const C_HIGH_LEFT  := Color(0.48, 0.43, 0.36)
const C_HIGH_RIGHT := Color(0.58, 0.52, 0.43)
const C_RAMP       := Color(0.78, 0.62, 0.32)
const C_GOAL       := Color(1.00, 0.85, 0.10)

# Screen offset so col 0 / row 0 isn't in the corner
const ORIGIN := Vector2(120.0, 80.0)

# --- Grid state ---
# floor_map : Vector2i -> int   (ground elevation at that tile; absent = gap/void)
# ramp_map  : Vector2i -> Dict  ({up_dir: Vector2i, base: int})
# block_map : Vector2i -> Node  (Block node currently at that position)
var floor_map: Dictionary = {}
var ramp_map:  Dictionary = {}
var block_map: Dictionary = {}

var goal_pos:  Vector2i
var goal_elev: int

var player_pos:  Vector2i
var player_elev: int = 0

@onready var tiles_root:    Node2D = $TilesRoot
@onready var entities_root: Node2D = $EntitiesRoot
@onready var player:        Node2D = $EntitiesRoot/Player

var block_scene: PackedScene  # loaded in _ready so a missing file doesn't kill the script

signal level_complete

func _ready() -> void:
	block_scene = load("res://scenes/Block.tscn")
	if block_scene == null:
		push_error("Level: could not load res://scenes/Block.tscn — create the scene first")
	_build_level()
	_render_tiles()
	_init_entities()

# =============================================================================
# Level data
# =============================================================================

func _build_level() -> void:
	# Straight-line gap puzzle (all on row 0):
	#   col:  0    1    2    3   [4]   5    6    7
	#         [P]  [B]  [·]  [·]  _   [·]  [R↑] [G]
	#   P = player start, B = block, · = floor,
	#   _ = gap (no tile), R↑ = ramp going right, G = goal at elevation 1
	#
	# Solution: push B right three times so it fills the gap at col 4,
	# then walk over it, up the ramp, onto the platform.

	for col in [0, 1, 2, 3, 5, 6]:
		floor_map[Vector2i(col, 0)] = 0
	# col 4 intentionally absent (the gap)

	# Ramp at col 6: moving RIGHT from elevation 0 lifts the player to elevation 1
	ramp_map[Vector2i(6, 0)] = {"up_dir": DIR_RIGHT, "base": 0}

	# Elevated platform
	floor_map[Vector2i(7, 0)] = 1
	goal_pos  = Vector2i(7, 0)
	goal_elev = 1

	player_pos  = Vector2i(0, 0)
	player_elev = 0

# =============================================================================
# Coordinate conversion
# =============================================================================

func grid_to_screen(pos: Vector2i, elev: int = 0) -> Vector2:
	return ORIGIN + Vector2(
		(pos.x - pos.y) * TILE_W * 0.5,
		(pos.x + pos.y) * TILE_H * 0.5 - elev * ELEV_H
	)

# =============================================================================
# Tile rendering (placeholder polygons; swap for sprites later)
# =============================================================================

func _render_tiles() -> void:
	for child in tiles_root.get_children():
		child.queue_free()

	# Draw back-to-front so closer tiles paint over farther ones
	var positions: Array = floor_map.keys()
	positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.x + a.y) < (b.x + b.y)
	)
	for pos in positions:
		_add_tile(pos, floor_map[pos])

func _add_tile(pos: Vector2i, elev: int) -> void:
	var node := Node2D.new()
	tiles_root.add_child(node)
	node.position = grid_to_screen(pos, elev)
	node.z_index  = (pos.x + pos.y) * 10 + elev

	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	var is_ramp := ramp_map.has(pos)
	var is_goal := (pos == goal_pos)

	# --- Top face ---
	var top_color: Color
	if   is_goal:  top_color = C_GOAL
	elif is_ramp:  top_color = C_RAMP
	elif elev > 0: top_color = C_HIGH_TOP
	else:          top_color = C_TILE_TOP

	var top := Polygon2D.new()
	node.add_child(top)
	top.polygon = PackedVector2Array([
		Vector2(  0, -hh),
		Vector2( hw,   0),
		Vector2(  0,  hh),
		Vector2(-hw,   0),
	])
	top.color = top_color

	# Ramp: shade the uphill half darker so the slope reads clearly
	if is_ramp:
		var hint := Polygon2D.new()
		node.add_child(hint)
		hint.polygon = PackedVector2Array([
			Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh)
		])
		hint.color = C_RAMP.darkened(0.18)

	# --- Side walls for elevated tiles ---
	if elev > 0:
		var wh := float(elev) * ELEV_H

		var left_wall := Polygon2D.new()
		node.add_child(left_wall)
		left_wall.polygon = PackedVector2Array([
			Vector2(-hw,       0), Vector2(  0,       hh),
			Vector2(  0, hh + wh), Vector2(-hw,       wh),
		])
		left_wall.color = C_HIGH_LEFT

		var right_wall := Polygon2D.new()
		node.add_child(right_wall)
		right_wall.polygon = PackedVector2Array([
			Vector2(  0,       hh), Vector2(hw,        0),
			Vector2( hw,       wh), Vector2( 0, hh + wh),
		])
		right_wall.color = C_HIGH_RIGHT

# =============================================================================
# Entity initialisation
# =============================================================================

func _init_entities() -> void:
	# Wire player first so input works even if block spawning fails
	player.level = self
	player.set_grid_pos(player_pos, player_elev)

	if block_scene != null:
		_spawn_block(Vector2i(1, 0))

func _spawn_block(pos: Vector2i) -> void:
	var block: Node2D = block_scene.instantiate()
	entities_root.add_child(block)
	block_map[pos] = block
	block.level = self
	block.set_grid_pos(pos, floor_map.get(pos, 0))

# =============================================================================
# Movement — called by Player.gd
# =============================================================================

func request_move(dir: Vector2i) -> void:
	var to_pos := player_pos + dir

	# Block on solid ground in that cell: try to push before moving
	if block_map.has(to_pos) and floor_map.has(to_pos):
		if not _try_push(to_pos, dir):
			return

	var dest_elev := _surface_elev(to_pos)
	if dest_elev < 0:
		return  # Void — nothing to stand on

	var new_elev := _resolve_step(player_elev, to_pos, dest_elev, dir)
	if new_elev < 0:
		return  # e.g. wall with no ramp

	player_pos  = to_pos
	player_elev = new_elev
	player.set_grid_pos(player_pos, player_elev)
	_check_win()

# Elevation of the surface a character would stand on at pos.
# Returns -1 if pos is impassable void.
func _surface_elev(pos: Vector2i) -> int:
	if block_map.has(pos):
		var base: int = floor_map.get(pos, -1)
		return 0 if base < 0 else base + 1  # gap-fill → 0; on tile → tile+1
	return floor_map.get(pos, -1)

# Determines the elevation the player arrives at.
# Returns -1 if the move is illegal (e.g. stepping up a cliff without a ramp).
func _resolve_step(from_elev: int, to_pos: Vector2i,
		dest_surface: int, dir: Vector2i) -> int:
	# Ramp going the right way lets the player gain one elevation
	if ramp_map.has(to_pos):
		var r: Dictionary = ramp_map[to_pos]
		if r.up_dir == dir and r.base == from_elev:
			return from_elev + 1

	var diff := dest_surface - from_elev
	if diff > 0: return -1   # Cliff — no ramp
	if diff < -1: return -1  # Drop too large (remove to allow free-falling)
	return dest_surface

# Push the block at block_pos one step in dir.
# Returns false if the push is impossible.
func _try_push(block_pos: Vector2i, dir: Vector2i) -> bool:
	var block_base: int = floor_map.get(block_pos, 0)
	if player_elev != block_base:
		return false  # Player not level with the block's base

	var dest := block_pos + dir
	if block_map.has(dest):
		return false  # Something already occupies the target cell

	var dest_floor: int = floor_map.get(dest, -1)
	if dest_floor > block_base:
		return false  # Can't push a block up a ledge

	# Commit the move
	var block: Node2D = block_map[block_pos]
	block_map.erase(block_pos)
	block_map[dest] = block

	# Block settles at the destination floor, or at 0 if it falls into a gap
	var settled_base := 0 if dest_floor < 0 else dest_floor
	block.set_grid_pos(dest, settled_base)
	return true

# =============================================================================
# Win condition
# =============================================================================

func _check_win() -> void:
	if player_pos == goal_pos and player_elev == goal_elev:
		emit_signal("level_complete")
		get_tree().create_timer(0.5).timeout.connect(
			func() -> void:
				get_tree().change_scene_to_file("res://scenes/Level2.tscn")
		)
