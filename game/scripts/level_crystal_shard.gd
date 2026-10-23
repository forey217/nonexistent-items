extends Node2D
## 2D flight handles, physical 3D glass, and picking from the actual projected hull.
var polygon:=PackedVector2Array()
var source_center:=Vector2.ZERO
var edge:=PackedVector2Array()
var available:=false
var level_number:="01"
var level_name:="新手校准室"
var revealed:=0.0
var charge:=0.0
var hovered:=0.0
var fracture:=0.0
var lock_pulse:=0.0
var color:=Color("a7e5eb")
var freedom:=0.0
var pose_phase:=0.0
var surface_basis:=Transform2D.IDENTITY
var thickness:=Vector2(17,11)
var body:=Node3D.new()
var mesh:=MeshInstance3D.new()
var ink:=ShaderMaterial.new()
var camera:Camera3D
var solid_vertices:=PackedVector3Array()
var projected:=PackedVector2Array()
var front_projected:=PackedVector2Array()
var side_projected:Array[PackedVector2Array]=[]
var font=preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf")

func configure(source:PackedVector2Array,outer_edge:PackedVector2Array,playable:bool) -> void:
	available=playable
	for point in source:source_center+=point
	source_center/=source.size()
	for point in source:polygon.append(point-source_center)
	for point in outer_edge:edge.append(point-source_center)
	pose_phase=source_center.x*0.027+source_center.y*0.019
	ink.shader=preload("res://shaders/star_glass.gdshader")
	ink.set_shader_parameter("observatory",preload("res://assets/observatory_v45/sealed_observatory.png"))
	ink.set_shader_parameter("glass_paint",preload("res://assets/observatory_v45/star_glass_paint.png"))
	ink.set_shader_parameter("piece_origin",source_center)
	ink.set_shader_parameter("unlocked",1.0 if available else 0.0)
	mesh.mesh=_build_solid();mesh.material_override=ink
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)

func attach_renderer(renderer:Node2D) -> void:
	renderer.world.add_child(body);camera=renderer.camera
	ink.set_shader_parameter("vignette",load("res://assets/observatory_v45/level_02.png" if level_number=="02" else "res://assets/observatory_v45/level_01.png"))

func crown(point:Vector2) -> float:
	return 17.0+21.0*maxf(0,1.0-pow(absf(point.x)/112.0,1.5))+6.0*maxf(0,1.0-absf(point.y)/165.0)

func _build_solid() -> ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inset:=PackedVector2Array()
	var bounds:=Rect2(polygon[0],Vector2.ZERO)
	for p in polygon:bounds=bounds.expand(p)
	for p in polygon:inset.append(p.move_toward(Vector2.ZERO,3.1))
	var triangulation:=Geometry2D.triangulate_polygon(inset)
	for j in range(0,triangulation.size(),3):
		var points:Array[Vector3]=[]
		for k in range(3):
			var p:Vector2=inset[triangulation[j+k]]
			points.append(Vector3(p.x,-p.y,crown(p+source_center)))
		_triangle(surface,points,Color(1,0,0),bounds)
	for i in range(polygon.size()):
		var next:=(i+1)%polygon.size()
		var p:Vector2=polygon[i];var q:Vector2=polygon[next]
		var a:=Vector3(p.x,-p.y,crown(p+source_center)-4.0)
		var b:=Vector3(q.x,-q.y,crown(q+source_center)-4.0)
		var c:=Vector3(inset[next].x,-inset[next].y,crown(inset[next]+source_center))
		var d:=Vector3(inset[i].x,-inset[i].y,crown(inset[i]+source_center))
		var edge_finish:=Color(1 if i<2 else 0,1,0)
		_triangle(surface,[a,b,c],edge_finish,bounds);_triangle(surface,[a,c,d],edge_finish,bounds)
		var back_a:=Vector3(p.x*0.93,-p.y*0.93,-18)
		var back_b:=Vector3(q.x*0.93,-q.y*0.93,-18)
		_triangle(surface,[a,back_a,back_b],Color(1,0,1),bounds);_triangle(surface,[a,back_b,b],Color(1,0,1),bounds)
		solid_vertices.append(a);solid_vertices.append(back_a)
	surface.generate_normals()
	return surface.commit()

func _triangle(surface:SurfaceTool,points:Array[Vector3],finish:Color,bounds:Rect2) -> void:
	for point in points:
		surface.set_color(finish)
		surface.set_uv((Vector2(point.x,-point.y)-bounds.position)/bounds.size)
		surface.add_vertex(point)

func update_look(time:float,power:float,split:float,over:float,crack:float,spread:float=-1.0) -> void:
	charge=power;revealed=split;fracture=crack
	hovered=move_toward(hovered,over,0.12)
	freedom=split if spread<0 else spread
	var yaw:=lerpf(-0.22,-0.20+sin(time*0.44+pose_phase)*0.14,freedom)+hovered*0.055
	var pitch:=lerpf(0.06,0.07+sin(time*0.33+pose_phase)*0.09,freedom)
	var tilt:=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)
	var planar:=Basis(Vector3.BACK,-rotation)
	var basis:=planar*Basis.from_scale(Vector3(scale.x,scale.y,(scale.x+scale.y)*0.5))*tilt
	var offset:=Vector3(source_center.x,-source_center.y,0)*(1.0-freedom)
	body.transform=Transform3D(basis,Vector3(position.x-640,400-position.y,0)+basis*offset-planar*(Vector3(offset.x*scale.x,offset.y*scale.y,0)))
	ink.set_shader_parameter("clock",time);ink.set_shader_parameter("reveal",split)
	ink.set_shader_parameter("hover",hovered);ink.set_shader_parameter("charge",power)
	ink.set_shader_parameter("fracture",crack)
	ink.set_shader_parameter("lock_pulse",lock_pulse);ink.set_shader_parameter("opacity",modulate.a)
	body.visible=visible and modulate.a>0.001
	if is_instance_valid(camera):
		projected.clear();front_projected.clear();side_projected.clear()
		for v in solid_vertices:projected.append(camera.unproject_position(body.transform*v))
		projected=Geometry2D.convex_hull(projected)
		for p in polygon:front_projected.append(camera.unproject_position(body.transform*Vector3(p.x,-p.y,crown(p+source_center))))
		for i in range(solid_vertices.size()/2):
			var next:=(i+1)%(solid_vertices.size()/2)
			side_projected.append(PackedVector2Array([
				camera.unproject_position(body.transform*solid_vertices[i*2]),camera.unproject_position(body.transform*solid_vertices[next*2]),
				camera.unproject_position(body.transform*solid_vertices[next*2+1]),camera.unproject_position(body.transform*solid_vertices[i*2+1])]))
	queue_redraw()

func hit_test(at:Vector2) -> bool:
	if projected.size()<3:return false
	var local:Vector2=get_parent().to_local(at)
	if Geometry2D.is_point_in_polygon(local,front_projected):return true
	return side_projected.any(func(side):return Geometry2D.is_point_in_polygon(local,side))

func _draw() -> void:
	if not is_instance_valid(camera) or revealed<0.01:return
	var at:Vector2=to_local(get_parent().to_global(camera.unproject_position(body.transform*Vector3(0,0,48))))
	var alpha:=revealed*(1.0-charge)
	var badge:=Color("f6e7c4");badge.a=alpha
	if not available:
		draw_circle(at+Vector2(1,2),18,Color(0.02,0.10,0.16,0.28*alpha))
		draw_string(font,at+Vector2(-9,11),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,32,badge)
	else:
		var label_at:=at+Vector2(0,35)
		draw_circle(label_at,14,Color(0.015,0.08,0.14,0.8*alpha))
		draw_arc(label_at,14,0,TAU,40,Color(0.89,0.79,0.53,alpha*0.8),0.8,true)
		draw_string(font,label_at+Vector2(-10,5),level_number,HORIZONTAL_ALIGNMENT_LEFT,-1,15,badge)
