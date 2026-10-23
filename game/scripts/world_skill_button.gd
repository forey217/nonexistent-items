extends Button
## All buttons display the same shared cooldown; no independent timers.
const Instruments=preload("res://scripts/instrument_theme.gd")
var world:=0
var selected:=false:
	set(value):
		if selected!=value:selected=value;queue_redraw()
var cooldown_remaining:=0.0:
	set(value):
		if cooldown_remaining!=value:cooldown_remaining=value;queue_redraw()
var icon_font:=Instruments.body()

func _ready() -> void:
	focus_mode=Control.FOCUS_ALL;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	mouse_force_pass_scroll_events=false
	for state in ["normal","hover","pressed","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	add_theme_stylebox_override("focus",Instruments.focus_style())
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw);button_up.connect(queue_redraw)
	focus_entered.connect(queue_redraw);focus_exited.connect(queue_redraw)

func _draw() -> void:
	if selected or (is_hovered() and not disabled):
		draw_style_box(Instruments.state_style(selected,is_hovered() and not disabled),Rect2(Vector2.ZERO,size))
	var tint:Color=Instruments.BLUE if selected else Instruments.GOLD
	var center:=Vector2(24,34)
	if world==0:
		for i in range(3):
			var axis:=Vector2.from_angle(float(i)*PI/3.0)*10
			draw_line(center-axis,center+axis,tint,1.4,true)
			for sign_value in [-1,1]:
				var tip:Vector2=center+axis*sign_value;var back:Vector2=-axis.normalized()*4*sign_value
				draw_line(tip,tip+back.rotated(.6),tint,1,true);draw_line(tip,tip+back.rotated(-.6),tint,1,true)
	elif world<3:
		var direction:=1.0 if world==1 else -1.0
		draw_line(center-Vector2(0,10)*direction,center+Vector2(0,6)*direction,tint,1.8,true)
		draw_polyline(PackedVector2Array([center+Vector2(-5,1)*direction,center+Vector2(0,6)*direction,center+Vector2(5,1)*direction]),tint,1.8,true)
		draw_line(center+Vector2(-9,11)*direction,center+Vector2(9,11)*direction,tint,1.3,true)
	else:
		draw_polyline(PackedVector2Array([center+Vector2(-12,0),center+Vector2(0,-8),center+Vector2(12,0),center+Vector2(0,8),center+Vector2(-12,0)]),tint,1.2,true)
		draw_circle(center,3,tint,false,1.3,true)
	draw_string(icon_font,Vector2(46,41),["冰晶","重力","倒悬","显影"][world],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Instruments.MUTED if disabled and not selected else Instruments.TEXT)
	draw_string(icon_font,Vector2(9,16),str(world+1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Instruments.MUTED)
	if selected:
		draw_circle(Vector2(size.x-9,10),2.5,Instruments.BLUE,true,-1,true)
		draw_line(Vector2(44,size.y-8),Vector2(size.x-10,size.y-8),Instruments.GOLD,1,true)
	if cooldown_remaining>.001:
		draw_arc(center,18,-PI*.5,PI*1.5,40,Color(Instruments.GOLD,.20),1,true)
		draw_arc(center,18,-PI*.5,-PI*.5+TAU*clampf(1-cooldown_remaining/1.5,0,1),40,Instruments.BLUE,1.5,true)
