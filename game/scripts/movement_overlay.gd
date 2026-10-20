extends Node2D

var room: Node2D
var show_debug := false

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if room == null:
		return
	if room.marker_visible:
		var color := Color("5e9cb7") if room.marker_valid else Color("b56b53")
		draw_set_transform(room.marker_position,0,Vector2(1,0.5))
		draw_arc(Vector2.ZERO,13,0,TAU,40,color,2,true)
		draw_circle(Vector2.ZERO,3,color)
		draw_set_transform(Vector2.ZERO)
	if not show_debug:
		return
	draw_polyline(room.floor_polygon + PackedVector2Array([room.floor_polygon[0]]),Color(0.1,0.5,0.75,0.8),2,true)
	for prop in room.props:
		var polygon: PackedVector2Array = prop.global_footprint()
		draw_colored_polygon(polygon,Color(0.85,0.28,0.12,0.15))
		draw_polyline(polygon + PackedVector2Array([polygon[0]]),Color(0.85,0.28,0.12,0.9),1.5,true)
	draw_arc(room.player.position,room.player.FOOT_RADIUS,0,TAU,40,Color("2f88ad"),2,true)
	if room.player.is_navigating():
		var route := PackedVector2Array([room.player.position])
		for index in range(room.player.route_index,room.player.route.size()):
			route.append(room.player.route[index])
		if route.size()>1:
			draw_polyline(route,Color(0.1,0.48,0.7,0.8),2,true)
