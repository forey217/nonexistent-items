shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.65, 0.60, 0.49, 1.0);
uniform sampler2D surface_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool textured = false;
uniform float progress = 0.0;
uniform float floor_height = 0.0;
uniform float object_height = 1.5;
uniform float ceiling = 1.0;
uniform float ghost = 0.0;
uniform float residue = 0.0;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float height = clamp((world_position.y - floor_height) / object_height, 0.0, 1.0);
    float boundary = progress * 1.18 - 0.08;
    float wash = 1.0 - smoothstep(boundary - 0.10, boundary + 0.04, height);
    float partial = 1.0 - smoothstep(ceiling - 0.06, ceiling, height);
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
    float body = smoothstep(0.12, 0.78, progress);
    float grain = sin(world_position.x * 18.0 + world_position.y * 31.0) * sin(world_position.z * 22.0) * 0.025;
    vec3 pigment = tint.rgb;
    if (textured) {
        pigment *= mix(vec3(1.0), texture(surface_texture, world_position.xz * 0.30 + vec2(world_position.y * 0.27)).rgb, body * 0.55);
    }
    ALBEDO = mix(vec3(0.52, 0.60, 0.55), pigment + grain * body, body);
    ROUGHNESS = 0.94;
    float developed = wash * (rim * (1.0 - body) * 0.38 + body * 0.80);
    float echo = max(developed * 0.13, residue * (0.055 + rim * 0.14));
    ALPHA = partial * mix(developed, echo, ghost);
}
