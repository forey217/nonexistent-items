extends Control
## Resolution-independent paper/optical UI. Text is rendered separately.
var speaker := "tesla"
var kind := "story"

func shape(at: Vector2, dimensions: Vector2, cut: float=15.0) -> PackedVector2Array:
	return PackedVector2Array([at+Vector2(cut,0),at+Vector2(dimensions.x-cut,0),at+Vector2(dimensions.x,cut),at+Vector2(dimensions.x,dimensions.y-cut),at+Vector2(dimensions.x-cut,dimensions.y),at+Vector2(cut,dimensions.y),at+Vector2(0,dimensions.y-cut),at+Vector2(0,cut)])

func _draw() -> void:
	var heroine := speaker=="yanyue"
	var accent := Color("83c8df") if heroine else Color("b99a60")
	var paper := Color("faf7ee")
	var outline := Color("bfa778")
	var cut := 19.0 if kind=="story" else 12.0
	var polygon := shape(Vector2.ZERO,size,cut)
	draw_colored_polygon(shape(Vector2(0,5),size,cut),Color(0.07,0.13,0.18,0.19))
	draw_colored_polygon(shape(Vector2(5,-4),size,cut),Color(accent,0.30))
	draw_colored_polygon(polygon,paper)
	draw_polyline(polygon+PackedVector2Array([polygon[0]]),outline,1.5,true)
	var inset := shape(Vector2(5,5),size-Vector2(10,10),cut-3)
	draw_polyline(inset+PackedVector2Array([inset[0]]),Color(outline,0.35),0.8,true)
	var portrait_right := not heroine
	var mark := Vector2(size.x-29,22) if portrait_right else Vector2(27,22)
	if heroine:
		draw_circle(mark,7,accent)
		draw_circle(mark+Vector2(3,-2),6,paper)
	else:
		draw_arc(mark,7,0,TAU,28,accent,1.1,true)
		draw_line(mark-Vector2(11,0),mark+Vector2(11,0),accent,0.9,true)
		draw_line(mark-Vector2(0,11),mark+Vector2(0,11),accent,0.9,true)
	var start := 330.0 if heroine and kind=="story" else (107.0 if heroine else 30.0)
	var end := size.x-330.0 if portrait_right and kind=="story" else (size.x-107.0 if portrait_right else size.x-30.0)
	if kind=="story":
		var tab:=shape(Vector2(start-12,5),Vector2(174,43),8)
		draw_colored_polygon(tab,Color("f0eadc"))
		draw_polyline(tab+PackedVector2Array([tab[0]]),Color(outline,0.70),1.0,true)
		draw_line(Vector2(start,50),Vector2(end,50),Color(outline,0.40),1,true)
		var x := size.x-38 if heroine else 38.0
		draw_colored_polygon(PackedVector2Array([Vector2(x-5,size.y-23),Vector2(x+5,size.y-23),Vector2(x,size.y-16)]),accent)
	else:
		draw_line(Vector2(start,size.y-8),Vector2(end,size.y-8),Color(accent,0.65),1.2,true)
		if not heroine:
			for i in range(5):draw_line(Vector2(145+i*12,0),Vector2(145+i*12,4 if i%2 else 7),Color(outline,0.7),1,true)
