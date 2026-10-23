extends Node2D
## Real geometry; image concepts are never used as flattened gameplay backgrounds.
const S=preload("res://scripts/paper_mill_state.gd")
const Rig=preload("res://scripts/yanyue_walk_rig.gd")
const StairGuards=preload("res://scripts/paper_mill_stair_guards.gd")
var stair_guards:Array[Dictionary]=[]
var room:Node
var viewport:=SubViewport.new()
var world_root:=Node3D.new()
var camera:=Camera3D.new()
var output:=Sprite2D.new()
var roots:Array[Node3D]=[]
var roofs:Array[Node3D]=[]
var weight_nodes:Array[Node3D]=[]
var rails:Array[StandardMaterial3D]=[]
var world_lights:Array[StandardMaterial3D]=[]
var bridge:Node3D
var side_bridge:Node3D
var hatch:Node3D
var catch_tray:Node3D
var lift:Node3D
var wheel:Node3D
var upper_light:MeshInstance3D
var lower_light:MeshInstance3D
var cover:Node3D
var cage_door:Node3D
var support:Node3D
var clamp:Node3D
var portal:Node3D
var portal_mat:StandardMaterial3D
var paper_viewport:=SubViewport.new()
var paper:=Rig.new()
var actor:=Sprite3D.new()
var shadow:MeshInstance3D
var stone:StandardMaterial3D
var wood:StandardMaterial3D
var brass:StandardMaterial3D
var dark:StandardMaterial3D
var paper_mat:StandardMaterial3D
var roof_mat:StandardMaterial3D
var wall_mat:StandardMaterial3D
var water_mat:ShaderMaterial
var focus:=Vector2(10,8)
var zoom:=1.0
var target_zoom:=1.0
var angle:=0.0
var dragging:=false
var rotating:=false
var age:=0.0
var overview:=false
var auto_follow:=true
var link_time:=0.0
var marker_nodes:Dictionary={}
var floor_front:Node3D
var layer_stone:Array[StandardMaterial3D]=[]
var floating_paper:Array[CPUParticles3D]=[]
var highlight:Node3D
var highlight_label:Label3D
var zoom_anchor:=Vector2(740,400)
var zoom_age:=0.0
var lowpass_gate:Node3D
var sluice_gate:Node3D
var pressure_faces:Array[MeshInstance3D]=[]
var completion_paper:Node3D
var paper_unfold:=0.0
var break_fragments:Array[Node3D]=[]
var break_age:=-1.0
var seen_broken:=false
var stair_floor:Node3D
var logical_size:=Vector2(1280,800)
var safe_center:=Vector2(640,400)
var frame_to_ui:=true
var render_scale:=1.25
var resize_count:=0
var paper_container:Node2D
var paper_density:=2
var readability_marks:Array[Label3D]=[]
var focused_target:=""
const TORSO_HEIGHT:=.9
var torso_offset:=0.0
var zoom_ground_anchor:=Vector2.ZERO
var pointer_zoom:=false
var follow_recovery:=0.0
var framing_height:=S.HEIGHT

func _ready() -> void:
	viewport.size=Vector2i(1280,800);viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	add_child(viewport);viewport.add_child(world_root);world_root.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true
	output.texture=viewport.get_texture();output.centered=false;output.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;add_child(output)
	_update_resolution()
	get_viewport().size_changed.connect(_update_resolution)
	_materials();_lights();_landscape()
	for layer in range(2):_build_layer(layer)
	stair_guards=StairGuards.build(self)
	_build_mechanisms();_actor();_highlight()
	set_focus(room.player_plan(),true)
	_sync(0.0)

func _update_resolution() -> void:
	logical_size=get_viewport().get_visible_rect().size
	var screen_scale:=get_viewport().get_screen_transform().get_scale().abs()
	var wanted:=logical_size*screen_scale*render_scale
	wanted*=minf(1.0,3840.0/maxf(wanted.x,wanted.y))
	var pixels:=Vector2i(maxi(1,roundi(wanted.x)),maxi(1,roundi(wanted.y)))
	if viewport.size!=pixels:viewport.size=pixels;resize_count+=1
	output.scale=logical_size/Vector2(viewport.size)
	if is_instance_valid(paper_container):_update_actor_resolution()

func _update_actor_resolution() -> void:
	var screen_scale:=get_viewport().get_screen_transform().get_scale().abs()
	var density:=clampi(ceili(2.0*maxf(screen_scale.x,screen_scale.y)*maxf(1.0,zoom)),2,4)
	if paper_density!=density or paper_viewport.size!=Vector2i(256,320)*density:
		paper_density=density;paper_viewport.size=Vector2i(256,320)*density
		paper_container.scale=Vector2.ONE*density
		actor.pixel_size=1.0/(58.0*density);actor.offset=Vector2(0,110*density)

func to_render(at:Vector2) -> Vector2:return at*Vector2(viewport.size)/logical_size
func to_ui(at:Vector2) -> Vector2:return at*logical_size/Vector2(viewport.size)

func mat(color:String,texture:Texture2D=null) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=0.88
	m.albedo_texture=texture
	if texture!=null:m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*0.4;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _materials() -> void:
	stone=mat("c5c5b5",load("res://assets/paper_mill/stone.png"))
	stone.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	stone.cull_mode=BaseMaterial3D.CULL_DISABLED
	wood=mat("c9ae85",load("res://assets/paper_mill/wood.png"))
	wood.uv1_scale=Vector3.ONE*.30
	brass=mat("bba36e");brass.metallic=0.55;brass.roughness=0.43
	dark=mat("283e49");paper_mat=mat("e5ddbf");roof_mat=mat("aeb8bf",load("res://assets/paper_mill/roof.png"))
	wall_mat=mat("c1c3b6",load("res://assets/paper_mill/wall.png"))
	# Larger material features survive minification instead of becoming speckled noise.
	stone.uv1_scale=Vector3.ONE*.24;roof_mat.uv1_scale=Vector3.ONE*.27
	wall_mat.uv1_scale=Vector3.ONE*.25
	water_mat=ShaderMaterial.new();var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint:source_color=vec4(0.25,0.48,0.48,1.0);
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float w=sin(wp.x*8.0+TIME*2.0)*sin(wp.z*5.0-TIME*3.0);float foam=smoothstep(0.86,1.0,sin(wp.z*19.0-TIME*4.0+sin(wp.x*5.0)));ALBEDO=tint.rgb+w*0.035+foam*0.12;ROUGHNESS=0.38;METALLIC=0.1;}
"""
	water_mat.shader=shader

func group(parent:Node3D,at:Vector3=Vector3.ZERO) -> Node3D:
	var n:=Node3D.new();parent.add_child(n);n.position=at;return n

func box(parent:Node3D,at:Vector3,size:Vector3,material:Material) -> MeshInstance3D:
	var n:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;n.mesh=mesh;n.material_override=material;n.position=at;parent.add_child(n);return n

func cylinder(parent:Node3D,at:Vector3,radius:float,height:float,material:Material) -> MeshInstance3D:
	var n:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=12;n.mesh=mesh;n.material_override=material;n.position=at;parent.add_child(n);return n

func beam(parent:Node3D,a:Vector3,b:Vector3,width:float,material:Material) -> MeshInstance3D:
	var n:=box(parent,(a+b)*0.5,Vector3(width,a.distance_to(b),width),material)
	if a.distance_to(b)>0.001:n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return n

func point(at:Vector2,h:=0.0) -> Vector3:return Vector3(at.x,h,at.y)

func _lights() -> void:
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("a6b6ac")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("d4dfdf");env.environment.ambient_light_energy=0.62
	world_root.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-58,-35,0);sun.light_color=Color("fff1d2");sun.light_energy=0.9;sun.shadow_enabled=true;sun.directional_shadow_max_distance=75;world_root.add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-28,135,0);fill.light_color=Color("c4dae2");fill.light_energy=0.22;world_root.add_child(fill)

func _landscape() -> void:
	var earth:=mat("87927a")
	var noise:=FastNoiseLite.new();noise.frequency=.18
	var texture:=NoiseTexture2D.new();texture.width=256;texture.height=256;texture.noise=noise;texture.seamless=true
	var ramp:=Gradient.new();ramp.set_color(0,Color("4a5b45"));ramp.set_color(1,Color("99a18b"));texture.color_ramp=ramp
	earth.albedo_texture=texture;earth.uv1_triplanar=true;earth.uv1_scale=Vector3.ONE*.15
	box(world_root,Vector3(12,-2.7,9),Vector3(220,1,220),earth)
	var rock:=mat("8b9381",load("res://assets/paper_mill/stone.png"));var green:=mat("506a48")
	var rng:=RandomNumberGenerator.new();rng.seed=217
	for i in range(65):
		var x:=rng.randf_range(-24,48);var z:=rng.randf_range(-22,40)
		if x>-1 and x<27 and z>-1 and z<21:continue
		var n:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radial_segments=24;mesh.rings=12;n.mesh=mesh;n.material_override=rock
		n.position=Vector3(x,-1,z);n.scale=Vector3(rng.randf_range(2,6),rng.randf_range(2,5),rng.randf_range(2,6));world_root.add_child(n)
	for i in range(65):
		var x:=rng.randf_range(-12,37);var z:=rng.randf_range(-10,30)
		if x>0 and x<25 and z>0 and z<19:continue
		var base:=Vector3(x,-1.5,z);var height:=rng.randf_range(3,7)
		var bamboo:=Sprite3D.new();bamboo.texture=load("res://assets/paper_mill/bamboo-v01.png");bamboo.pixel_size=height/1536.0
		bamboo.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;bamboo.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;bamboo.alpha_scissor_threshold=.35
		bamboo.position=base+Vector3.UP*height*.5;bamboo.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;bamboo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_root.add_child(bamboo)
	# Back terraces join the playable courtyard to a continuous inhabited hillside.
	var hillside:=mat("8d9980",load("res://assets/paper_mill/stone.png"))
	for spec in [[Vector3(-8,0,8),Vector3(15,13,34)],[Vector3(12,0,-7),Vector3(50,15,12)]]:
		var rock_mesh:=SphereMesh.new();rock_mesh.radial_segments=32;rock_mesh.rings=16
		var hill:=MeshInstance3D.new();hill.mesh=rock_mesh;hill.material_override=hillside;hill.position=spec[0];hill.scale=spec[1];world_root.add_child(hill)
	var outskirts:=group(world_root,Vector3(0,S.HEIGHT,0));var roofs_out:=group(outskirts)
	box(outskirts,Vector3(-3,-.3,9),Vector3(6,.6,20),stone)
	box(outskirts,Vector3(12,-.3,-2),Vector3(30,.6,4),stone)
	building(outskirts,roofs_out,Vector2(-3,5),Vector2(4,4),false)
	building(outskirts,roofs_out,Vector2(10,-2.4),Vector2(5,3),false)
	for x in [-4.5,-1.0,4.0,13.0,20.0]:paper_rack(outskirts,Vector2(x,-.7),2.1)
	preload("res://scripts/static_mesh_batch.gd").compact(outskirts)

func floor_mesh(parent:Node3D,layer:int) -> void:
	var surfaces:Array[SurfaceTool]=[]
	for i in range(3 if layer==0 else 2):surfaces.append(SurfaceTool.new())
	for surface in surfaces:surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(48):
		for z in range(36):
			var fx:=x*.5;var fz:=z*.5
			if layer==0 and fx>=2.5 and fx<4.5 and fz>=3 and fz<8.5:continue
			if (fx>=10 and fx<12 and fz>=9 and fz<11) or (fx>=17 and fx<19 and fz>=6 and fz<8):continue
			if fx>=13 and fx<22 and fz>=11 and fz<12:continue
			if fx>=3 and fx<7 and fz>=10 and fz<11:continue
			var index:=1 if fx>=11 or fz>=10 else 0
			if layer==0 and fx>=2.5 and fx<9 and fz>=1.5 and fz<10:index=2
			var st:SurfaceTool=surfaces[index]
			var a:=Vector3(fx,0,fz);var b:=Vector3(fx+.5,0,fz);var c:=Vector3(fx+.5,0,fz+.5);var d:=Vector3(fx,0,fz+.5)
			for vertex in [a,c,b,a,d,c]:
				st.set_normal(Vector3.UP);st.set_uv(Vector2(vertex.x,vertex.z)/3.0);st.add_vertex(vertex)
	var floor_material:StandardMaterial3D=stone.duplicate();layer_stone.append(floor_material)
	for i in range(surfaces.size()):
		var n:=MeshInstance3D.new();n.mesh=surfaces[i].commit();n.material_override=floor_material
		if i==2:
			stair_floor=group(parent);stair_floor.name="StairCutaway";stair_floor.add_child(n)
		elif i==1 and layer==0:
			floor_front=group(parent);floor_front.name="FrontFloor";floor_front.add_child(n)
		else:parent.add_child(n)
	# Deep foundations are separate from the walkable top, with real cutout edges.
	for at in [Vector3(0,-0.65,9),Vector3(24,-0.65,9)]:box(parent,at,Vector3(0.5,1.3,18),stone)
	for at in [Vector3(12,-0.65,0),Vector3(12,-0.65,18)]:box(parent,at,Vector3(24,1.3,0.5),stone)
	for center in [S.DROP,S.LIFT]:
		for dx in [-1.12,1.12]:box(parent,point(center)+Vector3(dx,-0.5,0),Vector3(.22,1.0,2.3),stone)
		for dz in [-1.12,1.12]:box(parent,point(center)+Vector3(0,-0.5,dz),Vector3(2.3,1.0,.22),stone)

func walkway(parent:Node3D,at:Vector2,size:Vector2) -> Node3D:
	var n:=group(parent,point(at))
	for i in range(maxi(2,int(size.y*5))):box(n,Vector3(0,.08,-size.y*.5+i*.2),Vector3(size.x,.16,.18),wood)
	for x in [-size.x*.46,size.x*.46]:box(n,Vector3(x,-.1,0),Vector3(.1,.2,size.y),dark)
	return n

func _build_layer(layer:int) -> void:
	var root:=group(world_root,Vector3(0,S.HEIGHT if layer==0 else 0.0,0));roots.append(root)
	floor_mesh(root,layer)
	box(root,Vector3(17.5,-.32,11.5),Vector3(9,.15,.85),water_mat)
	box(root,Vector3(4.5,-.32,10.5),Vector3(4,.15,.85),water_mat)
	box(root,Vector3(22,-.32,8),Vector3(1.8,.15,18),water_mat)
	for edge in [0.2,23.8]:
		box(root,Vector3(edge,.34,9),Vector3(.35,.68,18),stone)
		for z in range(1,18,3):cylinder(root,Vector3(edge,.75,z),.10,1.25,wood)
	for z in [0.2,17.8]:box(root,Vector3(12,.34,z),Vector3(24,.68,.35),stone)
	var roof_group:=group(root);roofs.append(roof_group)
	building(root,roof_group,Vector2(5,14),Vector2(5,4),layer==0)
	building(root,roof_group,Vector2(10,15.2),Vector2(4.5,2.8),false)
	# Open timber canopies give the work areas detail without hiding their paths.
	for at in [Vector2(16,16),Vector2(20,1.2)]:
		for x in [-1.0,1.0]:
			for z in [-.55,.55]:box(root,point(at)+Vector3(x,.85,z),Vector3(.08,1.7,.08),wood)
		box(root,point(at)+Vector3(0,1.75,0),Vector3(2.3,.08,1.5),roof_mat)
		for i in range(3):
			for j in range(5):box(root,point(at)+Vector3(-.7+i*.65,.15+j*.045,0),Vector3(.5,.04,.6),paper_mat)
	for x in [2.0,9.0,15.0]:paper_rack(root,Vector2(x,16.7),2.5)
	for z in [2.0,4.5,7.0]:paper_rack(root,Vector2(1.1,z),2.0,PI*.5)
	for at in [Vector2(8,15),Vector2(12,16),Vector2(2,9),Vector2(21,16)]:vat(root,at)
	# Rail assemblies are low and leave space for the character on both sides.
	var railmat:=mat("8a8f88");rails.append(railmat)
	if layer==0:
		rail(root,Vector2(18,7),Vector2(18,10.8),railmat)
		rail(root,Vector2(18,12.2),Vector2(18,14),railmat);rail(root,Vector2(18,14),S.UPPER_ANCHOR,railmat)
		bridge=walkway(root,S.BRIDGE+Vector2(0,.5),Vector2(1.6,1.5))
		side_bridge=walkway(root,Vector2(5,10.5),Vector2(1.6,1.3))
		bridge.name="MovableBridge";side_bridge.name="SideBridge"
	else:
		for seg in [[Vector2(5,12),Vector2(7,12)],[Vector2(7,12),S.CATCH_PLATE],[S.CATCH_PLATE,Vector2(11,8)],[Vector2(11,8),S.DROP],[S.DROP,Vector2(18,10)],[Vector2(18,10),S.LIFT],[Vector2(11,8),Vector2(18,8)],[Vector2(18,8),S.SLUICE],[Vector2(12,8),Vector2(12,13)],[Vector2(12,13),S.LOWER_ANCHOR]]:rail(root,seg[0],seg[1],railmat)
		walkway(root,Vector2(5,10.5),Vector2(1.6,1.3));walkway(root,Vector2(18,11.5),Vector2(1.6,1.5))
	for at in [S.DROP,S.LIFT]:
		for x in [-1.25,1.25]:box(root,point(at)+Vector3(x,.2,0),Vector3(.16,.4,2.4),wood)
	# Visible staircase outside the active floor; the landing is the interaction point.
	if layer==0:
		for i in range(20):
			var rise:float=(i+1)*.24
			box(world_root,Vector3(3.5,rise*.5,3+i*.29),Vector3(1.6,rise,.36),stone)
			box(world_root,Vector3(3.5,rise+.012,3+i*.29+.15),Vector3(1.48,.025,.045),brass)
		for x in [2.57,4.43]:beam(world_root,Vector3(x,-.13,2.8),Vector3(x,4.67,8.8),.22,stone)
	var stair_sign:=Label3D.new();stair_sign.text="↓" if layer==0 else "↑";stair_sign.font_size=72;stair_sign.pixel_size=.009
	stair_sign.position=point(S.STAIRS if layer==0 else S.LOWER_STAIRS,.12);stair_sign.rotation_degrees.x=-90
	stair_sign.modulate=Color("e2c380");stair_sign.outline_modulate=Color("273c35");root.add_child(stair_sign)
	roof_group.name="Roofs"
	# Keep switchable groups distinct while batching their static mesh leaves.
	preload("res://scripts/static_mesh_batch.gd").compact(root,[&"Roofs",&"MovableBridge",&"SideBridge",&"FrontFloor",&"StairCutaway"])
	var particles:=CPUParticles3D.new();particles.amount=24;particles.lifetime=7.0
	particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;particles.emission_box_extents=Vector3(9,.1,6)
	particles.position=Vector3(12,.4,9);particles.direction=Vector3.UP;particles.gravity=Vector3(0,.1,0)
	particles.initial_velocity_min=.12;particles.initial_velocity_max=.35
	var sheet:=QuadMesh.new();sheet.size=Vector2(.13,.18);sheet.material=paper_mat;particles.mesh=sheet
	particles.scale_amount_min=.6;particles.scale_amount_max=1.2;particles.emitting=false;root.add_child(particles);floating_paper.append(particles)

func building(parent:Node3D,roof_parent:Node3D,at:Vector2,size:Vector2,is_tool:bool) -> void:
	var base:=point(at)
	box(parent,base+Vector3(0,1.2,size.y*.5),Vector3(size.x,2.4,.32),wall_mat)
	for x in [-size.x*.5,size.x*.5]:
		box(parent,base+Vector3(x,1.15,0),Vector3(.28,2.5,size.y),wall_mat)
		for z in [-size.y*.5,size.y*.5]:box(parent,base+Vector3(x,1.4,z),Vector3(.18,2.9,.18),wood)
	beam(parent,base+Vector3(-size.x*.55,2.6,-size.y*.5),base+Vector3(size.x*.55,2.6,-size.y*.5),.24,wood)
	for sign_value in [-1.0,1.0]:
		var panel:=box(roof_parent,base+Vector3(0,3.0,sign_value*size.y*.27),Vector3(size.x+.65,.16,size.y*.6),roof_mat);panel.rotation.x=sign_value*.32
		for i in range(int(size.x*6)):
			var x:float=at.x-size.x*.5+i*.17
			beam(roof_parent,Vector3(x,3.32,at.y),Vector3(x,2.68,at.y+sign_value*(size.y*.6)),.055,roof_mat)
	for i in range(3):
		box(parent,base+Vector3(-1+i,.65,.6),Vector3(.8,1.2,.65),wood)
		for j in range(4):box(parent,base+Vector3(-1+i,1.3+j*.04,.6),Vector3(.7,.035,.55),paper_mat)
	var lantern_mat:=mat("e2bb75");lantern_mat.emission_enabled=true;lantern_mat.emission=Color("c78a38");lantern_mat.emission_energy_multiplier=.5
	for x in [-size.x*.36,size.x*.36]:
		var at_lamp:=base+Vector3(x,1.85,-size.y*.5-.08)
		beam(parent,at_lamp+Vector3(0,.35,0),at_lamp,.035,dark)
		cylinder(parent,at_lamp,.13,.28,lantern_mat)
		for y in [-.16,.16]:cylinder(parent,at_lamp+Vector3(0,y,0),.15,.025,dark)
	if is_tool:
		box(parent,point(S.TOOL)+Vector3(0,.65,0),Vector3(1,.12,.65),wood)
		cylinder(parent,point(S.TOOL)+Vector3(0,.84,0),.20,.12,brass)

func paper_rack(parent:Node3D,at:Vector2,width:float,rotation:=0.0) -> void:
	var n:=group(parent,point(at));n.rotation.y=rotation
	for x in [-width*.5,width*.5]:cylinder(n,Vector3(x,1.1,0),.045,2.2,wood)
	beam(n,Vector3(-width*.6,2.0,0),Vector3(width*.6,2.0,0),.05,wood)
	for i in range(3):
		var x:float=-width*.4+i*width*.3
		var sheet:=box(n,Vector3(x,1.3,0),Vector3(width*.24,1.25,.018),paper_mat);sheet.rotation.z=sin(at.x+i)*.025
		box(n,Vector3(x,1.94,0),Vector3(.10,.04,.055),brass)

func vat(parent:Node3D,at:Vector2) -> void:
	box(parent,point(at)+Vector3(0,.2,0),Vector3(1.3,.4,.9),stone)
	box(parent,point(at)+Vector3(0,.42,0),Vector3(1.12,.03,.74),paper_mat)
	for z in [-.42,.42]:box(parent,point(at)+Vector3(0,.45,z),Vector3(1.4,.08,.06),wood)

func rail(parent:Node3D,a:Vector2,b:Vector2,material:Material) -> void:
	var dir:=(b-a).normalized();var side:=Vector2(-dir.y,dir.x)*.27
	for offset in [-side,side]:beam(parent,point(a+offset,.065),point(b+offset,.065),.065,material)
	for i in range(int(a.distance_to(b)*2.5)+1):
		var at:=a.lerp(b,float(i)/maxf(1,int(a.distance_to(b)*2.5)))
		beam(parent,point(at-side*1.4,.03),point(at+side*1.4,.03),.08,wood)

func pad(parent:Node3D,at:Vector2,symbol:String) -> MeshInstance3D:
	box(parent,point(at,.10),Vector3(1.2,.2,1.2),dark)
	var face:=box(parent,point(at,.23),Vector3(1.05,.06,1.05),brass)
	for x in [-.48,.48]:
		for z in [-.48,.48]:cylinder(parent,point(at)+Vector3(x,.28,z),.035,.035,dark)
	var label:=Label3D.new();label.text=symbol;label.font_size=70;label.pixel_size=.005;label.rotation_degrees.x=-90;label.position=point(at,.27);parent.add_child(label)
	return face

func _build_mechanisms() -> void:
	var u:=roots[0];var l:=roots[1]
	hatch=walkway(u,S.DROP,Vector2(2.0,2.0))
	support=group(u,point(S.DROP)+Vector3(-1.35,.35,0));box(support,Vector3.ZERO,Vector3(.18,.7,.18),brass)
	catch_tray=walkway(l,S.DROP,Vector2(1.85,1.85))
	for at in [S.DROP,S.LIFT]:
		for x in [-1.1,1.1]:
			box(world_root,point(at)+Vector3(x,S.HEIGHT*.5,0),Vector3(.18,S.HEIGHT+.7,.18),wood)
			for y in [.3,S.HEIGHT]:box(world_root,point(at)+Vector3(x,y,0),Vector3(.25,.25,.25),brass)
	lift=walkway(world_root,S.LIFT,Vector2(1.9,1.9))
	for x in [-1.0,1.0]:cylinder(world_root,point(S.LIFT)+Vector3(x,S.HEIGHT*.5+.6,0),.025,S.HEIGHT+1.1,brass)
	pressure_faces.append(pad(l,S.CATCH_PLATE,"接"));pressure_faces.append(pad(l,S.SLUICE,"闸"))
	for segment in [[Vector2(7,8),Vector2(9,8)],[Vector2(9,8),Vector2(9,10)],[Vector2(9,10),S.DROP]]:
		beam(l,point(segment[0],.08),point(segment[1],.08),.045,brass)
	upper_light=pad(u,S.UPPER_ANCHOR,"山")
	for at in [Vector2(5,12),S.LOWER_ANCHOR]:
		for x in [-.7,.7]:box(l,point(at)+Vector3(x,1.35,0),Vector3(.12,2.7,.18),wood)
		box(l,point(at,2.7),Vector3(1.6,.2,.5),dark)
	lower_light=box(l,point(S.LOWER_ANCHOR,2.57),Vector3(1.15,.07,.9),brass)
	cover=group(l,point(S.LOWER_ANCHOR,2.45));box(cover,Vector3.ZERO,Vector3(1.3,.12,1),wood)
	lowpass_gate=group(l,Vector3(12,.75,12.3))
	for x in [-.6,-.3,0.0,.3,.6]:box(lowpass_gate,Vector3(x,0,0),Vector3(.06,1.5,.06),brass)
	for x in [-.85,.85]:box(l,Vector3(12+x,1.1,12.3),Vector3(.13,2.2,.13),wood)
	cage_door=group(l,Vector3(5,.9,11.4))
	for x in [-.6,-.3,0.0,.3,.6]:box(cage_door,Vector3(x,0,0),Vector3(.04,1.8,.04),brass)
	wheel=group(l,Vector3(22,.9,4))
	var torus:=TorusMesh.new();torus.inner_radius=1.45;torus.outer_radius=1.68;torus.rings=32;torus.ring_segments=8
	var rim:=MeshInstance3D.new();rim.mesh=torus;rim.material_override=wood;rim.rotation.z=PI*.5;wheel.add_child(rim)
	for i in range(12):
		var a:=float(i)*TAU/12.0
		beam(wheel,Vector3.ZERO,Vector3(0,sin(a)*1.6,cos(a)*1.6),.09,wood)
		var paddle:=box(wheel,Vector3(0,sin(a)*1.65,cos(a)*1.65),Vector3(.8,.17,.34),wood);paddle.rotation.x=-a
	beam(l,Vector3(22,.9,4),Vector3(19,.9,4),.15,brass)
	beam(l,Vector3(19,.9,4),Vector3(19,1.2,7),.10,dark)
	sluice_gate=group(l,Vector3(21,.4,4));box(sluice_gate,Vector3.ZERO,Vector3(1.6,.7,.15),wood)
	clamp=group(world_root)
	for x in [-.12,.12]:box(clamp,Vector3(x,0,0),Vector3(.07,.3,.35),brass)
	cylinder(clamp,Vector3.ZERO,.08,.42,wood).rotation.z=PI*.5
	portal=group(u,point(S.EXIT))
	for x in [-.8,.8]:box(portal,Vector3(x,1.2,0),Vector3(.18,2.5,.25),wood)
	box(portal,Vector3(0,2.45,0),Vector3(1.9,.22,.32),wood)
	portal_mat=mat("86c2b4");portal_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;portal_mat.albedo_color.a=.16;portal_mat.emission_enabled=true;portal_mat.emission=Color("64c5af")
	box(portal,Vector3(0,1.15,0),Vector3(1.4,2.2,.04),portal_mat)
	completion_paper=group(u,point(S.UPPER_ANCHOR)+Vector3(0,1.6,.7))
	box(completion_paper,Vector3.ZERO,Vector3(2.3,1.5,.025),paper_mat)
	var drawing:=Label3D.new();drawing.text="水路既通 · 纸山重明\n潮纹所向：瓯江孤屿";drawing.font_size=32;drawing.pixel_size=.008;drawing.position.z=.02;drawing.modulate=Color("365b52");drawing.outline_size=0;completion_paper.add_child(drawing)
	for i in range(2):
		var n:=group(world_root);weight_nodes.append(n)
		box(n,Vector3(0,.27,0),Vector3(.64,.5,.64),dark)
		for x in [-.31,.31]:
			for z in [-.31,.31]:box(n,Vector3(x,.28,z),Vector3(.07,.53,.07),brass)
		cylinder(n,Vector3(0,.55,0),.19,.025,brass)
		var symbol:=Label3D.new();symbol.text="山" if i==0 else "水";symbol.font_size=64;symbol.pixel_size=.006;symbol.position=Vector3(0,.57,0);symbol.rotation_degrees.x=-90;n.add_child(symbol)
		readability_mark(n,"山" if i==0 else "水",Vector3(0,.95,0))
	readability_mark(roots[0],"夹",point(S.TOOL,1.15))
	readability_mark(clamp,"夹",Vector3(0,.8,0))
	readability_mark(lift,"↕",Vector3(0,.7,0))
	for i in range(8):
		var piece:=group(world_root);box(piece,Vector3.ZERO,Vector3(.12,.06,.45),wood);piece.hide();break_fragments.append(piece)

func _actor() -> void:
	paper_viewport.size=Vector2i(512,640);paper_viewport.transparent_bg=true;add_child(paper_viewport)
	paper_container=Node2D.new();paper_container.scale=Vector2.ONE*2;paper_viewport.add_child(paper_container);paper_container.add_child(paper);paper.position=Vector2(128,270)
	actor.texture=paper_viewport.get_texture();actor.pixel_size=.5/58.0;actor.offset=Vector2(0,220)
	actor.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;actor.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;actor.alpha_scissor_threshold=.04;actor.shaded=false
	actor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world_root.add_child(actor)
	actor.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_update_actor_resolution()
	var m:=mat("26392d");m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.albedo_color.a=.2
	shadow=cylinder(world_root,Vector3.ZERO,.25,.012,m)

func readability_mark(parent:Node3D,text:String,at:Vector3) -> void:
	var mark:=Label3D.new();mark.text=text;mark.position=at;mark.font=preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf")
	mark.billboard=BaseMaterial3D.BILLBOARD_ENABLED;mark.font_size=72;mark.outline_size=12
	mark.modulate=Color("eadbb5");mark.outline_modulate=Color("263e38");mark.shaded=false
	parent.add_child(mark);readability_marks.append(mark)

func _highlight() -> void:
	highlight=group(world_root)
	var torus:=TorusMesh.new();torus.inner_radius=.65;torus.outer_radius=.7;torus.rings=32;torus.ring_segments=6
	var material:=mat("ead29a");material.emission_enabled=true;material.emission=Color("cfb575")
	var ring:=MeshInstance3D.new();ring.mesh=torus;ring.material_override=material;highlight.add_child(ring)
	highlight_label=Label3D.new();highlight_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;highlight_label.font_size=34;highlight_label.pixel_size=.008;highlight_label.position.y=1.8
	highlight_label.modulate=Color("fff3d0");highlight_label.outline_modulate=Color("253c3b");highlight.add_child(highlight_label)

func screen(at:Vector2,layer:int,h:=.1) -> Vector2:
	return to_ui(camera.unproject_position(point(at,(S.HEIGHT if layer==0 else 0.0)+h)))

func ground(at:Vector2,layer:int=-1) -> Vector2:
	if layer<0:layer=room.view_layer
	var origin:=camera.project_ray_origin(to_render(at));var direction:=camera.project_ray_normal(to_render(at))
	var height:=S.HEIGHT if layer==0 else 0.0
	var t:float=(height-origin.y)/direction.y
	var hit:=origin+direction*t
	return Vector2(hit.x,hit.z)

func over_stairs(at:Vector2) -> bool:
	var polygon:=PackedVector2Array()
	for vertex in [Vector3(2.65,4.8,9.15),Vector3(4.35,4.8,9.15),Vector3(4.35,0,2.45),Vector3(2.65,0,2.45)]:
		polygon.append(to_ui(camera.unproject_position(vertex)))
	return Geometry2D.is_point_in_polygon(at,polygon)

func set_focus(at:Vector2,follow:=false) -> void:
	focus=at;auto_follow=follow;frame_to_ui=true;pointer_zoom=false
	if not follow:torso_offset=0.0

func return_to_actor() -> void:
	resume_actor_follow()

func resume_actor_follow() -> void:
	# A new movement intent resumes tracking without resetting camera pose or scale.
	room.view_layer=room.player_layer
	if not auto_follow:follow_recovery=.45
	auto_follow=true;frame_to_ui=true;pointer_zoom=false;cancel_drag()
	focused_target=""

func movement_active() -> bool:
	return not room.player.controls_locked and (room.player.is_navigating() or room.player.walking or Input.get_vector("walk_left","walk_right","walk_up","walk_down").length_squared()>.01)

func zoom_at(at:Vector2,factor:float) -> void:
	zoom_anchor=at;zoom_ground_anchor=ground(at);zoom_age=.65
	target_zoom=clampf(target_zoom*factor,.55,1.6)
	if room.view_layer==room.player_layer and (movement_active() or room.transition_age>0):
		resume_actor_follow()
	else:
		auto_follow=false;frame_to_ui=false;pointer_zoom=true

func begin_manual_observation() -> void:
	auto_follow=false;frame_to_ui=false;pointer_zoom=false
	focused_target=""

func cancel_drag() -> void:dragging=false;rotating=false

func _camera() -> void:
	# Do not clamp follow focus at the courtyard edges: the actor must stay framed.
	if not auto_follow and not pointer_zoom:
		focus.x=clampf(focus.x,-12,36);focus.y=clampf(focus.y,-12,30)
	var target:=point(focus,framing_height+torso_offset)
	var yaw:=deg_to_rad(45+angle)
	var offset:=Vector3(sin(yaw)*28,27,cos(yaw)*28)
	camera.size=19.0/zoom;camera.position=target+offset;camera.look_at(target)
	# Translate in the ground plane so the focus lands in the unobstructed HUD area.
	var shift:=ground(logical_size*.5)-ground(safe_center)
	camera.position+=Vector3(shift.x,0,shift.y)
	var right:=camera.global_basis.x;var forward:=-camera.global_basis.z;right.y=0;forward.y=0
	room.player.input_basis=Transform2D(Vector2(right.x,right.z).normalized(),-Vector2(forward.x,forward.z).normalized(),Vector2.ZERO)

func _process(delta:float) -> void:_sync(delta)

func _fade_stair_guards(delta:float) -> void:
	var excluded:Array[RID]=[]
	for section in stair_guards:
		section.root.visible=not section.upper or room.view_layer==0 or link_time>0
		if not section.root.visible:excluded.append(section.body.get_rid())
	var covered:Dictionary={}
	if room.player_layer==room.view_layer or room.transition_age>0:
		var space:=viewport.find_world_3d().direct_space_state
		for height in [.25,.65,1.2,1.65]:
			var target:=point(room.player_plan(),room.actor_height()+height)
			var origin:=camera.project_ray_origin(camera.unproject_position(target))
			var query:=PhysicsRayQueryParameters3D.create(origin,target,32,excluded)
			var hit:=space.intersect_ray(query)
			if not hit.is_empty():covered[int(hit.collider.get_meta("stair_guard"))]=true
	for i in range(stair_guards.size()):
		var section:Dictionary=stair_guards[i]
		section.fade=lerpf(section.fade,.7 if covered.has(i) else 0.0,1.0-exp(-delta*12.0))
		if absf(section.fade-(.7 if covered.has(i) else 0.0))<.001:section.fade=.7 if covered.has(i) else 0.0
		for mesh in section.meshes:
			var material:StandardMaterial3D=mesh.material_override
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if section.fade>0 else BaseMaterial3D.TRANSPARENCY_DISABLED
			material.albedo_color.a=1.0-section.fade

func _sync(delta:float) -> void:
	age+=delta;link_time=maxf(0,link_time-delta)
	if frame_to_ui and room.hud!=null:
		var desired:Vector2=room.hud.safe_rect().get_center()
		safe_center=safe_center.lerp(desired,1.0-exp(-delta*9.0))
		if safe_center.distance_to(desired)<.02:safe_center=desired
	var following:bool=auto_follow and room.player_layer==room.view_layer
	var desired_height:float=S.HEIGHT if room.view_layer==0 else 0.0
	if room.transition_age>0:desired_height=room.actor_height()
	elif link_time>0 and not following:desired_height=S.HEIGHT*.45
	framing_height=move_toward(framing_height,lerpf(framing_height,desired_height,1.0-exp(-delta*18.0)),delta*12.0)
	if absf(framing_height-desired_height)<.0001:framing_height=desired_height
	if following:
		torso_offset=lerpf(torso_offset,TORSO_HEIGHT,1.0-exp(-delta*14.0))
		if absf(torso_offset-TORSO_HEIGHT)<.0001:torso_offset=TORSO_HEIGHT
	zoom=lerpf(zoom,target_zoom,1.0-exp(-delta*14.0))
	if absf(zoom-target_zoom)<.0001:zoom=target_zoom
	if absf(zoom-target_zoom)<.005:_update_actor_resolution()
	for i in range(readability_marks.size()):
		var mark:=readability_marks[i];mark.pixel_size=.006/maxf(.55,zoom)
		mark.visible=zoom<.85 and (i!=2 or not room.state.clip_owned)
	zoom_age=maxf(0,zoom_age-delta)
	if following and not dragging and not rotating:
		var destination:Vector2=room.player_plan()
		var response:=lerpf(12.0,20.0,clampf((zoom-1.0)/.6,0,1))
		# A world-space bound derived from screen pixels also protects close views
		# at low frame rates. Manual-to-follow recovery is allowed to ease in first.
		var max_lag:=68.0*camera.size/maxf(1.0,logical_size.y)
		if follow_recovery>0:
			focus=focus.move_toward(focus.lerp(destination,1.0-exp(-delta*12.0)),delta*24.0)
			# Far manual views need enough time to arrive before the drift guard
			# engages; otherwise the end of recovery itself would produce a jump.
			if focus.distance_to(destination)<=max_lag:follow_recovery=maxf(0,follow_recovery-delta)
		else:focus=focus.lerp(destination,1.0-exp(-delta*response))
		if follow_recovery<=0 and focus.distance_to(destination)>max_lag:
			focus=destination+destination.direction_to(focus)*max_lag
		if focus.distance_to(destination)<.0005:focus=destination
	_camera()
	if pointer_zoom:
		# Keep the originally selected ground point fixed through the entire zoom,
		# without resuming actor tracking while the player is stationary.
		focus+=zoom_ground_anchor-ground(zoom_anchor);_camera()
		if zoom_age<=0 and zoom==target_zoom:pointer_zoom=false
	_fade_stair_guards(delta)
	var s=room.state
	var actor_screen:=to_ui(camera.unproject_position(point(room.player_plan(),room.actor_height()+1.6)))
	var actor_foot:=to_ui(camera.unproject_position(point(room.player_plan(),room.actor_height())))
	var actor_bounds:=Rect2(Vector2(actor_screen.x-22*zoom,actor_screen.y-10*zoom),Vector2(44*zoom,absf(actor_foot.y-actor_screen.y)+25*zoom))
	var target_bounds:=Rect2()
	var inspected:Dictionary=room.target_by_id(focused_target)
	if not inspected.is_empty() and inspected.layer==room.view_layer:
		var at:Vector2=screen(inspected.pos,inspected.layer,.7)
		target_bounds=Rect2(at-Vector2(25,45)*zoom,Vector2(50,70)*zoom)
	var near_workshop:bool=Rect2(1,10,13,8).has_point(room.player_plan())
	wall_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if near_workshop and room.view_layer==room.player_layer else BaseMaterial3D.TRANSPARENCY_DISABLED
	wall_mat.albedo_color.a=.24 if near_workshop and room.view_layer==room.player_layer else 1.0
	for i in range(2):
		roots[i].visible=i==room.view_layer or link_time>0
		roofs[i].visible=link_time<=0 and (room.player_plan().y<11.5 or room.player_layer!=i)
		if roofs[i].visible and (i==room.player_layer or i==room.view_layer and target_bounds.has_area()):
			for mesh in roofs[i].get_children():
				if not mesh is MeshInstance3D:continue
				var bounds:AABB=mesh.get_aabb();var projected:=Rect2()
				for corner in range(8):
					var vertex:Vector3=mesh.global_transform*bounds.get_endpoint(corner)
					var pixel:=to_ui(camera.unproject_position(vertex))
					if corner==0:projected=Rect2(pixel,Vector2.ZERO)
					else:projected=projected.expand(pixel)
				if i==room.player_layer and projected.intersects(actor_bounds) or i==room.view_layer and target_bounds.has_area() and projected.intersects(target_bounds):roofs[i].visible=false;break
		rails[i].albedo_color=[Color("b3e1e3"),Color("b39d76"),Color("a398b7"),Color("a8c2a7")][s.worlds[i]]
		layer_stone[i].albedo_color=[Color("d2dbd7"),Color("ded0b5"),Color("d4cddd"),Color("d5d7c0")][s.worlds[i]]
		floating_paper[i].emitting=s.worlds[i]==2
		var w:Dictionary=s.weights[i]
		weight_nodes[i].position=point(w.pos,s.weight_height(i))
		weight_nodes[i].visible=w.layer==room.view_layer or w.mode=="fall" or link_time>0
	hatch.visible=not s.hatch_broken;support.visible=not s.support_released
	if s.hatch_broken and not seen_broken:break_age=0.0
	seen_broken=s.hatch_broken
	if break_age>=0:
		break_age+=delta
		for i in range(break_fragments.size()):
			var piece:=break_fragments[i];var t:=break_age
			piece.visible=t<1.7 and link_time>0
			piece.position=point(S.DROP)+Vector3(sin(i*2.4)*t*.4,S.HEIGHT-t*t*2.2,cos(i*2.4)*t*.4)
			piece.rotation=Vector3(t*(i+1),t*2,t*i*.3)
	floor_front.visible=link_time<=0 or room.transition_age>0
	stair_floor.visible=room.transition_age<=0
	bridge.visible=s.bridge_solid();side_bridge.visible=s.worlds[0]==3 or s.clip_owned
	catch_tray.position.y=s.catch_height*.15
	lift.position.y=s.lift_height
	cage_door.rotation.x=PI*.48 if s.cage_open else 0.0
	cover.position.x=S.LOWER_ANCHOR.x+(1.5 if s.upper_anchored else 0.0)
	lowpass_gate.position.y=-1.0 if s.lowpass_open else .75
	sluice_gate.position.y=.9 if s.pressure("sluice") or s.lower_anchored else .4
	for i in range(2):pressure_faces[i].position.y=.12 if s.pressure("catch" if i==0 else "sluice") else .23
	completion_paper.visible=s.lower_anchored
	paper_unfold=move_toward(paper_unfold,1.0 if s.lower_anchored else 0.0,delta*.8)
	completion_paper.scale.y=maxf(.02,smoothstep(0.0,1.0,paper_unfold))
	if s.pressure("sluice") or s.lower_anchored:wheel.rotation.x+=delta*1.7
	clamp.visible=s.clip_target!=""
	if clamp.visible:clamp.position=point(S.DROP+Vector2(1.0,0),.4) if s.clip_target=="catch" else point(S.BRIDGE+Vector2(.8,0),S.HEIGHT+.3)
	portal.visible=room.view_layer==0
	portal_mat.albedo_color.a=.45 if s.lower_anchored else .05
	actor.visible=room.player_layer==room.view_layer or link_time>0
	actor.position=point(room.player_plan(),room.actor_height()+.04)
	shadow.position=actor.position;shadow.visible=actor.visible
	var dir:Vector2=room.player._last_direction
	var a:=camera.unproject_position(actor.position);var b:=camera.unproject_position(actor.position+Vector3(dir.x,0,dir.y))
	var screen_dir:Vector2=(b-a).normalized()
	var row:int=(0 if screen_dir.x>=0 else 1) if screen_dir.y>=0 else (2 if screen_dir.x>=0 else 3)
	paper.pose(room.player._walk_time if room.transition_age<=0 else room.elapsed*100,room.player.walking or room.transition_age>0,row,screen_dir,delta)
	paper.push_amount=room.push_age/.45 if room.interacting else 0.0
	paper.cast_amount=sin((.5-room.world_cast_time)/.5*PI) if room.world_cast_time>0 else 0.0
	var target_id:String=room.hud.hover_target if room.hud!=null and not room.hud.hover_target.is_empty() else room.hit_target(get_viewport().get_mouse_position())
	var target:Dictionary=room.target_by_id(target_id)
	highlight.visible=not target.is_empty() and int(target.layer)==room.view_layer
	if highlight.visible:
		highlight.position=point(target.pos,(S.HEIGHT if target.layer==0 else 0.0)+.14)
		highlight_label.text=("走入楼梯 · "+("下楼" if room.player_layer==0 else "上楼")) if target.id=="stairs" else target.name+" · E / 右键"

func _unhandled_input(event:InputEvent) -> void:
	if room.hud!=null and room.hud.menu.visible:return
	if event is InputEventMouse and room.hud!=null and room.hud.blocks_map(event.position):return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			zoom_at(event.position,1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.12);get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_MIDDLE:
			if event.pressed:begin_manual_observation()
			dragging=event.pressed;get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_LEFT and (event.alt_pressed or rotating):
			if event.pressed:begin_manual_observation()
			rotating=event.pressed;get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if rotating:angle=clampf(angle+event.relative.x*.20,-45,45);_camera();get_viewport().set_input_as_handled()
		elif dragging:
			focus+=ground(event.position-event.relative)-ground(event.position);_camera();get_viewport().set_input_as_handled()

func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:cancel_drag()

func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not room.player.controls_locked and not room.hud.menu.visible and not dragging and not rotating:
		for action in ["walk_left","walk_right","walk_up","walk_down"]:
			if event.is_action_pressed(action):resume_actor_follow();break
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_MIDDLE:dragging=false
		if event.button_index==MOUSE_BUTTON_LEFT:rotating=false
