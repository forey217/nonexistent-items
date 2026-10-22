extends Node2D
var index:=1
var record: Dictionary={"status":"empty","data":{}}
var selected:=false
var hovered:=false
var paper: Texture2D
var thumbnail: Texture2D
var location:=""
var progress:=""
var font:=FontVariation.new()
const RECT:=Rect2(-130,-182,260,364)
const ACTION:=Rect2(-98,130,196,30)
const INK:=Color("203b4a")

func _ready() -> void:
	font.base_font=preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf")
	font.variation_embolden=0.16

func contains(at: Vector2) -> bool:
	return RECT.has_point(to_local(at))

func on_action(at: Vector2) -> bool:
	return ACTION.has_point(to_local(at))

func text(value: String,y: float,points: int,color: Color=INK) -> void:
	var width:=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,points).x
	draw_string(font,Vector2(-width*0.5,y),value,HORIZONTAL_ALIGNMENT_LEFT,210,points,color)

func _draw() -> void:
	var outline:=StyleBoxFlat.new()
	outline.bg_color=Color(0,0,0,0);outline.border_color=Color("efd18c")
	outline.set_border_width_all(2 if selected else 1)
	outline.set_corner_radius_all(4)
	outline.shadow_color=Color(0.85,0.64,0.27,0.30 if selected else 0.0);outline.shadow_size=7
	if paper!=null:draw_texture_rect(paper,RECT,false)
	if selected or hovered:draw_style_box(outline,Rect2(-130,-134,260,315))
	text("存档 %02d"%index,-70,27)
	draw_line(Vector2(-84,-53),Vector2(84,-53),Color("a59270"),0.8,true)
	var ready: bool=record.status=="ready"
	var damaged: bool=record.status=="damaged"
	text(location if ready else ("记录暂不可读" if damaged else "新建记录"),-25,21)
	if ready:
		if thumbnail!=null:
			draw_texture_rect_region(thumbnail,Rect2(-88,-8,176,62),Rect2(245,220,800,350),Color(0.85,0.79,0.66,0.88))
			draw_rect(Rect2(-88,-8,176,62),Color("af9971"),false,1)
		text(progress,76,16)
		var stamp:=Time.get_datetime_dict_from_unix_time(int(record.data.saved_at)+int(Time.get_time_zone_from_system().bias)*60)
		text("最近 %02d-%02d  %02d:%02d"%[stamp.month,stamp.day,stamp.hour,stamp.minute],97,14,Color("53616c"))
		text("观测 %d 分钟"%int(float(record.data.play_seconds)/60.0),115,13,Color("53616c"))
	else:
		for radius in [39.0,49.0]:draw_arc(Vector2(0,34),radius,0.25,TAU-0.35,64,Color(0.67,0.57,0.40,0.34),0.8,true)
		draw_line(Vector2(-13,34),Vector2(13,34),Color("8b7454"),2,true)
		draw_line(Vector2(0,21),Vector2(0,47),Color("8b7454"),2,true)
		text("原记录已保留" if damaged else "记录新的观测旅程",106,14,Color("53616c"))
	var button:=StyleBoxFlat.new();button.bg_color=Color("213846") if selected else Color(0.87,0.83,0.72,0.5)
	button.border_color=Color("ac915c");button.set_border_width_all(1);button.set_corner_radius_all(3)
	draw_style_box(button,ACTION)
	text("无法读取" if damaged else ("继续观测" if ready else "开启观测"),151,18,Color("f8efd6") if selected else INK)
	if selected:
		draw_circle(Vector2(0,-139),4,Color("97dce8"))
		draw_arc(Vector2(0,-139),8,0,TAU,32,Color(0.64,0.87,0.94,0.6),1,true)
