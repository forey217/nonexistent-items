extends Node2D
## A floor destination, drawn in room space so camera movement cannot detach it.
var age := 0.0

func _process(delta: float) -> void:
	if not visible:return
	age+=delta
	queue_redraw()

func contains_point(world: Vector2) -> bool:
	return ((world-global_position)/Vector2(34,27)).length_squared()<=1.0

func _draw() -> void:
	var pulse:=0.75+0.25*sin(age*2.1)
	var gold:=Color("bd9859")
	var light:=Color("fff1c9")
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.48))
	for ring in range(7,0,-1):
		draw_circle(Vector2.ZERO,23+ring*2,Color(0.94,0.71,0.33,0.014*pulse))
	draw_arc(Vector2.ZERO,27,0,TAU,80,Color(gold,0.7),1.2,true)
	draw_arc(Vector2.ZERO,22,age*0.25,age*0.25+PI*1.4,60,Color(light,0.95),1.8,true)
	for i in range(4):
		var direction:=Vector2.from_angle(i*PI*0.5)
		draw_line(direction*29,direction*33,Color(gold,0.9),1.2,true)
	draw_set_transform(Vector2.ZERO)
	var tip:=Vector2(0,-11-3*sin(age*2.1))
	var diamond:=PackedVector2Array([tip+Vector2(0,-18),tip+Vector2(7,-9),tip,tip+Vector2(-7,-9),tip+Vector2(0,-18)])
	draw_colored_polygon(diamond,Color(0.22,0.38,0.43,0.8))
	draw_polyline(diamond,light,1.5,true)
	draw_line(tip+Vector2(0,-13),tip+Vector2(0,-5),Color(gold,0.95),1.3,true)
