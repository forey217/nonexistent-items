extends Node2D
## Local, depth-sorted starlight; no floor decal and no extra collisions.
var clock := 0.0
var hovered := false
var attention := 0.0
var core := Vector2.ZERO
var ink := ShaderMaterial.new()
var behind := Node2D.new()
var colors: Array[Color]=[Color("8bdce9"),Color("e0bf7e"),Color("b5a0df")]

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
	attention=move_toward(attention,1.0 if hovered else 0.0,delta*3.5)
	ink.set_shader_parameter("clock",clock)
	ink.set_shader_parameter("attention",attention)
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
		behind.draw_circle(core,radius,Color(0.07,0.38,0.64,(0.014+attention*0.007)*breath))
	for i in range(3):orbit_arc(behind,i,PI,TAU,0.40+attention*0.18)

func _draw() -> void:
	for index in range(3):
		orbit_arc(self,index,0.0,PI,0.62+attention*0.18)
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
		var opacity:=sin(age*PI)*(0.32+attention*0.35)
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
