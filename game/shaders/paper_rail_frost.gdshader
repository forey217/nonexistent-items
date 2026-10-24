shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform float age = 2.0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float kind = 0.0;
varying vec3 local_at;
void vertex() {
    local_at = VERTEX;
    if (kind > 1.5) {
        // A pooled mist quad: its four vertices store the same local centre.
        vec4 centre = MODEL_MATRIX * vec4(VERTEX, 1.0);
        centre.xyz += INV_VIEW_MATRIX[0].xyz * (UV.x - 0.5) * 0.40;
        centre.xyz += INV_VIEW_MATRIX[1].xyz * (UV.y - 0.5) * 0.25;
        POSITION = PROJECTION_MATRIX * VIEW_MATRIX * centre;
    } else {
        POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    }
}
void fragment() {
    float arrived = smoothstep(0.0, 0.075, age - COLOR.r);
    if (kind > 1.5) {
        float radius = length((UV - vec2(0.5)) * vec2(1.7, 2.0));
        float front = smoothstep(-0.04, 0.035, age - COLOR.r) * (1.0 - smoothstep(0.07, 0.23, age - COLOR.r));
        ALBEDO = vec3(0.66, 0.88, 0.98);
        ALPHA = (1.0 - smoothstep(0.12, 0.72, radius)) * front * strength * 0.21;
        EMISSION = ALBEDO * 0.10;
    } else {
        float grain = fract(sin(dot(local_at.xz, vec2(127.1, 311.7))) * 43758.5453);
        float edge = smoothstep(0.48, 0.90, abs(UV.y * 2.0 - 1.0));
        ALBEDO = mix(vec3(0.26, 0.62, 0.78), vec3(0.86, 0.97, 1.0), max(edge, grain * 0.25));
        float front = (1.0 - smoothstep(0.06, 0.22, age - COLOR.r)) * arrived;
        if (kind > 0.5) {
            ALBEDO = mix(vec3(0.52, 0.80, 0.90), vec3(0.91, 0.98, 1.0), grain);
            EMISSION = ALBEDO * (0.08 + front * (0.20 + 0.25 * sin(age * 44.0 + COLOR.b * 15.0)));
        } else {
            EMISSION = ALBEDO * (0.035 + front * 0.12);
        }
        ROUGHNESS = 0.34;
        METALLIC = 0.10;
        ALPHA = arrived * strength * (0.84 + edge * 0.12);
    }
}
