extends Node2D
## A real piece of the same crystal: shared source coordinates keep the image whole.
var polygon:=PackedVector2Array()
var source_center:=Vector2.ZERO
var edge:=PackedVector2Array()
var available:=false
var revealed:=0.0
var charge:=0.0
var hovered:=0.0
var fracture:=0.0
var lock_pulse:=0.0
var color:=Color("a7e5eb")
var ink:=ShaderMaterial.new()
var inside:=Polygon2D.new()
var details:=Node2D.new()
var font:=SystemFont.new()
var face:=Node2D.new()
var surface_basis:=Transform2D.IDENTITY
var thickness:=Vector2(17,11)
var freedom:=0.0
var pose_phase:=0.0

func configure(source:PackedVector2Array,outer_edge:PackedVector2Array,playable:bool) -> void:
	available=playable
	for vertex in source:source_center+=vertex
	source_center/=source.size()
	for vertex in source:polygon.append(vertex-source_center)
	for vertex in outer_edge:edge.append(vertex-source_center)
	pose_phase=source_center.x*0.027+source_center.y*0.019
	font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	ink.shader=preload("res://shaders/crystal_universe.gdshader")
	ink.set_shader_parameter("kind",5)
	ink.set_shader_parameter("piece_origin",source_center)
	inside.polygon=polygon;inside.material=ink
	add_child(face);face.add_child(inside);face.add_child(details)
	details.draw.connect(_draw_details)

func update_look(time:float,power:float,split:float,hover:float,crack:float,spread:float=-1.0) -> void:
	charge=power;revealed=split;hovered=hover;fracture=crack
	freedom=split if spread<0 else spread
	# A common projection keeps the joined crystal watertight. Separated pieces
	# then acquire their own small yaw/pitch, exposing changing side thickness.
	var yaw:=lerpf(-0.35+sin(time*0.38)*0.08,-0.25+sin(time*0.58+pose_phase)*0.30,freedom)
	var pitch:=lerpf(0.16+cos(time*0.29)*0.035,0.12+sin(time*0.44+pose_phase)*0.17,freedom)
	surface_basis=Transform2D(Vector2(cos(yaw),sin(yaw)*sin(pitch)*0.20),Vector2(-sin(pitch)*0.12,cos(pitch)),Vector2.ZERO)
	face.transform=surface_basis
	face.position=surface_basis.basis_xform(source_center*(1.0-freedom))-source_center*(1.0-freedom)
	thickness=Vector2(16.0-sin(yaw)*13.0,10.0+sin(pitch)*12.0)
	ink.set_shader_parameter("clock",time)
	ink.set_shader_parameter("charge",power)
	ink.set_shader_parameter("glass_finish",1.0)
	ink.set_shader_parameter("view_phase",yaw+time*0.13)
	# Locked fragments retain dim starlight rather than advertising extra worlds.
	inside.modulate=Color.WHITE.lerp(Color(0.56,0.66,0.80),revealed if not available else 0.0)
	queue_redraw();details.queue_redraw()

func hit_test(at:Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(face.to_local(at),polygon):return true
	var local:=to_local(at)
	for i in range(polygon.size()):
		var extent:=1.0 if i==0 else maxf(freedom,fracture*0.13)
		if extent<0.005:continue
		var a:Vector2=face.transform*polygon[i]
		var b:Vector2=face.transform*polygon[(i+1)%polygon.size()]
		if (b-a).orthogonal().dot(thickness)<=0:continue
		var side:=PackedVector2Array([a,b,b+thickness*extent,a+thickness*extent])
		if Geometry2D.is_point_in_polygon(local,side):return true
	return false

func _draw() -> void:
	var glow:float=fracture*0.018+revealed*(0.006+hovered*0.010)+charge*0.015
	for i in range(6,0,-1):
		var shape:=PackedVector2Array()
		for vertex in polygon:shape.append(face.transform*(vertex*(1.0+i*0.027)))
		draw_colored_polygon(shape,Color(color,glow))
	# Extruded side walls are geometry, with a darker back edge and a bevel lip.
	# Joined internal cuts have no side walls; they only become exposed on opening.
	for i in range(polygon.size()):
		var extent:=1.0 if i==0 else maxf(freedom,fracture*0.13)
		if extent<0.005:continue
		var a:Vector2=face.transform*polygon[i]
		var b:Vector2=face.transform*polygon[(i+1)%polygon.size()]
		var normal:Vector2=(b-a).orthogonal().normalized()
		if normal.dot(thickness)<=0.01:continue
		var depth:=thickness*extent
		var back_a:=a+depth;var back_b:=b+depth
		var light:=clampf(0.46+normal.dot(Vector2(-0.65,-0.76))*0.45,0.08,0.9)
		var near_color:=Color("28627f").lerp(Color("8bd5e2"),light).lerp(Color("e6fff3"),charge*0.85)
		var far_color:=Color("0b1d3c").lerp(Color("376780"),light).lerp(Color("bdede5"),charge*0.75)
		draw_polygon(PackedVector2Array([a,b,back_b,back_a]),PackedColorArray([near_color,near_color,far_color,far_color]))
		draw_line(back_a,back_b,Color("4a8199").lerp(Color("e6fff5"),charge),0.9,true)
		draw_line(b,back_b,Color(0.24,0.53,0.64,0.62),0.8,true)
		var mid_a:=a+depth*0.23;var mid_b:=b+depth*0.23
		draw_line(mid_a,mid_b,Color(0.55,0.86,0.90,0.31),0.8,true)

func _draw_details() -> void:
	# Broad lit and shaded face planes plus an inset bevel give the front a crown.
	for i in range(polygon.size()):
		var a:Vector2=polygon[i];var b:Vector2=polygon[(i+1)%polygon.size()]
		var normal:Vector2=(b-a).orthogonal().normalized()
		var light:=normal.dot(Vector2(-0.65,-0.76))
		var face_color:=Color(0.69,0.91,0.98,0.06+maxf(light,0)*0.13) if light>0 else Color(0.015,0.04,0.11,-light*0.22)
		details.draw_colored_polygon(PackedVector2Array([a,b,Vector2.ZERO]),face_color)
		var strength:=1.0 if i==0 else maxf(freedom,fracture*0.45)
		if strength<0.005:continue
		var inset_a:=a.lerp(Vector2.ZERO,0.10)
		var inset_b:=b.lerp(Vector2.ZERO,0.10)
		var bevel_color:=Color("346d91").lerp(Color("c7f1ef"),clampf(0.5+light*0.48,0,1)).lerp(Color.WHITE,charge)
		bevel_color.a=strength*0.88
		var inner_color:=Color(bevel_color,bevel_color.a*0.22)
		details.draw_polygon(PackedVector2Array([a,b,inset_b,inset_a]),PackedColorArray([bevel_color,bevel_color,inner_color,inner_color]))
		details.draw_line(inset_a,inset_b,Color(0.62,0.89,0.94,strength*(0.18+maxf(light,0)*0.22)),0.6,true)
	# Internal cuts are nearly invisible at rest and brighten only when cracking.
	var alpha:=clampf(fracture*0.75+revealed*0.78+charge,0,1)
	var outline:=polygon+PackedVector2Array([polygon[0]])
	details.draw_polyline(outline,Color(color,alpha*0.09),9.0,true)
	details.draw_polyline(outline,Color("d6fff2")*Color(1,1,1,alpha),1.1,true)
	details.draw_polyline(edge,Color("eff8e4").lerp(Color.WHITE,charge),1.1,true)
	if revealed>0.01:
		var mark_color:=Color("f8eed5")*Color(1,1,1,revealed*(1.0-charge))
		if available:
			details.draw_circle(Vector2.ZERO,17.0,Color(0.02,0.10,0.20,0.72*revealed))
			details.draw_arc(Vector2.ZERO,17.0,0,TAU,48,Color("d5eecf")*Color(1,1,1,revealed),0.8,true)
			details.draw_string(font,Vector2(-12,7),"01",HORIZONTAL_ALIGNMENT_LEFT,-1,19,mark_color)
			var text:="新手校准室"
			var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x
			details.draw_string(font,Vector2(-width*0.5,-28),text,HORIZONTAL_ALIGNMENT_LEFT,-1,9,mark_color)
		else:
			var question_color:=mark_color.lerp(Color("efca9e"),lock_pulse*0.6)
			details.draw_circle(Vector2.ZERO,15.0,Color(0.02,0.07,0.15,0.65*revealed))
			details.draw_string(font,Vector2(-12,10),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,31,question_color)
