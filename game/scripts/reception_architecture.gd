extends Node2D
## Textured interior shell, independent of actor movement and interactive furniture.
var hub: Node2D
var solid_footprints: Array[PackedVector2Array]=[]
var library: Texture2D=preload("res://assets/interior_v30/reception_wall.png")
var panorama: Texture2D=preload("res://assets/interior_v30/panorama_wall.png")
var title_font: Font=preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf")
const WALL_HEIGHT:=260.0

func _ready() -> void:
	z_index=-5
	for uv in [Vector2(0.17,8.35),Vector2(8.35,0.17)]:
		var pillar:=Pillar.new();pillar.texture=library
		pillar.position=hub.iso(uv.x,uv.y)
		hub.sort_layer.add_child(pillar)
		var footprint: PackedVector2Array=hub._footprint(Vector2(0.56,0.56))
		var body:=StaticBody2D.new();body.collision_layer=1;body.collision_mask=2
		var shape:=CollisionPolygon2D.new();shape.polygon=footprint
		body.add_child(shape);pillar.add_child(body)
		var global_shape:=PackedVector2Array()
		for point in footprint:global_shape.append(point+pillar.position)
		solid_footprints.append(global_shape)
	for edge in [[hub.iso(17,0),hub.iso(17,17)],[hub.iso(17,17),hub.iso(0,17)]]:
		for i in range(17):
			var start: Vector2=edge[0].lerp(edge[1],float(i)/17)
			var end: Vector2=edge[0].lerp(edge[1],float(i+1)/17)
			var rail:=Rail.new();rail.position=(start+end)*0.5
			rail.start=start-rail.position;rail.end=end-rail.position
			hub.sort_layer.add_child(rail)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(hub):return
	# Both elevations continue well beyond the camera; the upper storey closes the frame.
	draw_rect(Rect2(-2200,-1600,5600,4200),Color("c1bba9"))
	var corner: Vector2=hub.iso(0,0)
	for start in [0.0,9.0,18.0,27.0]:
		var finish: float=start+9.0
		_wall(hub.iso(0,finish),hub.iso(0,start),library)
		_wall(hub.iso(start,0),hub.iso(finish,0),panorama)
		_upper_storey(hub.iso(0,finish),hub.iso(0,start))
		_upper_storey(hub.iso(start,0),hub.iso(finish,0))
	var pillar:=PackedVector2Array([corner+Vector2(-8,0),corner+Vector2(0,4),corner+Vector2(8,0),corner+Vector2(8,-1000),corner+Vector2(0,-1004),corner+Vector2(-8,-1000)])
	draw_colored_polygon(pillar,Color("344754"))
	draw_line(corner,corner-Vector2(0,1000),Color("bca174"),2,true)
	# Legible vector lettering is kept out of generated artwork.
	var left: Vector2=hub.iso(0,9)
	var center: Vector2=left.lerp(corner,0.5)-Vector2(0,WALL_HEIGHT*0.68)
	var basis:=Transform2D(Vector2(0.894427,-0.447214),Vector2(0,1),center)
	draw_set_transform_matrix(basis)
	var title:="世界观察局"
	var width:=title_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
	draw_string(title_font,Vector2(-width*0.5,8),title,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("efd9a0"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _wall(a: Vector2,b: Vector2,texture: Texture2D) -> void:
	var up:=Vector2(0,WALL_HEIGHT)
	var points:=PackedVector2Array([a-up,b-up,b,a])
	draw_polygon(points,PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),texture)
	draw_line(a-up,b-up,Color("c0a775"),3,true)
	draw_line(a,b,Color("9d895f"),4,true)
	draw_line(a-up,a,Color("42525f"),5,true)

func _upper_storey(a: Vector2,b: Vector2) -> void:
	var points:=PackedVector2Array([a-Vector2(0,1000),b-Vector2(0,1000),b-Vector2(0,WALL_HEIGHT),a-Vector2(0,WALL_HEIGHT)])
	draw_polygon(points,PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(0.235,0.065),Vector2(0.37,0.065),Vector2(0.37,0.16),Vector2(0.235,0.16)]),library)
	for height in [WALL_HEIGHT,460.0,680.0,900.0]:
		draw_line(a-Vector2(0,height),b-Vector2(0,height),Color("6b6559"),9,true)
		draw_line(a-Vector2(0,height+3),b-Vector2(0,height+3),Color("c5ad79"),2,true)
	for t in [0.0,0.5,1.0]:
		var base:=a.lerp(b,t)
		draw_line(base-Vector2(0,260),base-Vector2(0,1000),Color("4a5356"),12,true)
		draw_line(base-Vector2(0,260)+Vector2(4,0),base-Vector2(0,1000)+Vector2(4,0),Color("ba9d66"),2,true)

class Pillar extends Node2D:
	var texture: Texture2D
	func _draw() -> void:
		var points:=PackedVector2Array([Vector2(-17,-262),Vector2(17,-245),Vector2(17,5),Vector2(-17,-12)])
		draw_polygon(points,PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(0.027,0),Vector2(0.103,0),Vector2(0.103,1),Vector2(0.027,1)]),texture)
		draw_line(points[0],points[3],Color("baa071"),1.5,true)
		draw_line(points[1],points[2],Color("d4b982"),1.5,true)

class Rail extends Node2D:
	var start:=Vector2.ZERO
	var end:=Vector2.ZERO
	func _draw() -> void:
		var rise:=Vector2(0,35)
		draw_colored_polygon(PackedVector2Array([start,end,end-rise,start-rise]),Color(0.43,0.62,0.68,0.15))
		draw_line(start-rise,end-rise,Color("b29a68"),2.5,true)
		draw_line(start,start-Vector2(0,39),Color("536776"),4,true)
