extends Node2D
## Pre-rendered 2D architecture with live puzzle instrumentation.
var room: Node2D
var clock:=0.0
var font:=SystemFont.new()
var backgrounds: Array[Texture2D]=[]

func _ready() -> void:
	font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	for i in range(3): backgrounds.append(load("res://assets/calibration_v03/room-%d.png"%i))

func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()

func p(u: float,v: float) -> Vector2:return room.iso(u,v)

func shape(points: PackedVector2Array,fill: Color,line: Color,width: float=1.0) -> void:
	draw_colored_polygon(points,fill)
	draw_polyline(points+PackedVector2Array([points[0]]),line,width,true)

func tile(u: float,v: float,w: float,h: float) -> PackedVector2Array:
	return PackedVector2Array([p(u,v),p(u+w,v),p(u+w,v+h),p(u,v+h)])

func _draw() -> void:
	if room==null or backgrounds.is_empty():return
	var world: int=room.state.world
	draw_texture_rect(backgrounds[world],Rect2(0,0,1280,800),false)
	var amber:=Color("a28a5d")
	var active:=Color("60bca8")
	var cable:=PackedVector2Array([p(6.8,1.3),p(6.8,3.85),p(9.9,3.85),p(9.9,2.0),room.portal_position])
	draw_polyline(cable,Color("485c65"),5.0,true)
	draw_polyline(cable,active if room.state.gate_open else amber,1.4,true)
	for point in [p(6.8,3.85),p(9.9,3.85),p(9.9,2.0)]:
		draw_circle(point,4.0,Color("53636a"))
		draw_circle(point,1.8,active if room.state.gate_open else amber)
	if world==0:
		for i in range(10):
			var at:=p(1.1+float((i*7)%10),1.6+float((i*3)%6))
			draw_line(at+Vector2(-20,0),at+Vector2(13,-3),Color(0.83,0.98,1.0,0.35),1.2,true)
			draw_line(at+Vector2(13,-3),at+Vector2(23,0),Color(0.83,0.98,1.0,0.35),0.8,true)
	elif world==1:
		for at in [room.first_plate,room.rail_end]:
			for i in range(4):
				var x: float=float(i)*5
				draw_line(at+Vector2(-42+x,16+x*0.5),at+Vector2(-37+x,13+x*0.5),Color(0.29,0.22,0.18,0.25),1.0,true)
	else:
		for i in range(4):
			var at:=p(1.0+i*2.6,6.7)
			draw_set_transform(at,0,Vector2(1,0.5))
			draw_arc(Vector2.ZERO,16+sin(clock+i)*3,0.4,5.6,32,Color(0.63,0.55,0.76,0.24),1.2,true)
			draw_set_transform(Vector2.ZERO)
	# Floor engraving and warning boundary leave the walking lanes unobstructed.
	for i in range(8):
		var u:=2.3+i*0.9
		draw_line(p(u,5.7),p(u+0.38,5.7),Color(amber,0.55),2,true)
	for u in [3.1,6.6,8.5]:
		var at:=p(u,5.62)
		draw_polyline(PackedVector2Array([at+Vector2(-5,-5),at+Vector2(3,0),at+Vector2(-5,1)]),Color("8b866f"),1.5,true)
	_plate(room.first_plate,room.state.first_latched,"01")
	_plate(room.rail_end,room.state.final_pressed,"02")
	var stop: Vector2=room.first_plate+Vector2(15,-3)
	shape(PackedVector2Array([stop+Vector2(-9,-5),stop+Vector2(12,5),stop+Vector2(5,9),stop+Vector2(-16,-1)]),Color("42555c"),Color("65777c"))
	if not room.state.first_latched:
		var top:=PackedVector2Array([stop+Vector2(-9,-23),stop+Vector2(12,-13),stop+Vector2(5,-9),stop+Vector2(-16,-19)])
		shape(PackedVector2Array([top[2],top[3],top[3]+Vector2(0,18),top[2]+Vector2(0,18)]),Color("675650"),Color("3c454a"))
		shape(top,Color("c7a471"),Color("584f48"))
		for i in range(3):draw_line(stop+Vector2(-9+i*6,-17+i*3),stop+Vector2(-9+i*6,-10+i*3),Color("414750"),3,true)
	else:draw_line(stop+Vector2(-8,-2),stop+Vector2(6,5),active,2,true)
	# Rail LEDs follow the actual paperweight position.
	for i in range(20):
		var at:=p(2.12+i*0.38,5.21)-Vector2(0,13)
		var passed: bool=room.state.rail_position/room.State.RAIL_LENGTH>=float(i)/19.0
		draw_circle(at,1.6,active if passed else Color("6a7c82"))
	_floor_label(p(4.0,6.25),"OBSERVATORY / CALIBRATION 01",Color("718389"),0.78)
	if room._marker_time>0:
		draw_set_transform(room._marker,0,Vector2(1,0.5))
		draw_arc(Vector2.ZERO,12,0,TAU,32,active,2,true)
		draw_set_transform(Vector2.ZERO)
	if room.debug_visible:
		for polygon in room.obstacle_polygons():
			draw_colored_polygon(polygon,Color(0.9,0.2,0.1,0.15))
			draw_polyline(polygon+PackedVector2Array([polygon[0]]),Color("c96945"),1.6,true)
		draw_arc(room.player.position,13,0,TAU,32,Color("e55b35"),1.8,true)

func _floor_label(at: Vector2,text: String,color: Color,size: float=1.0) -> void:
	draw_set_transform_matrix(Transform2D(Vector2(size,size*0.5),Vector2(-size,size*0.5),at))
	draw_string(font,Vector2.ZERO,text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
	draw_set_transform(Vector2.ZERO)

func _plate(at: Vector2,active: bool,numeral: String) -> void:
	var corners:=PackedVector2Array([at+Vector2(0,-20),at+Vector2(36,-2),at+Vector2(0,16),at+Vector2(-36,-2)])
	var lower:=PackedVector2Array()
	for point in corners:lower.append(point+Vector2(0,5))
	shape(lower,Color("394b55"),Color("40505a"))
	shape(corners,Color("809d91") if active else Color("9e9377"),Color("455760"),1.4)
	shape(PackedVector2Array([at+Vector2(0,-14),at+Vector2(25,-2),at+Vector2(0,10),at+Vector2(-25,-2)]),Color("9bbdab") if active else Color("c8ba95"),Color("e0d4b1"))
	for offset in [Vector2(0,-17),Vector2(30,-2),Vector2(0,13),Vector2(-30,-2)]:
		draw_circle(at+offset,1.5,Color("d8d5bf"))
	draw_string(font,at+Vector2(-8,3),numeral,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("3e5359"))
	draw_line(at+Vector2(-16,12),at+Vector2(-4,18),Color("79e5bd") if active else Color("5e7074"),2,true)
