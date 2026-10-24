extends Node2D
## Real geometry; image concepts are never used as flattened gameplay backgrounds.
const S=preload("res://scripts/paper_mill_state.gd")
const RAIL_COLORS:=[Color("b3e1e3"),Color("b39d76"),Color("a398b7"),Color("a8c2a7")]
const STONE_COLORS:=[Color("d2dbd7"),Color("ded0b5"),Color("d4cddd"),Color("d5d7c0")]
var film=preload("res://scripts/paper_world_film.gd").new()
var switch_fx=preload("res://scripts/world_switch_fx.gd").new()
const MissionModel=preload("res://scripts/paper_mission_model.gd")
var mission_models:Dictionary={}
var lift_arrival_materials:Dictionary={}
var tool_model:Node3D
var catch_ring:Node3D
var bridge_ring:Node3D
var yard=preload("res://scripts/paper_mill_yard.gd").new()
const Rig=preload("res://scripts/yanyue_walk_rig.gd")
const StairGuards=preload("res://scripts/paper_mill_stair_guards.gd")
const GuardFade=preload("res://scripts/paper_guard_fade.gd")
var stair_guards:Array[Dictionary]=[]
var waterbank_guards=preload("res://scripts/paper_waterbank_guards.gd").new()
var push_arrow:Node3D
var push_arrow_material:StandardMaterial3D
var room:Node
var viewport:=SubViewport.new()
var world_root:=Node3D.new()
var camera:=Camera3D.new()
var output:=Sprite2D.new()
var roots:Array[Node3D]=[]
var roofs:Array[Node3D]=[]
var weight_nodes:Array[Node3D]=[]
var weight_shadows:Array[MeshInstance3D]=[]
var rule_details=preload("res://scripts/paper_rule_details.gd").new()
var rails:Array[StandardMaterial3D]=[]
const RailNetwork=preload("res://scripts/paper_rail_network.gd")
var rail_networks:Array=[]
var rail_frost=preload("res://scripts/paper_rail_frost.gd").new()
var lift_rail_material:StandardMaterial3D
var lift_rail_tongues:Node3D
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
var memory_props:Node3D

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
	memory_props=preload("res://scripts/paper_mill_memory_props.gd").new()
	world_root.add_child(memory_props);memory_props.build(self)
	stair_guards=StairGuards.build(self)
	waterbank_guards.build(self)
	add_child(rail_frost);rail_frost.build(self)
	# Capture environment leaves before mechanisms/labels are added to the floors.
	film.view=self;add_child(film)
	for layer in range(2):film.register_environment(roots[layer],layer)
	# Live details are common to both films: one pose, no stale static duplicate.
	world_root.add_child(rule_details);rule_details.build(self)
	_build_mechanisms();_actor();_highlight()
	rail_frost.build_lift()
	_build_weight_shadows()
	_build_push_guides()
	add_child(switch_fx);switch_fx.z_index=30;switch_fx.modulate.a=.55
	var foot_material:=ShaderMaterial.new();foot_material.shader=preload("res://shaders/paper_switch_fx.gdshader")
	foot_material.set_shader_parameter("actor_mask",paper_viewport.get_texture());switch_fx.material=foot_material
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
	for spec in [[Vector3(-18,-3,8),Vector3(9,10,34)],[Vector3(12,-3,-16),Vector3(45,11,9)]]:
		var rock_mesh:=SphereMesh.new();rock_mesh.radial_segments=32;rock_mesh.rings=16
		var hill:=MeshInstance3D.new();hill.mesh=rock_mesh;hill.material_override=hillside;hill.position=spec[0];hill.scale=spec[1];world_root.add_child(hill)
	yard.exterior(self)

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
			if layer==0 and S.OLD_CORRIDOR_GAP.has_point(Vector2(fx+.25,fz+.25)):continue
			if layer==1 and fx>=3 and fx<7 and fz>=10 and fz<11:continue
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
		shaft_lining(parent,center)

func shaft_lining(parent:Node3D,center:Vector2) -> void:
	# The courtyard already owns the horizontal surface at y=0. Closed boxes
	# put a second, differently tinted cap there, fighting it as the camera moves.
	# Keep every side/bottom at its original position and omit only buried caps.
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in [0,2]:
		for offset in [-1.12,1.12]:
			var at:=point(center)+Vector3(0,-.5,0);at[axis]+=offset
			var mesh:=BoxMesh.new();mesh.size=Vector3(.22,1.0,2.3) if axis==0 else Vector3(2.3,1.0,.22)
			var arrays:=mesh.get_mesh_arrays()
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				if normals[indices[i]].y>.5:continue
				for j in range(3):
					var index:=indices[i+j]
					surface.set_normal(normals[index]);surface.set_uv(uvs[index]);surface.add_vertex(vertices[index]+at)
	var lining:=MeshInstance3D.new();lining.name="ShaftLining%d_%d"%[center.x,center.y];lining.mesh=surface.commit();lining.material_override=stone;parent.add_child(lining)

func walkway(parent:Node3D,at:Vector2,size:Vector2) -> Node3D:
	var n:=group(parent,point(at))
	for i in range(maxi(2,int(size.y*5))):box(n,Vector3(0,.08,-size.y*.5+i*.2),Vector3(size.x,.16,.18),wood)
	for x in [-size.x*.46,size.x*.46]:box(n,Vector3(x,-.1,0),Vector3(.1,.2,size.y),dark)
	return n

func _build_layer(layer:int) -> void:
	var root:=group(world_root,Vector3(0,S.HEIGHT if layer==0 else 0.0,0));roots.append(root)
	floor_mesh(root,layer)
	box(root,Vector3(17.5,-.32,11.5),Vector3(9,.15,.85),water_mat)
	if layer==0:
		var gap:=S.OLD_CORRIDOR_GAP
		box(root,point(gap.get_center(),-.32),Vector3(gap.size.x,.15,gap.size.y-.08),water_mat)
	else:box(root,Vector3(4.5,-.32,10.5),Vector3(4,.15,.85),water_mat)
	box(root,Vector3(22,-.32,8),Vector3(1.8,.15,18),water_mat)
	for edge in [0.2,23.8]:
		box(root,Vector3(edge,.34,9),Vector3(.35,.68,18),stone)
		for z in range(1,18,3):cylinder(root,Vector3(edge,.38,z),.07,.20,wood)
	for z in [0.2,17.8]:box(root,Vector3(12,.34,z),Vector3(24,.68,.35),stone)
	var roof_group:=group(root);roofs.append(roof_group)
	yard.workyard(self,root,layer)
	# Only simulation edges create track; intersecting routes are separate networks.
	var railmat:=mat("8a8f88");railmat.cull_mode=BaseMaterial3D.CULL_DISABLED;rails.append(railmat)
	if layer==0:
		bridge=walkway(root,S.BRIDGE+Vector2(0,.5),Vector2(1.6,1.5))
		side_bridge=walkway(root,S.OLD_CORRIDOR_DECK.get_center(),S.OLD_CORRIDOR_DECK.size)
		bridge.name="MovableBridge";side_bridge.name="SideBridge"
		var network=RailNetwork.new(self);network.build(root,S.MOUNTAIN_STOPS,S.UPPER_EDGES,railmat,bridge);rail_networks.append(network)
	else:
		var water=RailNetwork.new(self);water.build(root,S.WATER_STOPS,S.WATER_EDGES,railmat);rail_networks.append(water)
		var mountain=RailNetwork.new(self);mountain.crossings.append(Vector2(12,10));mountain.build(root,S.MOUNTAIN_STOPS,S.LOWER_EDGES,railmat);rail_networks.append(mountain)
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
	preload("res://scripts/static_mesh_batch.gd").compact(root,[&"Roofs",&"MovableBridge",&"SideBridge",&"FrontFloor",&"StairCutaway",&"LowPapermakingDetails"])
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

func pad(parent:Node3D,at:Vector2,symbol:String) -> MeshInstance3D:
	var id:String={"接":"catch_pad","闸":"sluice_pad","山":"upper_anchor"}.get(symbol,"lower_anchor")
	var model=MissionModel.new(id);parent.add_child(model);model.position=point(at);mission_models[id]=model
	return model.face

func _build_mechanisms() -> void:
	var u:=roots[0];var l:=roots[1]
	hatch=walkway(u,S.DROP,Vector2(2.0,2.0))
	support=group(u,point(S.DROP)+Vector3(-1.35,.35,0));box(support,Vector3.ZERO,Vector3(.18,.7,.18),brass)
	catch_tray=walkway(l,S.DROP,Vector2(1.85,1.85))
	for at in [S.DROP,S.LIFT]:
		for x in [-1.1,1.1]:
			box(world_root,point(at)+Vector3(x,S.HEIGHT*.5,0),Vector3(.18,S.HEIGHT+.7,.18),wood)
			for y in [.3,S.HEIGHT]:box(world_root,point(at)+Vector3(x,y,0),Vector3(.25,.25,.25),brass)
	lift=MissionModel.new("lift");world_root.add_child(lift);lift.position=point(S.LIFT);mission_models["lift"]=lift
	# Platform track travels with the lift. Only short docking tongues extend
	# across the lip when aligned, leaving the empty shaft visibly open.
	lift_rail_material=rails[1].duplicate()
	var track=RailNetwork.new(self)
	for x in [-RailNetwork.GAUGE,RailNetwork.GAUGE]:
		track.prism(lift,[Vector2(x-.0325,0),Vector2(x+.0325,0),Vector2(x+.0325,1.1),Vector2(x-.0325,1.1)],lift_rail_material)
	lift_rail_tongues=group(lift)
	for x in [-RailNetwork.GAUGE,RailNetwork.GAUGE]:
		track.prism(lift_rail_tongues,[Vector2(x-.0325,1.1),Vector2(x+.0325,1.1),Vector2(x+.0325,RailNetwork.DOCK_LIP),Vector2(x-.0325,RailNetwork.DOCK_LIP)],lift_rail_material)
	for z in [.20,.58,.96]:track.sleeper(lift,Vector2(0,z),Vector2.DOWN)

	for x in [-1.0,1.0]:cylinder(world_root,point(S.LIFT)+Vector3(x,S.HEIGHT*.5+.6,0),.025,S.HEIGHT+1.1,brass)
	for x in [-1.18,1.18]:
		for y in [.16,S.HEIGHT+.16]:
			var dock_layer:=0 if y>S.HEIGHT*.5 else 1
			if not lift_arrival_materials.has(dock_layer):lift_arrival_materials[dock_layer]=brass.duplicate()
			var dock_material:StandardMaterial3D=lift_arrival_materials[dock_layer]
			box(world_root,point(S.LIFT)+Vector3(x,y,0),Vector3(.08,.035,.65),dock_material)
			for i in range(4):box(world_root,point(S.LIFT)+Vector3(x,y+i*.065,-.29),Vector3(.10,.015,.045),dock_material)
	pressure_faces.append(pad(l,S.CATCH_PLATE,"接"));pressure_faces.append(pad(l,S.SLUICE,"闸"))
	for segment in [[Vector2(7,8),Vector2(9,8)],[Vector2(9,8),Vector2(9,10)],[Vector2(9,10),S.DROP]]:
		beam(l,point(segment[0],.08),point(segment[1],.08),.045,brass)
	upper_light=pad(u,S.UPPER_ANCHOR,"山")
	for at in [Vector2(5,12),S.LOWER_ANCHOR]:
		for x in [-.7,.7]:box(l,point(at)+Vector3(x,1.35,0),Vector3(.12,2.7,.18),wood)
		box(l,point(at,2.7),Vector3(1.6,.2,.5),dark)
	var lower_model=MissionModel.new("lower_anchor");l.add_child(lower_model);lower_model.position=point(S.LOWER_ANCHOR,2.34);mission_models["lower_anchor"]=lower_model;lower_light=lower_model.face
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
	tool_model=MissionModel.new("clip");roots[0].add_child(tool_model);tool_model.position=point(S.TOOL,.45)+Vector3(0,0,.36);tool_model.scale=Vector3.ONE*1.45;mission_models["tool"]=tool_model
	catch_ring=MissionModel.new("ring");roots[1].add_child(catch_ring);catch_ring.position=point(S.DROP+Vector2(1.4,0),.25);mission_models["catch"]=catch_ring
	bridge_ring=MissionModel.new("ring");roots[0].add_child(bridge_ring);bridge_ring.position=point(S.BRIDGE+Vector2(.9,-.5),.10);mission_models["bridge"]=bridge_ring
	clamp=MissionModel.new("clip");world_root.add_child(clamp);clamp.scale=Vector3.ONE*1.15;mission_models["held_clip"]=clamp
	portal=preload("res://scripts/paper_archive_gate.gd").new();u.add_child(portal);portal.position=point(S.EXIT)
	# A slight turn keeps a readable opening at both limits of the orbit camera.
	portal.rotation.y=PI*.125;portal.build(self)
	completion_paper=group(u,point(S.UPPER_ANCHOR)+Vector3(0,1.6,.7))
	box(completion_paper,Vector3.ZERO,Vector3(2.3,1.5,.025),paper_mat)
	var drawing:=Label3D.new();drawing.text="水路既通 · 纸山重明\n潮纹所向：瓯江孤屿";drawing.font_size=32;drawing.pixel_size=.008;drawing.position.z=.02;drawing.modulate=Color("365b52");drawing.outline_size=0;completion_paper.add_child(drawing)
	for i in range(2):
		var n=MissionModel.new("mountain" if i==0 else "water");world_root.add_child(n);weight_nodes.append(n);mission_models["w%d"%i]=n
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

func _process(delta:float) -> void:_sync(0 if room.hud!=null and room.hud.menu.visible else delta)

func _build_push_guides() -> void:
	push_arrow=group(world_root);push_arrow_material=mat("c6db91")
	push_arrow_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	beam(push_arrow,Vector3(.72,.03,0),Vector3(1.48,.03,0),.075,push_arrow_material)
	for sign_value in [-1,1]:beam(push_arrow,Vector3(1.48,.03,0),Vector3(1.2,.03,sign_value*.22),.075,push_arrow_material)

func _update_push_guide() -> void:
	push_arrow.hide()
	if room.hud==null or room.hud.menu.visible or not room.pending.has("direction"):return
	var index:=int(room.pending.id.trim_prefix("w"));var w:Dictionary=room.state.weights[index]
	if w.mode!="rest" or w.layer!=room.view_layer:return
	var direction:Vector2=room.pending.direction
	push_arrow.position=point(w.pos,room.state.weight_height(index)+.1)
	push_arrow.rotation.y=-atan2(direction.y,direction.x);push_arrow.show()

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
		GuardFade.sync(section,covered.has(i),delta)

func _build_weight_shadows() -> void:
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float strength=0.16;
void fragment(){float r=length((UV-vec2(.5))*2.0);ALBEDO=vec3(.12,.16,.13);ALPHA=(1.0-smoothstep(.24,1.0,r))*strength;}
"""
	for i in range(2):
		var n:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=Vector2(1.1,1.1)
		var material:=ShaderMaterial.new();material.shader=shader;n.mesh=mesh;n.material_override=material
		n.rotation.x=-PI*.5;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_root.add_child(n);weight_shadows.append(n)

func _sync(delta:float) -> void:
	age+=delta;link_time=maxf(0,link_time-delta)
	if frame_to_ui and room.hud!=null:
		var desired:Vector2=room.hud.safe_rect().get_center()
		safe_center=safe_center.lerp(desired,1.0-exp(-delta*9.0))
		if safe_center.distance_to(desired)<.02:safe_center=desired
	var following:bool=auto_follow and room.player_layer==room.view_layer
	var desired_height:float=S.HEIGHT if room.view_layer==0 else 0.0
	if room.transition_age>0 or room.lift_riding and following:desired_height=room.actor_height()
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
		var destination:Vector2=room.player.display_position()/room.SCALE
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
	memory_props.sync(delta,s.worlds)
	rule_details.sync(delta,s.worlds,room.hud==null or room.hud.audio.preferences.motion_enabled)
	for i in range(2):
		roots[i].visible=(i==room.view_layer or link_time>0) and not (i==0 and room.lift_riding and s.lift_in_transit())
		roofs[i].visible=false # No roofs or furniture remain over the active courts.
		rails[i].albedo_color=RAIL_COLORS[s.worlds[i]]
		layer_stone[i].albedo_color=STONE_COLORS[s.worlds[i]]
		floating_paper[i].emitting=false
		var w:Dictionary=s.weights[i]
		weight_nodes[i].position=point(w.pos,s.weight_height(i))
		weight_nodes[i].visible=w.layer==room.view_layer or w.mode=="fall" or link_time>0
		var support_height:float=s.weight_support_height(i)
		var surface_height:=support_height+.023
		if w.station=="hatch" and not s.hatch_broken:surface_height=support_height+.17
		elif w.station=="catch" and i==0:surface_height=support_height+.17+s.catch_height*.15
		elif w.station=="lift":surface_height=support_height+.16
		weight_shadows[i].position=point(w.pos,surface_height)
		weight_shadows[i].visible=weight_nodes[i].visible and w.mode!="fall"
		var gap:float=maxf(0.0,s.weight_height(i)-support_height-.18)
		weight_shadows[i].material_override.set_shader_parameter("strength",.17/(1.0+gap*.9))
		weight_shadows[i].scale=Vector3.ONE*(1.0+gap*.14)
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
	bridge.visible=s.bridge_solid();side_bridge.visible=s.old_corridor_solid()
	waterbank_guards.sync(delta)
	tool_model.visible=not s.clip_owned
	catch_ring.set_fixed(s.clip_target=="catch");bridge_ring.set_fixed(s.clip_target=="bridge")
	catch_ring.position.y=.25+s.catch_height*.15
	catch_tray.position.y=s.catch_height*.15
	lift.position.y=s.lift_height
	lift_rail_tongues.visible=s.lift_docked(0) or s.lift_docked(1)
	lift_rail_material.albedo_color=rails[0 if s.lift_height>S.HEIGHT*.5 else 1].albedo_color
	rail_frost.sync(delta,s.worlds,room.hud==null or room.hud.audio.preferences.motion_enabled)
	cage_door.rotation.x=PI*.48 if s.cage_open else 0.0
	cover.position.x=S.LOWER_ANCHOR.x+(1.5 if s.upper_anchored else 0.0)
	lowpass_gate.position.y=-1.0 if s.lowpass_open else .75
	sluice_gate.position.y=.9 if s.waterwheel_running() else .4
	for i in range(2):pressure_faces[i].position.y=.12 if s.pressure("catch" if i==0 else "sluice") else .23
	# The completed poem is now a small colophon by the anchor, not a second large scroll.
	completion_paper.visible=s.lower_anchored
	completion_paper.scale.x=.45;completion_paper.scale.z=.45
	completion_paper.position=point(S.UPPER_ANCHOR)+Vector3(1.15,.70,-.25)
	paper_unfold=move_toward(paper_unfold,1.0 if s.lower_anchored else 0.0,delta*.8)
	completion_paper.scale.y=maxf(.02,smoothstep(0.0,1.0,paper_unfold))*.40
	if s.waterwheel_running():wheel.rotation.x+=delta*1.7
	clamp.visible=s.clip_target!=""
	if clamp.visible:clamp.position=(catch_ring.global_position if s.clip_target=="catch" else bridge_ring.global_position)+Vector3(0,.36,0)
	portal.visible=room.view_layer==0
	portal.tick(delta,s)
	actor.visible=room.player_layer==room.view_layer or link_time>0
	actor.position=point(room.player.display_position()/room.SCALE,room.actor_height()+.04)
	shadow.position=actor.position;shadow.visible=actor.visible
	var dir:Vector2=room.player._last_direction
	var a:=camera.unproject_position(actor.position);var b:=camera.unproject_position(actor.position+Vector3(dir.x,0,dir.y))
	var screen_dir:Vector2=(b-a).normalized()
	var row:int=preload("res://scripts/yanyue_facing.gd").row(screen_dir,paper.facing_row,room.player.controls_locked or room.transition_age>0)
	paper.pose(room.player.display_distance() if room.transition_age<=0 else room.elapsed*100,room.player.walking or room.transition_age>0,row,screen_dir,delta,room.player.movement_ratio if room.transition_age<=0 else 1.0)
	paper.push_amount=room.push_age/.45 if room.interacting else 0.0
	_update_push_guide()
	paper.cast_amount=sin((.5-room.world_cast_time)/.5*PI) if room.world_cast_time>0 else 0.0
	film.sync(delta)
	switch_fx.active=film.active and room.player_layer==film.layer_index
	switch_fx.progress=film.progress
	switch_fx.position=screen(room.player_plan(),room.player_layer,.03)
	switch_fx.queue_redraw()
	var target_id:String=room.hud.hover_target if room.hud!=null and not room.hud.hover_target.is_empty() else room.hit_target(get_viewport().get_mouse_position())
	var target:Dictionary=room.target_by_id(target_id)
	highlight.visible=not target.is_empty() and int(target.layer)==room.view_layer
	if highlight.visible:
		highlight.position=point(target.pos,(S.HEIGHT if target.layer==0 else 0.0)+.14)
		if target.id in ["w0","w1"]:highlight.position.y=s.weight_height(int(target.id.trim_prefix("w")))+.08
		highlight_label.text=("走入楼梯 · "+("下楼" if room.player_layer==0 else "上楼")) if target.id=="stairs" else target.name+" · E / 右键"
		if target.id in ["w0","w1"]:
			highlight_label.text="右键 / E · 选择方向"
		elif target.id=="exit":
			highlight_label.text="走入归位门，返回观察局" if s.upper_anchored and s.lower_anchored else "归位门 · 等待双锚稳定"
	portal.hovered=target_id=="exit" and room.view_layer==0

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
