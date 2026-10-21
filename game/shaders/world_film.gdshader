shader_type canvas_item;
render_mode unshaded;
uniform sampler2D old_film : filter_linear, repeat_disable;
uniform sampler2D new_film : filter_linear, repeat_disable;
uniform sampler2D actor_mask : filter_linear, repeat_disable;
uniform float phase : hint_range(0.0,1.0) = 0.0;
uniform float alignment : hint_range(0.0,1.0) = 0.0;
uniform vec4 actor_rect = vec4(0.0,0.0,1.0,1.0);

vec4 film_sample(sampler2D film, vec2 uv) {
	if (uv.x<0.0 || uv.y<0.0 || uv.x>1.0 || uv.y>1.0) return vec4(0.0);
	return texture(film,uv);
}

void fragment() {
	vec2 pixel=TEXTURE_PIXEL_SIZE;
	float settled=smoothstep(0.0,1.0,alignment);
	vec2 old_shift=vec2(-8.0,4.0)*sin(alignment*3.14159265);
	vec2 new_shift=vec2(18.0,-9.0)*(1.0-settled);
	vec4 old_layer=film_sample(old_film,UV-old_shift*pixel);
	vec4 new_layer=film_sample(new_film,UV-new_shift*pixel);
	float blend=1.0-pow(1.0-clamp(phase,0.0,1.0),2.8);
	float alpha=mix(old_layer.a,new_layer.a,blend);
	vec3 premultiplied=mix(old_layer.rgb*old_layer.a,new_layer.rgb*new_layer.a,blend);
	vec4 environment=vec4(premultiplied/max(alpha,0.0001),alpha);
	vec4 live_scene=texture(TEXTURE,UV);
	vec2 actor_uv=(UV-actor_rect.xy)/actor_rect.zw;
	float silhouette=0.0;
	if (actor_uv.x>=0.0 && actor_uv.y>=0.0 && actor_uv.x<=1.0 && actor_uv.y<=1.0) {
		silhouette=smoothstep(0.02,0.12,texture(actor_mask,actor_uv).a);
	}
	// Preserve the original depth-tested actor, including its animated silhouette.
	COLOR=mix(environment,live_scene,silhouette);
}
