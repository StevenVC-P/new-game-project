shader_type canvas_item;

// Painterly physical-atlas terrain with a political border overlay for the world map.
// Every input is a small data texture built from WorldMapData, so moving the camera
// never rebuilds geometry and changed world data only means re-uploading a texture.
// Detail noise is a fixed function of world position (no randomness) and tiles
// horizontally with the planet so the wrap seam is invisible.

// R elevation (sea level 0), G moisture, B forest, A mountain relief.
uniform sampler2D terrain_tex : filter_linear, repeat_enable;
// R cultivated land around settlements.
uniform sampler2D development_tex : filter_linear, repeat_enable;
// R kingdom id + 1, G region id + 1, B contested flag. Spread into the sea so borders end at coasts.
uniform sampler2D political_tex : filter_nearest, repeat_enable;
uniform sampler2D kingdom_palette : filter_nearest;
uniform vec2 world_size = vec2(7200.0, 3600.0);
uniform vec2 terrain_size = vec2(1024.0, 512.0);
uniform vec2 political_size = vec2(512.0, 256.0);
uniform float zoom = 1.0;
uniform float show_borders = 1.0;
uniform int hovered_region = -1;
uniform int selected_region = -1;

#include "res://shaders/natural_palette.gdshaderinc"

// Largest elevation change detail noise may make at the shoreline.
const float COAST_CRINKLE = 0.012;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

// Fractal noise in world units. Octaves smaller than a few screen pixels fade to their
// mean, so distant views stay calm instead of shimmering. Base wavelengths must divide
// the world width (7200) through every halving so the noise tiles across the seam.
float fbm(vec2 p, float base_wavelength, int octaves) {
	float sum = 0.0;
	float amplitude = 0.5;
	float norm = 0.0;
	float wavelength = base_wavelength;
	for (int o = 0; o < octaves; o++) {
		float fade = smoothstep(1.5, 4.0, wavelength * zoom);
		float value = vnoise(p / wavelength, world_size.x / wavelength);
		sum += amplitude * mix(0.5, value, fade);
		norm += amplitude;
		amplitude *= 0.5;
		wavelength *= 0.5;
	}
	return sum / norm;
}

// Cubic B-spline filtering from four bilinear taps: smooth elevation without texel facets.
vec4 sample_smooth(sampler2D tex, vec2 uv, vec2 size) {
	vec2 st = uv * size - 0.5;
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

vec4 bspline_weights(float f) {
	float f2 = f * f;
	float f3 = f2 * f;
	return vec4(
		(1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0,
		(4.0 - 6.0 * f2 + 3.0 * f3) / 6.0,
		(1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0,
		f3 / 6.0);
}

void fragment() {
	vec2 wp = world_pos;
	vec2 uv = wp / world_size;
	float latitude = 90.0 - clamp(uv.y, 0.0, 1.0) * 180.0;
	float texel = world_size.x / terrain_size.x;

	vec4 terrain = sample_smooth(terrain_tex, uv, terrain_size);
	float relief = clamp(terrain.a, 0.0, 1.0);

	// Detail on top of the authored fields: coast crinkle, ridged mountain texture, rolling ground.
	float coast_noise = fbm(wp, 80.0, 5) - 0.5;
	// Ridged noise folds the authored range profiles into crests and valleys.
	float ridge_noise = 1.0 - abs(2.0 * fbm(wp + vec2(911.0, 377.0), 60.0, 6) - 1.0);
	float ridges = ridge_noise * ridge_noise;
	float rolling = fbm(wp + vec2(141.0, 59.0), 22.5, 4) - 0.5;
	// The drawn coast must stay within a fraction of a texel of the data coast: clicks,
	// region lookups, and river mouths all use the data. So the crinkle is small, and
	// detail may raise land but never sink it more than the crinkle allows.
	float inland = smoothstep(0.0, 0.08, terrain.r);
	float detail = coast_noise * COAST_CRINKLE;
	detail += inland * (relief * (ridges - 0.35) * 0.45 + rolling * 0.02 * (1.0 + 2.0 * relief));
	float e = terrain.r + detail;
	if (terrain.r > 0.0) {
		e = max(e, terrain.r - COAST_CRINKLE);
		detail = e - terrain.r;
	}

	// Hillshade: smooth large-scale slope from the data, fine slope from the detail noise.
	float ex = sample_smooth(terrain_tex, uv + vec2(texel / world_size.x, 0.0), terrain_size).r;
	float ey = sample_smooth(terrain_tex, uv + vec2(0.0, texel / world_size.y), terrain_size).r;
	vec2 gradient = vec2(ex - terrain.r, ey - terrain.r) / texel;
	gradient += vec2(dFdx(detail), dFdy(detail)) * zoom;
	vec3 normal = normalize(vec3(-gradient * 38.0, 1.0));
	vec3 light = normalize(vec3(-0.65, -0.75, 0.9));
	float shade = dot(normal, light) / light.z;

	float e_width = max(fwidth(e), 1e-5);
	float land = smoothstep(-e_width, e_width, e);
	float land_e = max(e, 0.0);
	float t = temperature(latitude, land_e);
	float m = terrain.g;

	// --- Land ---
	float tone = fbm(wp + vec2(53.0, 17.0), 240.0, 3);
	// Altitude cools vegetation, but snow on high ground comes from the snowline below,
	// so mountains in warm latitudes stay rock-colored rather than turning into ice fields.
	float biome_t = max(t, temperature(latitude, 0.0) - 0.22);
	vec3 land_col = biome_color(biome_t, m + (tone - 0.5) * 0.12);

	float development = texture(development_tex, uv).r;
	float canopy = fbm(wp + vec2(207.0, 61.0), 20.0, 4);
	float forest = terrain.b * (1.0 - development * 0.85);
	float forest_mask = smoothstep(0.38, 0.62, forest + (canopy - 0.5) * 0.55);
	// Up close, forests break into clumps of darker canopy.
	float clumps = smoothstep(0.45, 0.68, fbm(wp + vec2(5.0, 77.0), 5.0, 2)) * smoothstep(1.2, 2.5, zoom);
	vec3 canopy_col = forest_color(t) * (0.8 + 0.4 * canopy) * (1.0 - 0.2 * clumps);
	land_col = mix(land_col, canopy_col, forest_mask * 0.92);

	// Bare rock on high or steep ground; snow above a snowline that drops toward the poles.
	vec3 rock = vec3(0.56, 0.51, 0.44);
	float slope = length(gradient);
	float rockiness = smoothstep(0.36, 0.7, land_e) * mix(0.35, 0.9, relief) + smoothstep(0.012, 0.04, slope) * relief * 0.5;
	land_col = mix(land_col, rock, clamp(rockiness, 0.0, 0.92));
	// Snow settles on crests and gentle ground; steep faces stay bare rock.
	float snowline = mix(0.34, 1.0, smoothstep(0.2, 0.75, temperature(latitude, 0.0)));
	float snow = smoothstep(snowline - 0.03, snowline + 0.06, land_e + (ridges - 0.5) * 0.3);
	snow *= (0.4 + 0.6 * ridges) * (1.0 - 0.55 * smoothstep(0.02, 0.07, slope));
	land_col = mix(land_col, vec3(0.92, 0.93, 0.95), snow * 0.92);

	// Cultivated hinterland: a warm tint at any distance, a field patchwork up close.
	vec2 field_axis = vec2(cos(0.45), sin(0.45));
	vec2 field_pos = vec2(dot(wp, field_axis), dot(wp, vec2(-field_axis.y, field_axis.x)));
	vec2 field_cell = floor(field_pos / vec2(3.2, 2.0));
	float field_pick = hash12(field_cell);
	vec3 field_col = mix(vec3(0.78, 0.72, 0.45), vec3(0.58, 0.64, 0.36), step(0.5, field_pick));
	field_col = mix(field_col, vec3(0.70, 0.60, 0.42), step(0.8, field_pick));
	vec2 field_edge = abs(fract(field_pos / vec2(3.2, 2.0)) - 0.5);
	field_col *= 1.0 - 0.1 * smoothstep(0.4, 0.5, max(field_edge.x, field_edge.y));
	float field_visibility = smoothstep(0.9, 1.8, zoom);
	float cultivated = smoothstep(0.08, 0.5, development) * (1.0 - snow) * (1.0 - smoothstep(0.4, 0.6, land_e));
	land_col = mix(land_col, mix(land_col * vec3(1.06, 1.03, 0.92), field_col, field_visibility), cultivated * 0.85);

	// Painterly brushwork: soft horizontal strokes and a low-frequency wash.
	float strokes = vnoise(vec2(wp.x / 11.25, wp.y / 2.5), world_size.x / 11.25);
	land_col *= 0.95 + 0.1 * tone;
	land_col *= 1.0 + (strokes - 0.5) * 0.06 * smoothstep(0.5, 1.5, zoom);
	land_col *= mix(1.0, clamp(shade, 0.45, 1.35), 0.85);

	// Light beach line just inside the coast.
	float beach = (1.0 - smoothstep(0.0, 0.012, e)) * smoothstep(0.6, 1.4, zoom) * (1.0 - snow);
	land_col = mix(land_col, vec3(0.86, 0.80, 0.62), beach * 0.5);

	// --- Water ---
	float depth = max(-e, 0.0);
	vec3 shallow = vec3(0.47, 0.66, 0.68);
	vec3 coastal = vec3(0.26, 0.47, 0.60);
	vec3 deep = vec3(0.10, 0.22, 0.38);
	vec3 water_col = mix(shallow, coastal, smoothstep(0.0, 0.07, depth));
	water_col = mix(water_col, deep, smoothstep(0.07, 0.55, depth));
	float swell = fbm(wp + vec2(331.0, 773.0), 45.0, 3);
	water_col *= 0.96 + 0.08 * swell;

	// Water-lining: faint contour lines following the coast, dropped once they would crowd.
	float lining = depth / 0.022;
	float lining_width = max(fwidth(lining), 1e-5);
	float lining_line = 1.0 - clamp(abs(fract(lining) - 0.5) / lining_width - 0.6, 0.0, 1.0);
	lining_line *= (1.0 - smoothstep(0.03, 0.1, depth)) * (1.0 - smoothstep(0.12, 0.3, lining_width)) * step(0.004, depth);
	water_col = mix(water_col, water_col * 0.82, lining_line * 0.5);

	// Pack ice only close to the poles: the map stretches high latitudes, so a wide ice
	// band reads as a far larger cap than it is.
	float ice_noise = fbm(wp + vec2(17.0, 431.0), 60.0, 4);
	float ice = smoothstep(77.0, 84.0, latitude) + 1.0 - smoothstep(-80.0, -72.0, latitude);
	ice = smoothstep(0.45, 0.6, ice + (ice_noise - 0.5) * 0.6);
	water_col = mix(water_col, vec3(0.84, 0.89, 0.92), ice * 0.9);

	vec3 col = mix(water_col, land_col, land);

	// Inked coastline.
	float coast_line = 1.0 - smoothstep(0.6, 1.5, abs(e) / e_width);
	col = mix(col, vec3(0.20, 0.25, 0.26), coast_line * 0.6);

	// --- Political overlay ---
	// A smooth vote over the 4x4 political cells around this point turns the blocky id grid
	// into curved borders at any zoom. Kingdoms and regions are voted on separately.
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
	int best_r = 0;
	int second_r = 0;
	float best_rw = -1.0;
	float second_rw = 0.0;
	for (int q = 0; q < 16; q++) {
		if (q >= r_n) { break; }
		if (r_w[q] > best_rw) {
			second_rw = max(best_rw, 0.0);
			second_r = best_r;
			best_rw = r_w[q];
			best_r = r_ids[q];
		} else if (r_w[q] > second_rw) {
			second_rw = r_w[q];
			second_r = r_ids[q];
		}
	}

	// Distance to the nearest border in screen pixels, from how evenly the vote is split.
	float k_margin = best_kw - second_kw;
	float k_px = k_margin / max(fwidth(k_margin), 1e-5);
	float r_margin = best_rw - second_rw;
	float r_px = r_margin / max(fwidth(r_margin), 1e-5);
	float political = land * show_borders;

	if (best_k > 0) {
		// Soft ribbon of the kingdom's color just inside its borders; the interior stays natural.
		vec3 kingdom_col = texelFetch(kingdom_palette, ivec2(best_k - 1, 0), 0).rgb;
		float ribbon_px = mix(5.0, 16.0, smoothstep(0.2, 2.0, zoom));
		float ribbon = (1.0 - smoothstep(0.0, ribbon_px, k_px)) * step(0.0001, second_kw);
		col = mix(col, kingdom_col, ribbon * 0.42 * political);
	}

	float border_px = mix(1.2, 2.4, smoothstep(0.3, 2.5, zoom));
	float k_line = (1.0 - smoothstep(border_px * 0.5, border_px * 0.5 + 1.0, k_px)) * step(0.0001, second_kw);
	vec3 line_col = vec3(0.22, 0.16, 0.13);
	if (best_k > 0 && second_k == 0) {
		line_col = texelFetch(kingdom_palette, ivec2(best_k - 1, 0), 0).rgb * 0.55;
	} else if (best_k == 0 && second_k > 0) {
		line_col = texelFetch(kingdom_palette, ivec2(second_k - 1, 0), 0).rgb * 0.55;
	}
	col = mix(col, line_col, k_line * 0.9 * political);

	// Region boundaries appear as faint lines once regions become the unit of interest.
	float r_line = (1.0 - smoothstep(0.35, 1.15, r_px)) * step(0.0001, second_rw);
	float region_visibility = smoothstep(0.38, 0.75, zoom) * (1.0 - k_line);
	col = mix(col, vec3(0.24, 0.21, 0.17), r_line * 0.4 * region_visibility * political);

	// Contested ground: diagonal hatching anchored to the world, spaced in screen pixels.
	float hatch_px = abs(fract((wp.x + wp.y) * zoom / 8.0) - 0.5) * 8.0;
	float hatch = (1.0 - smoothstep(0.55, 1.35, hatch_px)) * smoothstep(0.35, 0.65, contested);
	col = mix(col, vec3(0.48, 0.17, 0.12), hatch * 0.32 * political);

	// Hover and selection: lift the region slightly and trace its outline.
	int region_id = best_r - 1;
	int neighbor_region_id = second_r - 1;
	float region_edge = 1.0 - smoothstep(1.0, 2.2, r_px);
	if (hovered_region >= 0 && (region_id == hovered_region || neighbor_region_id == hovered_region)) {
		if (region_id == hovered_region) {
			col = mix(col, vec3(1.0, 0.97, 0.86), 0.10 * land);
		}
		col = mix(col, vec3(1.0, 0.93, 0.62), region_edge * step(0.0001, second_rw) * 0.8 * land);
	}
	if (selected_region >= 0 && (region_id == selected_region || neighbor_region_id == selected_region)) {
		if (region_id == selected_region) {
			col = mix(col, vec3(1.0, 0.96, 0.82), 0.14 * land);
		}
		float selected_edge = 1.0 - smoothstep(1.6, 3.0, r_px);
		col = mix(col, vec3(0.98, 0.78, 0.28), selected_edge * step(0.0001, second_rw) * land);
	}

	COLOR = vec4(col, 1.0);
}
