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

func configure(source:PackedVector2Array,outer_edge:PackedVector2Array,playable:bool) -> void:
	available=playable
	for vertex in source:source_center+=vertex
	source_center/=source.size()
	for vertex in source:polygon.append(vertex-source_center)
	for vertex in outer_edge:edge.append(vertex-source_center)
	font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	ink.shader=preload("res://shaders/crystal_universe.gdshader")
	ink.set_shader_parameter("kind",5)
	ink.set_shader_parameter("piece_origin",source_center)
	inside.polygon=polygon;inside.material=ink;add_child(inside)
	add_child(details);details.draw.connect(_draw_details)

func update_look(time:float,power:float,split:float,hover:float,crack:float) -> void:
	charge=power;revealed=split;hovered=hover;fracture=crack
	ink.set_shader_parameter("clock",time)
	ink.set_shader_parameter("charge",power)
	# Locked fragments retain dim starlight rather than advertising extra worlds.
	inside.modulate=Color.WHITE.lerp(Color(0.56,0.66,0.80),revealed if not available else 0.0)
	queue_redraw();details.queue_redraw()

func hit_test(at:Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(at),polygon)

func _draw() -> void:
	var glow:float=fracture*0.018+revealed*(0.006+hovered*0.010)+charge*0.015
	for i in range(6,0,-1):
		var shape:=PackedVector2Array()
		for vertex in polygon:shape.append(vertex*(1.0+i*0.027))
		draw_colored_polygon(shape,Color(color,glow))

func _draw_details() -> void:
	var facet:=PackedVector2Array([polygon[0],polygon[1],Vector2.ZERO])
	details.draw_colored_polygon(facet,Color(color,0.08+charge*0.08))
	# Internal cuts are nearly invisible at rest and brighten only when cracking.
	var alpha:=clampf(fracture*0.75+revealed*0.78+charge,0,1)
	var outline:=polygon+PackedVector2Array([polygon[0]])
	details.draw_polyline(outline,Color(color,alpha*0.09),9.0,true)
	details.draw_polyline(outline,Color("d6fff2")*Color(1,1,1,alpha),1.1,true)
	details.draw_polyline(edge,Color("f3dfb2").lerp(Color.WHITE,charge),1.6,true)
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
