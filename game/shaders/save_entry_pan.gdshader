shader_type canvas_item;
uniform vec2 image_origin = vec2(0.0);
uniform float image_scale = 1.0;
uniform float image_opacity = 1.0;
uniform float edge_softness = 0.035;

void fragment() {
	vec2 uv = (UV - image_origin) / image_scale;
	float edge = min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y));
	float coverage = smoothstep(0.0, max(0.0001, edge_softness), edge);
	vec4 room = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	COLOR = vec4(room.rgb, room.a * image_opacity * coverage);
}
