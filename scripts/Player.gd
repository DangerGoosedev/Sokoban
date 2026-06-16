extends Node2D

# --- Isometric constants (must match Level.gd) ---
const TILE_W := 32.0
const TILE_H := 16.0
const ELEV_H := 12.0

# --- Grid state ---
var grid_pos := Vector2i.ZERO
var elevation := 0

# Set by Level.gd after instantiation: player.level = self
var level: Node = null

func _ready() -> void:
	_build_visual()

func _unhandled_input(event: InputEvent) -> void:
	# Filter keyboard auto-repeat so each press = one step
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("exit_button"):
		get_tree().quit()
		return

	# Named by screen diagonal, not arrow-key direction — in this isometric
	# view none of the four moves is a straight up/down/left/right on screen.
	var dir := Vector2i.ZERO
	if   event.is_action_pressed("move_se"): dir = IsoDir.SE
	elif event.is_action_pressed("move_nw"): dir = IsoDir.NW
	elif event.is_action_pressed("move_ne"): dir = IsoDir.NE
	elif event.is_action_pressed("move_sw"): dir = IsoDir.SW

	if dir != Vector2i.ZERO and level != null:
		level.request_move(dir)

# Called by Level.gd to place the player after a validated move
func set_grid_pos(pos: Vector2i, elev: int) -> void:
	grid_pos = pos
	elevation = elev
	position = level.grid_to_screen(pos, elev)  # use Level's version so ORIGIN matches
	print("Player: grid_pos=%s elev=%d -> position=%s global_position=%s z_index=%d visible=%s" % [pos, elev, position, global_position, z_index, visible])

# --- Placeholder visual (replace with sprite later) ---
func _build_visual() -> void:
	# Body: tapered hexagon standing upright on the tile surface.
	# y=0 is the tile surface; negative y goes up the screen.
	var body := Polygon2D.new()
	add_child(body)
	var w := 8.0
	body.polygon = PackedVector2Array([
		Vector2( 0,   -32),   # head
		Vector2( w,   -22),   # right shoulder
		Vector2( w,    -8),   # right hip
		Vector2( 0,     0),   # feet (tile surface)
		Vector2(-w,    -8),   # left hip
		Vector2(-w,   -22),   # left shoulder
	])
	body.color = Color(0.95, 0.35, 0.25)

	# Dark outline
	var outline := Line2D.new()
	add_child(outline)
	outline.points = PackedVector2Array([
		Vector2( 0,   -32),
		Vector2( w,   -22),
		Vector2( w,    -8),
		Vector2( 0,     0),
		Vector2(-w,    -8),
		Vector2(-w,   -22),
		Vector2( 0,   -32),
	])
	outline.default_color = Color(0.6, 0.18, 0.1)
	outline.width = 1.5
