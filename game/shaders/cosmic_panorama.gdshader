shader_type canvas_item;
uniform sampler2D panorama : source_color, filter_linear_mipmap;
uniform float clock=0.0;
uniform float convergence=0.0;
uniform float camera_roll=0.0;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	vec2 uv=UV;
	vec2 p=uv-0.5;
	float zoom=1.0-convergence*0.12;
	vec2 drift=vec2(sin(clock*0.035),cos(clock*0.027))*0.004;
	vec2 pixel=p*vec2(1.6,1.0);
	pixel=vec2(pixel.x*cos(camera_roll)-pixel.y*sin(camera_roll),pixel.x*sin(camera_roll)+pixel.y*cos(camera_roll));
	vec2 view=pixel/vec2(1.6,1.0);
	float c=abs(cos(camera_roll)),s=abs(sin(camera_roll));
	float cover=1.0/max(c+s/1.6,c+s*1.6);
	vec3 col=texture(panorama,view*(0.98*zoom*cover)+0.5+drift).rgb;
	// Preserve the user's brighter painting; only a gentle edge falloff.
	col*=0.94+0.06*(1.0-smoothstep(0.25,0.75,length(p)));
	for(int i=0;i<3;i++){
		float layer=float(i);
		vec2 q=(p*(1.0-convergence*(0.08+layer*0.03))+0.5)*vec2(93.0,58.0)*(1.0+layer*0.47);
		q+=vec2(clock*(0.16+layer*0.12),clock*(0.05+layer*0.03));
		vec2 id=floor(q);
		vec2 local=fract(q)-vec2(hash21(id+2.1),hash21(id+8.3));
		float star=exp(-dot(local,local)*400.0)*step(0.986,hash21(id+layer));
		float blink=0.5+0.5*sin(clock*(0.7+layer*0.2)+hash21(id)*90.0);
		col+=vec3(0.67,0.86,1.0)*star*(0.3+blink*0.6);
	}
	float veil=exp(-pow(p.x*5.4,2.0))*0.10;
	col=mix(col,vec3(0.045,0.12,0.25),veil);
	COLOR=vec4(col,1.0);
}
