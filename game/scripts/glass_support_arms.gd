extends Node2D
## Projected mechanical scenery: mounts follow the live deck; collars touch the glass rim.
## Behind the room render so struts cannot cover the actor or receive input.
const GLASS_CENTER := Vector2(659,385)
const GLASS_RADII := Vector2(598,353)
var view: Node2D
var mounts: Array[Vector3]=[Vector3(0,-0.40,2),Vector3(12,-0.40,2),Vector3(2,-0.40,8),Vector3(10,-0.40,8)]
var light_color := Color("addde5")

func _ready() -> void:
	z_index=-15

func _process(delta: float) -> void:
	var target: Color=[Color("addde5"),Color("e2c38b"),Color("c7b6e9")][view.room.state.world]
	light_color=light_color.lerp(target,1.0-exp(-delta*4.0))
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(view) or not view.camera.is_inside_tree():return
	for i in range(mounts.size()):
		var base: Vector2=view.camera.unproject_position(mounts[i])
		var radial: Vector2=(base-GLASS_CENTER)/GLASS_RADII
		var contact:=GLASS_CENTER+radial.normalized()*GLASS_RADII
		var direction: Vector2=(contact-base).normalized()
		var tangent:=direction.orthogonal()
		var elbow:=base.lerp(contact,0.47)+tangent*(13.0 if i%2==0 else -13.0)
		_glass_socket(contact,direction,i)
		# Twin trusses, an articulated knuckle and an inset telescopic piston.
		_beam(base+tangent*7,elbow+tangent*6,6,Color("526a79"))
		_beam(base-tangent*7,elbow-tangent*6,6,Color("526a79"))
		for j in [0.25,0.65]:
			var at:=base.lerp(elbow,j)
			_beam(at-tangent*8,at+tangent*8,3,Color("bfa46a"))
		_beam(base,elbow,5,Color("b6c6c9"))
		_beam(elbow,contact+direction*7,13,Color("3b5265"))
		_beam(elbow+direction*7,contact-direction*11,6,Color("c0cfd0"))
		draw_line(elbow+direction*10,contact-direction*14,light_color,1.8,true)
		for j in [0.13,0.66,0.88]:
			var at:=elbow.lerp(contact,j)
			_beam(at-direction*3,at+direction*3,17,Color("b6a071"))
		_joint(base,11)
		_joint(elbow,8)
		# The pin continues past the rim; white glass lips occlude its edges.
		_beam(contact-direction*4,contact+direction*8,7,Color("d0ba80"))
		draw_line(contact+tangent*10-direction*3,contact+tangent*4+direction*2,Color("e1f8ff"),1.6,true)
		draw_line(contact-tangent*10-direction*3,contact-tangent*4+direction*2,Color("e1f8ff"),1.6,true)

func _beam(a: Vector2,b: Vector2,width: float,color: Color) -> void:
	if a.distance_squared_to(b)<0.01:return
	var side: Vector2=(b-a).orthogonal().normalized()*width*0.5
	var face:=PackedVector2Array([a-side,b-side,b+side,a+side])
	var extrusion:=Vector2(2.5,4.5)
	draw_colored_polygon(PackedVector2Array([a+side,b+side,b+side+extrusion,a+side+extrusion]),color.darkened(0.42))
	draw_colored_polygon(face,color)
	draw_polyline(face+PackedVector2Array([face[0]]),Color("253c4c"),1.1,true)
	draw_line(a-side,b-side,color.lightened(0.28),1.3,true)

func _joint(at: Vector2,radius: float) -> void:
	draw_circle(at+Vector2(2,4),radius+1,Color("233747"))
	draw_circle(at,radius,Color("bba16c"))
	draw_arc(at,radius-2,0,TAU,28,Color("dfca91"),1.2,true)
	draw_circle(at,radius*0.48,Color("354d61"))
	draw_line(at-Vector2(2,1),at+Vector2(2,1),Color("bdced0"),1.5,true)

func _glass_socket(at: Vector2,normal: Vector2,index: int) -> void:
	var tangent:=normal.orthogonal()
	var lens:=PackedVector2Array()
	for i in range(49):
		var angle:=float(i)/48*TAU
		lens.append(at+tangent*cos(angle)*19+normal*sin(angle)*10)
	draw_colored_polygon(lens,Color(0.70,0.90,0.97,0.15))
	draw_polyline(lens,Color(0.79,0.96,1,0.65),1.4,true)
	# Local branching cracks, kept small so the shell feels strained, not shattered.
	for branch in range(5):
		var angle:=float(branch)/5.0*TAU+index*0.49
		var axis: Vector2=tangent*cos(angle)+normal*sin(angle)*0.60
		var distance:=25.0+float((branch*7+index*5)%17)
		var mid:=at+axis*distance*0.58
		var end:=at+axis*distance+tangent*(3.0 if branch%2 else -4.0)
		_crack(PackedVector2Array([at+axis*5,mid,end]))
		var split:=mid+(axis.rotated(0.61 if branch%2 else -0.54))*10.0
		_crack(PackedVector2Array([mid,split]))
	draw_circle(at,6,Color(0.10,0.22,0.30,0.70))
	draw_arc(at,8,-2.8,-0.3,20,Color("d4f5fc"),1.8,true)

func _crack(points: PackedVector2Array) -> void:
	draw_polyline(points,Color(0.11,0.25,0.34,0.62),2.5,true)
	draw_polyline(points,Color(0.84,0.97,1,0.77),1.05,true)
