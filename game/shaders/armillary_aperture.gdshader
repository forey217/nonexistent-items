shader_type canvas_item;
uniform float stage_time=0.0;
uniform float opacity=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	vec2 p=UV*2.0-1.0;
	float radius=length(p);
	float mask=1.0-smoothstep(0.955,1.0,radius);
	vec2 drift=vec2(sin(stage_time*0.32),cos(stage_time*0.21))*0.014;
	vec3 nebula=texture(TEXTURE,UV*0.65+vec2(0.14,0.16)+drift).rgb;
	vec3 color=mix(vec3(0.025,0.060,0.115),nebula*vec3(0.26,0.40,0.65),0.64);
	color+=vec3(0.025,0.055,0.09)*(1.0-radius);
	vec2 grid=vec2(18.0,33.0);
	vec2 cell=floor((UV+drift*0.3)*grid);
	vec2 local=fract((UV+drift*0.3)*grid);
	vec2 center=vec2(hash(cell),hash(cell+13.0))*0.68+0.16;
	float star=(1.0-smoothstep(0.010,0.060,length(local-center)))*step(0.70,hash(cell+8.0));
	float pulse=0.72+0.28*sin(stage_time*1.5+hash(cell)*6.283);
	color+=vec3(0.79,0.87,0.90)*star*pulse;
	float rim=smoothstep(0.88,0.98,radius);
	color+=vec3(0.18,0.24,0.24)*rim;
	COLOR=vec4(color,mask*opacity*0.96);
}
