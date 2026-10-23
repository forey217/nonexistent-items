shader_type canvas_item;
// All movement uses an explicit clock so the menu's motion switch freezes it.
uniform float motion_time = 0.0;
uniform vec2 pointer_offset = vec2(0.0);
uniform float entry_phase = 0.0;
uniform bool fixed_camera = false;
uniform float camera_zoom = 1.06;
uniform vec2 camera_focus = vec2(0.5);

void fragment() {
	float zoom = 1.06 + 0.014 * sin(motion_time * 0.45);
	zoom *= mix(1.0, 1.16, entry_phase);
	vec2 drift = vec2(sin(motion_time * 0.48) * 0.011, sin(motion_time * 0.36) * 0.006);
	vec2 focus = mix(vec2(0.5), vec2(0.70, 0.503), entry_phase);
	vec2 uv = (UV - vec2(0.5)) / zoom + focus + drift + pointer_offset;
	if (fixed_camera) {
		uv = (UV - vec2(0.5)) / camera_zoom + camera_focus;
	}
	vec4 painting = texture(TEXTURE, uv);
	// Illuminate the blue core; the painted brass frame stays rigid.
	vec2 orb = (uv - vec2(0.8897, 0.503)) * vec2(1.6, 1.0);
	float radius = length(orb);
	float core = 1.0 - smoothstep(0.067, 0.082, radius);
	float angle = atan(orb.y, orb.x);
	float filaments = pow(max(0.0, sin(angle * 3.0 - motion_time * 1.9 + radius * 95.0)), 8.0);
	float orbit = exp(-pow((radius - 0.052 - 0.009 * sin(angle * 2.0 + motion_time * 0.8)) * 130.0, 2.0));
	vec3 blue = vec3(0.16, 0.43, 0.78) * core * (0.09 + 0.07 * sin(motion_time * 1.4));
	blue += vec3(0.32, 0.65, 1.0) * core * filaments * orbit * 0.75;
	blue += vec3(0.20, 0.38, 0.52) * core * entry_phase * 0.22;
	// A gentle change in lamplight, not an on/off flicker.
	vec2 lamp = (uv - vec2(0.642, 0.434)) * vec2(1.6, 1.0);
	float warm = exp(-dot(lamp, lamp) * 125.0) * (0.055 + 0.045 * sin(motion_time * 1.1));
	// Long, slowly travelling shafts of window light make the room visibly alive.
	float beam_axis = uv.x + uv.y * 0.39;
	float beams = pow(max(0.0, sin(beam_axis * 37.0 - motion_time * 0.62)), 10.0);
	float window_mask = smoothstep(0.53, 0.92, uv.x) * smoothstep(0.08, 0.28, uv.y) * (1.0 - smoothstep(0.78, 0.98, uv.y));
	vec3 window_light = vec3(0.48, 0.67, 0.9) * beams * window_mask * 0.16;
	painting.rgb += blue + vec3(1.0, 0.65, 0.26) * warm + window_light;
	COLOR = painting;
}
