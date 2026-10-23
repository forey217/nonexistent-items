extends Node2D
## Clocked armillary gate. Rear, foreground and floor stay independently addressable.
const DURATION := 2.15
const CENTER := Vector2(0,-106)
const BRASS_DARK := Color("785333")
const BRASS := Color("c0a06a")
const BRASS_LIGHT := Color("f0d9a0")
var render_pass := "all"
var art_offset := Vector2.ZERO
var linked_pass: Node2D
var core: Sprite2D
var core_material: ShaderMaterial
var age := 0.0:
	set(value):
		age=value
		_sync_core()
		queue_redraw()
		if is_instance_valid(linked_pass):linked_pass.age=value

func _ready() -> void:
	if render_pass!="front":
		core=Sprite2D.new()
		core.texture=preload("res://assets/level_select/cosmos_bright_v23.png")
		core.position=CENTER+art_offset
		core.scale=Vector2(94.0/core.texture.get_width(),186.0/core.texture.get_height())
		core.show_behind_parent=true
		core_material=ShaderMaterial.new()
		core_material.shader=preload("res://shaders/armillary_aperture.gdshader")
		core.material=core_material
		add_child(core)
	_sync_core()

func opening() -> float:
	return smoothstep(0.26,0.70,age)*(1.0-smoothstep(1.45,2.02,age))

func strength() -> float:
	return smoothstep(0.22,0.45,age)*(1.0-smoothstep(1.94,DURATION,age))

func _sync_core() -> void:
	if not is_instance_valid(core):return
	core.visible=age>0.26 and age<2.03
	core.scale.x=94.0/core.texture.get_width()*maxf(0.01,opening())
	core_material.set_shader_parameter("stage_time",age)
	core_material.set_shader_parameter("opacity",opening()*strength())

func _point(theta: float,index: int) -> Vector3:
	var phase:=smoothstep(0.28,0.73,age)
	var close:=smoothstep(1.45,2.02,age)
	var p: Vector3
	if index==0:
		p=Vector3(cos(theta)*53,sin(theta)*101,0).rotated(Vector3.UP,-0.20)
		p=p.rotated(Vector3.FORWARD,-0.08)
	elif index==1:
		p=Vector3(cos(theta)*57,sin(theta)*100,0).rotated(Vector3.UP,0.84+(1-phase)*0.35+close*0.4)
		p=p.rotated(Vector3.FORWARD,0.27+(1-phase)*0.3-close*0.35)
	else:
		p=Vector3(cos(theta)*79,sin(theta)*48,0).rotated(Vector3.RIGHT,0.94)
		p=p.rotated(Vector3.FORWARD,-0.52+(1-phase)*0.5+close*0.7)
	p.x*=maxf(0.025,opening())
	return p

func _project(point: Vector3) -> Vector2:
	return CENTER+Vector2(point.x,-point.y-point.z*0.18)+art_offset

func _is_front(point: Vector3) -> bool:
	# Foreground metal stays below shoulder height; no orbit passes across the face.
	return point.z>1.0 and point.y<0.0

func _accept(front: bool) -> bool:
	return render_pass=="all" or (render_pass=="front" and front) or (render_pass=="rear" and not front)

func _ring(index: int,alpha: float) -> void:
	var width: float=[3.4,2.6,2.0][index]
	for segment in range(112):
		var a:=segment*TAU/112.0
		var p:=_point(a,index)
		var q:=_point(a+TAU/112.0,index)
		if not _accept(_is_front((p+q)*0.5)):continue
		var start:=_project(p);var end:=_project(q)
		var side: Vector2=(end-start).normalized().orthogonal()*width*0.5
		var shine:=clampf(0.48+0.30*cos(a+0.7)+0.15*sin(a*3+age*0.32),0.0,1.0)
		var color:=BRASS_DARK.lerp(BRASS_LIGHT,shine)
		draw_colored_polygon(PackedVector2Array([start-side,end-side,end+side,start+side]),Color(color,alpha))
		draw_line(start-side,end-side,Color(BRASS_LIGHT,alpha*0.85),0.75,true)
		draw_line(start+side,end+side,Color(BRASS_DARK,alpha*0.9),0.65,true)
	if index==0:
		for tick in range(56):
			var theta:=tick*TAU/56.0
			var p:=_point(theta,0)
			if not _accept(_is_front(p)):continue
			var inward:=(_project(Vector3.ZERO)-_project(p)).normalized()
			var at:=_project(p)+inward*3.0
			draw_line(at,at+inward*(4.5 if tick%7==0 else 2.1),Color(BRASS_DARK,alpha*0.85),0.75,true)
	for orb in range(2 if index==0 else 1):
		var theta:=0.8+index*1.7+orb*PI+age*(0.21+index*0.06)
		var p:=_point(theta,index)
		if not _accept(_is_front(p)):continue
		var at:=_project(p)
		var radius:=4.7 if index==0 else 3.8
		draw_circle(at+Vector2(0.8,1.0),radius+1.0,Color(BRASS_DARK,alpha),true,-1,true)
		draw_circle(at,radius,Color(BRASS_LIGHT,alpha),true,-1,true)
		draw_circle(at,radius-1.2,Color("284d68")*Color(1,1,1,alpha),true,-1,true)
		draw_circle(at+Vector2(-0.8,-0.9),radius*0.42,Color("78b5c5")*Color(1,1,1,alpha),true,-1,true)
		draw_circle(at+Vector2(-1.5,-1.7),0.8,Color("fff7dc")*Color(1,1,1,alpha),true,-1,true)

func _floor() -> void:
	var alpha:=smoothstep(0.0,0.28,age)*(1.0-smoothstep(1.75,DURATION,age))
	if alpha<=0.001:return
	draw_set_transform(art_offset+Vector2(0,2),0,Vector2(1,0.36))
	for halo in range(6,0,-1):
		draw_circle(Vector2.ZERO,40+halo*4,Color(0.91,0.72,0.39,alpha*0.010))
	for radius in [45.0,57.0]:
		draw_arc(Vector2.ZERO,radius,0,TAU*smoothstep(0.0,0.30,age),96,Color(BRASS,alpha*0.67),0.9,true)
	for i in range(24):
		var v:=Vector2.from_angle(i*TAU/24.0)
		draw_line(v*58,v*(62 if i%6==0 else 60),Color(BRASS,alpha*0.7),0.7,true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if age<=0 or age>=DURATION:return
	if render_pass!="front":_floor()
	var alpha:=strength()
	if alpha>0.001:
		for ring in range(3):_ring(ring,alpha)
		if render_pass!="front":
			var constellation:=PackedVector2Array([Vector2(-22,-53),Vector2(-16,-93),Vector2(16,-135),Vector2(29,-89)])
			for i in range(constellation.size()):
				var p:=constellation[i]
				p.x*=opening();p+=art_offset
				if i>0:
					var previous:=constellation[i-1];previous.x*=opening();previous+=art_offset
					draw_line(previous,p,Color(0.55,0.73,0.81,alpha*0.28),0.7,true)
				draw_circle(p,0.9,Color(0.87,0.91,0.83,alpha*0.7),true,-1,true)
			var rim:=PackedVector2Array()
			for i in range(97):
				var a:=i*TAU/96.0
				rim.append(CENTER+Vector2(cos(a)*47*opening(),sin(a)*93)+art_offset)
			draw_polyline(rim,Color(0.78,0.88,0.85,alpha*0.7),0.85,true)
	if render_pass!="front":
		var particles:=smoothstep(0.10,0.55,age)*(1.0-smoothstep(1.93,DURATION,age))
		for i in range(17):
			var t:=fposmod(age*0.28+i*0.137,1.0)
			var at:=CENTER+Vector2(sin(i*2.4)*62*opening(),102-t*211)+art_offset
			var a:=particles*sin(t*PI)*0.7
			draw_circle(at,0.7+float(i%3)*0.25,Color(0.96,0.88,0.64,a),true,-1,true)
