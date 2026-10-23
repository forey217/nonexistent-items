shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;
uniform sampler2D observatory : source_color, filter_linear_mipmap;
uniform sampler2D vignette : source_color, filter_linear_mipmap;
uniform sampler2D glass_paint : source_color, filter_linear_mipmap;
uniform float clock = 0.0;
uniform float reveal = 0.0;
uniform float unlocked = 0.0;
uniform float hover = 0.0;
uniform float charge = 0.0;
uniform float opacity = 1.0;
uniform float lock_pulse = 0.0;
uniform float fracture = 0.0;
uniform vec2 piece_origin = vec2(0.0);
varying vec2 source;
varying vec4 finish;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){source=vec2(VERTEX.x,-VERTEX.y)+piece_origin;finish=COLOR;}
void fragment(){
    vec2 p=source/vec2(105.0,175.0);
    float seam=finish.g*(1.0-finish.r);
    vec3 n=normalize(mix(NORMAL,vec3(0.0,0.0,1.0),seam*(1.0-reveal)));
    float fresnel=pow(1.0-abs(dot(n,normalize(VIEW))),2.1);
    vec2 reflection_uv=clamp(vec2(0.5)+n.xy*0.32+p*0.12,vec2(0.02),vec2(0.98));
    vec3 reflected=texture(observatory,reflection_uv).rgb;
    float sweep=exp(-pow((p.x*0.7+p.y*0.22-sin(clock*0.19)*0.27-0.2)*7.0,2.0));
    float rim=finish.g*mix(reveal*0.70+fracture*0.30,1.0,finish.r);
    float side=finish.b;
    vec3 glass=mix(vec3(0.10,0.31,0.46),vec3(0.42,0.71,0.78),0.46+0.22*n.x+0.12*n.y);
    glass+=reflected*(0.32+fresnel*0.40)+vec3(0.36,0.62,0.68)*sweep*0.36;
    glass=mix(glass,vec3(0.035,0.14,0.23)+reflected*0.45,side*0.78);
    glass+=vec3(0.49,0.70,0.73)*rim*(0.20+0.80*max(n.y,0.0));
    vec2 q=p*vec2(14.0,21.0)+vec2(clock*0.015,0.0);
    float stars=exp(-dot(fract(q)-0.5,fract(q)-0.5)*260.0)*step(0.78,hash(floor(q)));
    float d=length(p*vec2(1.0,1.28));
    float core=exp(-d*d*37.0);
    float orbit=exp(-pow((length(p*vec2(1.0,2.6))-0.52)*27.0,2.0));
    float spiral=pow(max(sin(atan(p.y,p.x)*2.0-d*12.0+clock*0.65),0.0),5.0)*exp(-d*3.3);
    glass+=vec3(0.31,0.69,0.78)*spiral*0.45;
    glass+=vec3(0.69,0.90,0.94)*(core*0.75+orbit*0.12+stars*0.18)*(1.0-reveal*0.85)*(1.0-side*0.85);
    // Painted optical reflections are continuous over the joined source shape;
    // the actual bevels and side walls still change with the 3D pose.
    vec4 painted=texture(glass_paint,vec2(p.x*0.26+0.5,p.y*0.48+0.5));
    float coverage=painted.a*smoothstep(0.025,0.13,length(painted.rgb));
    glass=mix(glass,painted.rgb*0.82+vec3(0.025,0.065,0.09),coverage*0.87*(1.0-side)*(1.0-rim*0.55));
    // A static thumbnail, never another running scene or viewport.
    vec2 uv=UV*0.76+vec2(0.12,0.08);
    vec3 miniature=texture(vignette,uv).rgb;
    float interior=smoothstep(0.02,0.20,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
    float window=reveal*unlocked*interior*(1.0-rim)*(1.0-side);
    glass=mix(glass,miniature*0.82+vec3(0.09,0.20,0.25),window*0.88);
    float frost=reveal*(1.0-unlocked);
    glass=mix(glass,vec3(0.19,0.34,0.43)+reflected*0.18,frost*0.48);
    glass+=vec3(0.11,0.21,0.21)*hover+vec3(0.16,0.10,0.03)*lock_pulse;
    glass=mix(glass,vec3(0.87,0.98,1.0),charge*0.64);
    ALBEDO=glass;
    ALPHA=opacity;
}
