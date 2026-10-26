class_name TownBuildingPainter
extends RefCounted

# Town buildings as miniatures on their plots, in the regional map's style: seen from above and
# a little to the south, lit from the northwest, shadows falling southeast (BuildingPainter).
# Each drawing fills its footprint (rect, in map units) with a yard and what a family works
# there, so a farm reads as a field and a quarry as a pit.
#
# state: "variant" (0..1, fixed per building), "lod" (TownMapStyle.lod_level), "weathered"
# (0..1, from missing upkeep: roofs grey and sag in color), "idle" (no family works it: fields
# lie fallow, fires are out, yards look unused).

const SHADOW: Color = RegionMapStyle.COLOR_SHADOW
const WEATHER_COLOR: Color = Color(0.46, 0.43, 0.39)

static func draw(c: CanvasItem, rect: Rect2, profile: Dictionary, state: Dictionary) -> void:
	var roof: Color = tint(profile["roof"], state, true)
	var wall: Color = tint(profile["wall"], state, false)
	match str(profile["drawing"]):
		"house":
			draw_house(c, rect, state, roof, wall)
		"hut":
			draw_hut(c, rect, state, roof, wall)
		"field":
			draw_field(c, rect, state)
		"garden":
			draw_garden(c, rect, state)
		"woodshed":
			draw_woodshed(c, rect, state, roof, wall)
		"camp":
			draw_camp(c, rect, state)
		"forge":
			draw_forge(c, rect, state, roof, wall)
		"mender":
			draw_mender(c, rect, state)
		"quarry":
			draw_quarry(c, rect, state)
		"stone_shed":
			draw_stone_shed(c, rect, state, roof, wall)
		"brick_clamp":
			draw_brick_clamp(c, rect, state, roof, wall)
		"lime_kiln":
			draw_lime_kiln(c, rect, state)
		"mortar_yard":
			draw_mortar_yard(c, rect, state, roof, wall)
		"mason_yard":
			draw_mason_yard(c, rect, state, roof, wall)
		"sculptor":
			draw_sculptor(c, rect, state, roof, wall)
		"carver":
			draw_carver(c, rect, state, roof, wall)
		"tileworks":
			draw_tileworks(c, rect, state, roof, wall)
		"paver_yard":
			draw_paver_yard(c, rect, state, roof, wall)
		_:
			draw_house(c, rect, state, roof, wall)

# --- Materials --------------------------------------------------------------------------------

static func tint(color: Color, state: Dictionary, is_roof: bool) -> Color:
	var result: Color = color
	if is_roof:
		result = result.lerp(WEATHER_COLOR, float(state.get("weathered", 0.0)) * 0.65)
	if state.get("idle", false):
		result = result.lerp(Color(result.get_luminance(), result.get_luminance(), result.get_luminance()), 0.35).darkened(0.08)
	return result

static func at(r: Rect2, fx: float, fy: float) -> Vector2:
	return r.position + r.size * Vector2(fx, fy)

# A rectangle with its corners cut: yards, beds, and pits look dug and trodden, not ruled.
static func soft_rect(r: Rect2, cut: float) -> PackedVector2Array:
	var p: Vector2 = r.position
	var e: Vector2 = r.end
	return PackedVector2Array([
		Vector2(p.x + cut, p.y), Vector2(e.x - cut, p.y), Vector2(e.x, p.y + cut), Vector2(e.x, e.y - cut),
		Vector2(e.x - cut, e.y), Vector2(p.x + cut, e.y), Vector2(p.x, e.y - cut), Vector2(p.x, p.y + cut)])

static func yard(c: CanvasItem, r: Rect2, state: Dictionary, inset: float = 1.2) -> void:
	var area: Rect2 = r.grow(-inset)
	var color: Color = TownMapStyle.COLOR_YARD
	if state.get("idle", false):
		color = RegionMapLayer.faded(color, 0.55)
	c.draw_colored_polygon(soft_rect(area, minf(area.size.x, area.size.y) * 0.18), color)

static func blob(c: CanvasItem, center: Vector2, radius: Vector2, color: Color, sides: int = 10) -> void:
	RegionMapLayer.draw_blob(c, center, radius, color, sides)

static func box(c: CanvasItem, r: Rect2, color: Color, shadow: float = 0.0) -> void:
	if shadow > 0.0:
		c.draw_rect(Rect2(r.position + Vector2(shadow, shadow * 1.2), r.size), SHADOW)
	c.draw_rect(r, color)

# A gabled building (BuildingPainter) with its ridge along x, sized for the town: the front wall
# shows below the roof, with a door and windows up close.
static func gabled(c: CanvasItem, center: Vector2, size: Vector2, roof: Color, wall: Color, state: Dictionary, door: bool = true) -> void:
	var depth: float = size.y
	var drop: float = depth * 0.3
	BuildingPainter.draw_gabled(c, center, size, 0.0, roof, wall, Vector2(1.0, 1.2) * depth * 0.24, drop, maxf(0.35, depth * 0.05))
	if int(state.get("lod", 0)) < 1:
		return
	var wall_top: float = center.y + depth * 0.5
	if door:
		var door_x: float = center.x + size.x * (0.18 if float(state.get("variant", 0.5)) > 0.5 else -0.18)
		c.draw_rect(Rect2(Vector2(door_x - depth * 0.08, wall_top + drop * 0.15), Vector2(depth * 0.16, drop * 0.85)), TownMapStyle.COLOR_DOOR)
		var window_x: float = center.x - (door_x - center.x)
		c.draw_rect(Rect2(Vector2(window_x - depth * 0.07, wall_top + drop * 0.25), Vector2(depth * 0.14, drop * 0.4)), TownMapStyle.COLOR_WINDOW)

static func chimney(c: CanvasItem, base: Vector2, s: float, lit: bool, lod: int) -> void:
	var r: Rect2 = Rect2(base - Vector2(s * 0.5, s * 1.4), Vector2(s, s * 1.4))
	box(c, r, RegionMapStyle.COLOR_STONE, s * 0.4)
	c.draw_rect(Rect2(r.position, Vector2(s, s * 0.35)), RegionMapStyle.COLOR_STONE_LIGHT)
	if lit:
		smoke(c, r.position + Vector2(s * 0.5, 0.0), s, lod)

# Smoke drifting east on the breeze: a few soft puffs, more of them up close.
static func smoke(c: CanvasItem, top: Vector2, s: float, lod: int) -> void:
	var puffs: int = 2 + lod
	for i in range(puffs):
		var k: float = float(i)
		blob(c, top + Vector2(s * (0.4 + k * 0.9), -s * (0.6 + k * 0.7)), Vector2(s * (0.6 + k * 0.25), s * (0.5 + k * 0.2)), RegionMapLayer.faded(TownMapStyle.COLOR_SMOKE, 1.0 - k / (puffs + 1)), 8)

# Logs stacked with their cut ends facing south.
static func log_pile(c: CanvasItem, origin: Vector2, columns: int, rows: int, r: float) -> void:
	c.draw_rect(Rect2(origin + Vector2(r * 0.6, r * 0.6), Vector2(columns * r * 2.0, rows * r * 1.7)), SHADOW)
	for row in range(rows):
		var shift: float = r if row % 2 == 1 else 0.0
		for column in range(columns - (row % 2)):
			var center: Vector2 = origin + Vector2(r + column * r * 2.0 + shift, r + (rows - 1 - row) * r * 1.6)
			c.draw_circle(center, r, TownMapStyle.COLOR_TIMBER_DARK)
			c.draw_circle(center, r * 0.72, TownMapStyle.COLOR_LOG_END)

static func blocks(c: CanvasItem, origin: Vector2, columns: int, rows: int, size: Vector2, gap: float, color: Color) -> void:
	for row in range(rows):
		for column in range(columns):
			var r: Rect2 = Rect2(origin + Vector2(column * (size.x + gap), row * (size.y + gap)), size)
			box(c, r, color.darkened(0.12), size.y * 0.25)
			c.draw_rect(Rect2(r.position, Vector2(size.x, size.y * 0.55)), color.lightened(0.1))

static func fire_ring(c: CanvasItem, center: Vector2, r: float, lit: bool) -> void:
	for i in range(7):
		var angle: float = TAU * i / 7.0
		blob(c, center + Vector2(cos(angle), sin(angle) * 0.8) * r, Vector2(r * 0.32, r * 0.26), RegionMapStyle.COLOR_STONE, 6)
	blob(c, center, Vector2(r * 0.6, r * 0.5), Color(0.22, 0.18, 0.14), 8)
	if lit:
		blob(c, center + Vector2(0.0, -r * 0.1), Vector2(r * 0.32, r * 0.3), Color(0.98, 0.62, 0.22), 7)
		blob(c, center + Vector2(0.0, -r * 0.15), Vector2(r * 0.15, r * 0.14), Color(1.0, 0.88, 0.5), 6)

# A family's bell tent in temporary shelter, seen from above: the canvas lit on the northwest
# and shaded on the southeast, seams running to the center pole, the doorway open to the south.
static func tent(c: CanvasItem, center: Vector2, s: float) -> void:
	var r: float = s * 0.42
	blob(c, center + Vector2(r * 0.35, r * 0.45), Vector2(r * 1.05, r * 0.9), SHADOW, 14)
	blob(c, center, Vector2(r, r * 0.92), TownMapStyle.COLOR_TENT, 14)
	var shade: PackedVector2Array = PackedVector2Array([center])
	for i in range(8):
		var angle: float = -PI * 0.25 + PI * i / 7.0
		shade.append(center + Vector2(cos(angle) * r, sin(angle) * r * 0.92))
	c.draw_colored_polygon(shade, TownMapStyle.COLOR_TENT_SHADE)
	c.draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, r * 0.3), center + Vector2(-r * 0.3, r * 0.88), center + Vector2(r * 0.3, r * 0.88)]), TownMapStyle.COLOR_DOOR)
	for i in range(6):
		var angle: float = TAU * i / 6.0 + 0.3
		c.draw_line(center, center + Vector2(cos(angle) * r, sin(angle) * r * 0.92), TownMapStyle.COLOR_TENT_SHADE.darkened(0.15), s * 0.025)
	c.draw_circle(center, s * 0.05, TownMapStyle.COLOR_TIMBER_DARK)

# An unsheltered family: a bedroll on the bare ground.
static func bedroll(c: CanvasItem, center: Vector2, s: float) -> void:
	c.draw_colored_polygon(RegionMapLayer.rotated_rect(center + Vector2(s * 0.08, s * 0.1), Vector2(s * 0.45, s * 0.16), 0.3), SHADOW)
	c.draw_colored_polygon(RegionMapLayer.rotated_rect(center, Vector2(s * 0.45, s * 0.16), 0.3), Color(0.56, 0.36, 0.28))

# --- Homes ---------------------------------------------------------------------------------------

static func draw_house(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	var variant: float = float(state.get("variant", 0.5))
	yard(c, r, state)
	# A kitchen garden beside the house.
	var garden: Rect2 = Rect2(at(r, 0.12 if variant < 0.5 else 0.56, 0.66), r.size * Vector2(0.32, 0.22))
	c.draw_colored_polygon(soft_rect(garden, 0.8), Color(0.40, 0.33, 0.22))
	if int(state.get("lod", 0)) >= 1:
		for i in range(3):
			var y: float = garden.position.y + garden.size.y * (0.25 + i * 0.25)
			c.draw_line(Vector2(garden.position.x + 0.6, y), Vector2(garden.end.x - 0.6, y), Color(0.42, 0.58, 0.28), 0.7)
	# Thatch, timber shingles, or tile, by family and fortune.
	var roof_color: Color = roof
	if variant > 0.66:
		roof_color = tint(BuildingVisuals.ROOF_TIMBER, state, true)
	elif variant > 0.4:
		roof_color = roof.darkened(0.08)
	gabled(c, at(r, 0.5, 0.36), r.size * Vector2(0.66, 0.4), roof_color, wall, state)
	chimney(c, at(r, 0.73 if variant < 0.5 else 0.3, 0.3), r.size.x * 0.07, false, int(state.get("lod", 0)))

static func draw_hut(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	yard(c, r, state, 2.0)
	gabled(c, at(r, 0.46, 0.4), r.size * Vector2(0.48, 0.32), roof, wall.darkened(0.15), state)
	fire_ring(c, at(r, 0.74, 0.74), r.size.x * 0.07, not state.get("idle", false))

# --- Food ----------------------------------------------------------------------------------------

static func draw_field(c: CanvasItem, r: Rect2, state: Dictionary) -> void:
	var variant: float = float(state.get("variant", 0.5))
	var crop: Color = RegionMapStyle.COLOR_FIELD_WHEAT if variant < 0.55 else RegionMapStyle.COLOR_FIELD_GREEN
	if state.get("idle", false):
		crop = RegionMapStyle.COLOR_FIELD_FALLOW
	var area: Rect2 = r.grow(-1.0)
	c.draw_colored_polygon(soft_rect(area, 1.2), crop)
	var lod: int = int(state.get("lod", 0))
	var spacing: float = 2.4 if lod >= 1 else 4.0
	var furrow: Color = crop.darkened(0.16)
	var along_x: bool = variant < 0.3 or variant > 0.75
	var count: int = int((area.size.y if along_x else area.size.x) / spacing)
	for i in range(1, count):
		if along_x:
			var y: float = area.position.y + i * spacing
			c.draw_line(Vector2(area.position.x + 0.8, y), Vector2(area.end.x - 0.8, y), furrow, 0.6)
		else:
			var x: float = area.position.x + i * spacing
			c.draw_line(Vector2(x, area.position.y + 0.8), Vector2(x, area.end.y - 0.8), furrow, 0.6)
	if lod >= 1:
		# Hedge and field edge.
		c.draw_polyline(soft_rect(area, 1.2) + PackedVector2Array([soft_rect(area, 1.2)[0]]), Color(0.30, 0.40, 0.20, 0.8), 0.8)
	if not state.get("idle", false):
		var stack: Vector2 = at(r, 0.85 if variant < 0.5 else 0.15, 0.82)
		blob(c, stack + Vector2(0.8, 1.0), Vector2(2.6, 1.9), SHADOW)
		blob(c, stack, Vector2(2.4, 2.0), Color(0.86, 0.74, 0.40))
		blob(c, stack + Vector2(-0.6, -0.7), Vector2(1.2, 1.0), Color(0.94, 0.84, 0.52), 8)

static func draw_garden(c: CanvasItem, r: Rect2, state: Dictionary) -> void:
	var variant: float = float(state.get("variant", 0.5))
	yard(c, r, state, 1.5)
	var greens: Array[Color] = [Color(0.40, 0.56, 0.26), Color(0.52, 0.60, 0.30), Color(0.46, 0.36, 0.24)]
	for i in range(5):
		var h: float = fmod(variant * 7.3 + i * 0.37, 1.0)
		var center: Vector2 = at(r, 0.22 + fmod(i * 0.29 + variant, 0.6), 0.25 + fmod(i * 0.41 + variant * 0.5, 0.55))
		var color: Color = greens[i % greens.size()] if not state.get("idle", false) else RegionMapStyle.COLOR_FIELD_FALLOW
		blob(c, center, Vector2(r.size.x * (0.09 + h * 0.05), r.size.y * (0.06 + h * 0.04)), color, 9)
	if int(state.get("lod", 0)) >= 1:
		blob(c, at(r, 0.8, 0.8), Vector2(1.6, 1.2), TownMapStyle.COLOR_TIMBER, 8)

# --- Wood ----------------------------------------------------------------------------------------

static func draw_woodshed(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	yard(c, r, state)
	gabled(c, at(r, 0.5, 0.3), r.size * Vector2(0.56, 0.3), roof, wall, state)
	log_pile(c, at(r, 0.14, 0.58), 4, 3, r.size.x * 0.055)
	if int(state.get("lod", 0)) >= 1:
		var stump: Vector2 = at(r, 0.78, 0.72)
		c.draw_circle(stump + Vector2(0.5, 0.6), 1.4, SHADOW)
		c.draw_circle(stump, 1.3, TownMapStyle.COLOR_TIMBER_DARK)
		c.draw_circle(stump, 1.0, TownMapStyle.COLOR_LOG_END)
		c.draw_line(stump + Vector2(-0.4, -0.2), stump + Vector2(1.4, -1.6), TownMapStyle.COLOR_TIMBER_DARK, 0.4)

static func draw_camp(c: CanvasItem, r: Rect2, state: Dictionary) -> void:
	yard(c, r, state, 2.0)
	# A lean-to of poles and brush.
	var a: Vector2 = at(r, 0.2, 0.28)
	var b: Vector2 = at(r, 0.72, 0.28)
	c.draw_colored_polygon(PackedVector2Array([a + Vector2(1.0, 1.4), b + Vector2(1.0, 1.4), b + Vector2(2.0, 7.0), a + Vector2(2.0, 7.0)]), SHADOW)
	c.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0.0, 6.0), a + Vector2(0.0, 6.0)]), Color(0.46, 0.38, 0.24))
	c.draw_line(a, b, TownMapStyle.COLOR_TIMBER_DARK, 0.7)
	for i in range(4):
		blob(c, at(r, 0.22 + i * 0.09, 0.72), Vector2(1.5, 1.1), Color(0.42, 0.34, 0.20).lightened(i * 0.04), 7)
	fire_ring(c, at(r, 0.76, 0.7), r.size.x * 0.07, not state.get("idle", false))

# --- Tools ---------------------------------------------------------------------------------------

static func draw_forge(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	var lod: int = int(state.get("lod", 0))
	yard(c, r, state)
	gabled(c, at(r, 0.46, 0.3), r.size * Vector2(0.6, 0.32), roof, wall, state)
	chimney(c, at(r, 0.8, 0.3), r.size.x * 0.07, not state.get("idle", false), lod)
	log_pile(c, at(r, 0.1, 0.66), 3, 2, r.size.x * 0.04)
	if lod >= 1:
		var anvil: Vector2 = at(r, 0.62, 0.74)
		c.draw_colored_polygon(PackedVector2Array([anvil + Vector2(-1.4, -0.5), anvil + Vector2(1.6, -0.5), anvil + Vector2(0.8, 0.6), anvil + Vector2(-0.8, 0.6)]), Color(0.22, 0.22, 0.24))
		c.draw_circle(at(r, 0.8, 0.76), 1.4, RegionMapStyle.COLOR_STONE)
		c.draw_circle(at(r, 0.8, 0.76), 0.4, RegionMapStyle.COLOR_STONE.darkened(0.3))

static func draw_mender(c: CanvasItem, r: Rect2, state: Dictionary) -> void:
	yard(c, r, state, 2.0)
	# A workbench under a cloth awning.
	var awning: Rect2 = Rect2(at(r, 0.2, 0.22), r.size * Vector2(0.5, 0.3))
	c.draw_rect(Rect2(awning.position + Vector2(1.2, 1.5), awning.size), SHADOW)
	c.draw_rect(awning, Color(0.80, 0.72, 0.56))
	for i in range(1, 4):
		var x: float = awning.position.x + awning.size.x * i / 4.0
		c.draw_line(Vector2(x, awning.position.y), Vector2(x, awning.end.y), Color(0.66, 0.42, 0.30), 0.8)
	box(c, Rect2(at(r, 0.24, 0.6), r.size * Vector2(0.4, 0.08)), TownMapStyle.COLOR_TIMBER, 0.6)
	fire_ring(c, at(r, 0.78, 0.72), r.size.x * 0.06, not state.get("idle", false))

# --- Stone ---------------------------------------------------------------------------------------

static func draw_quarry(c: CanvasItem, r: Rect2, state: Dictionary) -> void:
	var lod: int = int(state.get("lod", 0))
	var pit: Rect2 = Rect2(at(r, 0.08, 0.08), r.size * Vector2(0.62, 0.7))
	for step in range(4):
		var inset: float = step * pit.size.x * 0.1
		var level: Rect2 = pit.grow(-inset)
		var shade: Color = RegionMapStyle.COLOR_STONE_LIGHT.lerp(RegionMapStyle.COLOR_ROCK_DARK, step / 3.5)
		c.draw_colored_polygon(soft_rect(level, minf(level.size.x, level.size.y) * 0.2), shade)
		# Each ledge's south face catches the light.
		c.draw_line(Vector2(level.position.x + 1.0, level.end.y), Vector2(level.end.x - 1.0, level.end.y), shade.lightened(0.18), 0.6)
	c.draw_line(at(r, 0.62, 0.65), at(r, 0.86, 0.9), TownMapStyle.COLOR_EARTH, 2.0)
	blocks(c, at(r, 0.74, 0.12), 2, 3, Vector2(3.0, 2.0), 0.8, RegionMapStyle.COLOR_STONE_LIGHT)
	if lod >= 1:
		var foot: Vector2 = at(r, 0.68, 0.48)
		c.draw_line(foot, foot + Vector2(-4.0, -7.0), TownMapStyle.COLOR_TIMBER_DARK, 0.6)
		c.draw_line(foot + Vector2(-4.0, -7.0), foot + Vector2(-10.0, -2.0), TownMapStyle.COLOR_TIMBER_DARK, 0.4)

static func draw_stone_shed(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	yard(c, r, state)
	gabled(c, at(r, 0.5, 0.28), r.size * Vector2(0.56, 0.28), roof, wall, state)
	blocks(c, at(r, 0.14, 0.6), 4, 2, Vector2(3.4, 2.2), 0.6, RegionMapStyle.COLOR_STONE_LIGHT)

static func draw_brick_clamp(c: CanvasItem, r: Rect2, state: Dictionary, _roof: Color, _wall: Color) -> void:
	var lod: int = int(state.get("lod", 0))
	yard(c, r, state)
	var clamp_center: Vector2 = at(r, 0.36, 0.34)
	blob(c, clamp_center + Vector2(1.5, 1.8), r.size * Vector2(0.24, 0.2), SHADOW, 12)
	blob(c, clamp_center, r.size * Vector2(0.24, 0.2), TownMapStyle.COLOR_BRICK, 12)
	blob(c, clamp_center + Vector2(-0.8, -1.0), r.size * Vector2(0.14, 0.1), TownMapStyle.COLOR_BRICK.lightened(0.15), 10)
	if not state.get("idle", false):
		smoke(c, clamp_center + Vector2(0.0, -r.size.y * 0.12), r.size.x * 0.07, lod)
	# Green bricks drying in rows.
	for row in range(2):
		for column in range(5 if lod >= 1 else 3):
			var size: Vector2 = Vector2(1.8, 0.9) if lod >= 1 else Vector2(3.0, 0.9)
			var origin: Vector2 = at(r, 0.12, 0.66 + row * 0.12) + Vector2(column * (size.x + 0.6), 0.0)
			box(c, Rect2(origin, size), TownMapStyle.COLOR_BRICK.lightened(0.25), 0.3)

static func draw_lime_kiln(c: CanvasItem, r: Rect2, state: Dictionary) -> void:
	var lod: int = int(state.get("lod", 0))
	yard(c, r, state)
	var kiln: Vector2 = at(r, 0.4, 0.4)
	var radius: float = r.size.x * 0.2
	c.draw_circle(kiln + Vector2(1.8, 2.2), radius, SHADOW)
	c.draw_circle(kiln, radius, RegionMapStyle.COLOR_STONE)
	c.draw_circle(kiln + Vector2(-radius * 0.15, -radius * 0.15), radius * 0.85, RegionMapStyle.COLOR_STONE_LIGHT)
	c.draw_circle(kiln, radius * 0.45, Color(0.18, 0.15, 0.13))
	if not state.get("idle", false):
		c.draw_circle(kiln, radius * 0.25, Color(0.95, 0.55, 0.22))
		smoke(c, kiln + Vector2(0.0, -radius * 0.6), r.size.x * 0.06, lod)
	blob(c, at(r, 0.78, 0.74), r.size * Vector2(0.12, 0.09), TownMapStyle.COLOR_LIME, 12)
	blocks(c, at(r, 0.1, 0.74), 3, 1, Vector2(2.6, 1.8), 0.6, RegionMapStyle.COLOR_STONE)

static func draw_mortar_yard(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	yard(c, r, state)
	gabled(c, at(r, 0.36, 0.26), r.size * Vector2(0.44, 0.26), roof, wall, state, false)
	for i in range(2):
		var tub: Vector2 = at(r, 0.3 + i * 0.3, 0.7)
		c.draw_circle(tub + Vector2(0.6, 0.8), 2.4, SHADOW)
		c.draw_circle(tub, 2.4, TownMapStyle.COLOR_TIMBER)
		c.draw_circle(tub, 1.8, TownMapStyle.COLOR_LIME.darkened(0.12))
	blob(c, at(r, 0.8, 0.36), r.size * Vector2(0.12, 0.1), Color(0.82, 0.74, 0.52), 10)

static func draw_mason_yard(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	var lod: int = int(state.get("lod", 0))
	yard(c, r, state)
	gabled(c, at(r, 0.32, 0.26), r.size * Vector2(0.48, 0.28), roof, wall, state)
	blocks(c, at(r, 0.12, 0.62), 3, 2, Vector2(4.0, 2.8), 0.9, RegionMapStyle.COLOR_STONE_LIGHT)
	# A timber crane over the dressed stone.
	var foot: Vector2 = at(r, 0.78, 0.7)
	c.draw_line(foot + Vector2(-2.5, 0.0), foot + Vector2(0.0, -9.0), TownMapStyle.COLOR_TIMBER_DARK, 0.8)
	c.draw_line(foot + Vector2(2.5, 0.0), foot + Vector2(0.0, -9.0), TownMapStyle.COLOR_TIMBER_DARK, 0.8)
	c.draw_line(foot + Vector2(0.0, -9.0), foot + Vector2(-7.0, -6.0), TownMapStyle.COLOR_TIMBER_DARK, 0.6)
	if lod >= 1:
		c.draw_line(foot + Vector2(-7.0, -6.0), foot + Vector2(-7.0, -2.0), Color(0.3, 0.26, 0.2), 0.25)
		box(c, Rect2(foot + Vector2(-8.2, -2.2), Vector2(2.4, 1.6)), RegionMapStyle.COLOR_STONE_LIGHT, 0.3)

static func draw_sculptor(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	yard(c, r, state)
	gabled(c, at(r, 0.4, 0.26), r.size * Vector2(0.5, 0.26), roof, wall, state)
	# A figure on its plinth.
	var plinth: Vector2 = at(r, 0.7, 0.72)
	box(c, Rect2(plinth - Vector2(2.4, 1.2), Vector2(4.8, 2.6)), RegionMapStyle.COLOR_STONE, 0.6)
	blob(c, plinth + Vector2(1.4, -0.4), Vector2(1.6, 1.0), SHADOW, 8)
	blob(c, plinth + Vector2(0.0, -2.4), Vector2(1.2, 2.0), RegionMapStyle.COLOR_STONE_LIGHT, 9)
	c.draw_circle(plinth + Vector2(0.0, -4.8), 0.9, RegionMapStyle.COLOR_STONE_LIGHT.lightened(0.1))
	blocks(c, at(r, 0.14, 0.64), 2, 1, Vector2(3.0, 2.4), 0.8, RegionMapStyle.COLOR_STONE_LIGHT)

static func draw_carver(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	yard(c, r, state)
	gabled(c, at(r, 0.46, 0.26), r.size * Vector2(0.52, 0.26), roof, wall, state)
	# Planks seasoning in a stack, and a carved post.
	for i in range(4):
		var plank: Rect2 = Rect2(at(r, 0.12, 0.6) + Vector2(0.0, i * 1.5), Vector2(r.size.x * 0.46, 1.1))
		box(c, plank, TownMapStyle.COLOR_LOG_END.darkened(i * 0.05), 0.4)
	var post: Vector2 = at(r, 0.8, 0.72)
	c.draw_circle(post + Vector2(0.6, 0.8), 1.4, SHADOW)
	c.draw_circle(post, 1.3, TownMapStyle.COLOR_TIMBER)
	c.draw_circle(post + Vector2(-0.3, -0.3), 0.7, TownMapStyle.COLOR_LOG_END)

static func draw_tileworks(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	var lod: int = int(state.get("lod", 0))
	yard(c, r, state)
	gabled(c, at(r, 0.4, 0.26), r.size * Vector2(0.5, 0.26), roof, wall, state)
	chimney(c, at(r, 0.78, 0.3), r.size.x * 0.07, not state.get("idle", false), lod)
	for row in range(2):
		var y: float = r.position.y + r.size.y * (0.62 + row * 0.14)
		c.draw_line(Vector2(r.position.x + r.size.x * 0.12, y + 1.6), Vector2(r.position.x + r.size.x * 0.86, y + 1.6), TownMapStyle.COLOR_TIMBER_DARK, 0.5)
		for column in range(6 if lod >= 1 else 3):
			var width: float = 2.0 if lod >= 1 else 4.0
			box(c, Rect2(Vector2(r.position.x + r.size.x * 0.12 + column * (width + 0.6), y), Vector2(width, 1.4)), TownMapStyle.COLOR_TILE_ORANGE, 0.3)

static func draw_paver_yard(c: CanvasItem, r: Rect2, state: Dictionary, roof: Color, wall: Color) -> void:
	yard(c, r, state)
	gabled(c, at(r, 0.3, 0.24), r.size * Vector2(0.4, 0.24), roof, wall, state, false)
	# Paving slabs in square stacks, joints showing.
	for row in range(2):
		for column in range(3):
			var slab: Rect2 = Rect2(at(r, 0.12, 0.52) + Vector2(column * 5.2, row * 4.6), Vector2(4.4, 3.8))
			box(c, slab, RegionMapStyle.COLOR_STONE, 0.6)
			c.draw_line(slab.position + Vector2(0.0, slab.size.y * 0.5), slab.position + Vector2(slab.size.x, slab.size.y * 0.5), RegionMapStyle.COLOR_STONE.darkened(0.25), 0.3)
			c.draw_line(slab.position + Vector2(slab.size.x * 0.5, 0.0), slab.position + Vector2(slab.size.x * 0.5, slab.size.y), RegionMapStyle.COLOR_STONE.darkened(0.25), 0.3)
