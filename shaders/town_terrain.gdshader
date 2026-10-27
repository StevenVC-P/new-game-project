shader_type canvas_item;

// Ground of the town map: the regional landscape magnified (shaders/region_terrain.gdshader
// paints the same land four times smaller). Meadow and farmland in the site's climate colors,
// forest floor under the drawn trees, rock and scree, stone and ore outcrops, trails and paths
// worn by the townsfolk, rutted tracks, and water with banks and beaches. Inputs are small per-tile data textures, so camera moves
// only change uniforms.
//
// Feature edges follow the tile data: masks are smoothly interpolated, so a boundary between
// tiles lies on the tile edge, and the warp that rounds it stays well inside a tile. What the
// player sees as farmland, woods, rock, road, or water is what the town map holds.

#include "res://shaders/natural_palette.gdshaderinc"

// R rough ground, G water, B fertile, A trees.
uniform sampler2D masks_a : filter_linear;
// R stone deposit, G iron deposit, B road, A sea.
uniform sampler2D masks_b : filter_linear;
// R lake, G water depth (distance from shore), B ground height (water low, rock high, blurred), A unused.
uniform sampler2D masks_c : filter_linear;
// R trodden ground (0 none, 0.5 trail, 1 path) per route cell: tile middles, the lines between
// tiles, and corners, at half-tile spacing (TownLogistics), so (2W+1) x (2H+1) texels.
uniform sampler2D path_mask : filter_linear;
uniform vec2 map_tiles = vec2(64.0, 44.0);
uniform vec2 path_cells = vec2(129.0, 89.0);
uniform float tile_units = 12.0;
uniform float zoom = 1.5;
// The site's climate (LocalCityMapGenerator / RegionalTerrain.climate_at).
uniform float site_temperature = 0.55;
uniform float site_moisture = 0.6;
// Ground under the drawn trees; matches the climate's tree style (RegionMapStyle.forest_floor_color).
uniform vec3 forest_floor = vec3(0.18, 0.29, 0.16);
// Shifts the noise per site, so neighbouring towns do not share their ground texture.
uniform vec2 noise_offset = vec2(0.0);

const float EDGE_WARP = 0.2;
const float RELIEF = 1.0;

varying vec2 map_pos;

void vertex() {
	map_pos = VERTEX;
}

// Cubic B-spline filtering from four bilinear taps (p in tiles), as on the regional map.
vec4 smooth_mask_sized(sampler2D tex, vec2 p, vec2 size) {
	vec2 st = p - 0.5;
	vec2 i = floor(st);
	vec2 f = st - i;
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (1.0 / 6.0) * (-f3 + 3.0 * f2 - 3.0 * f + 1.0);
	vec2 w1 = (1.0 / 6.0) * (3.0 * f3 - 6.0 * f2 + 4.0);
	vec2 w2 = (1.0 / 6.0) * (-3.0 * f3 + 3.0 * f2 + 3.0 * f + 1.0);
	vec2 w3 = (1.0 / 6.0) * f3;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 1.0 + w1 / g0 + 0.5) / size;
	vec2 h1 = (i + 1.0 + w3 / g1 + 0.5) / size;
	return g0.y * (g0.x * texture(tex, h0) + g1.x * texture(tex, vec2(h1.x, h0.y)))
		+ g1.y * (g0.x * texture(tex, vec2(h0.x, h1.y)) + g1.x * texture(tex, h1));
}

vec4 smooth_mask(sampler2D tex, vec2 p) {
	return smooth_mask_sized(tex, p, map_tiles);
}

// Fractal noise in tile units; octaves smaller than a few screen pixels fade to their mean so
// the fitted view stays calm instead of shimmering.
float fbm(vec2 p, float wavelength, int octaves) {
	float sum = 0.0;
	float amplitude = 0.5;
	float norm = 0.0;
	for (int o = 0; o < octaves; o++) {
		float fade = smoothstep(1.5, 4.0, wavelength * tile_units * zoom);
		sum += amplitude * mix(0.5, vnoise((p + noise_offset) / wavelength, 1.0e6), fade);
		norm += amplitude;
		amplitude *= 0.5;
		wavelength *= 0.5;
	}
	return sum / norm;
}

// Large-scale ground height, baked per tile (TownGroundLayer); sampled at three points for the
// lit slope, so it reads one texture.
float base_height(vec2 p) {
	return smooth_mask(masks_c, p).b;
}

void fragment() {
	vec2 p = map_pos / tile_units;
	float pixel = 1.0 / (tile_units * zoom);
	vec2 warp = (vec2(fbm(p + vec2(3.1, 9.2), 1.4, 2), fbm(p + vec2(17.3, 1.7), 1.4, 2)) - 0.5) * 2.0 * EDGE_WARP;
	vec2 q = p + warp;

	vec4 a = smooth_mask(masks_a, q);
	vec4 b = smooth_mask(masks_b, q);
	vec4 c = smooth_mask(masks_c, p);
	float edge = max(pixel * 1.2, 0.02);
	float water = smoothstep(0.5 - edge, 0.5 + edge, a.g);
	float sea = smoothstep(0.35, 0.65, b.a);
	float lake = smoothstep(0.35, 0.65, c.r);
	float still_water = max(sea, lake);

	// --- Light: gentle rolling ground, rock standing proud, banks sloping into water ---
	float detail = (fbm(p + vec2(13.0, 7.0), 6.0, 3) - 0.5) * 0.10;
	detail += (fbm(p + vec2(41.0, 3.0), 1.2, 3) - 0.5) * a.r * 0.35;
	float step_size = 0.2;
	float h = base_height(p);
	vec2 gradient = vec2(base_height(p + vec2(step_size, 0.0)) - h, base_height(p + vec2(0.0, step_size)) - h) / step_size;
	gradient += vec2(dFdx(detail), dFdy(detail)) * tile_units * zoom;
	vec3 normal = normalize(vec3(-gradient * RELIEF, 1.0));
	vec3 light = normalize(vec3(-0.55, -0.68, 0.72));
	float shade = clamp(dot(normal, light) / light.z, 0.45, 1.35);

	// --- Open ground: meadow in the site's climate colors ---
	float tone = fbm(p + vec2(71.0, 23.0), 14.0, 3);
	float fine = fbm(p + vec2(5.0, 91.0), 0.5, 3);
	float blades = fbm(p + vec2(31.0, 17.0), 0.12, 2);
	vec3 meadow = biome_color(site_temperature, site_moisture + (tone - 0.5) * 0.18);
	meadow *= 0.95 + 0.08 * fine + 0.05 * blades;

	// Farmland: lusher ground with darker loam showing through in soft patches.
	vec3 land = meadow;
	float fertile = smoothstep(0.34, 0.5, a.b + (fbm(p + vec2(2.0, 55.0), 2.0, 2) - 0.5) * 0.2);
	if (fertile > 0.0) {
		vec3 lush = biome_color(site_temperature, max(site_moisture, 0.45) + 0.3) * vec3(0.84, 0.95, 0.74);
		float loam = smoothstep(0.55, 0.75, fbm(p + vec2(33.0, 8.0), 1.6, 3));
		lush = mix(lush, vec3(0.42, 0.34, 0.22), loam * 0.35);
		land = mix(meadow, lush * (0.94 + 0.1 * fine), fertile * 0.8);
	}

	// Forest floor under the drawn trees: leaf litter and moss.
	float forest = smoothstep(0.34, 0.5, a.a);
	vec3 floor_col = forest_floor * (0.9 + 0.25 * fbm(p + vec2(207.0, 61.0), 0.7, 3));
	land = mix(land, floor_col, forest * 0.9);

	// Rock: scree and ledges, lit by the relief.
	float rock = smoothstep(0.34, 0.5, a.r);
	if (rock > 0.0) {
		float strata = sin(p.y * 2.2 + fbm(p + vec2(9.0, 4.0), 3.0, 2) * 5.0) * 0.5 + 0.5;
		float scree = smoothstep(0.55, 0.7, fbm(p + vec2(29.0, 71.0), 0.4, 2));
		vec3 rock_col = mix(vec3(0.53, 0.52, 0.49), vec3(0.64, 0.62, 0.58), strata * 0.6 + scree * 0.4) * (0.9 + 0.18 * fine);
		land = mix(land, rock_col, rock * 0.9);
	}
	// Stone deposits: pale outcrops with cracks. Ore: rust-stained ground and dark rock.
	if (b.r > 0.01) {
		float stone = smoothstep(0.34, 0.5, b.r);
		float outcrop = smoothstep(0.42, 0.62, fbm(p + vec2(77.0, 12.0), 1.0, 3));
		float cracks = 1.0 - smoothstep(0.0, 0.04, abs(fbm(p + vec2(4.0, 44.0), 0.8, 2) - 0.5));
		vec3 stone_col = mix(vec3(0.62, 0.60, 0.54), vec3(0.74, 0.72, 0.66), outcrop) * (1.0 - cracks * 0.22 * outcrop);
		land = mix(land, stone_col, stone * 0.92);
	}
	if (b.g > 0.01) {
		float iron = smoothstep(0.34, 0.5, b.g);
		float stain = fbm(p + vec2(19.0, 63.0), 1.2, 3);
		vec3 iron_col = mix(vec3(0.58, 0.38, 0.25), vec3(0.32, 0.27, 0.24), smoothstep(0.5, 0.65, stain));
		land = mix(land, iron_col, iron * 0.85);
	}

	// Trodden ground (TownLogistics): a trail is a thin line of flattened, paler grass; a path is
	// bare packed earth up to about a tile wide with a trampled verge. Route cells are half a tile
	// apart, so the mask is sampled at twice the tile resolution (cell k sits at k / 2 tiles). A
	// path cell is 1.0 and a trail 0.5, so a trail never reaches the bare-earth band.
	float trodden = smooth_mask_sized(path_mask, q * 2.0 + 0.5, path_cells).r;
	if (trodden > 0.02) {
		float flattened = smoothstep(0.15, 0.24, trodden);
		float bare = smoothstep(0.3, 0.42, trodden + (fbm(p + vec2(57.0, 29.0), 0.5, 2) - 0.5) * 0.1);
		vec3 trampled = land * vec3(1.06, 1.03, 0.84) + vec3(0.04, 0.03, 0.0);
		land = mix(land, trampled, flattened * 0.55);
		vec3 earth = vec3(0.57, 0.48, 0.34) * (0.9 + 0.16 * fine);
		land = mix(land, earth, bare * 0.85);
	}

	// Tracks: packed earth with wheel ruts along their length.
	float road = smoothstep(0.38, 0.55, b.b);
	if (road > 0.0) {
		vec3 track = vec3(0.66, 0.56, 0.39) * (0.92 + 0.14 * fine);
		float ruts = smoothstep(0.62, 0.72, b.b) * (1.0 - smoothstep(0.0, 0.08, abs(fbm(p + vec2(3.0, 3.0), 0.9, 1) - 0.5)));
		track *= 1.0 - ruts * 0.15;
		land = mix(land, track, road * 0.9);
	}

	// Shore: sand along the sea, wet earth and reeds along rivers and lakes.
	float shore = smoothstep(0.2, 0.5, a.g) * (1.0 - water);
	vec3 bank = mix(vec3(0.46, 0.43, 0.30), vec3(0.40, 0.49, 0.29), fine);
	vec3 sand = vec3(0.86, 0.80, 0.62) * (0.95 + 0.08 * fine);
	land = mix(land, mix(bank, sand, sea), shore * (0.6 + 0.3 * sea) * (1.0 - rock));

	land *= 0.95 + 0.08 * tone;
	land *= shade;

	// --- Water ---
	float depth = clamp(c.g, 0.0, 1.0);
	vec3 river_col = mix(vec3(0.38, 0.62, 0.65), vec3(0.24, 0.47, 0.58), smoothstep(0.0, 0.5, depth));
	vec3 lake_col = mix(vec3(0.34, 0.58, 0.64), vec3(0.16, 0.36, 0.50), smoothstep(0.0, 0.7, depth));
	vec3 sea_col = mix(vec3(0.42, 0.66, 0.68), vec3(0.24, 0.46, 0.60), smoothstep(0.0, 0.4, depth));
	sea_col = mix(sea_col, vec3(0.11, 0.25, 0.42), smoothstep(0.4, 1.0, depth));
	vec3 water_col = mix(river_col, lake_col, lake);
	water_col = mix(water_col, sea_col, sea);
	// Glossy resin surface: soft streaks of reflected sky; a current along rivers.
	float gloss = smoothstep(0.58, 0.78, fbm(vec2(p.x * 0.5, p.y * 1.6) + vec2(8.0, 2.0), 2.0, 3));
	water_col += vec3(0.08, 0.09, 0.09) * gloss;
	float ripples = fbm(p * vec2(1.0, 2.4) + vec2(50.0, 9.0), 0.35, 2);
	water_col *= 0.97 + 0.06 * ripples;
	float rim = 1.0 - smoothstep(0.5, 0.65, a.g);
	water_col = mix(water_col, water_col * 0.78, rim * 0.6);

	vec3 col = mix(land, water_col, water);
	// A thin pale line where water meets land, with surf along the sea.
	float waterline = 1.0 - smoothstep(0.0, edge * 2.5, abs(a.g - 0.5));
	col = mix(col, vec3(0.88, 0.93, 0.91), waterline * (0.3 + 0.35 * sea));
	float surf = (1.0 - smoothstep(0.5, 0.62, a.g)) * water * sea * smoothstep(0.45, 0.7, fbm(p + vec2(91.0, 7.0), 0.6, 2));
	col = mix(col, vec3(0.92, 0.95, 0.94), surf * 0.5);

	// The board's edge darkens slightly, like the rim of a model base.
	float border = min(min(p.x, p.y), min(map_tiles.x - p.x, map_tiles.y - p.y));
	col *= mix(0.82, 1.0, smoothstep(0.0, 1.2, border));

	COLOR = vec4(col, 1.0);
}
