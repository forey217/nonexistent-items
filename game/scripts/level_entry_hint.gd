extends Control
## Offered once after control handover; only real play input dismisses it.
const Instruments=preload("res://scripts/instrument_theme.gd")
var offered:=false
var dismissed:=false
var obscured:=false
var opacity:=0.0
var text:="WASD / 左键移动　·　右键 / E 互动　·　H 提示"
var caption:Label

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(660,36)
	caption=Instruments.label(self,text,Vector2.ZERO,size,18)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	modulate.a=0;hide();set_process(false)

func offer() -> void:
	if offered:return
	offered=true;set_process(true)

func dismiss() -> void:
	if offered and not dismissed:dismissed=true;set_process(true)

func _process(delta:float) -> void:
	opacity=move_toward(opacity,0.0 if dismissed else 1.0,delta/(.65 if dismissed else .3))
	modulate.a=opacity;visible=not obscured and opacity>.001
	queue_redraw()
	if dismissed and opacity==0:set_process(false)
	elif not dismissed and opacity==1:set_process(false)

func _draw() -> void:
	for i in range(16):
		var inset:=float(i)*3.0
		draw_rect(Rect2(inset,0,size.x-inset*2,size.y),Color(Instruments.DEEP,.028))
