shader_type canvas_item;
render_mode unshaded;
uniform sampler2D actor_mask : filter_linear, repeat_disable;
uniform vec4 actor_rect=vec4(0.0,0.0,1.0,1.0);
void fragment(){
	vec2 uv=(SCREEN_UV-actor_rect.xy)/max(actor_rect.zw,vec2(.00001));
	if(uv.x>=0.0 && uv.y>=0.0 && uv.x<=1.0 && uv.y<=1.0){
		COLOR.a*=1.0-smoothstep(.02,.12,texture(actor_mask,uv).a);
	}
}
