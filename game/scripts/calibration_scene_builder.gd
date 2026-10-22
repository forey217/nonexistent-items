extends RefCounted
## Shared geometry for the sprite baker and the live orbit presentation.
## Original geometry + Kenney CC0 meshes; 2D gameplay physics remain separate.
var scene: Node3D
var theme:=0
var cream: StandardMaterial3D
var metal: StandardMaterial3D
var brass: StandardMaterial3D
var dark: StandardMaterial3D
var glow: StandardMaterial3D
var palette_shader: Shader
var stone_texture: Texture2D=preload("res://assets/interior_v30/ivory_floor.png")
var lab_wall: Texture2D=preload("res://assets/interior_v30/calibration_wall.png")
var panorama_wall: Texture2D=preload("res://assets/interior_v30/panorama_wall.png")

func configure(index: int,parent: Node3D) -> void:
	theme=index
	scene=parent
	palette_shader=Shader.new()
	palette_shader.code="""shader_type spatial;
uniform sampler2D palette : source_color, filter_nearest;
uniform vec4 enamel : source_color;
uniform vec4 alloy : source_color;
uniform vec4 slate : source_color;
void fragment(){
 vec3 c=texture(palette,UV).rgb;
 float lum=dot(c,vec3(0.299,0.587,0.114));
 vec3 result=enamel.rgb;
 if(lum<0.43) result=slate.rgb*mix(0.65,1.0,lum/0.43);
 else if(c.r>c.b*1.18 && c.r>c.g*1.08) result=alloy.rgb;
 else result=enamel.rgb*mix(0.8,1.08,lum);
 ALBEDO=result; ROUGHNESS=0.8;
}"""
	var creams := [Color("e4e9e7"),Color("e8dec9"),Color("e2dfee")]
	var metals := [Color("304a5c"),Color("4b4642"),Color("41435b")]
	cream=material(creams[theme])
	cream.albedo_texture=stone_texture
	metal=material(metals[theme])
	brass=material(Color("b19b6b"))
	brass.metallic=0.58;brass.roughness=0.37
	dark=material(Color("293841"))
	glow=material([Color("a3e5ed"),Color("edbc7e"),Color("c0b4ed")][theme],true)

func textured_panel(at: Vector3,size: Vector2,texture: Texture2D,angle:=0.0,uv:=Rect2(0,0,1,1)) -> MeshInstance3D:
	var mat:=material(Color.WHITE)
	mat.albedo_texture=texture
	mat.roughness=0.72
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale=Vector3(uv.size.x,uv.size.y,1)
	mat.uv1_offset=Vector3(uv.position.x,uv.position.y,0)
	mat.emission_enabled=true;mat.emission_texture=texture;mat.emission=Color.WHITE
	mat.emission_energy_multiplier=0.16
	var mesh:=QuadMesh.new();mesh.size=size
	var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=mat
	node.position=at;node.rotation.y=angle
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(node)
	return node

func interior_shell() -> void:
	preload("res://scripts/calibration_interior.gd").new().build(self)

func portal_frame() -> void:
	var frame:=Node3D.new();scene.add_child(frame);frame.rotation.y=PI*0.25
	var path: Array[Vector2]=[Vector2(-0.75,0.10),Vector2(-0.75,1.66),Vector2(-0.55,1.99),Vector2(0.55,1.99),Vector2(0.75,1.66),Vector2(0.75,0.10)]
	for i in range(path.size()-1):
		var a:=path[i];var b:=path[i+1];var center: Vector2=(a+b)*0.5
		var length:=a.distance_to(b)
		var angle:=-atan2(b.x-a.x,b.y-a.y)
		var body:=box(Vector3(center.x,center.y,0),Vector3(0.19,length+0.05,0.28),metal,frame)
		body.rotation.z=angle
		for edge in [-0.065,0.065]:
			var offset:=Vector2(edge,0).rotated(angle)
			var trim:=box(Vector3(center.x+offset.x,center.y+offset.y,0.15),Vector3(0.018,length+0.045,0.025),brass,frame)
			trim.rotation.z=angle
		var enamel:=box(Vector3(center.x,center.y,0.151),Vector3(0.080,length*0.84,0.026),cream,frame)
		enamel.rotation.z=angle
	for x in [-0.75,0.75]:
		box(Vector3(x,0.10,0),Vector3(0.34,0.20,0.40),metal,frame)
		box(Vector3(x,0.20,0),Vector3(0.35,0.035,0.41),brass,frame)
		for y in [0.38,0.66,0.94,1.22,1.50]:
			var screw:=cylinder(Vector3(x,y,0.18),0.026,0.02,brass,frame)
			screw.rotation.x=PI*0.5
	var seal:=cylinder(Vector3(0,2.10,0.12),0.16,0.045,brass,frame);seal.rotation.x=PI*0.5
	var seal_core:=cylinder(Vector3(0,2.10,0.15),0.12,0.018,dark,frame);seal_core.rotation.x=PI*0.5
	box(Vector3(0,2.10,0.17),Vector3(0.018,0.20,0.014),brass,frame)
	box(Vector3(0,2.10,0.17),Vector3(0.20,0.018,0.014),brass,frame)

func material(color: Color, emission := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=0.74
	m.diffuse_mode=BaseMaterial3D.DIFFUSE_BURLEY
	if emission:
		m.emission_enabled=true
		m.emission=color
		m.emission_energy_multiplier=0.65
	return m

func box(at: Vector3, size: Vector3, mat: Material, parent: Node3D=scene) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.material_override=mat
	node.position=at
	parent.add_child(node)
	return node

func cylinder(at: Vector3, radius: float, height: float, mat: Material, parent: Node3D=scene) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=16
	node.mesh=mesh
	node.material_override=mat
	node.position=at
	parent.add_child(node)
	return node

func model(key: String, at: Vector3, size: Vector3, angle: float=0.0) -> Node3D:
	var node: Node3D=load("res://assets/kenney_modular_space/"+key+".glb").instantiate()
	scene.add_child(node)
	node.position=at
	node.scale=size
	node.rotation.y=angle
	recolor(node)
	return node

func recolor(node: Node) -> void:
	if node is MeshInstance3D:
		var m := ShaderMaterial.new()
		m.shader=palette_shader
		m.set_shader_parameter("palette",load("res://assets/kenney_modular_space/Textures/colormap.png"))
		m.set_shader_parameter("enamel",cream.albedo_color)
		m.set_shader_parameter("alloy",brass.albedo_color)
		m.set_shader_parameter("slate",metal.albedo_color)
		node.material_override=m
	for child in node.get_children(): recolor(child)

func room_base() -> void:
	interior_shell()
	# Service trenches lead from wall instrumentation to the calibration rig.
	box(Vector3(6.8,0.04,2.35),Vector3(0.18,0.025,3.1),dark)
	box(Vector3(6.8,0.06,2.35),Vector3(0.035,0.025,3.1),brass)
	for i in range(8): box(Vector3(6.8,0.07,1.0+i*0.38),Vector3(0.16,0.025,0.025),metal)
	# Deliberately substantial low-profile rail: recessed bed, sleepers, paired steel guides.
	box(Vector3(5.75,0.045,4.8),Vector3(7.7,0.09,0.9),metal)
	box(Vector3(5.75,0.095,4.8),Vector3(7.48,0.035,0.68),dark)
	for i in range(24):
		var x:=2.04+i*0.32
		box(Vector3(x,0.12,4.8),Vector3(0.12,0.055,0.68),metal)
		for z in [4.48,5.12]:
			cylinder(Vector3(x,0.16,z),0.036,0.035,brass)
	for z in [4.54,5.06]:
		box(Vector3(5.75,0.17,z),Vector3(7.48,0.09,0.075),brass)
		box(Vector3(5.75,0.218,z),Vector3(7.48,0.012,0.043),cream)
	# Closed guard edges stay entirely within the existing collision footprint.
	for z in [4.38,5.22]:
		box(Vector3(5.75,0.14,z),Vector3(7.7,0.23,0.06),metal)
		box(Vector3(5.75,0.265,z),Vector3(7.7,0.018,0.065),brass)
		for i in range(16): box(Vector3(2.1+i*0.48,0.272,z),Vector3(0.19,0.015,0.068),cream)
	for x in [1.97,9.52]:
		box(Vector3(x,0.2,4.8),Vector3(0.13,0.24,0.85),metal)
		for z in [4.5,5.1]: cylinder(Vector3(x,0.34,z),0.043,0.025,brass)
	# Rail maintenance hatches; no additional solid obstacles in walking lanes.
	for x in [3.1,7.2]:
		box(Vector3(x,0.045,5.55),Vector3(0.52,0.025,0.36),metal)
		for i in range(4): box(Vector3(x-0.16+i*0.11,0.06,5.55),Vector3(0.035,0.01,0.26),brass)

func receiver() -> void:
	# Back-mounted twin columns with diagonal braces, ratchet teeth and a contact head.
	for x in [-0.48,0.48]:
		box(Vector3(x,1.5,-0.12),Vector3(0.13,3.0,0.16),metal)
		box(Vector3(x,1.5,-0.025),Vector3(0.045,2.92,0.028),brass)
		box(Vector3(x,0.08,-0.12),Vector3(0.32,0.16,0.36),metal)
		cylinder(Vector3(x,1.48,-0.12),0.070,2.74,brass)
		for y in [0.22,0.70,1.18,1.66,2.14,2.62]:
			cylinder(Vector3(x,y,-0.12),0.089,0.055,metal)
		for j in range(14): box(Vector3(x,0.24+j*0.18,0.0),Vector3(0.10,0.045,0.035),cream)
	box(Vector3(0,2.96,-0.12),Vector3(1.23,0.18,0.32),metal)
	box(Vector3(0,2.82,0),Vector3(0.74,0.10,0.46),brass)
	box(Vector3(0,2.75,0),Vector3(0.47,0.06,0.30),glow)
	for i in range(6):
		var brace:=box(Vector3(0,0.36+i*0.33,-0.22),Vector3(0.93,0.045,0.045),metal)
		brace.rotation.z=0.18 if i%2==0 else -0.18
	box(Vector3(0.68,1.3,-0.12),Vector3(0.2,0.8,0.22),metal)
	box(Vector3(0.68,1.3,0.005),Vector3(0.10,0.62,0.025),brass)

func weight() -> void:
	var body:=material([Color("91bdca"),Color("93826b"),Color("9b8eb2")][theme])
	box(Vector3(0,0.16,0),Vector3(0.52,0.30,0.52),body)
	box(Vector3(0,0.025,0),Vector3(0.55,0.045,0.55),metal)
	box(Vector3(0,0.31,0),Vector3(0.54,0.035,0.54),brass)
	box(Vector3(0,0.335,0),Vector3(0.45,0.022,0.45),body)
	for x in [-0.22,0.22]:
		for z in [-0.22,0.22]:
			box(Vector3(x,0.165,z),Vector3(0.035,0.30,0.035),brass)
			cylinder(Vector3(x,0.36,z),0.022,0.025,metal)
	cylinder(Vector3(0,0.355,0),0.115,0.025,brass)
	cylinder(Vector3(0,0.373,0),0.075,0.015,dark)
	cylinder(Vector3(0,0.385,0),0.036,0.018,glow)

func cabinet() -> void:
	box(Vector3(0,0.85,0),Vector3(1.58,1.7,0.52),metal)
	box(Vector3(0,1.64,0),Vector3(1.7,0.14,0.63),brass)
	for x in [-0.4,0.4]:
		box(Vector3(x,1.03,0.275),Vector3(0.69,1.04,0.045),cream)
		box(Vector3(x,1.22,0.307),Vector3(0.51,0.48,0.02),dark)
		box(Vector3(x,1.22,0.325),Vector3(0.36,0.025,0.012),glow)
		for y in range(4): box(Vector3(x,0.34+y*0.1,0.31),Vector3(0.5,0.035,0.02),dark)
		for i in range(3): cylinder(Vector3(x-0.14+i*0.14,1.82,0),0.04,0.22,brass)
	for x in [-0.67,0.67]: box(Vector3(x,0.08,0),Vector3(0.18,0.16,0.53),dark)
	model("cables",Vector3(0.0,0.025,0.02),Vector3(0.55,0.5,0.35))
	textured_panel(Vector3(0,0.98,0.35),Vector2(1.25,1.31),lab_wall,0,Rect2(0.025,0.15,0.18,0.67))

func console_desk() -> void:
	for x in [-0.85,0.85]: box(Vector3(x,0.4,0),Vector3(0.39,0.8,0.85),metal)
	box(Vector3(0,0.83,0),Vector3(2.22,0.16,1.04),brass)
	box(Vector3(0,0.93,-0.22),Vector3(2.15,0.12,0.48),cream)
	for x in [-0.65,0,0.65]:
		var screen:=box(Vector3(x,1.18,-0.25),Vector3(0.56,0.48,0.11),metal)
		screen.rotation.x=-0.13
		box(Vector3(x,1.19,-0.18),Vector3(0.46,0.32,0.025),dark)
		for i in range(3): box(Vector3(x,1.08+i*0.09,-0.16),Vector3(0.34-i*0.06,0.015,0.01),glow)
	for i in range(9): box(Vector3(-0.7+i*0.18,0.935,0.22),Vector3(0.09,0.03,0.085),cream if i%3 else glow)
	box(Vector3(0.65,0.95,0.28),Vector3(0.34,0.04,0.23),dark)
	for x in [-0.65,0.0,0.65]:
		textured_panel(Vector3(x,1.18,-0.145),Vector2(0.45,0.32),lab_wall,0,Rect2(0.78,0.21,0.16,0.36))
	for side in [-1.0,1.0]:
		textured_panel(Vector3(side*1.055,0.42,0),Vector2(0.70,0.53),lab_wall,side*PI*0.5,Rect2(0.017,0.33,0.17,0.40))

