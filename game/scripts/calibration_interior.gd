extends RefCounted
## Continuous, real 3D interior. Presentation only: puzzle/collision coordinates stay unchanged.
const MODULE:=8.0
const WALL_HEIGHT:=4.0

func build(b: RefCounted) -> void:
	_floor(b)
	_walls(b)
	_boundary(b)
	# Architecture uses even interior illumination; tall walls must not cast
	# a giant directional shadow across the gameplay surface.
	_no_architectural_shadows(b.scene)

func _no_architectural_shadows(node: Node) -> void:
	if node is GeometryInstance3D:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():_no_architectural_shadows(child)

func _floor(b: RefCounted) -> void:
	var mat: StandardMaterial3D=b.material(b.cream.albedo_color.darkened(0.13))
	mat.albedo_texture=b.stone_texture
	mat.uv1_scale=Vector3(42,42,1)
	mat.roughness=0.88
	var plane:=PlaneMesh.new();plane.size=Vector2(84,84)
	var floor:=MeshInstance3D.new();floor.name="ContinuousLaboratoryFloor"
	floor.mesh=plane;floor.material_override=mat;floor.position=Vector3(6,0.02,4)
	b.scene.add_child(floor)
	var grout: StandardMaterial3D=b.material(Color("c2c0b6"))
	# Quiet joints continue beyond the viewport; no floating deck silhouette.
	for i in range(-18,25):
		b.box(Vector3(i*2,0.022,4),Vector3(0.009,0.004,84),grout)
		b.box(Vector3(6,0.022,i*2),Vector3(84,0.004,0.009),grout)
	var trim: StandardMaterial3D=b.material(Color("a89570"))
	for z in [0.43,7.58]:b.box(Vector3(6,0.028,z),Vector3(11.16,0.008,0.022),trim)
	for x in [0.43,11.58]:b.box(Vector3(x,0.028,4),Vector3(0.022,0.008,7.16),trim)

func _walls(b: RefCounted) -> void:
	_elevation(b,false)
	_elevation(b,true)
	var frame: StandardMaterial3D=b.material(Color("354450"))
	b.box(Vector3(-0.14,7,-0.14),Vector3(0.42,14,0.42),frame)
	for offset in [Vector3(0.085,0,-0.14),Vector3(-0.14,0,0.085)]:
		b.box(offset+Vector3(0,7,0),Vector3(0.025,14,0.025),b.brass)

func _point(at: Vector3,side: bool) -> Vector3:
	return Vector3(at.z,at.y,at.x) if side else at

func _elevation(b: RefCounted,side: bool) -> void:
	var parent: Node3D=b.scene
	var elevation:=Node3D.new()
	elevation.name="InteriorSideWall" if side else "InteriorBackWall"
	parent.add_child(elevation);b.scene=elevation
	var backing: StandardMaterial3D=b.material(Color("e1d8c5"))
	var upper: StandardMaterial3D=b.material(Color("e8e1d3"))
	upper.albedo_texture=b.stone_texture
	upper.uv1_scale=Vector3(3,3,1)
	var frame: StandardMaterial3D=b.material(Color("354450"))
	var gold: StandardMaterial3D=b.material(Color("bda77b"))
	gold.metallic=0.42;gold.roughness=0.53
	b.box(_point(Vector3(6,7,-0.46),side),_point(Vector3(100,14,0.20),side),backing)
	for i in range(-5,7):
		var center: float=-0.34+(float(i)+0.5)*MODULE
		b.textured_panel(_point(Vector3(center,WALL_HEIGHT*0.5,-0.34),side),Vector2(MODULE,WALL_HEIGHT),b.panorama_wall if side else b.lab_wall,PI*0.5 if side else 0.0)
		b.box(_point(Vector3(center,9,-0.335),side),_point(Vector3(MODULE,10,0.04),side),upper)
		for height in [0.10,4.05,7.0,10.0,13.0]:
			b.box(_point(Vector3(center,height,-0.22),side),_point(Vector3(MODULE,0.12,0.16),side),frame)
			b.box(_point(Vector3(center,height+0.05,-0.125),side),_point(Vector3(MODULE,0.018,0.018),side),gold)
		var seam: float=center-MODULE*0.5
		b.box(_point(Vector3(seam,7,-0.24),side),_point(Vector3(0.18,14,0.20),side),frame)
		b.box(_point(Vector3(seam+0.055,7,-0.12),side),Vector3(0.018,14,0.018),gold)
	b.scene=parent

func _boundary(b: RefCounted) -> void:
	# Low transparent partitions mark the unchanged walkable boundary.
	# They are render geometry only; existing 2D walls still enforce the boundary.
	var glass: StandardMaterial3D=b.material(Color(0.62,0.76,0.78,0.13))
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var post: StandardMaterial3D=b.material(Color("657782"))
	var trim: StandardMaterial3D=b.material(Color("bda678"))
	for x in range(7):
		b.box(Vector3(x*2,0.22,8),Vector3(0.038,0.44,0.038),post)
	for z in range(5):
		b.box(Vector3(12,0.22,z*2),Vector3(0.038,0.44,0.038),post)
	b.box(Vector3(6,0.20,8),Vector3(12,0.32,0.012),glass)
	b.box(Vector3(12,0.20,4),Vector3(0.012,0.32,8),glass)
	b.box(Vector3(6,0.40,8),Vector3(12,0.025,0.025),trim)
	b.box(Vector3(12,0.40,4),Vector3(0.025,0.025,8),trim)
