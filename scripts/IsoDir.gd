extends RefCounted
class_name IsoDir

# Canonical screen-diagonal directions for this isometric grid. There is no
# straight up/down/left/right on screen in this view — every move is one of
# these 4 diagonals. Player/Level/Block all reference these names instead of
# re-deriving raw Vector2i values, so the mapping can't drift out of sync
# between scripts again.
const NE := Vector2i( 0, -1)
const SE := Vector2i( 1,  0)
const SW := Vector2i( 0,  1)
const NW := Vector2i(-1,  0)
