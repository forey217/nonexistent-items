extends Node2D
## Calibration instruments retain the previous furniture's collision footprints.
var room: Node2D
var footprint:=PackedVector2Array()
var prop_name:=""
var art:=Sprite2D.new()
var kind:="cabinet"
var last_world:=-1
var font:=SystemFont.new()
var sample_height:=0.0

func configure(key: String,title: String,center: Vector2,shape: PackedVector2Array,_width: float) -> void:
	kind="cabinet" if key=="bookcase" else "console"
	prop_name=title
	position=center
	footprint=shape
	font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	art.scale=Vector2.ONE*0.5
	art.position=Vector2(0,-77)
	art.show_behind_parent=true
	add_child(art)
	var body:=StaticBody2D.new()
	body.collision_layer=1
	body.collision_mask=2
	var collision:=CollisionPolygon2D.new()
	collision.polygon=shape
	body.add_child(collision)
	add_child(body)

func _process(delta: float) -> void:
	if room==null:return
	var world: int=room.state.world
	if last_world!=world:
		last_world=world
		art.texture=load("res://assets/calibration_v03/"+kind+"-"+str(world)+".png")
	sample_height=move_toward(sample_height,24.0 if world==2 else 0.0,delta*24.0)
	queue_redraw()

func global_footprint() -> PackedVector2Array:
	var result:=PackedVector2Array()
	for point in footprint:result.append(point+position)
	return result

func contains_visual(at: Vector2) -> bool:
	var bounds:=Rect2(-48,-126,96,142) if kind=="cabinet" else Rect2(-76,-110,152,150)
	return bounds.has_point(at-position)

func inspection_text() -> String:
	if kind=="cabinet":
		return ["场律电源：样品向下、摩擦很小；轻推镇纸会一直滑到挡块。","场律电源：向下受力 ×4，镇纸推不动，但能压下校准板。","场律电源：样品正在上浮；同一块镇纸也能上浮触碰接收器。"][room.state.world]
	return "校准监测：挡块%s · 上部%s · 末端压力%s；后两项同时满足才能开门。"%["已释放" if room.state.first_latched else "未释放","已记录" if room.state.receiver_latched else "未记录","已满足" if room.state.final_pressed else "未满足"]

func _draw() -> void:
	if room==null:return
	var active:=Color("8de0bb")
	var off:=Color("5d626b")
	if kind=="cabinet":
		# A sealed sample demonstrates gravity rather than adding unrelated clutter.
		draw_style_box(tube_style(),Rect2(-32,-82,13,42))
		var colors: Array[Color]=[Color("a9e4ed"),Color("e5b774"),Color("c6b1ed")]
		draw_circle(Vector2(-25.5,-47-sample_height),3.6,colors[room.state.world])
		draw_string(font,Vector2(-13,-52),["↓","⇓","↑"][room.state.world],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("c8d9dc"))
	else:
		for i in range(3):
			var lit: bool=[room.state.first_latched,room.state.receiver_latched,room.state.final_pressed][i]
			draw_circle(Vector2(-33+i*29,-22+i*10),3,active if lit else off)
		badge(Vector2(-22,25),Vector2(86,19),"%d / 3 已校准"%int(int(room.state.first_latched)+int(room.state.receiver_latched)+int(room.state.final_pressed)))

func tube_style() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("233a47")
	style.border_color=Color("b6aa83")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func badge(at: Vector2,size: Vector2,text: String) -> void:
	draw_style_box(tube_style(),Rect2(at,size))
	draw_string(font,at+Vector2(7,size.y-6),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e0e2d9"))
