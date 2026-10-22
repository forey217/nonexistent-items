extends Node2D
## Shared distant sky; no navigation, collisions or GUI input on the backdrop.
var laboratory := false
var view: Node2D
var age := 0.0
var sky_material := ShaderMaterial.new()
var tint := Color("a2bdcf")
var world_blend := Vector3(1,0,0)

func _ready() -> void:
	z_index=-30
	var sky:=Sprite2D.new()
	sky.texture=preload("res://assets/level_select/cosmos_bright_v23.png")
	sky.centered=false
	sky.scale=Vector2(1280.0/sky.texture.get_width(),800.0/sky.texture.get_height())
	sky_material.shader=preload("res://shaders/observatory_space.gdshader")
	sky_material.set_shader_parameter("panorama",sky.texture)
	sky.material=sky_material
	add_child(sky)
	var optics:=Optics.new();optics.space=self;add_child(optics)

func _process(delta: float) -> void:
	age+=delta
	var destination:=Color("a2bdcf")
	if laboratory and is_instance_valid(view):
		destination=[Color("99d6e2"),Color("dbb88a"),Color("bab0dc")][view.room.state.world]
		var weights:=Vector3.ZERO;weights[view.room.state.world]=1.0
		world_blend=world_blend.lerp(weights,1.0-exp(-delta*3.6))
	tint=tint.lerp(destination,1.0-exp(-delta*2.8))
	sky_material.set_shader_parameter("clock",age)
	sky_material.set_shader_parameter("world_tint",tint)
	queue_redraw()

func arc_points(center: Vector2,radii: Vector2,rotation: float,start: float,end: float,count:=120) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for i in range(count+1):
		var a:=lerpf(start,end,float(i)/count)
		points.append(center+(Vector2(cos(a),sin(a))*radii).rotated(rotation))
	return points

class Optics extends Node2D:
	var space: Node2D
	func _process(_delta: float) -> void:queue_redraw()
	func _draw() -> void:
		if space.laboratory:_globe()
		else:_station()
		for i in range(28):
			var x:=fmod(i*173.7+space.age*(0.7+float(i%4)*0.16),1280.0)
			var y:=fmod(i*97.3+42.0,800.0)
			var alpha:=0.22+sin(space.age*0.8+i)*0.12
			draw_circle(Vector2(x,y),1.0 if i%4 else 1.8,Color(0.91,0.96,1,alpha))
	func _station() -> void:
		var c:=Vector2(640,320)
		for radius in [214.0,227.0]:
			draw_polyline(space.arc_points(c,Vector2(radius,radius*0.77),-0.12,PI*0.94,TAU*1.04),Color(0.89,0.79,0.56,0.57),1.8,true)
		for i in range(27):
			var a:=PI+float(i)/26.0*PI
			var p:=c+Vector2(cos(a)*220,sin(a)*171).rotated(-0.12)
			var n:=(p-c).normalized()
			draw_line(p,p+n*(9 if i%3==0 else 4),Color(0.95,0.85,0.65,0.7),1.2,true)
		# Anti-gravity halo below the slab, with a quiet moving light.
		for radius in [Vector2(399,150),Vector2(420,158)]:
			draw_polyline(space.arc_points(Vector2(640,554),radius,0,0,TAU),Color(0.61,0.85,0.91,0.30),1.8,true)
		var a: float=space.age*0.12
		draw_circle(Vector2(640+cos(a)*420,554+sin(a)*158),3,Color("d6f1f3"))
	func _globe() -> void:
		var c:=Vector2(659,385)
		var r:=Vector2(598,353)
		# Optical rim and separated reflection strokes suggest a clear glass shell.
		for data in [[r,Color(0.68,0.91,0.99,0.16),9.0],[r,Color(0.86,0.97,1,0.70),1.4],[r-Vector2(12,8),Color(0.70,0.92,1,0.20),1.0]]:
			draw_polyline(space.arc_points(c,data[0],0,0,TAU),data[1],data[2],true)
		draw_polyline(space.arc_points(c,r-Vector2(22,17),0,3.63,4.37,45),Color(0.87,0.98,1,0.35),6,true)
		draw_polyline(space.arc_points(c,r-Vector2(33,23),0,5.14,5.73,45),Color(0.87,0.98,1,0.27),3,true)
		var orbit:=0.0
		if is_instance_valid(space.view):orbit=deg_to_rad(space.view.angle)*0.17
		for rotation in [-0.18+orbit,0.27+orbit]:
			var points: PackedVector2Array=space.arc_points(c,Vector2(620,229),rotation,0,TAU,160)
			draw_polyline(points,Color(0.17,0.24,0.29,0.46),6,true)
			draw_polyline(points,Color(0.89,0.76,0.48,0.76),2.0,true)
		for i in range(66):
			var a:=float(i)/66.0*TAU
			var p:=c+Vector2(cos(a),sin(a))*r
			var n:=(p-c).normalized()
			draw_line(p-n*(10 if i%6==0 else 4),p,Color(0.93,0.83,0.60,0.65),1.1,true)
		# A distant ringed planet sits outside the experiment, away from the rail.
		var planet:=Vector2(1100,150)
		draw_circle(planet,28,Color(0.52,0.73,0.81,0.8))
		draw_circle(planet+Vector2(-7,-8),18,Color(0.73,0.88,0.91,0.3))
		draw_polyline(space.arc_points(planet,Vector2(52,12),-0.33,0,TAU,70),Color(0.95,0.83,0.62,0.69),2.2,true)
		_world_echoes()
	func _world_echoes() -> void:
		var blend: Vector3=space.world_blend
		for i in range(9):
			var side:=1.0 if i%2==0 else -1.0
			var x:=659.0+side*(470.0+float(i%3)*32.0)
			var y:=175.0+fmod(i*67.0+space.age*6.0,400.0)
			var at:=Vector2(x,y)
			var crystal:=PackedVector2Array([at+Vector2(0,-14),at+Vector2(7,-2),at+Vector2(0,16),at+Vector2(-7,2)])
			draw_colored_polygon(crystal,Color(0.70,0.94,1,blend.x*0.30))
			draw_polyline(crystal+PackedVector2Array([crystal[0]]),Color(0.82,0.98,1,blend.x*0.55),1.1,true)
			# Dense-world particles descend; inverted-world particles climb.
			var heavy:=Vector2(x+12,130+fmod(i*73.0+space.age*20.0,470.0))
			draw_line(heavy,heavy+Vector2(0,7),Color(1,0.83,0.51,blend.y*0.52),1.5,true)
			var rising:=Vector2(x-13,610-fmod(i*83.0+space.age*14.0,480.0))
			draw_circle(rising,1.6,Color(0.87,0.80,1,blend.z*0.7))
			draw_line(rising,rising+Vector2(0,9),Color(0.79,0.72,1,blend.z*0.28),1,true)
		var ring: PackedVector2Array=space.arc_points(Vector2(1139,581),Vector2(67,26),-0.3,0,TAU,70)
		draw_polyline(ring,Color(1,0.80,0.45,blend.y*0.55),2,true)
		# A small inverted skyline, distant enough to remain scenery.
		for i in range(8):
			var x:=828.0+i*14.0
			var h:=16.0+float((i*7)%5)*7.0
			draw_rect(Rect2(x,117,10,h),Color(0.57,0.55,0.78,blend.z*0.30))
			draw_line(Vector2(x,117+h),Vector2(x+10,117+h),Color(0.85,0.79,1,blend.z*0.48),1,true)
