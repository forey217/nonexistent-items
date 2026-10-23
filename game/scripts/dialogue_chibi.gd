extends Control
## Transparent character art over a quiet runtime-drawn brass/ivory badge.
var speaker:=""
var texture: Texture2D
var opacity:=1.0
var observation:=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	size=Vector2(64,64)

func set_speaker(value: String) -> void:
	if speaker!=value:
		speaker=value;opacity=0.0
		texture=load("res://assets/dialogue_chibi_v37/"+("yanyue" if value=="yanyue" else "tesla")+".png")
		set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	opacity=minf(1.0,opacity+delta/0.12)
	queue_redraw()
	if opacity>=1.0:set_process(false)

func _draw() -> void:
	if not observation:
		draw_circle(Vector2(32,34),30,Color(0.08,0.16,0.20,0.12*opacity))
		draw_circle(Vector2(32,32),30,Color(0.98,0.96,0.91,0.98*opacity))
		draw_arc(Vector2(32,32),30,0,TAU,80,Color(0.72,0.60,0.40,opacity),1.3,true)
	if texture==null:return
	var dimensions:=texture.get_size()
	var scale_factor:=minf(60.0/dimensions.x,60.0/dimensions.y)
	var fitted:=dimensions*scale_factor
	draw_texture_rect(texture,Rect2(Vector2(32,32)-fitted*0.5,fitted),false,Color(1,1,1,opacity))
