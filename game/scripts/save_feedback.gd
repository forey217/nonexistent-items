extends CanvasLayer
## One reusable stamp. Only the successful file-commit branch may notify it.
const FONT=preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf")
const DURATION:=1.40
var ink:=Control.new()
var age:=DURATION
var commits:=0
var displays:=0
var last_display:=-10.0
var clock:=0.0
var suppressed:=false
var paper:=StyleBoxFlat.new()
var instrument_mode:=false
const Instruments=preload("res://scripts/instrument_theme.gd")
var glass:=Instruments.style()

func _ready() -> void:
	layer=25
	paper.bg_color=Color(0.98,0.96,0.91,0.96)
	paper.border_color=Color("b9a374");paper.set_border_width_all(1);paper.set_corner_radius_all(5)
	ink.size=Vector2(258,40)
	ink.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ink.draw.connect(_draw_stamp)
	add_child(ink);ink.hide()

func notify_saved() -> void:
	commits+=1
	# Successes within one feedback interval share the same notification.
	if clock-last_display<1.8:return
	last_display=clock;displays+=1;age=0.0

func _process(delta: float) -> void:
	clock+=delta;age=minf(DURATION,age+delta)
	ink.visible=not suppressed and age<DURATION
	if ink.visible:
		ink.modulate.a=smoothstep(0.0,0.15,age)*(1.0-smoothstep(1.02,DURATION,age))
		ink.queue_redraw()

func _draw_stamp() -> void:
	ink.draw_style_box(glass if instrument_mode else paper,Rect2(Vector2.ZERO,ink.size))
	var gold:=Instruments.GOLD if instrument_mode else Color("ab8a51")
	var center:=Vector2(24,20)
	ink.draw_arc(center,10,-PI*0.5,PI*1.5,40,gold,1.0,true)
	ink.draw_polyline(PackedVector2Array([center+Vector2(-5,0),center+Vector2(-1,4),center+Vector2(6,-4)]),gold,1.7,true)
	ink.draw_string(FONT,Vector2(44,26),"观测记录已保存",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Instruments.TEXT if instrument_mode else Color("294653"))

