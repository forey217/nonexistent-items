extends CanvasLayer
## A captured room becomes a stamped record, then slips into the bureau's files.
signal reveal_hub
signal finished
signal sound_cue(cue: String)
const DURATION := 1.95
const REVEAL_TIME := 1.58
const THROW_START := 1.00
const THROW_END := 1.51
const ARC_HEIGHT := 112.0
const TITLE_FONT=preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf")
var image: Texture2D
var age := 0.0
var active := false
var number := 1
var record_title:="校准记录归档"
var record_scene:="新手校准室"
var revealed := false
var stamped := false
var filed := false
var acknowledged := false
var canvas := Node2D.new()
var body_font := SystemFont.new()

func _ready() -> void:
	layer=100
	body_font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	add_child(canvas)
	canvas.draw.connect(_draw_frame)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func begin(snapshot: Texture2D,run_number: int) -> void:
	image=snapshot
	number=run_number
	active=true
	canvas.queue_redraw()

func _input(event: InputEvent) -> void:
	# Input is consumed before either room can receive clicks or reset commands.
	if event is InputEventKey and event.physical_keycode==KEY_M:return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:return
	age+=delta
	if age>=0.68 and not stamped:
		stamped=true;sound_cue.emit("stamp")
	if age>=THROW_START and not filed:
		filed=true;sound_cue.emit("file")
	if age>=1.52 and not acknowledged:
		acknowledged=true;sound_cue.emit("arrived")
	if age>=REVEAL_TIME and not revealed:
		revealed=true;reveal_hub.emit()
	canvas.queue_redraw()
	if age>=DURATION:
		active=false
		finished.emit()

func _panel(rect: Rect2,fill: Color,border: Color,radius:=9.0,width:=1) -> void:
	var style:=StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=border
	style.set_border_width_all(width)
	style.set_corner_radius_all(int(radius))
	canvas.draw_style_box(style,rect)

func _text(text: String,at: Vector2,size: int,color: Color,fancy:=false) -> void:
	canvas.draw_string(TITLE_FONT if fancy else body_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw_frame() -> void:
	if not active:return
	var fade:=1.0-smoothstep(REVEAL_TIME,DURATION,age)
	var ink:=Color("405660")
	var gold:=Color("b69d6e")
	canvas.draw_rect(Rect2(0,0,1280,800),Color(0.949,0.933,0.886,fade))
	canvas.modulate.a=fade
	var shrink:=smoothstep(0.02,0.57,age)
	# Tip the stamped sheet back, then throw it along a raised parabolic arc.
	var anticipation:=smoothstep(0.84,THROW_START,age)
	var flight_time:=clampf((age-THROW_START)/(THROW_END-THROW_START),0,1)
	var filing:=1.0-pow(1.0-flight_time,1.35)
	var launch:=Vector2(640,400).lerp(Vector2(595,398),shrink)+Vector2(-10,-6)*anticipation
	var center:=launch.lerp(Vector2(1090,392),filing)
	center.y-=4.0*ARC_HEIGHT*filing*(1.0-filing)
	var rotation:=lerpf(0.0,-0.025,shrink)-0.17*anticipation
	rotation=lerpf(rotation,0.015,smoothstep(0.05,1.0,filing))
	rotation+=sin(filing*TAU)*0.025*sin(filing*PI)
	var card_size:=Vector2(1280,800).lerp(Vector2(616,434),shrink)
	card_size*=lerpf(1.0,0.29,filing)
	card_size.y*=lerpf(1.0,0.06,smoothstep(1.39,1.53,age))
	var detail:=smoothstep(0.18,0.54,age)
	if detail>0.001:
		canvas.draw_set_transform(Vector2.ZERO)
		_text("世 界 观 察 局",Vector2(65,70),21,Color(ink,detail),true)
		canvas.draw_line(Vector2(65,87),Vector2(1210,87),Color(gold,detail*0.55),1.0,true)
		_text(record_title,Vector2(65,121),14,Color(ink,detail*0.7))
		_draw_cabinet(false,detail)
		_draw_cabinet(true,detail)
	if age<1.54:
		canvas.draw_set_transform(center,rotation)
		var rect:=Rect2(-card_size*0.5,card_size)
		_panel(Rect2(rect.position+Vector2(6,8)*shrink,rect.size),Color(0.17,0.22,0.24,0.13*shrink),Color.TRANSPARENT,9,0)
		_panel(rect,Color("fffcf2"),Color(gold,detail),9,2)
		var scale_x:=card_size.x/616.0
		var scale_y:=card_size.y/434.0
		canvas.draw_set_transform(center,rotation,Vector2(scale_x,scale_y))
		var photo_rect:=Rect2(Vector2(-308,-217).lerp(Vector2(-288,-137),shrink),Vector2(616,434).lerp(Vector2(576,315),shrink))
		canvas.draw_rect(photo_rect,Color("f1eddf"))
		if image!=null:
			var source:=Rect2(Vector2.ZERO,Vector2(1280,800))
			source.position=Vector2(130,75)*shrink
			source.size=Vector2(1280,800).lerp(Vector2(1030,625),shrink)
			canvas.draw_texture_rect_region(image,photo_rect,source)
		if detail>0.001:
			_panel(Rect2(-294,-203,588,405),Color.TRANSPARENT,Color(gold,detail*0.7),4,1)
			_text("世界观察局 · 异常空间记录",Vector2(-281,-174),20,Color(ink,detail),true)
			_text("NO. %03d"%number,Vector2(192,-174),14,Color(gold,detail))
			_text(record_scene,Vector2(-280,-149),13,Color(ink,detail*0.8))
			canvas.draw_line(Vector2(-280,-141),Vector2(279,-141),Color(gold,detail*0.55),1.0,true)
			_text("稳定锚点  03 / 03",Vector2(-280,187),13,Color(ink,detail*0.8))
			_text("空间关系：已恢复",Vector2(135,187),13,Color(ink,detail*0.8))
			if age>=0.60:_draw_stamp(age,Vector2(scale_x,scale_y),center,rotation)
		canvas.draw_set_transform(Vector2.ZERO)
	if filing>0.86:_draw_cabinet(true,detail)
	if detail>0.001:
		var caption: String="异常空间，已收好。" if age>=1.52 else "本次异常：已稳定"
		var font_size:=25
		var width:=TITLE_FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		_text(caption,Vector2(640-width*0.5,690),font_size,Color(ink,detail),true)
		if age>=1.52:_text("归档成功",Vector2(1062,559),14,Color("5a9a87"))

func _draw_stamp(time: float,scale_xy: Vector2,center: Vector2,rotation: float) -> void:
	var phase:=clampf((time-0.60)/0.13,0,1)
	var punch:=1.0+0.42*pow(1.0-phase,2.0)-sin(phase*PI)*0.04
	var offset:=Vector2(88,53)+Vector2(0,-20*(1.0-phase))
	var global_offset:=offset*scale_xy
	global_offset=global_offset.rotated(rotation)
	canvas.draw_set_transform(center+global_offset,rotation-0.14,scale_xy*punch)
	var red:=Color("b7634b")
	red.a=phase*0.94
	_panel(Rect2(-133,-43,266,86),Color.TRANSPARENT,red,4,4)
	_panel(Rect2(-125,-35,250,70),Color.TRANSPARENT,red,2,1)
	_text("校准完成",Vector2(-110,17),47,red,true)
	if time>=0.68 and time<0.91:
		var burst:=1.0-(time-0.68)/0.23
		for side in [-1,1]:
			for y in [-1,1]:
				var start:=Vector2(side*145,y*48)
				canvas.draw_line(start,start+Vector2(side*14,y*8)*burst,Color(red,burst*0.55),2.0,true)

func _draw_cabinet(front_only: bool,alpha: float) -> void:
	var gold:=Color("b09b74")
	var dark:=Color("475e66")
	if not front_only:
		_panel(Rect2(971,310,260,241),Color(0.18,0.23,0.25,alpha*0.10),Color.TRANSPARENT,12,0)
		_panel(Rect2(961,302,260,241),Color("e2d8bf"),Color(gold,alpha),10,2)
		_panel(Rect2(972,313,238,78),Color("f7f1df"),Color(gold,alpha*0.7),5,1)
		_text("校 准 档 案",Vector2(1017,345),23,Color(dark,alpha),true)
		_text("世 界 观 察 局  /  A - 01",Vector2(1020,372),12,Color(dark,alpha*0.65))
		_panel(Rect2(988,386,206,13),Color(dark,alpha),Color(gold,alpha),5,2)
	else:
		_panel(Rect2(963,401,256,140),Color("e2d8bf"),Color(gold,alpha),6,1)
		for y in [411,471]:
			_panel(Rect2(975,y,232,57),Color("eee6d2"),Color(gold,alpha*0.75),5,1)
			_panel(Rect2(1059,y+12,62,20),Color("faf6e9"),Color(gold,alpha),3,1)
			canvas.draw_line(Vector2(1077,y+24),Vector2(1103,y+24),Color(dark,alpha*0.8),2.0,true)
		canvas.draw_line(Vector2(986,399),Vector2(1198,399),Color("c6b38b"),3.0,true)
