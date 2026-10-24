shader_type canvas_item;
render_mode unshaded;
uniform sampler2D old_film : filter_linear, repeat_disable;
uniform sampler2D new_film : filter_linear, repeat_disable;
uniform sampler2D actor_mask : filter_linear, repeat_disable;
uniform float phase : hint_range(0.0,1.0)=0.0;
uniform vec4 actor_rect=vec4(0.0,0.0,1.0,1.0);
uniform bool actor_visible=true;
void fragment(){
	// Only target-floor environment geometry moves. Shared live mechanisms, other
	// floors, labels and surroundings use the identical camera in both films.
	float blend=1.0-pow(1.0-clamp(phase,0.0,1.0),2.8);
	vec4 environment=mix(texture(old_film,UV),texture(new_film,UV),blend);
	vec4 live_scene=texture(TEXTURE,UV);
	vec2 actor_uv=(UV-actor_rect.xy)/max(actor_rect.zw,vec2(.00001));
	float silhouette=0.0;
	if(actor_visible && actor_uv.x>=0.0 && actor_uv.y>=0.0 && actor_uv.x<=1.0 && actor_uv.y<=1.0){
		silhouette=smoothstep(.02,.12,texture(actor_mask,actor_uv).a);
	}
	COLOR=mix(environment,live_scene,silhouette);
}
