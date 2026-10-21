extends Button
## Each tile selects one specific world; there is no cycle action.
var world := 0
var selected := false
var cooldown_remaining := 0.0
var icon_font := SystemFont.new()

func _ready() -> void:
	icon_font.font_names = PackedStringArray(["Microsoft YaHei","Arial"])
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var tint: Color = [Color("659ead"),Color("b67b55"),Color("9181b0")][world]
	var box := StyleBoxFlat.new()
	box.bg_color = tint.lightened(0.84) if selected else Color("f3efe6")
	if is_hovered() and not disabled: box.bg_color = tint.lightened(0.72)
	box.border_color = tint if selected else Color("d3c9b6")
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(7)
	draw_style_box(box,Rect2(Vector2.ZERO,size))
	var center := Vector2(size.x*0.5,22)
	if world == 0:
		for i in range(3):
			var axis := Vector2.from_angle(float(i)*PI/3.0)*9
			draw_line(center-axis,center+axis,tint,1.6,true)
			for sign_value in [-1,1]:
				var tip: Vector2 = center+axis*sign_value
				var back: Vector2 = -axis.normalized()*4*sign_value
				draw_line(tip,tip+back.rotated(0.6),tint,1.2,true)
				draw_line(tip,tip+back.rotated(-0.6),tint,1.2,true)
	else:
		var direction := 1.0 if world == 1 else -1.0
		draw_line(center-Vector2(0,9)*direction,center+Vector2(0,7)*direction,tint,2,true)
		draw_polyline(PackedVector2Array([center+Vector2(-5,2)*direction,center+Vector2(0,7)*direction,center+Vector2(5,2)*direction]),tint,2,true)
		draw_line(center+Vector2(-9,12)*direction,center+Vector2(9,12)*direction,tint,1.5,true)
	var title: String = ["冰晶","重力","倒悬"][world]
	var width := icon_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	draw_string(icon_font,Vector2((size.x-width)*0.5,49),title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("425b67"))
	draw_string(icon_font,Vector2(5,13),str(world+1),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("8c7b5e"))
	if selected:
		draw_circle(Vector2(size.x-7,7),2.4,tint)
	elif cooldown_remaining > 0.001:
		draw_style_box(_veil(),Rect2(Vector2.ZERO,size))

func _veil() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.94,0.93,0.90,0.38)
	box.set_corner_radius_all(7)
	return box
