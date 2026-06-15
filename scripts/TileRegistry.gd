extends Resource
class_name TileRegistry

# Assign your spritesheet here in the Inspector
@export var texture: Texture2D

@export_group("Tile Size (pixels)")
@export var tile_w: int = 32
@export var tile_h: int = 16

# Each entry is the (column, row) cell in the spritesheet.
# Pixel rect is computed as: cell * tile_size → size tile_size.
@export_group("Sheet Positions (column, row)")
@export var floor_pos      := Vector2i(0, 0)
@export var floor_high_pos := Vector2i(1, 0)
@export var ramp_right_pos := Vector2i(2, 0)
@export var ramp_left_pos  := Vector2i(3, 0)
@export var ramp_up_pos    := Vector2i(4, 0)
@export var ramp_down_pos  := Vector2i(5, 0)
@export var goal_tile_pos  := Vector2i(6, 0)
@export var block_top_pos  := Vector2i(0, 1)

# Returns a centred Sprite2D for the named tile, or null if texture is unset.
func make_sprite(tile_name: String) -> Sprite2D:
	if texture == null:
		return null
	var cell := _cell_for(tile_name)
	if cell.x < 0:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2i(cell.x * tile_w, cell.y * tile_h, tile_w, tile_h)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	return sprite

func _cell_for(name: String) -> Vector2i:
	match name:
		"floor":       return floor_pos
		"floor_high":  return floor_high_pos
		"ramp_right":  return ramp_right_pos
		"ramp_left":   return ramp_left_pos
		"ramp_up":     return ramp_up_pos
		"ramp_down":   return ramp_down_pos
		"goal":        return goal_tile_pos
		"block_top":   return block_top_pos
	return Vector2i(-1, -1)
