extends Button
## Code-native skill icon with radial recovery, shared by every input method.
var cooldown_remaining := 0.0
var cooldown_duration := 3.0
var world := 0
var clock := 0.0
var icon_font := SystemFont.new()

func _ready() -> void:
	icon_font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	focus_mode=Control.FOCUS_NONE
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())

func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()

func _draw() -> void:
	var center:=size*0.5
	var color: Color=[Color("8cd9ec"),Color("e6ae79"),Color("bda7ed")][world]
	draw_circle(center,29,Color("243d50"))
	draw_arc(center,28,-PI*0.5,TAU-PI*0.5,64,Color(color,0.72),2.0,true)
	for i in range(3):
		var angle:=float(i)/3.0*TAU-PI*0.5
		var a:=center+Vector2.from_angle(angle)*18
		var b:=center+Vector2.from_angle(angle+TAU/3.0)*18
		draw_line(a,b,color,1.8,true)
		draw_line(a,center,color,1.1,true)
	draw_circle(center,4,color)
	if cooldown_remaining>0.001:
		var fraction:=clampf(cooldown_remaining/cooldown_duration,0,1)
		var wedge:=PackedVector2Array([center])
		for i in range(49): wedge.append(center+Vector2.from_angle(-PI*0.5+TAU*fraction*float(i)/48.0)*27)
		draw_colored_polygon(wedge,Color(0.035,0.07,0.13,0.88))
		draw_arc(center,28,-PI*0.5+TAU*fraction,TAU-PI*0.5,64,color,2.8,true)
		var text:="%.1f"%maxf(0.1,cooldown_remaining)
		var width:=icon_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
		draw_string(icon_font,center+Vector2(-width*0.5,7),text,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ffffff"))
	else:
		draw_arc(center,30,0,TAU,64,Color(color,0.3+sin(clock*2.0)*0.12),1.5,true)
	draw_style_box(_key_style(),Rect2(size.x-24,size.y-18,22,17))
	draw_string(icon_font,Vector2(size.x-19,size.y-5),"Q",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f2e6c8"))

func _key_style() -> StyleBoxFlat:
	var result:=StyleBoxFlat.new()
	result.bg_color=Color("3e5060")
	result.border_color=Color("a9956d")
	result.set_border_width_all(1)
	result.set_corner_radius_all(3)
	return result
