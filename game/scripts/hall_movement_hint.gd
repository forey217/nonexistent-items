extends Control
## One movement invitation: fade in on handover, fade out on the first input.
const SERIF=preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf")
const INK=Color("294859")
const GOLD=Color("a5834e")
var offered := false
var dismissed := false
var obscured := false
var opacity := 0.0
var age := 0.0

func _ready() -> void:
	position=Vector2(340,696)
	size=Vector2(600,84)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_mode=Node.PROCESS_MODE_ALWAYS
	modulate.a=0.0
	hide()

func offer() -> void:
	if offered:return
	offered=true
	show()

func obscure(value: bool) -> void:
	obscured=value
	visible=offered and not value and opacity>0.001

func dismiss() -> void:
	if offered:dismissed=true

func _process(delta: float) -> void:
	if not offered:return
	age+=delta
	opacity=move_toward(opacity,0.0 if dismissed else 1.0,delta/(0.85 if dismissed else 0.7))
	modulate.a=opacity
	position.y=696+7*(1.0-opacity)
	visible=not obscured and opacity>0.001
	queue_redraw()

func _text(text: String,at: Vector2,font_size: int,color: Color) -> void:
	draw_string_outline(SERIF,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color(0.98,0.96,0.89,0.65))
	draw_string(SERIF,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	# A small instrument divider; the text floats directly above the marble.
	for side in [-1,1]:
		draw_line(Vector2(300+side*12,10),Vector2(300+side*86,10),Color(GOLD,0.5),1,true)
	var star:=PackedVector2Array([Vector2(300,5),Vector2(303,10),Vector2(300,15),Vector2(297,10)])
	draw_colored_polygon(star,Color(GOLD,0.85))
	var key_start:=70.0
	for i in range(4):
		var at:=Vector2(key_start+i*35,26)
		var shape:=PackedVector2Array([at+Vector2(4,0),at+Vector2(25,0),at+Vector2(29,4),at+Vector2(29,28),at+Vector2(25,32),at+Vector2(4,32),at+Vector2(0,28),at+Vector2(0,4),at+Vector2(4,0)])
		draw_colored_polygon(shape,Color(0.99,0.96,0.87,0.12))
		draw_polyline(shape,Color(GOLD,0.82),1,true)
		var letter: String=["W","A","S","D"][i]
		var width:=SERIF.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
		_text(letter,at+Vector2((29-width)*0.5,24),20,INK)
	_text("移动",Vector2(218,52),24,INK)
	draw_colored_polygon(PackedVector2Array([Vector2(292,40),Vector2(295,44),Vector2(292,48),Vector2(289,44)]),GOLD)
	_text("鼠标左键",Vector2(318,52),22,INK)
	_text("点击地面",Vector2(422,52),24,INK)
