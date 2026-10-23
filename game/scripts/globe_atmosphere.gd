extends Node2D
## Local, depth-sorted starlight and the first observation invitation.
signal awakened
var clock := 0.0
var hovered := false
var attention := 0.0
var core := Vector2.ZERO
var ink := ShaderMaterial.new()
var behind := Node2D.new()
var colors: Array[Color]=[Color("8bdce9"),Color("e0bf7e"),Color("b5a0df")]
var guidance_active:=false
var guidance_age:=0.0
var guidance_strength:=0.0
var orbit_strength:=0.0
var base_strength:=0.0
var hint_opacity:=0.0
var finishing:=false
var resumed:=false

func begin_guidance(animated: bool=true) -> void:
	if guidance_active or finishing:return
	guidance_active=true;resumed=not animated;guidance_age=-0.4 if animated else 10.0

func finish_guidance() -> void:
	guidance_active=false;finishing=true;hint_opacity=0.0
	# The world picker pauses the hall; let just this local light finish its fade.
	process_mode=Node.PROCESS_MODE_ALWAYS

func configure(globe: Node2D) -> void:
	core=globe.art.position+Vector2(2.5,-89.5)*globe.art.scale
	ink.shader=preload("res://shaders/globe_core.gdshader")
	globe.art.material=ink

func _ready() -> void:
	# Stay inside the globe's depth group, behind its brass artwork, above the floor.
	get_parent().add_child(behind)
	get_parent().move_child(behind,0)
	behind.draw.connect(_draw_behind)

func _process(delta: float) -> void:
	clock+=delta
	if guidance_active:
		var previous:=guidance_age
		guidance_age+=delta
		if previous<0 and guidance_age>=0:awakened.emit()
		var breath:=0.90+0.10*sin(maxf(0.0,guidance_age-1.2)*TAU/3.0)
		guidance_strength=smoothstep(0.0,0.8,guidance_age)*breath
		orbit_strength=smoothstep(0.25,1.2,guidance_age)*breath
		base_strength=smoothstep(0.55,1.2,guidance_age)*breath
		hint_opacity=0.0 if resumed else smoothstep(1.2,1.5,guidance_age)*(1.0-smoothstep(3.9,4.2,guidance_age))
	elif finishing:
		guidance_strength=move_toward(guidance_strength,0.0,delta*2.0)
		orbit_strength=move_toward(orbit_strength,0.0,delta*2.0)
		base_strength=move_toward(base_strength,0.0,delta*2.0)
		if maxf(guidance_strength,maxf(orbit_strength,base_strength))<=0.0:
			finishing=false;process_mode=Node.PROCESS_MODE_INHERIT
	attention=move_toward(attention,1.0 if hovered else 0.0,delta*3.5)
	ink.set_shader_parameter("clock",clock)
	ink.set_shader_parameter("attention",attention)
	ink.set_shader_parameter("guidance",guidance_strength)
	ink.set_shader_parameter("orbit_guidance",orbit_strength)
	queue_redraw()
	behind.queue_redraw()

func orbit(phase: float,index: int) -> Vector2:
	var tilt: float=[-0.42,0.72,-0.98][index]+sin(clock*0.13+index)*0.06
	var point:=Vector2(cos(phase)*(64.0+index*4.0),sin(phase)*(23.0+index*3.0))
	return core+point.rotated(tilt)

func orbit_arc(canvas: Node2D,index: int,start: float,end: float,alpha: float) -> void:
	var line:=PackedVector2Array()
	for i in range(49):line.append(orbit(lerpf(start,end,i/48.0),index))
	canvas.draw_polyline(line,Color(colors[index],alpha),0.85,true)

func _draw_behind() -> void:
	var breath:=0.75+0.25*sin(clock*1.6)
	for i in range(12):
		var radius:=43.0+i*2.0
		behind.draw_circle(core,radius,Color(0.07,0.38,0.64,(0.014+attention*0.007)*breath+guidance_strength*0.012))
	for i in range(3):orbit_arc(behind,i,PI,TAU,0.40+attention*0.18)
	if base_strength>0.001:
		# A restrained reflection follows the existing base, inside the prop's depth group.
		behind.draw_set_transform(Vector2(0,20),0,Vector2(1,0.46))
		for i in range(7,0,-1):behind.draw_circle(Vector2.ZERO,76+i*2,Color(0.32,0.60,0.75,0.010*base_strength))
		behind.draw_arc(Vector2.ZERO,90,0,TAU,96,Color(0.82,0.69,0.40,0.66*base_strength),1.3,true)
		behind.draw_arc(Vector2.ZERO,85,clock*0.3,clock*0.3+PI*1.4,72,Color(0.57,0.84,0.93,0.64*base_strength),1.4,true)
		if not resumed and guidance_age>0.85 and guidance_age<1.85:
			var wave:=guidance_age-0.85
			behind.draw_arc(Vector2.ZERO,90+wave*12,0,TAU,96,Color(0.89,0.79,0.52,sin(wave*PI)*0.35),1.2,true)
		behind.draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	for index in range(3):
		orbit_arc(self,index,0.0,PI,0.62+attention*0.18)
		if orbit_strength>0.001:
			var sweep:=clock*(0.36+index*0.06)+index*2.1
			orbit_arc(self,index,sweep,sweep+PI*0.55,0.62*orbit_strength)
		var phase:=clock*(0.52+index*0.12)*(1.0 if index!=1 else -1.0)+index*2.1
		var trail:=PackedVector2Array()
		for i in range(13):trail.append(orbit(phase-(12-i)*0.025,index))
		draw_polyline(trail,Color(colors[index],0.26+attention*0.18),1.5,true)
		var at:=orbit(phase,index)
		for radius in [7.0,4.5]:draw_circle(at,radius,Color(colors[index],0.055+attention*0.025))
		var crystal:=PackedVector2Array([at+Vector2(0,-6.5),at+Vector2(3.4,0),at+Vector2(0,6.5),at+Vector2(-3.4,0)])
		draw_colored_polygon(crystal,Color(colors[index],0.95))
		draw_polyline(crystal+PackedVector2Array([crystal[0]]),Color("fcf2d6"),0.8,true)
		draw_line(at+Vector2(0,-5),at+Vector2(0,4),Color("fff9e8"),0.9,true)
	# Sparse rising motes stay around the globe, above the stand and floor.
	for i in range(9):
		var age:=fposmod(clock*(0.10+i*0.003)+i*0.237,1.0)
		var opacity:=sin(age*PI)*(0.32+attention*0.35+guidance_strength*0.24)
		var at:=core+Vector2(sin(i*7.1+clock*0.2)*(37+i%3*7),26.0-age*92.0)
		var color:=Color(colors[i%3],opacity)
		draw_line(at-Vector2(2.0,0),at+Vector2(2.0,0),color,0.9,true)
		draw_line(at-Vector2(0,3.0),at+Vector2(0,3.0),color,0.9,true)
	# Hover adds a small observation scan instead of flashing the whole room.
	if attention>0.01:
		var start:=clock*0.62
		draw_arc(core,49.0,start,start+PI*0.74,48,Color("b8eff5")*Color(1,1,1,attention*0.65),1.5,true)
		for i in range(8):
			var radial:=Vector2.from_angle(i*TAU/8.0)
			draw_line(core+radial*52,core+radial*55,Color(colors[1],attention*0.55),1.0,true)
