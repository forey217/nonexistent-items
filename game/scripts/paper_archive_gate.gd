extends Node3D
## Visual state follows the real anchors; no navigation or completion ownership.
const OPEN_SECONDS:=1.65
const Paper=preload("res://scripts/paper_mill_state.gd")
var view:Node
var paper_surface:MeshInstance3D
var sheet_material:=ShaderMaterial.new()
var roller:Node3D
var bottom_bar:Node3D
var latch_nodes:Array[Node3D]=[]
var emblem_materials:Array[StandardMaterial3D]=[]
var glow_material:=StandardMaterial3D.new()
var glow_nodes:Array[MeshInstance3D]=[]
var floor_material:=StandardMaterial3D.new()
var floor_glow:MeshInstance3D
var seams:Array[MeshInstance3D]=[]
var initialized:=false
var last_dual:=false
var opened:=false
var animating:=false
var progress:=0.0
var clock:=0.0
var age:=0.0
var openings:=0
var audio_stages:=0
var hovered:=false
var label:Label3D

func material(hex:String,metal:=false) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=.83
	if metal:m.metallic=.50;m.roughness=.52
	return m

func build(v:Node) -> void:
	view=v
	var timber:=v.wood.duplicate() as StandardMaterial3D;timber.albedo_color=Color("9b805a")
	var endgrain:=material("5b4c39");var copper:=material("a58a55",true);var recess:=material("414b3c")
	var stone:=v.stone.duplicate() as StandardMaterial3D;stone.albedo_color=Color("b5b29e")
	var paper_roll:=material("d7cfb1")
	for side in [-1,1]:
		var x:float=side*1.29
		v.box(self,Vector3(x,.12,0),Vector3(.50,.24,.53),stone)
		v.box(self,Vector3(x,1.48,0),Vector3(.25,2.73,.29),timber)
		v.box(self,Vector3(x,.39,0),Vector3(.29,.28,.33),copper)
		v.box(self,Vector3(x,2.72,0),Vector3(.31,.23,.35),copper)
		v.box(self,Vector3(x,1.48,.154),Vector3(.11,2.10,.018),endgrain)
		v.beam(self,Vector3(x,2.34,.03),Vector3(x-side*.33,2.70,.03),.105,timber)
		for y in [.36,2.68]:
			for dx in [-.085,.085]:v.box(self,Vector3(x+dx,y,.177),Vector3(.035,.035,.025),endgrain)
		var bearing:MeshInstance3D=v.cylinder(self,Vector3(side*1.17,2.76,.12),.18,.105,copper);bearing.rotation.z=PI*.5
		var pin:MeshInstance3D=v.cylinder(self,Vector3(side*1.26,2.76,.12),.065,.18,endgrain);pin.rotation.z=PI*.5
		var latch:Node3D=v.group(self,Vector3(side*.91,2.48,.17));latch_nodes.append(latch)
		latch.name="LatchLeft" if side<0 else "LatchRight"
		v.box(latch,Vector3(0,-.08,0),Vector3(.10,.25,.07),copper)
		v.box(latch,Vector3(0,-.19,.02),Vector3(.18,.07,.10),copper)
	v.box(self,Vector3(0,2.98,0),Vector3(2.99,.20,.39),timber)
	v.box(self,Vector3(0,3.10,0),Vector3(3.10,.075,.44),endgrain)
	v.box(self,Vector3(0,2.91,.21),Vector3(2.78,.028,.024),copper)
	roller=v.group(self,Vector3(0,2.76,.12))
	roller.name="ScrollRoller"
	var core:MeshInstance3D=v.cylinder(roller,Vector3.ZERO,.13,2.23,paper_roll);core.rotation.z=PI*.5
	for side in [-1,1]:
		var cap:MeshInstance3D=v.cylinder(roller,Vector3(side*1.105,0,0),.15,.05,copper);cap.rotation.z=PI*.5
		v.box(roller,Vector3(side*.82,0,.132),Vector3(.045,.09,.012),copper)
	v.box(self,Vector3(0,3.015,.24),Vector3(.72,.31,.065),recess)
	label=Label3D.new();label.text="归 档";label.font=preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf")
	label.font_size=42;label.pixel_size=.006;label.outline_size=0;label.modulate=Color("d6c291");label.position=Vector3(0,3.015,.281);add_child(label)
	for index in range(2):
		var emblem:Node3D=v.group(self,Vector3(-.97 if index==0 else .97,2.97,.27))
		v.box(emblem,Vector3.ZERO,Vector3(.36,.34,.06),recess)
		var em:=material("86714d",true);em.emission_enabled=true;em.emission=Color("b8aa74");em.emission_energy_multiplier=0.0;emblem_materials.append(em)
		if index==0:
			for points in [[Vector3(-.135,-.08,.045),Vector3(-.04,.105,.045),Vector3(.035,-.02,.045),Vector3(.085,.065,.045),Vector3(.145,-.08,.045)]]:
				for i in range(1,points.size()):v.beam(emblem,points[i-1],points[i],.027,em)
		else:
			for row in range(3):
				for i in range(5):
					var a:=float(i)/5.0;var b:=float(i+1)/5.0
					v.beam(emblem,Vector3(lerpf(-.14,.14,a),row*.075-.075+sin(a*TAU)*.02,.045),Vector3(lerpf(-.14,.14,b),row*.075-.075+sin(b*TAU)*.02,.045),.021,em)
	paper_surface=MeshInstance3D.new()
	var mesh:=QuadMesh.new();mesh.size=Vector2(2.22,2.51);paper_surface.mesh=mesh;paper_surface.position=Vector3(0,1.455,.13)
	sheet_material.shader=preload("res://shaders/paper_archive_scroll.gdshader");sheet_material.set_shader_parameter("landscape",preload("res://assets/paper_mill/archive_landscape.svg"))
	paper_surface.material_override=sheet_material;paper_surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(paper_surface)
	bottom_bar=v.group(self,Vector3(0,2.71,.13))
	bottom_bar.name="ScrollHem"
	var bottom:MeshInstance3D=v.cylinder(bottom_bar,Vector3.ZERO,.045,2.33,endgrain);bottom.rotation.z=PI*.5
	for side in [-1,1]:
		var cap:MeshInstance3D=v.cylinder(bottom_bar,Vector3(side*1.12,0,0),.058,.09,copper);cap.rotation.z=PI*.5
	glow_material=material("bdc6ad");glow_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glow_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	# Sparse nested edge rails give depth while leaving the actor's passage empty.
	for side in [-1,1]:
		for i in range(3):
			glow_nodes.append(v.beam(self,Vector3(side*(.78-i*.10),.24+i*.07,-.10-i*.12),Vector3(side*(.78-i*.10),2.52-i*.10,-.10-i*.12),.018,glow_material))
		seams.append(v.beam(self,Vector3(side*1.29,.65,.172),Vector3(side*1.29,2.60,.172),.018,glow_material))
	floor_material=material("d2c799");floor_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;floor_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var fm:=PlaneMesh.new();fm.size=Vector2(1.86,.55);floor_glow=MeshInstance3D.new();floor_glow.mesh=fm;floor_glow.material_override=floor_material
	floor_glow.position=Vector3(0,.035,.27);floor_glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(floor_glow)
	apply_pose(0.0,0.0,1.0)
	preload("res://scripts/static_mesh_batch.gd").compact(self,[&"ScrollRoller",&"ScrollHem",&"LatchLeft",&"LatchRight"])

func baseline(state:RefCounted) -> void:
	initialized=true;last_dual=state.upper_anchored and state.lower_anchored
	opened=last_dual;animating=false;progress=1.0 if opened else 0.0;age=OPEN_SECONDS if opened else 0.0;audio_stages=0
	update_emblems(state);apply_pose(progress,1.0 if opened else 0.0,1.0)

func motion_enabled() -> bool:
	return view.room.hud==null or view.room.hud.audio.preferences.motion_enabled

func tick(delta:float,state:RefCounted) -> void:
	if not initialized:baseline(state)
	var dual:bool=state.upper_anchored and state.lower_anchored
	if not dual and last_dual:baseline(state)
	if dual and not last_dual:
		opened=true;animating=true;age=0;progress=0;audio_stages=0;openings+=1
	last_dual=dual
	# Presentation can accelerate physics; the door keeps its readable real-time beat.
	var dt:float=delta/maxf(Engine.time_scale,.01) if view.room.presentation_mode else delta
	clock+=dt
	if animating:
		age+=dt
		var duration:float=OPEN_SECONDS if motion_enabled() else .18
		progress=clampf(age/duration,0,1)
		if progress>=1:animating=false
		if dt>0 and motion_enabled():
			if age>=.16 and audio_stages==0:_sound("clamp");audio_stages=1
			if age>=.43 and audio_stages==1:_sound("paper");audio_stages=2
	update_emblems(state)
	var unroll:float=smoothstep(.17,.75,progress) if motion_enabled() else (1.0 if opened else 0.0)
	var aperture:float=smoothstep(.60,1.0,progress) if motion_enabled() else (1.0 if opened else 0.0)
	apply_pose(unroll,aperture,progress if not motion_enabled() and opened else 1.0)

func _sound(kind:String) -> void:
	if kind=="clamp":view.room.sound.play_resonance("clamp")
	else:view.room.sound.play_archive_paper()

func update_emblems(state:RefCounted) -> void:
	for i in range(emblem_materials.size()):
		var lit:bool=state.upper_anchored if i==0 else state.lower_anchored
		var m:=emblem_materials[i]
		m.albedo_color=Color("d2bc7d") if lit else Color("86714d")
		m.emission=Color("b8aa74")*(.32 if lit else 0.0);m.emission_energy_multiplier=1.0

func apply_pose(unroll:float,aperture:float,reveal:float) -> void:
	paper_surface.visible=unroll>.001
	paper_surface.scale.y=maxf(.001,unroll);paper_surface.position.y=2.71-1.255*unroll
	bottom_bar.position.y=2.71-2.51*unroll
	roller.rotation.x=-unroll*TAU*1.1
	for i in range(latch_nodes.size()):latch_nodes[i].rotation.z=(-1.0 if i==0 else 1.0)*smoothstep(.05,.28,progress)*.85
	sheet_material.set_shader_parameter("unfold",unroll);sheet_material.set_shader_parameter("opening",aperture);sheet_material.set_shader_parameter("reveal",reveal)
	sheet_material.set_shader_parameter("still_time",clock if motion_enabled() else 0.0)
	var glow:float=aperture*reveal
	glow_material.albedo_color=Color(Color("c1cbb1"),glow*(.36 if hovered else .22))
	floor_material.albedo_color=Color(Color("d2c799"),glow*.12)
	for n in glow_nodes:n.visible=glow>.001
	for n in seams:n.visible=glow>.001
	floor_glow.visible=glow>.001

func ready_for_entry() -> bool:return opened and not animating
