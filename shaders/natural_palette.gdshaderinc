// Natural colors and noise shared by the world atlas and the regional map, so both
// scales paint the same climate the same way.

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 lattice_gradient(vec2 lattice) {
	float angle = hash12(lattice) * 6.2831853;
	return vec2(cos(angle), sin(angle));
}

// Gradient noise in 0..1 whose lattice repeats every `period` cells horizontally.
// Gradient rather than value noise: thresholded value noise shows its square lattice.
float vnoise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	float a = dot(lattice_gradient(vec2(x0, i.y)), f);
	float b = dot(lattice_gradient(vec2(x1, i.y)), f - vec2(1.0, 0.0));
	float c = dot(lattice_gradient(vec2(x0, i.y + 1.0)), f - vec2(0.0, 1.0));
	float d = dot(lattice_gradient(vec2(x1, i.y + 1.0)), f - vec2(1.0, 1.0));
	return clamp(0.5 + 0.75 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y), 0.0, 1.0);
}

float temperature(float latitude, float land_elevation) {
	// Same formula as WorldFieldBuilder.temperature().
	float southern_cold = smoothstep(60.0, 80.0, -latitude) * 0.12;
	return clamp(1.0 - pow(abs(latitude) / 90.0, 1.45) * 1.02 - land_elevation * 0.4 - southern_cold, 0.0, 1.0);
}

// Open ground by temperature (t) and moisture (m), both 0..1.
vec3 biome_color(float t, float m) {
	vec3 cold_dry = vec3(0.70, 0.67, 0.53);
	vec3 hot_dry = vec3(0.86, 0.75, 0.53);
	vec3 cool_mid = vec3(0.60, 0.64, 0.42);
	vec3 hot_mid = vec3(0.76, 0.70, 0.43);
	vec3 cool_wet = vec3(0.46, 0.58, 0.35);
	vec3 hot_wet = vec3(0.38, 0.56, 0.29);
	float heat = smoothstep(0.45, 0.78, t);
	vec3 dry = mix(cold_dry, hot_dry, heat);
	vec3 mid = mix(cool_mid, hot_mid, heat);
	vec3 wet = mix(cool_wet, hot_wet, heat);
	vec3 col = mix(dry, mid, smoothstep(0.16, 0.38, m));
	col = mix(col, wet, smoothstep(0.42, 0.72, m));
	vec3 tundra = vec3(0.62, 0.63, 0.55);
	vec3 snow = vec3(0.93, 0.94, 0.95);
	col = mix(tundra, col, smoothstep(0.24, 0.38, t));
	col = mix(snow, col, smoothstep(0.1, 0.2, t));
	return col;
}

// Canopy color by temperature; RegionMapStyle.forest_color() mirrors it for drawn trees.
vec3 forest_color(float t) {
	vec3 boreal = vec3(0.24, 0.35, 0.27);
	vec3 temperate = vec3(0.25, 0.40, 0.22);
	vec3 jungle = vec3(0.15, 0.36, 0.17);
	vec3 col = mix(boreal, temperate, smoothstep(0.34, 0.55, t));
	return mix(col, jungle, smoothstep(0.7, 0.86, t));
}
