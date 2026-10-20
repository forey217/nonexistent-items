extends Node2D

const ORIGIN := Vector2(640, 220)
const AXIS_U := Vector2(52, 26)
const AXIS_V := Vector2(-52, 26)

func iso(u: float, v: float) -> Vector2:
	return ORIGIN + AXIS_U * u + AXIS_V * v

func _draw() -> void:
	var floor_shape := PackedVector2Array([iso(0,0), iso(9,0), iso(9,9), iso(0,9)])
	# A shallow plinth makes the open front edges readable without hiding the actor.
	for edge in [[iso(9,0), iso(9,9)], [iso(9,9), iso(0,9)]]:
		var side := PackedVector2Array([edge[0], edge[1], edge[1]+Vector2(0,15), edge[0]+Vector2(0,15)])
		draw_colored_polygon(side, Color("a99e8b"))
		draw_polyline(side + PackedVector2Array([side[0]]), Color("6b655b"), 1.5, true)
	# Rear walls are backdrop art; their floor edge has a separate solid collision.
	for edge_index in range(2):
		var endpoint := iso(0,9) if edge_index == 0 else iso(9,0)
		var wall := PackedVector2Array([ORIGIN, endpoint, endpoint-Vector2(0,120), ORIGIN-Vector2(0,120)])
		draw_colored_polygon(wall, Color("ddd7cc") if edge_index == 0 else Color("d0cabe"))
		draw_polyline(wall + PackedVector2Array([wall[0]]), Color("615a50"), 2.0, true)
		for panel in range(10):
			var anchor := ORIGIN.lerp(endpoint, float(panel)/9.0)
			draw_line(anchor, anchor-Vector2(0,120), Color("a69c8d"), 1.0, true)
		var trim := Vector2(0,31)
		draw_line(ORIGIN-trim, endpoint-trim, Color("71675b"), 3.0, true)
		draw_line(ORIGIN-Vector2(0,116), endpoint-Vector2(0,116), Color("857256"), 4.0, true)
	for u in range(9):
		for v in range(9):
			var tile := PackedVector2Array([iso(u,v), iso(u+1,v), iso(u+1,v+1), iso(u,v+1)])
			var shade := Color("e7dfd0") if (u+v)%2 == 0 else Color("ded5c5")
			if u >= 3 and u <= 7 and v >= 4 and v <= 7:
				shade = Color("8195a1") if (u+v)%2 == 0 else Color("7b8e9a")
			draw_colored_polygon(tile, shade)
			draw_polyline(tile + PackedVector2Array([tile[0]]), Color(0.37,0.34,0.29,0.20), 1.0, true)
	var rug := PackedVector2Array([iso(3,4),iso(8,4),iso(8,8),iso(3,8),iso(3,4)])
	draw_polyline(rug, Color("bea16b"), 2.5, true)
	draw_polyline(floor_shape + PackedVector2Array([floor_shape[0]]), Color("746a5a"), 2.0, true)
	# Small office wall panels, kept away from the floor navigation area.
	var left_frame := PackedVector2Array([iso(0,3)-Vector2(0,100),iso(0,4.3)-Vector2(0,100),iso(0,4.3)-Vector2(0,47),iso(0,3)-Vector2(0,47)])
	draw_colored_polygon(left_frame, Color("9bafba"))
	draw_polyline(left_frame + PackedVector2Array([left_frame[0]]), Color("87734e"), 3.0, true)
	var center := (left_frame[0]+left_frame[2])*0.5
	draw_arc(center, 13, 0, TAU, 32, Color("e4eced"), 1.4, true)
