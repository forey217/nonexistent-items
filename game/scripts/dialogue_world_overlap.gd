extends Control
## Three copies of the same room slide into shared space, synchronized to speech.
const FONT = preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf")
var active := false
var age := 0.0
var layer_offsets: Array[Vector2]=[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
var colors: Array[Color]=[Color("8bdbed"),Color("e6c381"),Color("c1b3f4")]

func _ready() -> void:
	position=Vector2(385,125);size=Vector2(510,400)
	mouse_filter=Control.MOUSE_FILTER_IGNORE;pivot_offset=size*0.5
	hide_demo()

func show_demo() -> void:
	if active:return
	active=true;age=0;modulate.a=0;show();set_process(true)
	_sync_layers()

func hide_demo() -> void:
	active=false;hide();set_process(false)

func _sync_layers() -> void:
	var approach:=smoothstep(0.45,2.65,age)
	# Leave a hairline registration difference so all three worlds stay legible.
	var spread:=lerpf(1.0,0.055,approach)
	layer_offsets[0]=Vector2(-55,-24)*spread
	layer_offsets[1]=Vector2.ZERO
	layer_offsets[2]=Vector2(55,24)*spread

func _process(delta: float) -> void:
	age+=delta;_sync_layers()
	var entrance:=smoothstep(0.0,0.42,age)
	modulate.a=entrance;scale=Vector2.ONE*lerpf(0.96,1.0,entrance)
	queue_redraw()

func project(x: float,z: float,height: float=0) -> Vector2:
	return Vector2((x-z)*31,(x+z)*14-height*48)

func stroke(points: PackedVector2Array,color: Color,width: float=1.3,closed: bool=false) -> void:
	if closed:points=points+PackedVector2Array([points[0]])
	draw_polyline(points,color,width,true)

func box(at: Vector2,width: float,depth: float,height: float,color: Color) -> void:
	var a:=at+project(-width*0.5,-depth*0.5)
	var b:=at+project(width*0.5,-depth*0.5)
	var c:=at+project(width*0.5,depth*0.5)
	var d:=at+project(-width*0.5,depth*0.5)
	var up:=Vector2(0,-height*48)
	draw_colored_polygon(PackedVector2Array([d,c,c+up,d+up]),Color(color,0.13))
	draw_colored_polygon(PackedVector2Array([b,c,c+up,b+up]),Color(color,0.10))
	draw_colored_polygon(PackedVector2Array([a+up,b+up,c+up,d+up]),Color(color,0.16))
	stroke(PackedVector2Array([a+up,b+up,c+up,d+up]),Color(color,0.92),1.3,true)
	for point in [b,c,d]:draw_line(point,point+up,Color(color,0.7),1,true)

func room(index: int) -> void:
	var origin:=Vector2(255,174)+layer_offsets[index]
	var ink:=colors[index]
	var corners:=PackedVector2Array([origin+project(-2.5,-2.0),origin+project(2.5,-2.0),origin+project(2.5,2.0),origin+project(-2.5,2.0)])
	draw_colored_polygon(corners,Color(ink,0.075))
	stroke(corners,Color(ink,0.85),1.5,true)
	var up:=Vector2(0,-93)
	for pair in [[0,1],[0,3]]:
		var a: Vector2=corners[pair[0]];var b: Vector2=corners[pair[1]]
		draw_colored_polygon(PackedVector2Array([a,b,b+up,a+up]),Color(ink,0.055))
		stroke(PackedVector2Array([a,a+up,b+up,b]),Color(ink,0.75),1.4)
	for i in range(-1,2):
		draw_line(origin+project(i,-2),origin+project(i,2),Color(ink,0.14),0.8,true)
		draw_line(origin+project(-2.5,i),origin+project(2.5,i),Color(ink,0.14),0.8,true)
	box(origin+project(1.10,-0.85),1.45,0.62,0.65,ink)
	box(origin+project(-0.8,0.35),0.48,0.48,0.38,ink)
	# Same opening and same furniture on every layer: this is overlapping space.
	var door:=origin+project(-1.3,-2.0)
	stroke(PackedVector2Array([door+project(-0.42,0),door+project(-0.42,0,1.45),door+project(0.42,0,1.45),door+project(0.42,0)]),Color(ink,0.8),2)

func _draw() -> void:
	if not active:return
	for i in range(12,0,-1):draw_circle(Vector2(255,155),45+i*13,Color(0.035,0.09,0.14,0.055))
	for i in [0,2,1]:room(i)
	for i in range(3):
		var label:=Vector2(91+i*139,275)
		draw_circle(label+Vector2(-12,-6),3,colors[i])
		draw_string_outline(FONT,label,["冰晶世界","重力世界","倒悬世界"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,18,4,Color("162b39"))
		draw_string(FONT,label,["冰晶世界","重力世界","倒悬世界"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,18,colors[i])
	var title:="平行世界重叠"
	var title_size:=FONT.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,30)
	draw_string_outline(FONT,Vector2(255-title_size.x*0.5,329),title,HORIZONTAL_ALIGNMENT_LEFT,-1,30,5,Color("162b39"))
	draw_string(FONT,Vector2(255-title_size.x*0.5,329),title,HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("f6e5bf"))
	var note:="同一处空间，出现不同的规则"
	var note_size:=FONT.get_string_size(note,HORIZONTAL_ALIGNMENT_LEFT,-1,19)
	draw_string_outline(FONT,Vector2(255-note_size.x*0.5,370),note,HORIZONTAL_ALIGNMENT_LEFT,-1,19,4,Color("162b39"))
	draw_string(FONT,Vector2(255-note_size.x*0.5,370),note,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("f8f4e9"))
