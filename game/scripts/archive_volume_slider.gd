extends HSlider
## Native slider input and focus, dressed as a brass instrument scale.
func _ready() -> void:
	min_value=0;max_value=100;step=1
	focus_mode=Control.FOCUS_ALL
	var blank:=ImageTexture.create_from_image(Image.create_empty(20,28,false,Image.FORMAT_RGBA8))
	for icon in ["grabber","grabber_highlight","grabber_disabled"]:add_theme_icon_override(icon,blank)
	for style in ["slider","grabber_area","grabber_area_highlight","focus"]:add_theme_stylebox_override(style,StyleBoxEmpty.new())
	value_changed.connect(func(_value):queue_redraw())
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw);focus_exited.connect(queue_redraw)
	drag_ended.connect(func(_changed):queue_redraw())

func _draw() -> void:
	var start:=Vector2(10,size.y*0.5)
	var end:=Vector2(size.x-10,start.y)
	var knob:=start.lerp(end,float(value-min_value)/(max_value-min_value))
	for tick in range(11):
		var at:=start.lerp(end,tick/10.0)
		draw_line(at+Vector2(0,10),at+Vector2(0,17 if tick%5==0 else 14),Color("ac915c"),0.8,true)
	draw_line(start,end,Color("c4b795"),4,true)
	draw_line(start,end,Color("a68a56"),1,true)
	draw_line(start,knob,Color("365565"),3,true)
	if has_focus() or get_global_rect().has_point(get_global_mouse_position()):
		draw_circle(knob,18,Color(0.77,0.63,0.37,0.13),true,-1,true)
	var diamond:=PackedVector2Array([knob+Vector2(0,-13),knob+Vector2(9,0),knob+Vector2(0,13),knob+Vector2(-9,0),knob+Vector2(0,-13)])
	draw_colored_polygon(diamond,Color("c9b17c"))
	draw_polyline(diamond,Color("81633b"),1.1,true)
	draw_circle(knob,3.8,Color("6495a3"),true,-1,true)
	draw_circle(knob+Vector2(-1,-1),1.6,Color("d2eeee"),true,-1,true)
