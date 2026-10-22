shader_type canvas_item;
uniform float clock=0.0;
uniform int kind=0;
uniform float charge=0.0;
uniform vec2 piece_origin=vec2(0.0);
uniform float glass_finish=0.0;
uniform float view_phase=0.0;
varying vec2 place;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){place=(VERTEX+piece_origin)/vec2(76.0,120.0);}
void fragment(){
	vec2 p=place;
	vec2 sky=p*vec2(9.0,14.0)+vec2(clock*0.06,0.0);
	vec2 cell=floor(sky);
	float stars=exp(-dot(fract(sky)-0.5,fract(sky)-0.5)*280.0)*step(0.71,hash21(cell));
	vec3 col=vec3(0.035,0.075,0.17)+vec3(0.24,0.43,0.59)*stars;
	if(kind==0){
		col=mix(vec3(0.07,0.22,0.39),vec3(0.28,0.68,0.80),clamp((p.y+1.0)*0.5,0.0,1.0));
		float aurora=pow(max(0.0,1.0-abs(p.y+0.28+sin(p.x*4.0+clock*0.35)*0.18)),8.0);
		col+=vec3(0.16,0.49,0.30)*aurora;
		float peaks=0.38-abs(sin(p.x*4.0+0.9))*0.66;
		if(p.y>peaks)col=mix(vec3(0.52,0.77,0.89),vec3(0.14,0.35,0.57),clamp((p.y-peaks)*1.4,0.0,1.0));
		if(p.y>0.70-abs(sin(p.x*3.1))*0.46)col=vec3(0.12,0.32,0.46);
		vec2 snow=fract(p*vec2(8.0,11.0)+vec2(clock*0.12,clock*0.31))-0.5;
		col+=vec3(0.6,0.8,0.85)*exp(-dot(snow,snow)*340.0);
	}else if(kind==1){
		col=vec3(0.11,0.065,0.17)+vec3(0.26,0.12,0.05)*(p.y+1.0)*0.5;
		vec2 v=p-vec2(0.0,-0.12);
		vec2 q=vec2(v.x*cos(0.38)-v.y*sin(0.38),v.x*sin(0.38)+v.y*cos(0.38));
		float d=length(q*vec2(1.0,2.6));
		float ring=exp(-pow((d-0.69)*18.0,2.0));
		col+=vec3(0.88,0.54,0.20)*ring*(0.6+0.4*sin(atan(q.y,q.x)*5.0+clock*0.5));
		float planet=length(p-vec2(0.02,-0.13));
		if(planet<0.42){float bands=0.55+0.15*sin(p.y*42.0+sin(p.x*5.0));col=vec3(0.91,0.65,0.32)*bands*(0.6+0.5*(-p.x));}
		col+=vec3(0.6,0.48,0.32)*stars;
	}else if(kind==2){
		col=mix(vec3(0.25,0.14,0.39),vec3(0.07,0.10,0.23),(p.y+1.0)*0.5);
		float column=floor((p.x+1.0)*5.0);
		float height=0.18+hash21(vec2(column,4.0))*0.65;
		if(p.y<(-1.0+height)){col=vec3(0.07,0.06,0.17);vec2 w=fract(p*vec2(24,34));if(w.x<0.26&&w.y<0.25)col+=vec3(0.44,0.29,0.58);}
		float stair=0.44-floor((p.x+0.8)*5.0)*0.10;
		if(abs(p.y-stair)<0.025&&abs(p.x)<0.75)col+=vec3(0.66,0.54,0.80);
		float moon=length(p-vec2(0.35,-0.10));
		col+=vec3(0.56,0.48,0.74)*exp(-moon*moon*24.0);
		col+=vec3(0.42,0.46,0.77)*stars;
	}else if(kind==3){
		col=mix(vec3(0.055,0.32,0.46),vec3(0.015,0.08,0.24),(p.y+1.0)*0.5);
		float rays=pow(max(0.0,sin(p.x*8.0+p.y*2.2+clock*0.2)),12.0)*(1.0-p.y)*0.13;
		col+=vec3(0.15,0.7,0.63)*rays;
		for(int j=0;j<4;j++){float f=float(j);vec2 pos=vec2(sin(f*4.8)*0.52,-0.6+f*0.37+sin(clock*0.45+f)*0.08);vec2 q=p-pos;float jelly=length(q*vec2(1.0,1.5));col+=vec3(0.12,0.76,0.75)*exp(-jelly*jelly*90.0);if(q.y>0.02&&q.y<0.26&&abs(q.x+sin(q.y*24.0+clock)*0.018)<0.009)col+=vec3(0.12,0.55,0.62);}
	}else if(kind==4){
		col=mix(vec3(0.13,0.09,0.22),vec3(0.27,0.16,0.20),(p.y+1.0)*0.5);
		vec2 grid=fract(p*5.0)-0.5;
		float circuits=(1.0-smoothstep(0.015,0.04,min(abs(grid.x),abs(grid.y))))*0.15;
		col+=vec3(0.8,0.43,0.14)*circuits;
		vec2 q=p*vec2(1.0,1.5);float d=length(q);
		col+=vec3(0.96,0.62,0.20)*(exp(-pow((d-0.50)*32.0,2.0))+exp(-pow((d-0.72)*32.0,2.0))*0.5);
		col+=vec3(0.40,0.65,0.80)*exp(-d*d*11.0);
	}else{
		float d=length(p*vec2(1.0,0.70));
		float spiral=sin(atan(p.y,p.x)*3.0+d*9.0-clock*0.7);
		col=vec3(0.025,0.10,0.23)+vec3(0.16,0.40,0.53)*pow(max(0.0,spiral),5.0)*exp(-d*1.1);
		col+=vec3(0.65,0.81,0.80)*stars;
		col+=vec3(0.16,0.41,0.44)*exp(-d*d*8.0);
	}
	float sweep=abs(p.x*0.82+p.y*0.32-sin(view_phase)*0.70);
	float reflection=exp(-sweep*sweep*95.0)*glass_finish;
	col+=vec3(0.22,0.39,0.48)*reflection*0.52;
	col=mix(col,vec3(0.92,1.0,0.97),charge*0.86);
	COLOR=vec4(col,1.0);
}
