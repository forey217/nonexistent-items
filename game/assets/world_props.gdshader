shader_type canvas_item;
uniform int world_kind = 0;
float grain(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453); }
void fragment() {
 vec4 source=texture(TEXTURE,UV);
 vec3 c=source.rgb;
 if(world_kind==0) {
  float light=dot(c,vec3(0.299,0.587,0.114));
  c=mix(c,vec3(light*0.75+0.12,light*0.96+0.15,light+0.18),0.68);
  float facet=step(0.85,fract(UV.x*7.0+UV.y*3.0));
  c+=facet*0.065;
 } else if(world_kind==1) {
  c=floor(c*5.0+0.5)/5.0;
  c=pow(c,vec3(1.15))*vec3(1.06,0.94,0.85);
  vec2 cell=fract(FRAGCOORD.xy/5.0)-vec2(0.5);
  float dots=1.0-step(0.17,length(cell));
  float shade=1.0-dot(c,vec3(0.299,0.587,0.114));
  c-=dots*shade*0.16;
 } else {
  float light=dot(c,vec3(0.299,0.587,0.114));
  c=mix(c,vec3(light*0.83+0.17,light*0.80+0.19,light*0.98+0.18),0.54);
  c=mix(c,vec3(0.94,0.91,0.96),0.16);
  c+=(grain(FRAGCOORD.xy)-0.5)*0.07;
 }
 COLOR=vec4(clamp(c,0.0,1.0),source.a);
}
