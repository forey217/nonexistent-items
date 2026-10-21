shader_type canvas_item;
uniform float clock = 0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float cloud(vec2 p){float n=0.0,a=0.5;for(int i=0;i<4;i++){n+=a*noise(p);p=p*2.03+17.1;a*=0.5;}return n;}
void fragment(){
 vec2 uv=UV;vec2 p=uv*vec2(3.4,2.3);
 float n=cloud(p+vec2(clock*0.018,-clock*0.007));
 float band=exp(-pow((uv.y-0.68+sin(uv.x*5.0+clock*0.025)*0.14)*3.4,2.0));
 vec3 col=mix(vec3(0.035,0.055,0.10),vec3(0.12,0.20,0.28),n);
 col+=vec3(0.07,0.18,0.20)*pow(n,2.0)*band;
 col+=vec3(0.12,0.075,0.17)*cloud(p*1.8-vec2(clock*0.008,0))*0.25;
 vec2 q=uv*vec2(180.0,112.0)+vec2(clock*0.48,clock*0.16);
 vec2 id=floor(q);float seed=hash(id);
 vec2 local=fract(q)-vec2(hash(id+2.1),hash(id+8.3));
 float stars=(1.0-smoothstep(0.015,0.11,length(local)))*step(0.983,seed);
 float twinkle=0.65+0.35*sin(clock*(0.8+seed)+seed*100.0);
 col+=vec3(0.81,0.87,0.82)*stars*twinkle;
 float edge=smoothstep(0.85,0.22,length((uv-0.5)*vec2(1.15,0.85)));
 COLOR=vec4(col*(0.65+0.35*edge),1.0);
}
