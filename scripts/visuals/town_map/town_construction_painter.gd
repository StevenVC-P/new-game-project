class_name TownConstructionPainter
extends RefCounted

# What is being built, and what the town keeps its goods in, as miniatures in the town map's
# style (TownBuildingPainter): staked plots, building sites that fill with stacked materials and
# then rise as timber frames, scaffolding around an upgrade, the founders' stockpile, and the
# storehouse.

const STAKE: Color = Color(0.78, 0.66, 0.44)
const STRING_LINE: Color = Color(0.94, 0.90, 0.78, 0.8)
const CLEARED: Color = Color(0.56, 0.46, 0.32, 0.7)
const PLOT_FILL: Color = Color(0.96, 0.90, 0.66, 0.22)
const SACK: Color = Color(0.80, 0.72, 0.52)
const CRATE: Color = Color(0.58, 0.42, 0.26)

static func stake(c: CanvasItem, point: Vector2, s: float) -> void:
	c.draw_line(point + Vector2(s * 0.3, s * 0.4), point + Vector2(s * 0.9, s * 1.0), TownBuildingPainter.SHADOW, s * 0.5)
	c.draw_circle(point, s * 0.45, TownMapStyle.COLOR_TIMBER_DARK)
	c.draw_circle(point, s * 0.28, STAKE)

# A residential plot: stakes at the corners and a string line around the land.
static func plot(c: CanvasItem, r: Rect2, claimed: bool) -> void:
	var area: Rect2 = r.grow(-1.0)
	c.draw_colored_polygon(TownBuildingPainter.soft_rect(area, 1.0), CLEARED if claimed else PLOT_FILL)
	var corners: PackedVector2Array = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y), area.position])
	c.draw_polyline(corners, STRING_LINE, 0.6)
	for i in range(4):
		stake(c, corners[i], 1.5)

# A building site. Supplying: cleared and staked ground with the materials piling up. Building:
# a timber frame rising with progress, its rafters closing in toward the end.
static func site(c: CanvasItem, r: Rect2, supply: float, progress: float, lod: int) -> void:
	var area: Rect2 = r.grow(-1.0)
	c.draw_colored_polygon(TownBuildingPainter.soft_rect(area, minf(area.size.x, area.size.y) * 0.15), CLEARED)
	var corners: PackedVector2Array = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y), area.position])
	c.draw_polyline(corners, STRING_LINE, 0.3)
	for i in range(4):
		stake(c, corners[i], 0.9)
	# Materials on site: logs and a few cut planks, more as they arrive.
	var piles: int = int(ceil(supply * 3.0))
	for i in range(piles):
		var origin: Vector2 = TownBuildingPainter.at(r, 0.1 + i * 0.12, 0.72)
		TownBuildingPainter.log_pile(c, origin, 2, 1 + int(supply > 0.6), r.size.x * 0.035)
	if progress <= 0.0:
		return
	frame(c, Rect2(TownBuildingPainter.at(r, 0.2, 0.18), r.size * Vector2(0.6, 0.42)), progress, lod)

# Posts at the corners and along the walls, then wall plates, then rafters, as progress grows.
static func frame(c: CanvasItem, body: Rect2, progress: float, lod: int) -> void:
	var timber: Color = TownMapStyle.COLOR_LOG_END.darkened(0.15)
	var w: float = maxf(0.45, body.size.y * 0.06)
	c.draw_rect(Rect2(body.position + Vector2(w, w * 1.3), body.size), RegionMapLayer.faded(TownBuildingPainter.SHADOW, 0.6))
	var posts: int = 3
	for i in range(posts):
		var x: float = body.position.x + body.size.x * i / float(posts - 1)
		for y: float in [body.position.y, body.end.y]:
			c.draw_circle(Vector2(x, y), w * 1.1, TownMapStyle.COLOR_TIMBER_DARK)
	if progress > 0.3:
		var plates: float = clampf((progress - 0.3) / 0.3, 0.0, 1.0)
		c.draw_line(body.position, body.position + Vector2(body.size.x * plates, 0.0), timber, w)
		c.draw_line(Vector2(body.position.x, body.end.y), Vector2(body.position.x + body.size.x * plates, body.end.y), timber, w)
		c.draw_line(body.position, Vector2(body.position.x, body.end.y), timber, w)
	if progress > 0.6:
		var rafters: int = int(round(clampf((progress - 0.6) / 0.4, 0.0, 1.0) * 6.0))
		var ridge_y: float = body.get_center().y
		for i in range(rafters + 1):
			var x: float = body.position.x + body.size.x * i / 6.0
			c.draw_line(Vector2(x, body.position.y), Vector2(x, ridge_y), timber.darkened(0.1), w * 0.7)
			c.draw_line(Vector2(x, body.end.y), Vector2(x, ridge_y), timber.darkened(0.2), w * 0.7)
		c.draw_line(Vector2(body.position.x, ridge_y), Vector2(body.end.x, ridge_y), TownMapStyle.COLOR_TIMBER_DARK, w)
	if lod >= 1 and progress > 0.0:
		# A ladder against the south wall.
		var foot: Vector2 = Vector2(body.position.x + body.size.x * 0.7, body.end.y + body.size.y * 0.35)
		c.draw_line(foot, foot + Vector2(0.0, -body.size.y * 0.4), timber, 0.3)
		c.draw_line(foot + Vector2(1.0, 0.0), foot + Vector2(1.0, -body.size.y * 0.4), timber, 0.3)

# Scaffolding poles around a building being upgraded in place, the more the further along.
static func scaffold(c: CanvasItem, r: Rect2, progress: float) -> void:
	var area: Rect2 = r.grow(-0.6)
	var timber: Color = TownMapStyle.COLOR_LOG_END
	var poles: int = 2 + int(progress * 4.0)
	for i in range(poles):
		var t: float = float(i) / float(max(1, poles - 1))
		for y: float in [area.position.y + area.size.y * 0.15, area.end.y - area.size.y * 0.2]:
			var point: Vector2 = Vector2(area.position.x + area.size.x * t, y)
			c.draw_circle(point + Vector2(0.4, 0.5), 0.5, TownBuildingPainter.SHADOW)
			c.draw_circle(point, 0.45, timber.darkened(0.25))
	c.draw_line(Vector2(area.position.x, area.position.y + area.size.y * 0.15), Vector2(area.end.x, area.position.y + area.size.y * 0.15), timber, 0.35)
	c.draw_line(Vector2(area.position.x, area.end.y - area.size.y * 0.2), Vector2(area.end.x, area.end.y - area.size.y * 0.2), timber, 0.35)

# The founders' stockpile: sacks, crates, and a log stack under the open sky.
static func stockpile(c: CanvasItem, r: Rect2, lod: int) -> void:
	TownBuildingPainter.yard(c, r, {}, 1.2)
	TownBuildingPainter.log_pile(c, TownBuildingPainter.at(r, 0.12, 0.18), 3, 2, r.size.x * 0.05)
	for i in range(3):
		var center: Vector2 = TownBuildingPainter.at(r, 0.25 + i * 0.16, 0.66 + (i % 2) * 0.06)
		TownBuildingPainter.blob(c, center + Vector2(0.6, 0.7), Vector2(1.7, 1.3), TownBuildingPainter.SHADOW, 8)
		TownBuildingPainter.blob(c, center, Vector2(1.6, 1.3), SACK.darkened(i * 0.05), 8)
	TownBuildingPainter.box(c, Rect2(TownBuildingPainter.at(r, 0.62, 0.22), r.size * Vector2(0.24, 0.22)), CRATE, 0.8)
	if lod >= 1:
		var lid: Rect2 = Rect2(TownBuildingPainter.at(r, 0.62, 0.22), r.size * Vector2(0.24, 0.22))
		c.draw_line(lid.position, lid.end, CRATE.darkened(0.3), 0.3)
		c.draw_line(Vector2(lid.end.x, lid.position.y), Vector2(lid.position.x, lid.end.y), CRATE.darkened(0.3), 0.3)

# A storehouse: a long barn on posts with wide doors, crates and sacks waiting by the door.
static func draw_storehouse(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	TownBuildingPainter.yard(c, r, state)
	TownBuildingPainter.gabled(c, TownBuildingPainter.at(r, 0.5, 0.34), r.size * Vector2(0.78, 0.4), roof, wall, state, false)
	var door: Rect2 = Rect2(TownBuildingPainter.at(r, 0.4, 0.58), r.size * Vector2(0.2, 0.1))
	c.draw_rect(door, TownMapStyle.COLOR_DOOR)
	TownBuildingPainter.box(c, Rect2(TownBuildingPainter.at(r, 0.12, 0.74), r.size * Vector2(0.16, 0.13)), CRATE, 0.6)
	TownBuildingPainter.blob(c, TownBuildingPainter.at(r, 0.78, 0.8), Vector2(1.5, 1.2), SACK, 8)
