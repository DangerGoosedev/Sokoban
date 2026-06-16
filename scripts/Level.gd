extends Node2D

const TILE_W := 32.0
const TILE_H := 16.0
const ELEV_H := 12.0  # pixels per elevation unit — must match Block.gd / Player.gd

const DIR_RIGHT := Vector2i( 1,  0)
const DIR_LEFT  := Vector2i(-1,  0)

# floor_map     : Vector2i -> int   (ground elevation; absent = gap/void)
# ramp_map      : Vector2i -> Dict  ({up_dir: Vector2i, base: int})
# block_map     : Vector2i -> Node  (Block node at that cell)
# wall_map      : Vector2i -> Array (blocked exit directions, from block_left/right)
# blocked_cells : Vector2i -> true  (whole cell excluded from play, from is_blocked)
var floor_map: Dictionary = {}
var ramp_map:  Dictionary = {}
var block_map: Dictionary = {}
var wall_map:  Dictionary = {}
var blocked_cells: Dictionary = {}

var goal_pos:  Vector2i
var goal_elev: int

var player_pos:  Vector2i
var player_elev: int = 0

# Drag each TileMapLayer from the Scene panel into these slots in the Inspector.
# (Select the Level node — the root — to see these, not the TileMap node.)
@export var layer_elev_0: TileMapLayer  # ground floor
@export var layer_elev_1: TileMapLayer  # one step up
@export var layer_elev_2: TileMapLayer  # two steps up

# Set these to match cell coordinates in your TileMap.
# Hover over a cell in the TileMap editor to see its (col, row) coords.
@export var player_start_cell: Vector2i = Vector2i(0, 0)
@export var block_spawn_cells: Array[Vector2i] = []

@onready var entities_root: Node2D = $EntitiesRoot
@onready var player:        Node2D = $EntitiesRoot/Player

# Built from the three exports above in _ready()
var _layers: Array[TileMapLayer] = []

var block_scene: PackedScene

# Names of custom data layers that actually exist on the TileSet, so missing
# ones (e.g. wall data the user hasn't added yet) are skipped instead of
# spamming "invalid custom data layer" errors.
var _available_custom_data: Dictionary = {}

signal level_complete

func _ready() -> void:
	block_scene = load("res://scenes/Block.tscn")
	if block_scene == null:
		push_error("Level: could not load res://scenes/Block.tscn")

	# Collect only the layers that were assigned in the Inspector
	_layers.clear()
	for l: TileMapLayer in [layer_elev_0, layer_elev_1, layer_elev_2]:
		if l != null:
			_layers.append(l)

	if _layers.is_empty():
		push_error("Level: no TileMapLayers assigned — drag them into Layer Elev 0/1/2 on the Level node")
		return

	_check_available_custom_data()
	_build_level_from_tilemap()
	_init_entities()

func _check_available_custom_data() -> void:
	var ts: TileSet = _layers[0].tile_set
	if ts == null:
		return
	for i in ts.get_custom_data_layers_count():
		_available_custom_data[ts.get_custom_data_layer_name(i)] = true

func _tile_bool(td: TileData, data_name: String) -> bool:
	if not _available_custom_data.has(data_name):
		return false
	return bool(td.get_custom_data(data_name))

# =============================================================================
# Level data — read from TileMapLayer, no hardcoded layouts
# =============================================================================

func _build_level_from_tilemap() -> void:
	floor_map.clear()
	ramp_map.clear()
	wall_map.clear()
	blocked_cells.clear()

	for elev in _layers.size():
		var layer := _layers[elev]
		if layer == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			var td := layer.get_cell_tile_data(cell)
			if td == null:
				continue

			# is_blocked excludes this cell from play entirely — the tile can
			# still be painted for visuals (e.g. a decorative area, the strip
			# around a cube platform's base) but the player and blocks can
			# never enter it, regardless of elevation rules.
			if _tile_bool(td, "is_blocked"):
				floor_map.erase(cell)
				blocked_cells[cell] = true
				continue
			blocked_cells.erase(cell)

			floor_map[cell] = elev

			if _tile_bool(td, "is_goal"):
				goal_pos  = cell
				goal_elev = elev

			# Two named ramp bools — ramps only ever run along the left/right
			# diagonal. Tick the one matching the direction the player
			# presses to walk UP this ramp.
			#   ramp_left  → press move_left  (character moves upper-left)
			#   ramp_right → press move_right (character moves lower-right)
			# The ramp tile must be on the HIGHER elevation layer (the destination level).
			# e.g. a ramp going from elev 0 to elev 1 belongs on layer_elev_1.
			if   _tile_bool(td, "ramp_left"):
				ramp_map[cell] = {"up_dir": DIR_LEFT,  "base": elev}
			elif _tile_bool(td, "ramp_right"):
				ramp_map[cell] = {"up_dir": DIR_RIGHT, "base": elev}

			# Two named wall bools — tick one or both to wall off that side
			# (e.g. the outer rim of a platform, or the missing half of a
			# corner tile where the platform doesn't cover the full diamond).
			# Blocks movement across that face in BOTH directions.
			#   block_left  → wall facing upper-left
			#   block_right → wall facing lower-right
			var blocked_exits: Array = []
			if _tile_bool(td, "block_left"):  blocked_exits.append(DIR_LEFT)
			if _tile_bool(td, "block_right"): blocked_exits.append(DIR_RIGHT)
			if not blocked_exits.is_empty():
				wall_map[cell] = blocked_exits


# =============================================================================
# Coordinate conversion — delegates to TileMap so entities align with tiles
# =============================================================================

func grid_to_screen(pos: Vector2i, elev: int = 0) -> Vector2:
	# Use the correct layer for this elevation, then convert its local-space
	# tile centre all the way back to Level's local space (handles any layer
	# offsets the user has set in the editor for the visual elevation look).
	var idx   := clampi(elev, 0, _layers.size() - 1)
	var layer := _layers[idx]
	# map_to_local returns the top vertex of the isometric diamond;
	# add half tile height to reach the visual centre.
	return to_local(layer.to_global(layer.map_to_local(pos))) + Vector2(0.0, TILE_H * 0.5)

# =============================================================================
# Entity initialisation
# =============================================================================

func _init_entities() -> void:
	player_pos  = player_start_cell
	player_elev = floor_map.get(player_start_cell, 0)
	player.level = self
	player.set_grid_pos(player_pos, player_elev)

	if block_scene != null:
		for cell in block_spawn_cells:
			_spawn_block(cell)

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

	# Whole-cell exclusion — is_blocked areas are never enterable.
	if blocked_cells.has(to_pos):
		return

	# Wall check — a block_* flag on either tile makes that shared face solid.
	if wall_map.has(player_pos) and dir in wall_map[player_pos]:
		return
	if wall_map.has(to_pos) and -dir in wall_map[to_pos]:
		return

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
		if r.up_dir == dir and r.base - 1 == from_elev:
			return r.base
	var diff := dest_surface - from_elev
	if diff > 0:  return -1
	if diff == 0: return dest_surface
	# diff < 0 — descending is only allowed in two specific cases:
	if diff == -1:
		# Walking down off a ramp the player is standing on
		if ramp_map.has(player_pos):
			var r: Dictionary = ramp_map[player_pos]
			if r.up_dir == -dir and r.base == from_elev:
				return dest_surface
		# Stepping down onto a block sitting in a void (block-bridge mechanic)
		if block_map.has(to_pos):
			return dest_surface
	return -1

func _try_push(block_pos: Vector2i, dir: Vector2i) -> bool:
	var block_base: int = floor_map.get(block_pos, 0)
	if player_elev != block_base:
		return false
	var dest := block_pos + dir
	if blocked_cells.has(dest):
		return false
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
