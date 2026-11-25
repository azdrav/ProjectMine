shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 energy_color : source_color = vec4(0.1,0.65,1.0,1.0);
uniform vec4 core_color : source_color = vec4(0.85,0.96,1.0,1.0);
uniform bool billboard = false;
uniform float brightness = 1.0;
void vertex() {
	// Writing POSITION anywhere disables Godot's implicit transform for all paths.
	POSITION = PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.0);
	if (billboard) {
		vec3 center = (MODEL_MATRIX * vec4(0.0,0.0,0.0,1.0)).xyz;
		vec2 scale = vec2(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz));
		vec3 point = center + INV_VIEW_MATRIX[0].xyz*VERTEX.x*scale.x + INV_VIEW_MATRIX[1].xyz*VERTEX.y*scale.y;
		POSITION = PROJECTION_MATRIX*VIEW_MATRIX*vec4(point,1.0);
	}
}
void fragment() {
	float opacity;
	float core;
	if (billboard) {
		float radius = length(UV*2.0-1.0);
		opacity = pow(max(0.0,1.0-radius),2.0);
		core = pow(max(0.0,1.0-radius),8.0);
	} else {
		float edge = max(0.0,1.0-abs(UV.x*2.0-1.0));
		float tail = pow(1.0-UV.y,1.5);
		core = pow(edge,16.0)*(1.0-smoothstep(0.0,0.3,UV.y));
		opacity = (pow(edge,2.0)*0.32+core)*tail;
	}
	ALBEDO = mix(energy_color.rgb,core_color.rgb,core*0.8)*COLOR.rgb*brightness;
	ALPHA = opacity*COLOR.a;
}
