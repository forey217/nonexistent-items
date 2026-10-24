extends RefCounted
## A normalized direction dead band, shared by 2D and camera-projected sprites.
static func row(direction: Vector2,previous: int,force: bool=false) -> int:
	if direction.length_squared()<0.0001:return previous
	var unit:=direction.normalized()
	if force:return (0 if unit.x>=0 else 1) if unit.y>=0 else (2 if unit.x>=0 else 3)
	var horizontal:=1 if previous%2==0 else -1
	var vertical:=1 if previous<2 else -1
	var threshold:=0.14
	if absf(unit.x)>threshold:horizontal=1 if unit.x>0 else -1
	if absf(unit.y)>threshold:vertical=1 if unit.y>0 else -1
	return (0 if horizontal>0 else 1) if vertical>0 else (2 if horizontal>0 else 3)
