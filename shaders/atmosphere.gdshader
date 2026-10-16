shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.45, 0.65, 1.0, 1.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float intensity = 1.6;

void fragment() {
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float day = smoothstep(-0.35, 0.45, dot(world_n, normalize(sun_dir)));
	float a = pow(rim, 2.5) * intensity * (0.08 + day);
	ALBEDO = color.rgb * a;
}
