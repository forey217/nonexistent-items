shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D landscape : source_color, filter_linear_mipmap_anisotropic;
uniform float unfold : hint_range(0.0,1.0) = 0.0;
uniform float opening : hint_range(0.0,1.0) = 0.0;
uniform float reveal : hint_range(0.0,1.0) = 1.0;
uniform float still_time = 0.0;
void vertex() {
    VERTEX.z += sin(UV.y*15.0+UV.x*3.0+still_time*.38)*.008*opening;
}
void fragment() {
    vec2 uv=UV;
    float edge=min(uv.x,1.0-uv.x);
    float window_x=smoothstep(.155,.235,edge);
    float window_y=smoothstep(.075,.15,uv.y)*(1.0-smoothstep(.88,.965,uv.y));
    float aperture=window_x*window_y*smoothstep(.04,.95,opening);
    float fibers=sin(uv.y*970.0+sin(uv.x*630.0)*1.5)*.008+sin(uv.x*1680.0+uv.y*37.0)*.004;
    vec3 paper=vec3(.82,.785,.66)+fibers;
    paper+=vec3(.04,.035,.024)*sin(uv.x*3.14159);
    vec4 ink=texture(landscape,uv);
    float draw_on=smoothstep(.1,.85,unfold);
    ALBEDO=mix(paper,ink.rgb,ink.a*draw_on*.92);
    ROUGHNESS=.95;
    EMISSION=vec3(.085,.08,.055)*opening;
    ALPHA=(1.0-aperture)*reveal;
}
