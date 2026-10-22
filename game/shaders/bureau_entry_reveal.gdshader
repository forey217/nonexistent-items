shader_type canvas_item;
uniform float reveal = 0.0;
uniform vec2 focus = vec2(0.72, 0.50);
uniform float opacity = 1.0;

void fragment() {
	vec2 aspect = vec2(1.6, 1.0);
	float reach = max(max(length(focus * aspect), length((vec2(1.0, 0.0) - focus) * aspect)),
		max(length((vec2(0.0, 1.0) - focus) * aspect), length((vec2(1.0) - focus) * aspect)));
	float radius = mix(-0.09, reach + 0.09, smoothstep(0.0, 0.88, reveal));
	float distance_to_globe = length((UV - focus) * aspect);
	float paper_alpha = smoothstep(radius - 0.075, radius + 0.075, distance_to_globe);
	vec4 illustrated_room = texture(TEXTURE, UV);
	COLOR = vec4(illustrated_room.rgb, illustrated_room.a * paper_alpha * opacity);
}
