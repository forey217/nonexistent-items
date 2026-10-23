extends CanvasLayer
signal dismissed
signal level_committed
signal finished
signal cue(event: String)
const TITLE=preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf")
const CENTER=Vector2(640,360)
var age := 0.0
var selection_age := -1.0
var committed := false
var hovered := false
var clock_material: ShaderMaterial
var art:=Node2D.new()
var root:=Control.new()
var sky: ColorRect
var close_button: Button
var enter_button: Button
var heading: Label
var subtitle: Label
var font:=SystemFont.new()
var rift_starts: Array[Vector2]=[]
var bases: Array[Vector2]=[Vector2(230,240),Vector2(1030,240),Vector2(248,553),Vector2(1043,554),Vector2(831,138)]
var colors: Array[Color]=[Color("8bdce9"),Color("d6b078"),Color("b3a0da")]

func _ready() -> void:
	layer=50
	font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(root)
	sky=ColorRect.new();sky.size=Vector2(1280,800);sky.mouse_filter=Control.MOUSE_FILTER_IGNORE
	clock_material=ShaderMaterial.new();clock_material.shader=preload("res://shaders/constellation.gdshader")
	sky.material=clock_material;root.add_child(sky)
	root.add_child(art);art.draw.connect(_draw_map)
	var ui=preload("res://scripts/tutorial_hud.gd").new()
	close_button=ui.button(root,"返回接待室   Esc",Vector2(22,20),Vector2(190,38))
	close_button.pressed.connect(close)
	heading=ui.label(root,"平行世界观测",Vector2(360,49),38,Color("e6e6cd"))
	heading.size=Vector2(560,55);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font",TITLE)
	subtitle=ui.label(root,"选择一枚世界水晶，建立稳定通道",Vector2(350,110),15,Color("9cb8bc"))
	subtitle.size=Vector2(580,28);subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	enter_button=ui.button(root,"进入 · 新手校准室",Vector2(520,629),Vector2(240,44))
	enter_button.pressed.connect(select_level)
	ui.free()

func close() -> void:
	if selection_age<0:dismissed.emit()

func select_level() -> void:
	if selection_age>=0:return
	for i in range(bases.size()):rift_starts.append(rift_position(i))
	selection_age=0.0
	close_button.disabled=true;enter_button.disabled=true
	close_button.hide();enter_button.hide()
	heading.text="世界正在汇聚"
	subtitle.text="建立通往新手校准室的裂隙…"
	cue.emit("fold")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode==KEY_M:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:close()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if event.position.distance_to(CENTER)<148.0 and selection_age<0:
			select_level();get_viewport().set_input_as_handled()
	if event is InputEventKey:get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	age+=delta
	clock_material.set_shader_parameter("clock",age)
	hovered=get_viewport().get_mouse_position().distance_to(CENTER)<148 and selection_age<0
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered else Input.CURSOR_ARROW)
	if selection_age>=0:
		selection_age+=delta
		if selection_age>1.05:heading.hide();subtitle.hide()
		if selection_age>=1.64 and not committed:
			committed=true
			sky.hide();heading.hide();subtitle.hide();close_button.hide();enter_button.hide()
			level_committed.emit()
			cue.emit("arrived")
		if selection_age>=1.97:
			set_process(false);finished.emit()
	art.queue_redraw()

func rift_position(index: int) -> Vector2:
	return bases[index]+Vector2(sin(age*0.24+index*1.7)*20.0,cos(age*0.31+index)*12.0)

func _label(text: String,position: Vector2,size: int,color: Color,fancy:=false) -> void:
	art.draw_string(TITLE if fancy else font,position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _rift(at: Vector2,size: float,rotation: float,color: Color,kind: int,fade:=1.0) -> void:
	art.draw_set_transform(at,rotation,Vector2.ONE*size)
	var p:=PackedVector2Array([Vector2(-2,-70),Vector2(24,-33),Vector2(12,-9),Vector2(27,22),Vector2(2,72),Vector2(-20,35),Vector2(-12,5),Vector2(-25,-27)])
	art.draw_colored_polygon(p,Color(color,0.10*fade))
	art.draw_polyline(p+PackedVector2Array([p[0]]),Color(color,0.55*fade),1.5,true)
	var seam:=PackedVector2Array([Vector2(0,-64),Vector2(-7,-26),Vector2(5,0),Vector2(-4,30),Vector2(1,66)])
	art.draw_polyline(seam,Color(color,fade*0.8),2.0,true)
	for j in range(5):
		var y:=fposmod(age*(12.0 if kind==1 else -9.0)+j*25.0,100)-50
		var point:=Vector2(sin(float(j)*2.3)*9.0,y)
		if kind==0:
			art.draw_line(point-Vector2(3,0),point+Vector2(3,0),Color(color,fade*0.65),1.0,true)
		else:art.draw_circle(point,1.5,Color(color,fade*0.65))
	art.draw_set_transform(Vector2.ZERO)

func _crystal(at: Vector2,size: float,brightness: float) -> void:
	art.draw_set_transform(at,0,Vector2.ONE*size)
	var glow:=0.12+brightness*0.23+(0.035 if hovered else 0.0)
	for ring in range(5,0,-1):
		var e:=Vector2(54+ring*6,123+ring*5)
		art.draw_colored_polygon(PackedVector2Array([Vector2(0,-e.y),Vector2(e.x,-35),Vector2(e.x*0.55,80),Vector2(-8,e.y),Vector2(-e.x,35),Vector2(-e.x*0.65,-76)]),Color(0.46,0.77,0.81,glow*0.18))
	var pts:=PackedVector2Array([Vector2(0,-139),Vector2(57,-62),Vector2(43,78),Vector2(-10,140),Vector2(-57,38),Vector2(-44,-73)])
	art.draw_colored_polygon(pts,Color("476c80").lerp(Color("fbffe8"),brightness))
	art.draw_colored_polygon(PackedVector2Array([pts[0],pts[1],Vector2(0,8),pts[5]]),Color("a5dce0").lerp(Color.WHITE,brightness))
	art.draw_colored_polygon(PackedVector2Array([pts[1],pts[2],Vector2(0,8)]),Color("507a96").lerp(Color.WHITE,brightness))
	art.draw_colored_polygon(PackedVector2Array([pts[2],pts[3],Vector2(0,8)]),Color("86b5bf").lerp(Color.WHITE,brightness))
	art.draw_colored_polygon(PackedVector2Array([pts[3],pts[4],Vector2(0,8)]),Color("567783").lerp(Color.WHITE,brightness))
	art.draw_polyline(pts+PackedVector2Array([pts[0]]),Color("d2dbb9").lerp(Color.WHITE,brightness),1.6,true)
	var seam:=PackedVector2Array([Vector2(0,-113),Vector2(-8,-55),Vector2(9,-12),Vector2(-4,34),Vector2(3,76),Vector2(-9,116)])
	art.draw_polyline(seam,Color(0.83,0.96,0.92,0.8+0.2*sin(age*2.0)),3.2,true)
	art.draw_polyline(PackedVector2Array([seam[2],Vector2(28,-25),Vector2(43,-17)]),Color("c1ede5"),1.2,true)
	art.draw_set_transform(Vector2.ZERO)

func _draw_map() -> void:
	var progress:=selection_age
	if committed:
		art.draw_rect(Rect2(0,0,1280,800),Color(0.96,0.99,0.93,1.0-smoothstep(1.67,1.97,progress)))
		return
	for i in range(3):
		art.draw_set_transform(Vector2(640,390),float(i)*0.28-0.25,Vector2(1,0.34))
		art.draw_arc(Vector2.ZERO,235.0+float(i)*76,0,TAU,144,Color(0.66,0.65,0.47,0.12),1.0,true)
	art.draw_set_transform(Vector2.ZERO)
	for i in range(bases.size()):
		var position:=rift_position(i)
		var scale_rift:=0.72+0.06*float(i%3)
		var opacity:=0.65
		if progress>=0:
			var p:=smoothstep(0.0,0.88,progress-float(i)*0.045)
			var start:=rift_starts[i]
			var middle: Vector2=(start+CENTER)*0.5+(CENTER-start).orthogonal()*0.32
			position=start.bezier_interpolate(middle,middle,CENTER,p)
			scale_rift*=1.0-p
			opacity=1.0-p*0.6
			if p>0 and p<1:
				var tail:=start.lerp(position,maxf(0.0,p-0.20))
				art.draw_line(tail,position,Color(colors[i%3],0.08*(1-p)),7.0,true)
				art.draw_line(tail,position,Color(colors[i%3],0.50*(1-p)),2.0,true)
				for j in range(3):
					var t:=clampf(p-float(j)*0.055,0,1)
					var point:=start.bezier_interpolate(middle,middle,CENTER,t)
					art.draw_circle(point,2.8-float(j)*0.5,Color(colors[i%3],0.85*(1-p)))
		if scale_rift>0.015:_rift(position,scale_rift,sin(age*0.3+i)*0.10,colors[i%3],i%3,opacity)
	var zoom:=1.0
	var brightness:=0.0
	if progress>=0:
		brightness=smoothstep(0.50,1.54,progress)
		zoom=1.0+pow(clampf((progress-1.02)/0.60,0,1),2.4)*17.0
	_crystal(CENTER,zoom*(1.0+0.012*sin(age*1.8)),brightness)
	if progress<1.12:
		_label("关卡 01",Vector2(608,537),14,Color("b9bb94"))
		_label("新手校准室",Vector2(548,581),33,Color("e7e7d2"),true)
		_label("先定星位  ·  再压月痕  ·  最后封界缝",Vector2(491,608),14,Color("9db8ba"))
		_label("冰晶 / 重力 / 倒悬",Vector2(565,724),14,Color("8aa3b0"))
	var white:=smoothstep(1.34,1.63,progress)*(1.0-smoothstep(1.67,1.97,progress)) if progress>=0 else 0.0
	if white>0:
		# The white veil also covers the labels/buttons during the scene swap.
		art.z_index=10
		art.draw_rect(Rect2(0,0,1280,800),Color(0.96,0.99,0.93,white))
