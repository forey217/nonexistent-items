extends Node2D
var SHAPE:=PackedVector2Array([Vector2(-7,-118),Vector2(65,-62),Vector2(54,42),Vector2(14,114),Vector2(-62,60),Vector2(-74,-42)])
var kind:=0
var tint:=Color("8bdce9")
var clock:=0.0
var charge:=0.0
var primary:=false
var ink:=ShaderMaterial.new()
var inside:=Polygon2D.new()

func configure(world:int,color:Color,main:=false) -> void:
	kind=world;tint=color;primary=main
	ink.shader=preload("res://shaders/crystal_universe.gdshader")
	ink.set_shader_parameter("kind",world)
	inside.polygon=SHAPE
	inside.material=ink
	add_child(inside)
	var detail:=Node2D.new()
	add_child(detail)
	detail.draw.connect(_draw_facets)

func update_look(time:float,power:float) -> void:
	clock=time;charge=power
	ink.set_shader_parameter("clock",time)
	ink.set_shader_parameter("charge",power)
	queue_redraw()
	get_child(1).queue_redraw()

func _draw() -> void:
	for i in range(7,0,-1):
		var shape:=PackedVector2Array()
		for vertex in SHAPE:shape.append(vertex*(1.0+i*0.033))
		draw_colored_polygon(shape,Color(tint,(0.014+charge*0.014)*(1.0+float(7-i)*0.08)))

func _draw_facets() -> void:
	var canvas:Node2D=get_child(1)
	var seam:=Vector2(-4,7)
	# Transparent glass planes keep the universe visible through the crystal.
	canvas.draw_colored_polygon(PackedVector2Array([SHAPE[0],SHAPE[1],seam,SHAPE[5]]),Color(tint,0.12))
	canvas.draw_colored_polygon(PackedVector2Array([SHAPE[1],SHAPE[2],SHAPE[3],seam]),Color(0.78,0.93,1.0,0.11))
	canvas.draw_colored_polygon(PackedVector2Array([SHAPE[3],SHAPE[4],seam]),Color(0.02,0.05,0.12,0.24))
	canvas.draw_polyline(SHAPE+PackedVector2Array([SHAPE[0]]),Color("e9d8ae").lerp(Color.WHITE,charge),1.7,true)
	for i in [0,1,3,4,5]:canvas.draw_line(SHAPE[i],seam,Color(tint,0.28+charge*0.24),0.8,true)
	canvas.draw_line(SHAPE[0]+Vector2(0,12),SHAPE[5]+Vector2(7,1),Color("e4fafb"),1.8,true)
	var crack:=PackedVector2Array([Vector2(-7,-99),Vector2(-16,-53),Vector2(3,-17),Vector2(-9,22),Vector2(8,59),Vector2(13,96)])
	canvas.draw_polyline(crack,Color(tint,0.14+charge*0.15),8.0,true)
	canvas.draw_polyline(crack,Color("d8fff4").lerp(Color.WHITE,charge),1.9 if not primary else 2.6,true)
	if primary:
		canvas.draw_arc(Vector2(0,-4),31.0,0,TAU,60,Color(tint,0.35+charge*0.3),0.9,true)
		for i in range(3):
			var angle:=clock*0.16+i*TAU/3
			var at:=Vector2.from_angle(angle)*31+Vector2(0,-4)
			canvas.draw_circle(at,2.0,Color("fff3ce"),true,-1,true)
