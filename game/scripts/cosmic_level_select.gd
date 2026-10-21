extends "res://scripts/level_select.gd"
const COMMIT_TIME=2.50
const FINISH_TIME=2.85
const WORLD_NAMES=["冰晶宇宙","引力星环","倒悬之城","深海星域","机械天穹"]
const WORLD_SIZES=[0.91,0.91,0.83,0.83,0.66]
var worlds:Array[Node2D]=[]
var main_crystal:Node2D
var white_veil:ColorRect
var attention:=0.0
var caption_ink:StyleBoxFlat

func _ready() -> void:
	super._ready()
	bases=[Vector2(214,271),Vector2(1064,276),Vector2(239,573),Vector2(1047,579),Vector2(883,172)]
	colors=[Color("93e6f3"),Color("f4c58c"),Color("d5b4fa"),Color("72eee1"),Color("f4b884")]
	clock_material.shader=preload("res://shaders/cosmic_panorama.gdshader")
	clock_material.set_shader_parameter("panorama",preload("res://assets/level_select/cosmos_bright_v23.png"))
	heading.text="万千宇宙，一条归途"
	heading.position=Vector2(350,42);heading.size=Vector2(580,55)
	subtitle.text="观测世界裂隙，选择你的校准任务"
	subtitle.position=Vector2(350,104)
	for i in range(5):
		var crystal=preload("res://scripts/universe_crystal.gd").new()
		crystal.configure(i,colors[i])
		art.add_child(crystal);worlds.append(crystal)
	main_crystal=preload("res://scripts/universe_crystal.gd").new()
	main_crystal.configure(5,Color("b9f0e7"),true)
	art.add_child(main_crystal)
	white_veil=ColorRect.new()
	white_veil.size=Vector2(1280,800);white_veil.color=Color("f3fff6")
	white_veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;white_veil.modulate.a=0
	white_veil.z_index=100;root.add_child(white_veil)

func flight_progress(index:int,time:float) -> float:
	return clampf((time-0.14-index*0.075)/1.43,0,1)

func flight_position(index:int,time:float) -> Vector2:
	var t:=flight_progress(index,time)
	var start:Vector2=rift_starts[index]-CENTER
	var radius:=pow(1.0-t,0.86)
	var spin:=-t*TAU*0.87
	return CENTER+start.rotated(spin)*radius

func _process(delta:float) -> void:
	age+=delta
	hovered=get_viewport().get_mouse_position().distance_to(CENTER)<148 and selection_age<0
	attention=move_toward(attention,1.0 if hovered else 0.0,delta*3.0)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered else Input.CURSOR_ARROW)
	if selection_age>=0:selection_age+=delta
	clock_material.set_shader_parameter("clock",age)
	clock_material.set_shader_parameter("convergence",smoothstep(0.2,2.50,selection_age) if selection_age>=0 else 0.0)
	for i in range(worlds.size()):
		var world:Node2D=worlds[i]
		var t:=flight_progress(i,selection_age) if selection_age>=0 else 0.0
		world.position=flight_position(i,selection_age) if selection_age>=0 else rift_position(i)
		var stretch:float=WORLD_SIZES[i]*(1.0-t*0.82)
		world.scale=Vector2.ONE*stretch
		world.rotation=sin(age*0.31+i)*0.045-t*TAU*0.80
		world.modulate.a=1.0-smoothstep(0.83,1.0,t)
		world.visible=t<0.999 and not committed
		world.update_look(age,smoothstep(0.55,1.0,t)*0.7)
	var charge:=smoothstep(0.85,2.46,selection_age) if selection_age>=0 else attention*0.10
	var zoom:=1.0+pow(clampf((selection_age-1.77)/0.72,0,1),2.6)*18.0 if selection_age>=0 else 1.0
	main_crystal.position=CENTER
	main_crystal.scale=Vector2(0.92,1.16)*zoom*(1.0+sin(age*1.5)*0.008)
	main_crystal.rotation=-smoothstep(0.2,2.4,selection_age)*0.13 if selection_age>=0 else sin(age*0.2)*0.025
	main_crystal.update_look(age,charge)
	if selection_age>=0:
		heading.modulate.a=1.0-smoothstep(0.06,0.30,selection_age)
		subtitle.modulate.a=heading.modulate.a
		if selection_age>0.30:heading.hide();subtitle.hide()
		if selection_age>=COMMIT_TIME and not committed:
			committed=true
			sky.hide();art.hide();heading.hide();subtitle.hide();close_button.hide();enter_button.hide()
			level_committed.emit();cue.emit("arrived")
		white_veil.modulate.a=smoothstep(2.20,2.49,selection_age)*(1.0-smoothstep(2.54,FINISH_TIME,selection_age))
		if selection_age>=FINISH_TIME:
			set_process(false);finished.emit()
	art.queue_redraw()

func _draw_trail(index:int) -> void:
	var p:=flight_progress(index,selection_age)
	if p<=0.001 or p>=0.998:return
	var points:=PackedVector2Array()
	var glow:=PackedColorArray()
	var core_colors:=PackedColorArray()
	var ribbon:=PackedVector2Array()
	var other:=PackedVector2Array()
	var ribbon_colors:=PackedColorArray()
	var other_colors:=PackedColorArray()
	for j in range(43):
		var fraction:=float(j)/42.0
		var time:=selection_age-(1.0-fraction)*0.59
		if flight_progress(index,time)<0.001:continue
		var at:=flight_position(index,time)
		var next:=flight_position(index,time+0.008)
		var normal:Vector2=(next-at).normalized().orthogonal()
		var strength:=pow(fraction,1.6)*(1.0-smoothstep(0.92,1.0,p))
		points.append(at)
		glow.append(Color(colors[index],strength*0.14))
		core_colors.append(Color("fff5df").lerp(colors[index],0.55)*Color(1,1,1,strength*0.95))
		var width:=minf(10.0*pow(fraction,0.65),at.distance_to(CENTER)*0.28+1.0)
		ribbon.append(at+normal*width);other.append(at-normal*width)
		ribbon_colors.append(Color(colors[index],strength*0.45));other_colors.append(Color(colors[index],strength*0.45))
	if points.size()<2:return
	other.reverse();other_colors.reverse()
	art.draw_polyline_colors(points,glow,33.0,true)
	art.draw_colored_polygon(ribbon+other,Color(colors[index],0.12))
	art.draw_polygon(ribbon+other,ribbon_colors+other_colors)
	art.draw_polyline_colors(points,core_colors,3.0,true)
	for j in range(7):
		var when:=selection_age-j*0.044
		var at:=flight_position(index,when)
		art.draw_circle(at,3.2-j*0.32,Color(colors[index],(1.0-j/8.0)*(1.0-p)*0.85),true,-1,true)

func _draw_map() -> void:
	if committed:return
	# Wide tilted celestial orbits make the star map feel larger than its frame.
	for i in range(3):
		art.draw_set_transform(CENTER+Vector2(0,18),-0.20+i*0.19,Vector2(1.0,0.39))
		art.draw_arc(Vector2.ZERO,260.0+i*103,0,TAU,160,Color(0.92,0.80,0.55,0.23),0.9,true)
	art.draw_set_transform(Vector2.ZERO)
	if selection_age>=0:
		for i in range(5):_draw_trail(i)
		var power:=smoothstep(0.8,2.35,selection_age)
		for i in range(3):
			var radius:=60.0+fposmod(selection_age*90+i*34,145.0)
			var alpha:=power*(1.0-(radius-60.0)/145.0)*0.36
			art.draw_arc(CENTER,radius,age*0.7+i,age*0.7+i+TAU*0.78,100,Color("bff8ed")*Color(1,1,1,alpha),1.3,true)
	else:
		for i in range(5):
			var at:=rift_position(i)
			var label:String=WORLD_NAMES[i]
			var width:float=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
			var y:float=at.y+WORLD_SIZES[i]*120+23
			art.draw_style_box(_caption_style(),Rect2(at.x-width*0.5-10,y-17,width+20,26))
			_label(label,Vector2(at.x-width*0.5,y+1),14,Color("f8efdc"))
	# Label plates keep the brighter painting readable without dimming the universe.
	if selection_age<0.20:
		art.draw_style_box(_caption_style(),Rect2(472,517,336,101))
		_label("关卡 01  /  稳定锚点",Vector2(572,540),13,Color("f4d4a0"))
		_label("新手校准室",Vector2(548,579),33,Color("f5f5df"),true)
		_label("先定星位  ·  再压月痕  ·  最后封界缝",Vector2(491,606),14,Color("c4dedf"))
	if selection_age<0:_label("世界各循其律，归途由你校准。",Vector2(539,715),13,Color("e0e3d9"))

func _caption_style() -> StyleBoxFlat:
	if caption_ink!=null:return caption_ink
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.035,0.10,0.18,0.74)
	style.border_color=Color(0.84,0.73,0.48,0.28)
	style.set_border_width_all(1);style.set_corner_radius_all(7)
	caption_ink=style
	return style
