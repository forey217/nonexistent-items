extends StyleBox
## Small retained canvas primitives, in logical pixels. No screen texture or blur pass.
var mill:=false
var active:=false
var opacity:=.86

func _draw(canvas:RID,rect:Rect2) -> void:
	var r:=rect
	var base:=Color("304139") if mill else Color("3d423c")
	var copper:=Color("b39a69")
	var edge:=minf(14,r.size.x*.15)
	var xs:=[0.0,edge,r.size.x-edge,r.size.x]
	var ys:=[0.0,minf(12,r.size.y*.22),r.size.y-minf(10,r.size.y*.20),r.size.y]
	# A quiet diagonal reflection; the central text field stays consistently backed.
	for y in range(3):
		for x in range(3):
			var points:=PackedVector2Array();var colors:=PackedColorArray()
			for corner in [Vector2i(x,y),Vector2i(x+1,y),Vector2i(x+1,y+1),Vector2i(x,y+1)]:
				var u:float=xs[corner.x]/maxf(1,r.size.x);var v:float=ys[corner.y]/maxf(1,r.size.y)
				var c:=base.lightened(.035*(1-v)*(1-u)+(.035 if active else 0.0)).darkened(.09*v)
				c.a=clampf(opacity+(.025 if mill else 0.0),0,1)*(0.86 if corner.x in [0,3] or corner.y in [0,3] else 1.0)
				points.append(r.position+Vector2(xs[corner.x],ys[corner.y]));colors.append(c)
			RenderingServer.canvas_item_add_polygon(canvas,points,colors)
	# One-pixel contact shadow and a short reflection, never an enclosing frame.
	_line(canvas,r.position+Vector2(2,r.size.y+1),r.end+Vector2(-2,1),Color(0,0,0,.12))
	_line(canvas,r.position+Vector2(12,.5),r.position+Vector2(minf(r.size.x-12,112),.5),Color("b9c6b4")*Color(1,1,1,.25))
	_line(canvas,r.position+Vector2(12,r.size.y-.5),r.position+Vector2(minf(r.size.x-12,58),r.size.y-.5),Color(copper,.86 if active else .58))
	# Separate corner marks and an extremely faint, fixed-pitch material grain.
	_line(canvas,r.position+Vector2(.5,9),r.position+Vector2(.5,19),Color(copper,.40))
	_line(canvas,r.end-Vector2(.5,9),r.end-Vector2(.5,19),Color(copper,.26))
	for y in range(7,int(r.size.y)-4,9):
		_line(canvas,r.position+Vector2(8,y+.5),r.position+Vector2(r.size.x-8,y+.5),Color(.82,.84,.76,.008))
	if mill:
		for x in [18,24,34]:_line(canvas,r.position+Vector2(x,1),r.position+Vector2(x,4),Color(copper,.35))
	else:
		_line(canvas,r.position+Vector2(5,5),r.position+Vector2(9,5),Color(copper,.48))
		_line(canvas,r.position+Vector2(7,3),r.position+Vector2(7,7),Color(copper,.48))

func _line(canvas:RID,a:Vector2,b:Vector2,color:Color) -> void:
	RenderingServer.canvas_item_add_line(canvas,a,b,color,1.0,false)
