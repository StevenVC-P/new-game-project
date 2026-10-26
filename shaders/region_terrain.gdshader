shader_type canvas_item;

// Ground of the regional map, painted as a model landscape: lit relief, meadows, fertile
// land, rock and snow, outcrops of stone and ore, and glossy water with banks and beaches.
// Every input is a small per-tile data texture built from the region's tiles, so camera
// moves only change uniforms and changed tiles only mean re-uploading textures.
//
// Feature edges follow the tile data: masks are smoothly interpolated so a boundary between
// tiles still lies on the tile edge, and the small domain warp that rounds them stays well
// inside a tile. What the player sees as farmland, forest floor, rock, or water is what the
// game counts as such.

#include "res://shaders/natural_palette.gdshaderinc"

// R hill, G mountain, B open water, A fertile.
uniform sampler2D masks_a : filter_linear;
// R forest, G stone deposit, B iron deposit, A sea.
uniform sampler2D masks_b : filter_linear;
// R temperature, G moisture (from the world), B water depth (distance from shore), A lake.
uniform sampler2D masks_c : filter_linear;
// R smoothed ground height (hills and mountains, blurred), G open water, B, A unused.
uniform sampler2D masks_d : filter_linear;
uniform vec2 map_tiles = vec2(80.0, 50.0);
uniform float tile_units = 12.0;
uniform float zoom = 1.5;
// Ground under the drawn trees; matches the climate's tree style (RegionMapStyle.tree_style).
uniform vec3 forest_floor = vec3(0.18, 0.29, 0.16);

// Continuous map (one quad per chunk of the planet; see RegionalTerrain). With planet_tiles
// at 0 the quad is a whole bounded region on its board, drawn exactly as before.
uniform float planet_tiles = 0.0;
// Global tile of the quad's origin; noise is anchored to the planet, so chunks join.
uniform vec2 tile_origin = vec2(0.0);
// Tiles of margin the masks hold around the quad.
uniform float mask_offset = 0.0;
// How strongly the forest floor shows a canopy texture: 1 when individual trees are not drawn.
uniform float canopy_strength = 0.0;
// Political borders, voted on exactly like the world atlas (shaders/world_terrain.gdshader).
uniform sampler2D political_tex : filter_nearest, repeat_enable;
uniform sampler2D kingdom_palette : filter_nearest;
uniform vec2 political_size = vec2(512.0, 256.0);
// World units per tile.
uniform float tile_world = 1.2;
uniform float show_borders = 0.0;

// How far the warp may move a feature edge, in tiles.
const float EDGE_WARP = 0.22;
// Steepness of the lit relief.
const float RELIEF = 1.15;

varying vec2 map_pos;

void vertex() {
	map_pos = VERTEX;
}

// Cubic B-spline filtering from four bilinear taps (p in tiles). Smooth enough that lit
// relief shows no tile grid; a straight boundary between two tiles still crosses 0.5 on
// the tile edge, and a lone tile still peaks at about 0.44.
vec4 smooth_mask(sampler2D tex, vec2 p) {
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
	vec2 h0 = (i - 1.0 + w1 / g0 + 0.5) / map_tiles;
	vec2 h1 = (i + 1.0 + w3 / g1 + 0.5) / map_tiles;
	return g0.y * (g0.x * texture(tex, h0) + g1.x * texture(tex, vec2(h1.x, h0.y)))
		+ g1.y * (g0.x * texture(tex, vec2(h0.x, h1.y)) + g1.x * texture(tex, h1));
}

// The masks at a global tile position (the masks start mask_offset tiles before the quad).
vec4 mask_at(sampler2D tex, vec2 global_p) {
	return smooth_mask(tex, global_p - tile_origin + mask_offset);
}

// Fractal noise in tile units. Octaves smaller than a few screen pixels fade to their mean,
// so the zoomed-out board stays calm instead of shimmering. On the continuous map each
// octave's wavelength is nudged so a whole number of cells fits around the planet: the
// noise then repeats exactly at the date line.
float fbm(vec2 p, float wavelength, int octaves) {
	float sum = 0.0;
	float amplitude = 0.5;
	float norm = 0.0;
	for (int o = 0; o < octaves; o++) {
		float fade = smoothstep(1.5, 4.0, wavelength * tile_units * zoom);
		float value;
		if (planet_tiles > 0.0) {
			float period = max(1.0, round(planet_tiles / wavelength));
			value = vnoise(vec2(p.x * period / planet_tiles, p.y / wavelength), period);
		} else {
			value = vnoise(p / wavelength, 1.0e6);
		}
		sum += amplitude * mix(0.5, value, fade);
		norm += amplitude;
		amplitude *= 0.5;
		wavelength *= 0.5;
	}
	return sum / norm;
}

// Large-scale ground height from the data: blurred hills and mountains, banks sloping into
// water. Sampled at three points for the lit slope; fine detail adds its slope separately.
float base_height(vec2 p) {
	vec4 d = mask_at(masks_d, p);
	return d.r - smoothstep(0.3, 0.7, d.g) * 0.22;
}

vec4 bspline_weights(float f) {
	float f2 = f * f;
	float f3 = f2 * f;
	return vec4(
		(1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0,
		(4.0 - 6.0 * f2 + 3.0 * f3) / 6.0,
		(1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0,
		f3 / 6.0);
}

// Kingdom and region borders by the world atlas's smooth vote over political cells, so a
// border lies on exactly the same curve on both maps. Returns the color to lay over land.
vec3 political_overlay(vec3 col, vec2 p, float land) {
	// The planet is twice as wide as it is tall.
	vec2 uv = p / vec2(planet_tiles, planet_tiles * 0.5);
	vec2 pc = uv * political_size - 0.5;
	vec2 base_cell = floor(pc);
	vec2 cell_f = pc - base_cell;
	vec4 wx = bspline_weights(cell_f.x);
	vec4 wy = bspline_weights(cell_f.y);
	float wxa[4] = float[](wx.x, wx.y, wx.z, wx.w);
	float wya[4] = float[](wy.x, wy.y, wy.z, wy.w);
	int k_ids[16];
	float k_w[16];
	int k_n = 0;
	int r_ids[16];
	float r_w[16];
	int r_n = 0;
	float contested = 0.0;
	for (int j = 0; j < 4; j++) {
		int cy = clamp(int(base_cell.y) - 1 + j, 0, int(political_size.y) - 1);
		for (int i = 0; i < 4; i++) {
			int cx = int(mod(base_cell.x - 1.0 + float(i), political_size.x));
			vec4 s = texelFetch(political_tex, ivec2(cx, cy), 0);
			float w = wxa[i] * wya[j];
			int kid = int(s.r * 255.0 + 0.5);
			int rid = int(s.g * 255.0 + 0.5);
			contested += s.b * w;
			int k_slot = -1;
			for (int q = 0; q < 16; q++) {
				if (q >= k_n) { break; }
				if (k_ids[q] == kid) { k_slot = q; break; }
			}
			if (k_slot < 0) { k_slot = k_n; k_ids[k_slot] = kid; k_w[k_slot] = 0.0; k_n++; }
			k_w[k_slot] += w;
			int r_slot = -1;
			for (int q = 0; q < 16; q++) {
				if (q >= r_n) { break; }
				if (r_ids[q] == rid) { r_slot = q; break; }
			}
			if (r_slot < 0) { r_slot = r_n; r_ids[r_slot] = rid; r_w[r_slot] = 0.0; r_n++; }
			r_w[r_slot] += w;
		}
	}
	int best_k = 0;
	int second_k = 0;
	float best_kw = -1.0;
	float second_kw = 0.0;
	for (int q = 0; q < 16; q++) {
		if (q >= k_n) { break; }
		if (k_w[q] > best_kw) {
			second_kw = max(best_kw, 0.0);
			second_k = best_k;
			best_kw = k_w[q];
			best_k = k_ids[q];
		} else if (k_w[q] > second_kw) {
			second_kw = k_w[q];
			second_k = k_ids[q];
		}
	}
	float best_rw = -1.0;
	float second_rw = 0.0;
	for (int q = 0; q < 16; q++) {
		if (q >= r_n) { break; }
		if (r_w[q] > best_rw) {
			second_rw = max(best_rw, 0.0);
			best_rw = r_w[q];
		} else if (r_w[q] > second_rw) {
			second_rw = r_w[q];
		}
	}
	// Distance to the nearest border in screen pixels, from how evenly the vote is split.
	float k_margin = best_kw - second_kw;
	float k_px = k_margin / max(fwidth(k_margin), 1e-5);
	float r_margin = best_rw - second_rw;
	float r_px = r_margin / max(fwidth(r_margin), 1e-5);
	float political = land * show_borders;
	if (best_k > 0) {
		vec3 kingdom_col = texelFetch(kingdom_palette, ivec2(best_k - 1, 0), 0).rgb;
		float ribbon = (1.0 - smoothstep(0.0, 18.0, k_px)) * step(0.0001, second_kw);
		col = mix(col, kingdom_col, ribbon * 0.38 * political);
	}
	float k_line = (1.0 - smoothstep(1.2, 2.4, k_px)) * step(0.0001, second_kw);
	vec3 line_col = vec3(0.22, 0.16, 0.13);
	if (best_k > 0 && second_k == 0) {
		line_col = texelFetch(kingdom_palette, ivec2(best_k - 1, 0), 0).rgb * 0.55;
	} else if (best_k == 0 && second_k > 0) {
		line_col = texelFetch(kingdom_palette, ivec2(second_k - 1, 0), 0).rgb * 0.55;
	}
	col = mix(col, line_col, k_line * 0.85 * political);
	// Region boundaries: a faint dashed line.
	float dash = step(0.5, fract((p.x + p.y) * 0.5));
	float r_line = (1.0 - smoothstep(0.6, 1.4, r_px)) * step(0.0001, second_rw) * (1.0 - k_line);
	col = mix(col, vec3(0.24, 0.21, 0.17), r_line * (0.35 + 0.2 * dash) * political);
	// Contested ground: diagonal hatching anchored to the land, spaced in screen pixels.
	float hatch_px = abs(fract((p.x + p.y) * tile_units * zoom / 10.0) - 0.5) * 10.0;
	float hatch = (1.0 - smoothstep(0.55, 1.35, hatch_px)) * smoothstep(0.35, 0.65, contested);
	col = mix(col, vec3(0.48, 0.17, 0.12), hatch * 0.18 * political);
	return col;
}

void fragment() {
	vec2 p = map_pos / tile_units + tile_origin;
	float pixel = 1.0 / (tile_units * zoom);
	vec2 warp = (vec2(fbm(p + vec2(3.1, 9.2), 1.6, 2), fbm(p + vec2(17.3, 1.7), 1.6, 2)) - 0.5) * 2.0 * EDGE_WARP;
	vec2 q = p + warp;

	vec4 a = mask_at(masks_a, q);
	vec4 b = mask_at(masks_b, q);
	vec4 c = mask_at(masks_c, p);
	float edge = max(pixel * 1.2, 0.02);
	float water = smoothstep(0.5 - edge, 0.5 + edge, a.b);
	float sea = smoothstep(0.35, 0.65, b.a);
	float lake = smoothstep(0.35, 0.65, c.a);
	float still_water = max(sea, lake);

	// --- Light ---
	// Rolling ground everywhere, stronger on hills; crests and gullies on mountains. Its slope
	// comes from screen-space derivatives, so the noise is evaluated once per pixel.
	float detail = (fbm(p + vec2(13.0, 7.0), 4.5, 3) - 0.5) * (0.12 + a.r * 0.34);
	if (a.g > 0.01) {
		float ridge = 1.0 - abs(2.0 * fbm(p + vec2(41.0, 3.0), 3.0, 3) - 1.0);
		detail += ridge * ridge * a.g * 0.4;
	}
	float step_size = 0.15;
	float h = base_height(p);
	vec2 gradient = vec2(base_height(p + vec2(step_size, 0.0)) - h, base_height(p + vec2(0.0, step_size)) - h) / step_size;
	gradient += vec2(dFdx(detail), dFdy(detail)) * tile_units * zoom;
	vec3 normal = normalize(vec3(-gradient * RELIEF, 1.0));
	vec3 light = normalize(vec3(-0.55, -0.68, 0.72));
	float shade = clamp(dot(normal, light) / light.z, 0.35, 1.45);
	float slope = length(gradient);

	// --- Open ground ---
	float t = c.r;
	float m = c.g;
	float tone = fbm(p + vec2(71.0, 23.0), 9.0, 3);
	float fine = fbm(p * 1.0 + vec2(5.0, 91.0), 0.35, 3);
	vec3 meadow = biome_color(t, m + (tone - 0.5) * 0.16);
	meadow *= 0.96 + 0.08 * fine;

	// Fertile land: deeper, lusher green with darker soil showing through.
	// Thresholds below 0.5 keep lone tiles visible: smoothing lowers a single tile's peak.
	vec3 land = meadow;
	if (a.a > 0.01) {
		float fertile = smoothstep(0.34, 0.5, a.a + (fbm(p + vec2(2.0, 55.0), 1.2, 2) - 0.5) * 0.2);
		vec3 lush = biome_color(t, max(m, 0.45) + 0.32) * vec3(0.80, 0.94, 0.70);
		lush *= 0.92 + 0.14 * fbm(p + vec2(33.0, 8.0), 0.25, 2);
		land = mix(meadow, lush, fertile * 0.85);
	}

	// Hills: drier, olive grass that catches the light.
	float hill = smoothstep(0.25, 0.75, a.r);
	land = mix(land, biome_color(t - 0.03, m - 0.18) * vec3(1.0, 0.97, 0.88), hill * 0.45);

	// Forest floor under the drawn trees.
	float forest = smoothstep(0.34, 0.5, b.r);
	land = mix(land, forest_floor, forest * 0.88);
	if (canopy_strength > 0.0 && forest > 0.0) {
		// From afar, where single trees are not drawn, woods read as clumped canopy.
		float crowns = fbm(p + vec2(207.0, 61.0), 1.2, 3);
		vec3 canopy = forest_floor * 1.35 * (0.78 + 0.5 * crowns);
		land = mix(land, canopy, forest * canopy_strength * 0.85);
	}

	// Mountains: banded rock and scree, snow on the cold crests.
	float mountain = smoothstep(0.3, 0.7, a.g);
	float rocky = clamp(mountain + smoothstep(0.9, 2.0, slope) * 0.5, 0.0, 1.0);
	if (rocky > 0.0) {
		float strata = sin((p.y * 5.0 + fbm(p + vec2(9.0, 4.0), 2.0, 3) * 9.0)) * 0.5 + 0.5;
		vec3 rock = mix(vec3(0.50, 0.46, 0.41), vec3(0.62, 0.58, 0.51), strata) * (0.9 + 0.2 * fine);
		land = mix(land, rock, rocky * 0.92);
	}
	float peak_cold = t - mountain * 0.16;
	if (mountain > 0.0 && peak_cold < 0.3) {
		// Snow lies between the drawn peaks only on the coldest ground, in soft drifts.
		float drifts = smoothstep(0.4, 0.7, fbm(p + vec2(61.0, 5.0), 4.0, 2));
		float snow = smoothstep(0.30, 0.20, peak_cold) * mountain * mountain * drifts * (1.0 - 0.6 * smoothstep(1.4, 2.6, slope));
		land = mix(land, vec3(0.90, 0.92, 0.94), snow * 0.7);
	}

	// Stone deposits: pale outcrops with cracks. Iron: rust-stained ground and dark rock.
	if (b.g > 0.01) {
		float stone = smoothstep(0.34, 0.5, b.g);
		float outcrop = smoothstep(0.45, 0.65, fbm(p + vec2(77.0, 12.0), 0.7, 3));
		float cracks = 1.0 - smoothstep(0.0, 0.05, abs(fbm(p + vec2(4.0, 44.0), 0.5, 2) - 0.5));
		vec3 gravel = mix(land, vec3(0.60, 0.58, 0.52), 0.55);
		vec3 stone_col = mix(gravel, vec3(0.70, 0.68, 0.62), outcrop) * (1.0 - cracks * 0.2 * outcrop);
		land = mix(land, stone_col, stone * 0.85);
	}
	if (b.b > 0.01) {
		float iron = smoothstep(0.34, 0.5, b.b);
		float stain = fbm(p + vec2(19.0, 63.0), 0.9, 3);
		vec3 iron_col = mix(vec3(0.56, 0.38, 0.26), vec3(0.32, 0.27, 0.24), smoothstep(0.5, 0.65, stain));
		land = mix(land, iron_col, iron * (0.5 + 0.3 * stain));
	}

	// Shore: sand along the sea, wet earth and reeds along rivers and lakes.
	float shore = smoothstep(0.24, 0.5, a.b) * (1.0 - water);
	vec3 bank = mix(vec3(0.47, 0.44, 0.30), vec3(0.42, 0.50, 0.30), fine);
	vec3 sand = vec3(0.86, 0.80, 0.62) * (0.95 + 0.08 * fine);
	land = mix(land, mix(bank, sand, sea), shore * (0.55 + 0.35 * sea) * (1.0 - mountain));

	land *= 0.94 + 0.1 * tone;
	land *= shade;

	// --- Water ---
	float depth = clamp(c.b, 0.0, 1.0);
	vec3 river_col = mix(vec3(0.36, 0.60, 0.64), vec3(0.24, 0.47, 0.58), smoothstep(0.5, 0.95, a.b));
	vec3 lake_col = mix(vec3(0.34, 0.58, 0.64), vec3(0.16, 0.36, 0.50), smoothstep(0.0, 0.6, depth));
	vec3 sea_col = mix(vec3(0.42, 0.66, 0.68), vec3(0.24, 0.46, 0.60), smoothstep(0.0, 0.35, depth));
	sea_col = mix(sea_col, vec3(0.11, 0.25, 0.42), smoothstep(0.35, 1.0, depth));
	vec3 water_col = mix(river_col, lake_col, lake);
	water_col = mix(water_col, sea_col, sea);
	// Glossy resin surface: soft streaks of reflected sky, and the banks' shade near the edge.
	if (a.b > 0.3) {
		float gloss = smoothstep(0.58, 0.78, fbm(vec2(p.x * 0.6, p.y * 2.2) + vec2(8.0, 2.0), 1.4, 3));
		water_col += vec3(0.08, 0.09, 0.09) * gloss;
	}
	water_col *= mix(1.0, clamp(shade, 0.7, 1.15), 0.6);
	float rim = 1.0 - smoothstep(0.5, 0.62, a.b);
	water_col = mix(water_col, water_col * 0.78, rim * 0.6);

	vec3 col = mix(land, water_col, water);
	// A thin pale line where water meets land, like the edge of poured resin.
	float waterline = 1.0 - smoothstep(0.0, edge * 2.5, abs(a.b - 0.5));
	col = mix(col, vec3(0.86, 0.92, 0.90), waterline * 0.35 * (0.4 + 0.6 * still_water));

	if (planet_tiles > 0.0) {
		col = political_overlay(col, p, 1.0 - still_water);
	} else {
		// The board's edge darkens slightly, like the rim of a model base.
		float border = min(min(p.x, p.y), min(map_tiles.x - p.x, map_tiles.y - p.y));
		col *= mix(0.8, 1.0, smoothstep(0.0, 0.7, border));
	}

	COLOR = vec4(col, 1.0);
}
