shader_type canvas_item;
uniform sampler2D panorama : source_color, filter_linear_mipmap;
uniform float clock=0.0;
uniform vec4 world_tint : source_color=vec4(0.58,0.78,0.91,1.0);
void fragment(){
	vec2 p=UV-0.5;
	vec2 drift=vec2(sin(clock*0.018),cos(clock*0.014))*0.009;
	vec3 image=texture(panorama,UV*0.94+0.03+drift).rgb;
	float lum=dot(image,vec3(0.299,0.587,0.114));
	// Soft, luminous distance keeps the small actor and puzzle silhouette readable.
	vec3 col=mix(image,vec3(lum),0.32);
	col=mix(col,vec3(0.22,0.35,0.47),0.30);
	float quiet=exp(-dot(p*vec2(2.7,2.2),p*vec2(2.7,2.2)));
	col=mix(col,world_tint.rgb,0.17+quiet*0.13);
	col+=vec3(0.025,0.035,0.045);
	COLOR=vec4(col,1.0);
}
