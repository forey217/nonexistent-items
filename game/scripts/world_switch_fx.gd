extends Node2D
var active := false
var progress := 0.0
var color := Color("9bdce7")

func play(at: Vector2,index: int) -> void:
	position=at
	color=[Color("9bdce7"),Color("edb875"),Color("c7b3f6"),Color("b4c9a4")][index]
	progress=0
	active=true
	queue_redraw()

func update_progress(value: float) -> void:
	progress=clampf(value,0,1)
	if progress>=1: active=false
	queue_redraw()

func cancel() -> void:
	active=false
	queue_redraw()

func _draw() -> void:
	if not active:return
	var fade:=sin(progress*PI)
	var radius:=24.0+progress*62.0
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.43))
	draw_circle(Vector2.ZERO,radius,Color(color,fade*0.09))
	draw_arc(Vector2.ZERO,radius,0,TAU,80,Color(color,fade*0.85),2.0,true)
	var triangle:=PackedVector2Array()
	for i in range(4):
		triangle.append(Vector2.from_angle(-PI*0.5+float(i)/3.0*TAU+progress*0.5)*radius*0.82)
	draw_polyline(triangle,Color(color,fade*0.8),1.8,true)
	draw_set_transform(Vector2.ZERO)
	# Fold seams rise around the actor; no teleport, camera shake or white flash.
	for side in [-1,1]:
		var x:=float(side)*(19.0+progress*28.0)
		var seam:=PackedVector2Array([Vector2(x*0.4,4),Vector2(x,-43),Vector2(x*0.55,-112)])
		draw_polyline(seam,Color(color,fade*0.55),1.5,true)
	for i in range(5):
		var angle:=float(i)/5.0*TAU+progress*0.6
		var at:=Vector2(cos(angle)*(24+progress*25),-53+sin(angle)*35-progress*12)
		var shard:=PackedVector2Array([at+Vector2(0,-4),at+Vector2(3,0),at+Vector2(0,4),at+Vector2(-3,0)])
		draw_colored_polygon(shard,Color(color,fade*0.9))
