extends Node2D

const ORIGIN := Vector2(640, 220)
const AXIS_U := Vector2(52, 26)
const AXIS_V := Vector2(-52, 26)
var show_rug := true
var indoor_mode := false
var panoramic_mode := false
var stone: Texture2D

func iso(u: float, v: float) -> Vector2:
	return ORIGIN + AXIS_U * u + AXIS_V * v

func _draw() -> void:
	if panoramic_mode:
		_draw_continuous_hall()
		return
	var floor_shape := PackedVector2Array([iso(0,0), iso(9,0), iso(9,9), iso(0,9)])
	if indoor_mode:
		_draw_interior(floor_shape)
		return
	# A visible three-layer floating deck; the upper plane stays at the old coordinates.
	for index in range(2):
		var a: Vector2=iso(9,0) if index==0 else iso(9,9)
		var b: Vector2=iso(9,9) if index==0 else iso(0,9)
		var side:=PackedVector2Array([a,b,b+Vector2(0,51),a+Vector2(0,51)])
		draw_colored_polygon(side,Color("354a60") if index==0 else Color("263b50"))
		for y in [5.0,44.0,51.0]:
			draw_line(a+Vector2(0,y),b+Vector2(0,y),Color("bda36d"),3 if y!=44 else 2,true)
		for j in range(9):
			var start:=a.lerp(b,(j+0.13)/9.0)+Vector2(0,13)
			var end:=a.lerp(b,(j+0.87)/9.0)+Vector2(0,13)
			var panel:=PackedVector2Array([start,end,end+Vector2(0,23),start+Vector2(0,23)])
			draw_polyline(panel+PackedVector2Array([panel[0]]),Color("587083"),1.1,true)
			draw_line(start+Vector2(0,28),end+Vector2(0,28),Color("7ecbd6"),1.4,true)
	for u in range(9):
		for v in range(9):
			var tile := PackedVector2Array([iso(u,v), iso(u+1,v), iso(u+1,v+1), iso(u,v+1)])
			var shade := Color("e7dfd0") if (u+v)%2 == 0 else Color("ded5c5")
			if show_rug and u >= 3 and u <= 7 and v >= 4 and v <= 7:
				shade = Color("8195a1") if (u+v)%2 == 0 else Color("7b8e9a")
			draw_colored_polygon(tile, shade)
			draw_polyline(tile + PackedVector2Array([tile[0]]), Color(0.37,0.34,0.29,0.20), 1.0, true)
	var rug := PackedVector2Array([iso(3,4),iso(8,4),iso(8,8),iso(3,8),iso(3,4)])
	if show_rug:draw_polyline(rug, Color("bea16b"), 2.5, true)
	draw_polyline(floor_shape + PackedVector2Array([floor_shape[0]]), Color("746a5a"), 2.0, true)
	# Shallow safety curbs communicate the unchanged walkable boundary.
	for endpoint in [iso(0,9),iso(9,0)]:
		draw_line(ORIGIN,endpoint,Color("b9a16d"),5,true)
		draw_line(ORIGIN-Vector2(0,5),endpoint-Vector2(0,5),Color("b9e7e7"),2,true)
		for j in range(10):
			var at:=ORIGIN.lerp(endpoint,float(j)/9)
			draw_line(at,at-Vector2(0,11),Color("c4b080"),3,true)

func _draw_interior(shape: PackedVector2Array) -> void:
	if stone==null:stone=load("res://assets/interior_v30/ivory_floor.png")
	for edge in [[shape[1],shape[2]],[shape[2],shape[3]]]:
		var side:=PackedVector2Array([edge[0],edge[1],edge[1]+Vector2(0,16),edge[0]+Vector2(0,16)])
		draw_colored_polygon(side,Color("263643"))
		draw_line(edge[0]+Vector2(0,14),edge[1]+Vector2(0,14),Color("bba472"),2,true)
	draw_polygon(shape,PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(0,0),Vector2(2,0),Vector2(2,2),Vector2(0,2)]),stone)
	for u in range(10):draw_line(iso(u,0),iso(u,9),Color(0.36,0.32,0.25,0.14),0.8,true)
	for v in range(10):draw_line(iso(0,v),iso(9,v),Color(0.36,0.32,0.25,0.14),0.8,true)
	var inset:=PackedVector2Array([iso(0.22,0.22),iso(8.78,0.22),iso(8.78,8.78),iso(0.22,8.78),iso(0.22,0.22)])
	draw_polyline(inset,Color("b7a77e"),1.7,true)
	draw_polyline(shape+PackedVector2Array([shape[0]]),Color("8b7957"),2,true)

func _draw_continuous_hall() -> void:
	if stone==null:stone=load("res://assets/interior_v30/ivory_floor.png")
	var ground:=PackedVector2Array([iso(0,0),iso(42,0),iso(42,42),iso(0,42)])
	draw_polygon(ground,PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(0,0),Vector2(10,0),Vector2(10,10),Vector2(0,10)]),stone)
	for i in range(0,43,2):
		draw_line(iso(i,0),iso(i,42),Color(0.32,0.29,0.23,0.15),1,true)
		draw_line(iso(0,i),iso(42,i),Color(0.32,0.29,0.23,0.15),1,true)
	# An occupied waiting bay and a restrained instrument inlay divide the floor.
	var rug:=PackedVector2Array([iso(1.0,8.3),iso(4.9,8.3),iso(4.9,11.3),iso(1.0,11.3)])
	draw_colored_polygon(rug,Color("b5ac96"))
	draw_polyline(rug+PackedVector2Array([rug[0]]),Color("8f7b57"),2,true)
	for inset in [0.12,0.24]:
		var line:=PackedVector2Array([iso(1+inset,8.3+inset),iso(4.9-inset,8.3+inset),iso(4.9-inset,11.3-inset),iso(1+inset,11.3-inset),iso(1+inset,8.3+inset)])
		draw_polyline(line,Color(0.87,0.81,0.66,0.75),1,true)
	for radius in [Vector2(86,43),Vector2(94,47)]:
		var ring:=PackedVector2Array()
		for i in range(81):
			var a:=float(i)/80*TAU
			ring.append(iso(7.3,2)+Vector2(0,17)+Vector2(cos(a),sin(a))*radius)
		draw_polyline(ring,Color("ac9668"),1.5,true)
