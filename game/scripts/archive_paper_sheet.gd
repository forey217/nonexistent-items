extends Control
## Reuse the clean paper from the save cards; all ornament and text stay native UI.
const PAPER=preload("res://assets/save_slots_v39/card.png")
const BRASS=Color("ac915c")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var shadow:=StyleBoxFlat.new()
	shadow.bg_color=Color(0.02,0.04,0.05,0.18)
	shadow.set_corner_radius_all(7)
	shadow.shadow_color=Color(0.01,0.02,0.03,0.40)
	shadow.shadow_size=20;shadow.shadow_offset=Vector2(0,12)
	draw_style_box(shadow,Rect2(Vector2(3,6),size-Vector2(6,4)))
	var outline:=PackedVector2Array([Vector2(8,0),Vector2(size.x-8,0),Vector2(size.x,8),size-Vector2(0,8),size-Vector2(8,0),Vector2(8,size.y),Vector2(0,size.y-8),Vector2(0,8),Vector2(8,0)])
	draw_colored_polygon(outline,Color("f2e9d4"))
	draw_texture_rect_region(PAPER,Rect2(Vector2(5,5),size-Vector2(10,10)),Rect2(96,320,768,480),Color(1,1,1,0.65))
	draw_polyline(outline,BRASS,1.5,true)
	draw_rect(Rect2(Vector2(13,13),size-Vector2(26,26)),Color(BRASS,0.42),false,0.8)
	for x in [29.0,size.x-29.0]:
		for y in [29.0,size.y-29.0]:
			var center:=Vector2(x,y)
			draw_line(center-Vector2(6,0),center+Vector2(6,0),Color(BRASS,0.6),0.8,true)
			draw_line(center-Vector2(0,6),center+Vector2(0,6),Color(BRASS,0.6),0.8,true)
	var middle:=size.x*0.5
	for side in [-1,1]:draw_line(Vector2(middle+side*12,123),Vector2(middle+side*170,123),Color(BRASS,0.55),0.9,true)
	draw_colored_polygon(PackedVector2Array([Vector2(middle,119),Vector2(middle+3,123),Vector2(middle,127),Vector2(middle-3,123)]),BRASS)
	var clip:=StyleBoxFlat.new()
	clip.bg_color=Color("bca474");clip.border_color=Color("81633b")
	clip.set_border_width_all(1);clip.set_corner_radius_all(4)
	draw_style_box(clip,Rect2(middle-29,-11,58,30))
	draw_rect(Rect2(middle-23,-6,46,18),Color("d5bd86"),false,1)
	draw_circle(Vector2(middle,4),3.4,Color("526b72"),true,-1,true)
	draw_circle(Vector2(middle-0.8,3),1.1,Color("c0e6e4"),true,-1,true)
