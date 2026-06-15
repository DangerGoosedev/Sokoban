extends Node2D

const ELEV_H := 12.0  # pixels per elevation unit — must match Block.gd / Player.gd

const DIR_RIGHT := Vector2i( 1,  0)
const DIR_LEFT  := Vector2i(-1,  0)
const DIR_UP    := Vector2i( 0, -1)
const DIR_DOWN  := Vector2i( 0,  1)

# floor_map : Vector2i -> int   (ground elevation; absent = gap/void)
# ramp_map  : Vector2i -> Dict  ({up_dir: Vector2i, base: int})
# block_map : Vector2i -> Node  (Block node at that cell)
var floor_map: Dictionary = {}
var ramp_map:  Dictionary = {}
var block_map: Dictionary = {}

var goal_pos:  Vector2i
var goal_elev: int

var player_pos:  Vector2i
var player_elev: int = 0

@onready var tile_map:      TileMapLayer = $TileMapLayer
@onready var entities_root: Node2D       = $EntitiesRoot
@onready var player:        Node2D       = $EntitiesRoot/Player

var block_scene: PackedScene

signal level_complete

func _ready() -> void:
	block_scene = load("res://scenes/Block.tscn")
	if block_scene == null:
		push_error("Level: could not load res://scenes/Block.tscn")
	_build_level_from_tilemap()
	_init_entities()

# =============================================================================
# Level data — read from TileMapLayer, no hardcoded layouts
# =============================================================================

func _build_level_from_tilemap() -> void:
	floor_map.clear()
	ramp_map.clear()

	for cell: Vector2i in tile_map.get_used_cells():
		var td := tile_map.get_cell_tile_data(cell)
		if td == null:
			continue

		var elev: int = int(td.get_custom_data("elevation"))
		floor_map[cell] = elev

		if bool(td.get_custom_data("is_goal")):
			goal_pos  = cell
			goal_elev = elev

		if bool(td.get_custom_data("is_ramp")):
			var dirs := [DIR_RIGHT, DIR_LEFT, DIR_UP, DIR_DOWN]
			ramp_map[cell] = {
				"up_dir": dirs[clampi(int(td.get_custom_data("ramp_dir")), 0, 3)],
				"base":   elev,
			}

# =============================================================================
# Coordinate conversion — delegates to TileMap so entities align with tiles
# =============================================================================

func grid_to_screen(pos: Vector2i, elev: int = 0) -> Vector2:
	# map_to_local gives the tile centre in TileMapLayer's local space.
	# Elevation shifts upward (negative Y) by ELEV_H per level.
	return tile_map.map_to_local(pos) - Vector2(0.0, elev * ELEV_H)

# =============================================================================
# Entity initialisation
# =============================================================================

func _init_entities() -> void:
	# Player start and block spawn positions are still set here.
	# Tip: add custom data flags "player_start" and "block_spawn" to your
	# TileSet and read them the same way as is_goal/is_ramp when you're ready.
	player_pos  = Vector2i(0, 0)
	player_elev = 0
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
# Movement — called by Player.gd, unchanged from before
# =============================================================================

func request_move(dir: Vector2i) -> void:
	var to_pos := player_pos + dir

	if block_map.has(to_pos) and floor_map.has(to_pos):
		if not _try_push(to_pos, dir):
			return

	var dest_elev := _surface_elev(to_pos)
	if dest_elev < 0:
		return

	var new_elev := _resolve_step(player_elev, to_pos, dest_elev, dir)
	if new_elev < 0:
		return

	player_pos  = to_pos
	player_elev = new_elev
	player.set_grid_pos(player_pos, player_elev)
	_check_win()

func _surface_elev(pos: Vector2i) -> int:
	if block_map.has(pos):
		var base: int = floor_map.get(pos, -1)
		return 0 if base < 0 else base + 1
	return floor_map.get(pos, -1)

func _resolve_step(from_elev: int, to_pos: Vector2i,
		dest_surface: int, dir: Vector2i) -> int:
	if ramp_map.has(to_pos):
		var r: Dictionary = ramp_map[to_pos]
		if r.up_dir == dir and r.base == from_elev:
			return from_elev + 1
	var diff := dest_surface - from_elev
	if diff > 0: return -1
	if diff < -1: return -1
	return dest_surface

func _try_push(block_pos: Vector2i, dir: Vector2i) -> bool:
	var block_base: int = floor_map.get(block_pos, 0)
	if player_elev != block_base:
		return false
	var dest := block_pos + dir
	if block_map.has(dest):
		return false
	var dest_floor: int = floor_map.get(dest, -1)
	if dest_floor > block_base:
		return false
	var block: Node2D = block_map[block_pos]
	block_map.erase(block_pos)
	block_map[dest] = block
	block.set_grid_pos(dest, 0 if dest_floor < 0 else dest_floor)
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
