extends Node3D
## Code-native engravings share one visual language across the three worlds.
var view: Node2D
var marks: Array[Node3D] = []
var inks: Array[StandardMaterial3D] = []
var rings: Array[MeshInstance3D] = []
var ring_inks: Array[StandardMaterial3D] = []
var crack: Node3D
var seal: Node3D
var hovered_index := -1
var strengths: Array[float] = [0.0,0.0,0.0]
var builder = preload("res://scripts/calibration_scene_builder.gd").new()

func _ready() -> void:
	builder.configure(0,self)
	var brass := builder.material(Color("b9a174"))
	var dark := builder.material(Color("354a56"))
	for i in range(3):
		var root := Node3D.new()
		root.position=marker_position(i)
		add_child(root)
		marks.append(root)
		var ink := builder.material(Color("e0c987"),true)
		ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.cull_mode=BaseMaterial3D.CULL_DISABLED
		inks.append(ink)
		var ring_ink := builder.material(Color("ffdf8b"),true)
		ring_ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_inks.append(ring_ink)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius=0.45
		torus.outer_radius=0.47
		torus.rings=48
		torus.ring_segments=8
		ring.mesh=torus
		ring.material_override=ring_ink
		add_child(ring)
		ring.position=anchor_position(i)
		root.rotation.y=PI*0.25
		ring.visible=false
		rings.append(ring)
		if i<2:
			var disk := builder.cylinder(Vector3.ZERO,0.15,0.012,brass,root)
			var face := builder.cylinder(Vector3(0,0.009,0) if i==0 else Vector3(0,0,0.009),0.135,0.008,dark,root)
			if i==1:
				disk.rotation.x=PI*0.5
				face.rotation.x=PI*0.5
			var polygon := _star(0.11) if i==0 else _crescent(0.11)
			_flat(polygon,ink,root,i==0,Vector3(0,0.016,0) if i==0 else Vector3(0,0,0.016))
		else:
			crack=Node3D.new();root.add_child(crack)
			var path := PackedVector2Array([Vector2(0,0.86),Vector2(-0.12,0.55),Vector2(0.10,0.23),Vector2(-0.10,-0.05),Vector2(0.08,-0.40),Vector2(-0.04,-0.80)])
			_ribbon(path,0.025,ink,crack)
			_ribbon(PackedVector2Array([path[2],Vector2(0.28,0.38),Vector2(0.38,0.31)]),0.014,ink,crack)
			_ribbon(PackedVector2Array([path[3],Vector2(-0.31,-0.21)]),0.014,ink,crack)
			seal=Node3D.new();root.add_child(seal)
			_ribbon(PackedVector2Array([Vector2(0,-0.75),Vector2(0,0.75)]),0.014,ink,seal)
			_flat(PackedVector2Array([Vector2(0,0.24),Vector2(0.19,0),Vector2(0,-0.24),Vector2(-0.19,0)]),ink,seal,false)
			seal.hide()
	# A matching fracture engraving links the end pad to the rift without an arrow.
	var end := Node3D.new()
	end.position=view.to_world(view.room.rail_end,0.30)
	add_child(end)
	var end_ink := builder.material(Color("55516b"))
	_flat(PackedVector2Array([Vector2(-0.10,-0.23),Vector2(0.03,-0.05),Vector2(-0.06,0.03),Vector2(0.12,0.23),Vector2(0.01,0.01),Vector2(0.10,-0.07)]),end_ink,end,true)

func anchor_position(index: int) -> Vector3:
	# These are the actual paperweight contact surfaces, not their decorative signs.
	if index==0:return view.to_world(view.room.first_plate,0.29)
	if index==1:return view.to_world(view.room.rail_end,2.75)
	return view.to_world(view.room.rail_end,0.29)

func marker_position(index: int) -> Vector3:
	if index==0:return view.to_world(view.room.first_plate,0.30)
	if index==1:return view.to_world(view.room.rail_end,3.12)+Vector3(-0.50,0,-0.20)
	return view.to_world(view.room.portal_position,1.0)+Vector3(0.08,0,0.08)

func sync(state: RefCounted,delta: float) -> void:
	var done: Array[bool]=[state.first_latched,state.receiver_latched,view.room.gate_ready]
	var base_colors: Array[Color]=[Color("dfc88d"),Color("b7cee4"),Color("ad9acb")]
	for i in range(3):
		strengths[i]=move_toward(strengths[i],1.0 if hovered_index==i else 0.0,delta*7.0)
		var base := Color("8ccba7") if done[i] else base_colors[i]
		inks[i].albedo_color=base
		inks[i].emission=inks[i].albedo_color
		inks[i].emission_energy_multiplier=0.3
		rings[i].visible=strengths[i]>0.01
		rings[i].scale=Vector3.ONE*(0.96+strengths[i]*0.04)
		ring_inks[i].albedo_color=base.lerp(Color("ffe09a"),strengths[i])
		ring_inks[i].emission=ring_inks[i].albedo_color
	crack.visible=not view.room.gate_ready
	seal.visible=view.room.gate_ready
	crack.scale.x=1.0-smoothstep(0.55,0.94,view.room.seal_age) if view.room.seal_active else 1.0

func _star(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(10):points.append(Vector2.from_angle(-PI*0.5+i*PI/5.0)*(radius if i%2==0 else radius*0.43))
	return points

func _crescent(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(33):
		var a := lerpf(-PI*0.5,PI*0.5,float(i)/32.0)
		points.append(Vector2(-cos(a),sin(a))*radius)
	for i in range(33):
		var a := lerpf(PI*0.5,-PI*0.5,float(i)/32.0)
		points.append(Vector2(-cos(a)*0.28,sin(a))*radius)
	return points

func _ribbon(path: PackedVector2Array,width: float,ink: StandardMaterial3D,parent: Node3D) -> void:
	for i in range(path.size()-1):
		var normal := (path[i+1]-path[i]).normalized().orthogonal()*width
		_flat(PackedVector2Array([path[i]+normal,path[i+1]+normal,path[i+1]-normal,path[i]-normal]),ink,parent,false)

func _flat(points: PackedVector2Array,ink: StandardMaterial3D,parent: Node3D,horizontal: bool,offset:=Vector3.ZERO) -> MeshInstance3D:
	var indices := Geometry2D.triangulate_polygon(points)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,ink)
	for index in indices:
		var p := points[index]
		mesh.surface_add_vertex(Vector3(p.x,0,p.y) if horizontal else Vector3(p.x,p.y,0))
	mesh.surface_end()
	var result := MeshInstance3D.new()
	result.mesh=mesh
	result.position=offset
	result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result
