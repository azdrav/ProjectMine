shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, ambient_light_disabled;

uniform sampler2D surface_noise : repeat_enable, filter_linear_mipmap;
uniform vec4 base_color : source_color = vec4(0.35, 0.34, 0.30, 1.0);
uniform float world_tiling = 0.8;
uniform float variation = 0.18;
uniform float surface_roughness = 0.9;
uniform float surface_metallic = 0.0;
uniform float ambient_fill = 0.10;
uniform bool hazard_stripes = false;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// Dominant-plane projection: one shared texture fetch rather than triplanar blending.
	vec3 n = abs(normalize(world_normal));
	vec2 p = world_position.xy;
	if (n.x > n.y && n.x > n.z) { p = world_position.zy; }
	else if (n.y > n.z) { p = world_position.xz; }
	float grain = texture(surface_noise, p * world_tiling).r;
	vec3 color = base_color.rgb;
	if (hazard_stripes) {
		float stripe = step(0.5, fract((p.x + p.y) * 2.2));
		color = mix(vec3(0.025), base_color.rgb, stripe);
	}
	ALBEDO = color * (1.0 + (grain - 0.5) * variation);
	ROUGHNESS = clamp(surface_roughness + (grain - 0.5) * 0.12, 0.25, 1.0);
	METALLIC = surface_metallic;
	SPECULAR = 0.35;
	// Cheap static indirect-light approximation, not an emissive/glowing surface.
	EMISSION = ALBEDO * ambient_fill;
}
