extends Control
## Only visual state is animated; the actual objective always remains current.
var age:=2.0
var label:Label
var idle_mark:Label
var home:=Vector2.ZERO
var previous_text:=""
var old_target:=""

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	get_parent().set_meta("task_transition",self)
	previous_text=label.text;home=label.position

func confirm(receipt:String="") -> void:
	old_target=previous_text if receipt.is_empty() else receipt;age=0;queue_redraw()
	if is_instance_valid(idle_mark):idle_mark.hide()

func tick(delta:float) -> void:
	previous_text=label.text
	if age>=1.5:return
	age+=delta
	# Keep the latest text readable even if several conditions finish in one tick.
	label.modulate.a=lerpf(.65,1.0,smoothstep(.15,.75,age))
	label.position=home+Vector2(0,4.0*(1.0-smoothstep(.15,.75,age)))
	queue_redraw()
	if age>=1.5:cancel()

func cancel() -> void:
	age=2;old_target="";previous_text=label.text;label.position=home;label.modulate.a=1;queue_redraw()
	if is_instance_valid(idle_mark):idle_mark.show()

func _draw() -> void:
	if age>=1.5:return
	var alpha:=1.0-smoothstep(.8,1.5,age)
	var gold:=Color("e1c38b");gold.a=alpha*.9
	var w:float=get_parent().size.x
	draw_polyline(PackedVector2Array([Vector2(w-30,16),Vector2(w-26,20),Vector2(w-19,11)]),gold,1.8,true)
	draw_line(Vector2(12,2),Vector2(12+(w-24)*smoothstep(.18,.8,age),2),Color(gold,.45*alpha),1,true)
	if not old_target.is_empty() and age<.6:
		# A short completion receipt under the card; it never replaces the live goal.
		var font=preload("res://scripts/instrument_theme.gd").body()
		var text:="✓ "+old_target
		var y:float=get_parent().size.y+19
		var ink:=Color("162b35");ink.a=.88*(1-smoothstep(.35,.6,age))
		draw_style_box(preload("res://scripts/instrument_theme.gd").style(),Rect2(0,y-16,w,27))
		draw_string(font,Vector2(12,y+3),text,HORIZONTAL_ALIGNMENT_LEFT,w-24,16,Color(gold,ink.a))
