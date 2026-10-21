shader_type canvas_item;
uniform float clock = 0.0;
uniform float attention : hint_range(0.0, 1.0) = 0.0;
varying vec2 sprite_position;

float hash21(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

void vertex() {
	sprite_position=VERTEX;
}

void fragment() {
	vec4 base=texture(TEXTURE,UV);
	vec2 p=(sprite_position-vec2(2.5,-89.5))/96.0;
	float sphere=1.0-smoothstep(0.88,1.01,length(p));
	// Animate the blue glass only; keep the painted brass and stand intact.
	float blue=smoothstep(0.04,0.27,base.b-max(base.r,base.g)*0.9)*sphere;
	float pulse=0.72+0.28*sin(clock*1.6);
	vec2 flow=p+vec2(sin(p.y*3.0+clock*0.45)*0.10,clock*0.045);
	float ribbons=pow(max(0.0,1.0-abs(sin(flow.x*5.2+flow.y*3.7+sin(flow.y*6.0-clock*0.6)))),14.0);
	vec2 cell=flow*8.0;
	vec2 grid=floor(cell);
	vec2 star=fract(cell)-vec2(0.25+hash21(grid)*0.5,0.25+hash21(grid+7.0)*0.5);
	float twinkle=0.35+0.65*pow(0.5+0.5*sin(clock*1.5+hash21(grid+9.0)*6.28),3.0);
	float spark=exp(-dot(star,star)*900.0)*step(0.40,hash21(grid+13.0))*twinkle;
	float strength=0.8+attention*0.65;
	vec3 glow=vec3(0.08,0.27,0.38)*ribbons*(0.6+pulse*0.4)+vec3(0.45,0.85,1.0)*spark;
	glow+=vec3(0.02,0.05,0.09)*pulse;
	COLOR=vec4(base.rgb+glow*blue*strength,base.a);
}
