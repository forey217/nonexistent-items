shader_type canvas_item;
uniform float motion_time = 0.0;

void fragment() {
	// Screen-space coordinates give one sweep across the entire heading,
	// rather than restarting the shine inside every glyph's atlas region.
	float sweep = mix(0.18, 0.84, fract(motion_time / 5.5));
	float sheen = exp(-pow((SCREEN_UV.x - sweep) * 31.0, 2.0));
	float breathing = 0.97 + 0.03 * sin(motion_time * 0.8);
	COLOR.rgb = COLOR.rgb * breathing + vec3(0.42, 0.32, 0.15) * sheen;
}
