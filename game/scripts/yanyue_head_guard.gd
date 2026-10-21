extends Node3D
## A real 3D head collider, swept before accepting movement from the 2D controller.
const HEAD_HEIGHT:=1.95
const HEAD_RADIUS:=0.32
const WALL_LAYER:=4
var view: Node2D
var body:=CharacterBody3D.new()
var outline:=MeshInstance3D.new()
var blocked_sweeps:=0

func _ready() -> void:
	name="YanyueHeadCollision"
	for data in [
		[Vector3(0.10,1.02,4),Vector3(0.36,2.04,8.4)],
		[Vector3(6,1.02,0.10),Vector3(12.4,2.04,0.36)]
	]:
		var wall:=StaticBody3D.new()
		wall.name="HeadWall"
		wall.collision_layer=WALL_LAYER
		wall.collision_mask=0
		var collider:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=data[1]
		collider.shape=shape
		wall.position=data[0]
		wall.add_child(collider)
		add_child(wall)
	body.name="HeadBody"
	body.collision_layer=0
	body.collision_mask=WALL_LAYER
	var collider:=CollisionShape3D.new()
	var sphere:=SphereShape3D.new()
	sphere.radius=HEAD_RADIUS
	collider.shape=sphere
	body.add_child(collider)
	add_child(body)
	var mesh:=SphereMesh.new()
	mesh.radius=HEAD_RADIUS
	mesh.height=HEAD_RADIUS*2.0
	outline.mesh=mesh
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color=Color(0.22,0.85,0.96,0.23)
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	outline.material_override=mat
	outline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(outline)
	outline.visible=false

func sync_position(logic: Vector2,debug: bool) -> void:
	body.position=view.to_world(logic,HEAD_HEIGHT)
	outline.visible=debug

func guard_motion(from: Vector2,motion: Vector2) -> Vector2:
	if motion.length_squared()<0.000001:return motion
	var origin: Vector3=view.to_world(from,HEAD_HEIGHT)
	var remaining: Vector3=view.to_world(from+motion)-view.to_world(from)
	var travel:=Vector3.ZERO
	for slide in range(3):
		if remaining.length_squared()<0.00000001:break
		var query:=PhysicsTestMotionParameters3D.new()
		query.from=Transform3D(Basis.IDENTITY,origin+travel)
		query.motion=remaining
		query.margin=0.012
		var result:=PhysicsTestMotionResult3D.new()
		if not PhysicsServer3D.body_test_motion(body.get_rid(),query,result):
			travel+=remaining
			break
		blocked_sweeps+=1
		travel+=result.get_travel()
		remaining=result.get_remainder().slide(result.get_collision_normal())
	return Vector2(46.0*(travel.x-travel.z),23.0*(travel.x+travel.z))

func segment_is_clear(from: Vector2,to: Vector2) -> bool:
	return guard_motion(from,to-from).distance_to(to-from)<0.015
