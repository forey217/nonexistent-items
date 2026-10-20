extends RefCounted

const CELL := 10.0
var grid := AStarGrid2D.new()
var floor_polygon := PackedVector2Array()
var solid_polygons: Array[PackedVector2Array] = []
var segment_clear: Callable

func configure(floor_shape: PackedVector2Array, obstacles: Array[PackedVector2Array], radius: float, ray_test: Callable) -> void:
	segment_clear = ray_test
	var inset := Geometry2D.offset_polygon(floor_shape, -radius - 3.0)
	assert(not inset.is_empty())
	floor_polygon = inset[0]
	for polygon in obstacles:
		var expanded := Geometry2D.offset_polygon(polygon, radius + 3.0)
		if not expanded.is_empty():
			solid_polygons.append(expanded[0])
	grid.region = Rect2i(0, 0, 128, 80)
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = Vector2(CELL * 0.5, CELL * 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for y in range(grid.region.size.y):
		for x in range(grid.region.size.x):
			var cell := Vector2i(x, y)
			grid.set_point_solid(cell, not is_safe(grid.get_point_position(cell)))

func is_safe(point: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(point, floor_polygon):
		return false
	for polygon in solid_polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return false
	return true

func _cell_for(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))

func _free_cell_near(point: Vector2, require_connector: bool) -> Vector2i:
	var center := _cell_for(point)
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var candidate := center + Vector2i(dx, dy)
			if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate):
				continue
			var location := grid.get_point_position(candidate)
			var distance := point.distance_squared_to(location)
			if distance >= best_distance:
				continue
			if require_connector and not bool(segment_clear.call(point, location)):
				continue
			best_distance = distance
			best = candidate
	return best

func find_path(start: Vector2, destination: Vector2) -> PackedVector2Array:
	if not is_safe(destination):
		return PackedVector2Array()
	var start_id := _free_cell_near(start, true)
	var end_id := _free_cell_near(destination, true)
	if start_id.x < 0 or end_id.x < 0:
		return PackedVector2Array()
	var raw := grid.get_point_path(start_id, end_id, false)
	if raw.is_empty():
		return PackedVector2Array()
	raw.append(destination)
	# Smooth only where a swept circle confirms full-width clearance.
	var result := PackedVector2Array()
	var origin := start
	var next_index := 0
	while next_index < raw.size():
		var furthest := next_index
		for index in range(raw.size() - 1, next_index - 1, -1):
			if bool(segment_clear.call(origin, raw[index])):
				furthest = index
				break
		if not bool(segment_clear.call(origin, raw[furthest])):
			return PackedVector2Array()
		result.append(raw[furthest])
		origin = raw[furthest]
		next_index = furthest + 1
	return result
