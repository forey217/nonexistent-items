extends Node2D
## Shared hand-drawn rift; its clock is owned by the arrival controller.
var age := 0.0

func _draw() -> void:
	var opening:=smoothstep(0.0,0.22,age)*(1.0-smoothstep(0.72,1.10,age))
	if opening<0.001:return
	var points:=PackedVector2Array([Vector2(-2,0),Vector2(-12,-16),Vector2(-9,-39),Vector2(-20,-62),Vector2(-7,-88),Vector2(1,-134),Vector2(13,-103),Vector2(8,-80),Vector2(18,-54),Vector2(10,-28),Vector2(4,-9)])
	for layer in range(3,0,-1):
		draw_set_transform(Vector2(0,-56),0,Vector2(opening*(1.0+layer*0.28),1.0+layer*0.025))
		var shifted:=PackedVector2Array()
		for p in points:shifted.append(p+Vector2(0,56))
		draw_colored_polygon(shifted,Color(0.40,0.75,0.82,0.045*float(4-layer)*opening))
	draw_set_transform(Vector2.ZERO,0,Vector2(opening,1.0))
	draw_colored_polygon(points,Color(0.12,0.20,0.32,opening*0.94))
	draw_polyline(points+PackedVector2Array([points[0]]),Color(0.61,0.86,0.88,opening),2.0,true)
	var seam:=PackedVector2Array([Vector2(0,-3),Vector2(4,-29),Vector2(-4,-54),Vector2(5,-79),Vector2(0,-106),Vector2(1,-131)])
	draw_polyline(seam,Color(0.91,0.96,0.85,opening*0.9),1.5,true)
	for i in range(8):
		var t:=fposmod(age*0.65+float(i)*0.13,1.0)
		var at:=Vector2(sin(float(i)*2.4+age*3.0)*(12.0+t*10.0),-t*123.0)
		draw_circle(at,1.0+float(i%2)*0.4,Color(0.70,0.87,0.91,opening*(1.0-t)*0.8))
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.42))
	draw_arc(Vector2.ZERO,22.0+opening*3.0,0,TAU,48,Color(0.70,0.77,0.58,opening*0.65),1.4,true)
	draw_set_transform(Vector2.ZERO)
