extends "res://scripts/bureau_navigation.gd"
## Hub-only large map grid. Tutorial keeps its original navigation implementation.
var grid_origin:=Vector2.ZERO

func configure(floor_shape: PackedVector2Array,obstacles: Array[PackedVector2Array],radius: float,ray_test: Callable) -> void:
	super.configure(floor_shape,obstacles,radius,ray_test)
	var bounds:=Rect2(floor_shape[0],Vector2.ZERO)
	for point in floor_shape:bounds=bounds.expand(point)
	grid_origin=(bounds.position/ CELL).floor()*CELL-Vector2.ONE*CELL
	var dimensions: Vector2i=Vector2i(((bounds.end-grid_origin)/CELL).ceil())+Vector2i(2,2)
	grid.region=Rect2i(Vector2i.ZERO,dimensions)
	grid.offset=grid_origin+Vector2.ONE*(CELL*0.5)
	grid.update()
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			var cell:=Vector2i(x,y)
			grid.set_point_solid(cell,not is_safe(grid.get_point_position(cell)))

func _cell_for(point: Vector2) -> Vector2i:
	return Vector2i(((point-grid_origin)/CELL).floor())
