class_name LandscapePainter
extends RefCounted

# Natural features painted the same way at every scale: trees, shrubs, peaks, and boulders,
# seen from above and a little to the south, with shadows falling southeast. The regional
# map and the town map both paint through these, so a wood is the same wood in both.
# Shapes go into a TriangleBatch so thousands of them flush as one draw command.

const FLOWER_COLORS: Array[Color] = [Color(0.98, 0.96, 0.88), Color(0.98, 0.84, 0.30), Color(0.76, 0.58, 0.88)]

static func hash01(x: int, y: int, salt: int) -> float:
	return float(hash(Vector3i(x, y, salt)) & 0xFFFF) / 65535.0

static func faded(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)

# Dark, base, and light canopy colors of a tree style (RegionMapStyle.tree_style_for), shifted
# per tree so a wood is not one flat green.
static func tree_colors(style: Dictionary, variant: float) -> Array[Color]:
	var shift: float = (variant - 0.5) * 0.18
	var base: Color = style["base"]
	var dark: Color = style["dark"]
	var light: Color = style["light"]
	if shift > 0.0:
		return [dark.lightened(shift), base.lightened(shift), light.lightened(shift * 0.5)]
	return [dark.darkened(-shift), base.darkened(-shift), light.darkened(-shift * 0.5)]

static func add_broadleaf(batch: RegionMapLayer.TriangleBatch, style: Dictionary, center: Vector2, r: float, variant: float) -> void:
	var colors: Array[Color] = tree_colors(style, variant)
	batch.add_blob(center + Vector2(r * 0.45, r * 0.55), Vector2(r * 1.05, r * 0.82), RegionMapStyle.COLOR_SHADOW)
	batch.add_blob(center, Vector2(r, r), colors[0])
	batch.add_blob(center + Vector2(-r * 0.12, -r * 0.16), Vector2(r * 0.8, r * 0.8), colors[1])
	batch.add_blob(center + Vector2(-r * 0.34, -r * 0.38), Vector2(r * 0.4, r * 0.4), colors[2], 8)

static func add_conifer(batch: RegionMapLayer.TriangleBatch, style: Dictionary, center: Vector2, r: float, variant: float) -> void:
	var colors: Array[Color] = tree_colors(style, variant)
	batch.add_blob(center + Vector2(r * 0.6, r * 0.7), Vector2(r * 0.95, r * 0.6), RegionMapStyle.COLOR_SHADOW)
	batch.add_fan(center, star(center, r, r * 0.58, 8, variant * TAU), colors[0])
	var inner: Vector2 = center + Vector2(-r * 0.1, -r * 0.14)
	batch.add_fan(inner, star(inner, r * 0.68, r * 0.4, 8, variant * TAU + 0.3), colors[1])
	batch.add_blob(center + Vector2(-r * 0.2, -r * 0.26), Vector2(r * 0.22, r * 0.22), colors[2], 6)

static func add_scrub(batch: RegionMapLayer.TriangleBatch, style: Dictionary, center: Vector2, r: float, variant: float) -> void:
	var colors: Array[Color] = tree_colors(style, variant)
	batch.add_blob(center + Vector2(r * 0.4, r * 0.45), Vector2(r, r * 0.75), RegionMapStyle.COLOR_SHADOW)
	batch.add_blob(center, Vector2(r, r * 0.9), colors[0], 8)
	batch.add_blob(center + Vector2(-r * 0.2, -r * 0.22), Vector2(r * 0.6, r * 0.55), colors[1], 8)

static func add_shrub(batch: RegionMapLayer.TriangleBatch, style: Dictionary, center: Vector2, r: float, variant: float) -> void:
	var colors: Array[Color] = tree_colors(style, variant)
	batch.add_blob(center + Vector2(r * 0.4, r * 0.4), Vector2(r, r * 0.7), faded(RegionMapStyle.COLOR_SHADOW, 0.6), 6)
	batch.add_blob(center, Vector2(r, r * 0.85), colors[1], 7)
	batch.add_blob(center + Vector2(-r * 0.25, -r * 0.25), Vector2(r * 0.45, r * 0.4), colors[2], 6)

static func add_flower(batch: RegionMapLayer.TriangleBatch, center: Vector2, r: float, variant: float) -> void:
	var color: Color = FLOWER_COLORS[int(variant * FLOWER_COLORS.size()) % FLOWER_COLORS.size()]
	batch.add_blob(center, Vector2(r, r), color, 6)

static func star(center: Vector2, outer: float, inner: float, points: int, phase: float) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	for i in range(points * 2):
		var angle: float = phase + PI * i / points
		var radius: float = outer if i % 2 == 0 else inner
		polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return polygon

# A peak seen from above and a little to the south: lit western face, shaded eastern face,
# a shadow cast toward the southeast, and snow on cold summits (variant >= 1).
static func add_peak(batch: RegionMapLayer.TriangleBatch, base_center: Vector2, size: float, variant: float, rock_light: Color, rock_dark: Color) -> void:
	var snowy: bool = variant >= 1.0
	var lean: float = (fmod(variant, 1.0) - 0.25) * 3.0
	var half_width: float = 7.4 * size
	var height: float = 8.4 * size + fmod(variant, 1.0) * 3.0
	var left: Vector2 = base_center + Vector2(-half_width, 0.0)
	var right: Vector2 = base_center + Vector2(half_width, 0.0)
	var apex: Vector2 = base_center + Vector2(lean, -height)
	var foot: Vector2 = base_center + Vector2(lean * 0.3 + half_width * 0.12, 1.2)
	batch.add_polygon(PackedVector2Array([apex + Vector2(height * 0.4, height * 0.5), right + Vector2(half_width * 0.5, 1.5), foot + Vector2(1.0, 1.6)]), RegionMapStyle.COLOR_SHADOW)
	var tint: float = (fmod(variant * 7.0, 1.0) - 0.5) * 0.16
	batch.add_polygon(PackedVector2Array([left, apex, foot]), rock_light.lightened(tint) if tint > 0.0 else rock_light.darkened(-tint))
	batch.add_polygon(PackedVector2Array([apex, right, foot]), rock_dark.lightened(tint) if tint > 0.0 else rock_dark.darkened(-tint))
	if snowy:
		var cap: float = 0.42
		var notch: Vector2 = apex.lerp(foot, cap * 1.15) + Vector2(0.0, -0.6)
		batch.add_polygon(PackedVector2Array([apex.lerp(left, cap), apex, notch, apex.lerp(left, cap * 0.7).lerp(notch, 0.5)]), RegionMapStyle.COLOR_SNOW)
		batch.add_polygon(PackedVector2Array([apex, apex.lerp(right, cap), apex.lerp(right, cap * 0.65).lerp(notch, 0.5), notch]), RegionMapStyle.COLOR_SNOW_SHADE)

static func add_boulder(batch: RegionMapLayer.TriangleBatch, center: Vector2, r: float, variant: float, is_iron: bool) -> void:
	var outline: PackedVector2Array = PackedVector2Array()
	for i in range(7):
		var angle: float = TAU * i / 7.0 + variant * 2.0
		outline.append(center + Vector2(cos(angle), sin(angle) * 0.8) * r * (0.8 + 0.35 * hash01(i, int(variant * 1000.0), 7)))
	var body: Color = RegionMapStyle.COLOR_IRON_DARK if is_iron else RegionMapStyle.COLOR_STONE
	var top: Color = RegionMapStyle.COLOR_IRON_RUST if is_iron else RegionMapStyle.COLOR_STONE_LIGHT
	batch.add_blob(center + Vector2(r * 0.4, r * 0.5), Vector2(r * 1.05, r * 0.7), RegionMapStyle.COLOR_SHADOW, 8)
	batch.add_fan(center, outline, body)
	batch.add_blob(center + Vector2(-r * 0.25, -r * 0.25), Vector2(r * 0.5, r * 0.4), top, 6)
