// Painted ground for ZoneBuilder's plates.
//
// World-space triplanar, so neighbouring plates tile continuously. Two things
// hide the repeat that a 4m texture shows across a 300m field:
//  - each plate gets its own `offset` and `rotation` (ZoneBuilder picks them
//    from the plate's position), so no two plates line up;
//  - inside a plate the texture is read twice, rotated and scaled differently,
//    and the two reads are blended by ~20m blobs of noise. The eye locks onto
//    a repeat only when the same pixels recur on a grid; this breaks the grid.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tile_meters = 4.0;
uniform vec2 offset = vec2(0.0);
uniform float rotation = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.92;
// How hard the second read is blended in. 0 = plain tiling.
uniform float break_up : hint_range(0.0, 1.0) = 0.6;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 rot2(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 sample_plane(vec2 p) {
	vec2 uv = rot2(p / tile_meters, rotation) + offset;
	vec3 a = texture(albedo, uv).rgb;
	vec2 uv2 = rot2(p / (tile_meters * 1.37), rotation + 0.61) + offset.yx * 1.7;
	vec3 b = texture(albedo, uv2).rgb;
	float n = vnoise(p / 21.0 + offset * 7.0);
	float w = smoothstep(0.35, 0.65, n) * break_up;
	return mix(a, b, w);
}

void fragment() {
	vec3 n = abs(world_nrm);
	n = n / max(n.x + n.y + n.z, 0.0001);
	vec3 col = sample_plane(world_pos.xz) * n.y
		+ sample_plane(world_pos.zy) * n.x
		+ sample_plane(world_pos.xy) * n.z;
	ALBEDO = col * tint.rgb;
	ROUGHNESS = roughness;
	SPECULAR = 0.2;
}
