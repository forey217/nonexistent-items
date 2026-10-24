extends Node3D
const MemoryShader=preload("res://shaders/paper_memory.gdshader")
var entries:Array[Dictionary]=[]
var exposure:Array[float]=[0.0,0.0]
var view:Node
var timber:StandardMaterial3D
var ceramic:StandardMaterial3D
var linen:StandardMaterial3D
var ink:StandardMaterial3D
var plaster:StandardMaterial3D

func build(scene_view:Node) -> void:
	view=scene_view
	timber=view.mat("9b8971",view.wood.albedo_texture)
	ceramic=view.mat("7a8980");linen=view.mat("b6b19c");ink=view.mat("68756b")
	plaster=view.mat("a8ad9a",view.wall_mat.albedo_texture)
	var placements:Array[Dictionary]=[
		{"kind":"chair","layer":0,"at":Vector2(7.0,15.1),"yaw":-.22,"delay":.0,"height":1.35},
		{"kind":"tea","layer":0,"at":Vector2(11.6,17.0),"yaw":.0,"delay":.15,"height":1.15},
		{"kind":"frame","layer":0,"at":Vector2(7.27,14.5),"yaw":PI*.5,"delay":.28,"height":2.0},
		{"kind":"plant","layer":0,"at":Vector2(13.4,17.2),"yaw":.3,"delay":.09,"height":1.3},
		{"kind":"laundry","layer":0,"at":Vector2(22.8,15.7),"yaw":PI*.5,"delay":.38,"height":1.9},
		{"kind":"papers","layer":0,"at":Vector2(8.3,17.25),"yaw":.4,"delay":.22,"height":.15,"partial":.60},
		{"kind":"painting","layer":0,"at":Vector2(9.5,17.6),"yaw":.0,"delay":.46,"height":2.1,"partial":.64},
		{"kind":"chair","layer":1,"at":Vector2(7.0,15.1),"yaw":.45,"delay":.18,"height":1.35,"partial":.58},
		{"kind":"tea","layer":1,"at":Vector2(11.6,17.0),"yaw":-.18,"delay":.34,"height":1.15},
		{"kind":"plant","layer":1,"at":Vector2(23.0,2.0),"yaw":.0,"delay":.05,"height":1.3},
		{"kind":"papers","layer":1,"at":Vector2(8.2,17.2),"yaw":.3,"delay":.27,"height":.15},
		{"kind":"painting","layer":1,"at":Vector2(5.5,17.5),"yaw":.0,"delay":.44,"height":2.1}
	]
	# Keep the developing-memory effect, but move its tall domestic props onto
	# the rear village terrace. No chair, hanging cloth or picture enters play space.
	for layer in [0,1]:
		var depth:float=(view.S.HEIGHT if layer==0 else 0.0)+2.3
		view.box(view.roots[layer],Vector3(12.5,-depth*.5,-3.6),Vector3(23,depth,2.8),view.stone)
	for spec in placements:
		spec.at=Vector2(spec.at.x,{"frame":-4.2,"painting":-4.25,"papers":-2.9,"laundry":-3.6}.get(spec.kind,-3.4))
		var root:Node3D=view.group(view.roots[spec.layer],view.point(spec.at))
		root.name="Memory_"+spec.kind;root.rotation.y=spec.yaw
		match spec.kind:
			"chair":_chair(root)
			"tea":_tea(root)
			"frame","painting":_picture(root,spec.kind=="painting")
			"plant":_plant(root)
			"laundry":_laundry(root)
			"papers":_papers(root)
		preload("res://scripts/static_mesh_batch.gd").compact(root)
		var materials:Array[ShaderMaterial]=[]
		var ghosts:Array[ShaderMaterial]=[]
		var echoes:Node3D=view.group(root,Vector3(.055,.015,-.035))
		var has_echo:bool=spec.kind in ["chair","frame","laundry"]
		for mesh in root.get_children():
			if not mesh is MeshInstance3D:continue
			var source:StandardMaterial3D=mesh.material_override
			var material:=_material(source,spec)
			mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			materials.append(material)
			if has_echo:
				var echo:=MeshInstance3D.new();echo.mesh=mesh.mesh;echo.transform=mesh.transform
				var ghost_material:=_material(source,spec);ghost_material.set_shader_parameter("ghost",1.0)
				echo.material_override=ghost_material;echo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				echoes.add_child(echo);ghosts.append(ghost_material)
		root.hide()
		entries.append({"root":root,"layer":spec.layer,"kind":spec.kind,"delay":spec.delay,"partial":spec.get("partial",1.0),"materials":materials,"ghosts":ghosts,"progress":0.0,"residue":0.0})

func _material(source:StandardMaterial3D,spec:Dictionary) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=MemoryShader
	material.set_shader_parameter("tint",source.albedo_color)
	material.set_shader_parameter("textured",source.albedo_texture!=null)
	if source.albedo_texture!=null:material.set_shader_parameter("surface_texture",source.albedo_texture)
	material.set_shader_parameter("floor_height",view.S.HEIGHT if spec.layer==0 else 0.0)
	material.set_shader_parameter("object_height",spec.height)
	material.set_shader_parameter("ceiling",spec.get("partial",1.0))
	return material

func sync(delta:float,worlds:Array[int]) -> void:
	for layer in range(2):exposure[layer]=move_toward(exposure[layer],1.0 if worlds[layer]==3 else 0.0,delta/1.8 if worlds[layer]==3 else delta/0.55)
	for entry in entries:
		var progress:=clampf((exposure[entry.layer]-float(entry.delay))/(1.0-float(entry.delay)),0.0,1.0)
		if worlds[entry.layer]!=3 and float(entry.progress)>0.05 and not entry.ghosts.is_empty():entry.residue=maxf(entry.residue,entry.progress)
		entry.residue=move_toward(entry.residue,0.0,delta/0.85)
		entry.progress=progress
		entry.root.visible=progress>0.001 or entry.residue>0.001
		if not entry.root.visible:continue
		for material in entry.materials:material.set_shader_parameter("progress",progress)
		for material in entry.ghosts:
			material.set_shader_parameter("progress",progress)
			material.set_shader_parameter("residue",entry.residue)

func _chair(root:Node3D) -> void:
	view.box(root,Vector3(0,.55,0),Vector3(.62,.09,.6),timber)
	for side in [-.25,.25]:
		for depth in [-.24,.24]:view.box(root,Vector3(side,.27,depth),Vector3(.065,.54,.065),timber)
		view.box(root,Vector3(side,.98,.24),Vector3(.065,.85,.065),timber)
	for height in [.88,1.16]:view.box(root,Vector3(0,height,.24),Vector3(.55,.12,.055),timber)

func _tea(root:Node3D) -> void:
	view.box(root,Vector3(0,.8,0),Vector3(1.0,.08,.65),timber)
	for side in [-.42,.42]:
		for depth in [-.24,.24]:view.box(root,Vector3(side,.39,depth),Vector3(.065,.78,.065),timber)
	view.cylinder(root,Vector3(.19,.85,0),.15,.025,ceramic)
	view.cylinder(root,Vector3(.19,.94,0),.09,.16,ceramic)
	view.cylinder(root,Vector3(.19,1.023,0),.072,.008,ink)
	var handle:=MeshInstance3D.new();var torus:=TorusMesh.new()
	torus.inner_radius=.035;torus.outer_radius=.061;torus.rings=12;torus.ring_segments=8
	handle.mesh=torus;handle.material_override=ceramic;handle.rotation.x=PI*.5;handle.position=Vector3(.30,.95,0);root.add_child(handle)
	view.box(root,Vector3(-.23,.85,.02),Vector3(.27,.015,.31),linen)

func _picture(root:Node3D,painting:bool) -> void:
	var width:=.94 if painting else .55
	var center:=Vector3(0,1.5 if painting else .48,-.05)
	if painting:
		view.box(root,Vector3(0,.96,.06),Vector3(1.14,1.92,.12),plaster)
		view.box(root,Vector3(-.17,1.99,.06),Vector3(.80,.14,.12),plaster)
	else:
		view.beam(root,Vector3(-.20,0,.18),Vector3(-.20,.78,0),.035,timber)
		view.beam(root,Vector3(.20,0,.18),Vector3(.20,.78,0),.035,timber)
	view.box(root,center,Vector3(width,.71,.055),timber)
	view.box(root,center+Vector3(0,0,-.034),Vector3(width-.10,.60,.016),linen)
	for index in range(3):
		var mark:MeshInstance3D=view.box(root,center+Vector3(-width*.25+index*width*.23,-.08+index*.07,-.046),Vector3(width*.20,.12+index*.09,.008),ink)
		mark.rotation.z=-.3+index*.25

func _plant(root:Node3D) -> void:
	view.cylinder(root,Vector3(0,.22,0),.21,.40,ceramic)
	view.cylinder(root,Vector3(0,.43,0),.22,.055,ceramic)
	view.cylinder(root,Vector3(0,.46,0),.18,.012,ink)
	for index in range(5):
		var tip:=Vector3(sin(index*2.4)*.30,.80+index*.10,cos(index*2.4)*.22)
		view.beam(root,Vector3(0,.44,0),tip,.018,timber)
		var leaf:MeshInstance3D=view.box(root,tip,Vector3(.13,.018,.05),ink);leaf.rotation.z=.5+index*.6

func _laundry(root:Node3D) -> void:
	for side in [-.72,.72]:view.cylinder(root,Vector3(side,.88,0),.025,1.76,timber)
	view.beam(root,Vector3(-.72,1.73,0),Vector3(.72,1.73,0),.015,timber)
	view.box(root,Vector3(-.25,1.27,0),Vector3(.49,.86,.025),linen)
	view.box(root,Vector3(-.25,1.53,0),Vector3(.79,.24,.025),linen)
	view.box(root,Vector3(.42,1.34,.01),Vector3(.25,.71,.02),ceramic)
	for index in range(4):view.box(root,Vector3(-.44+index*.13,1.22,-.018),Vector3(.012,.66,.012),ceramic)

func _papers(root:Node3D) -> void:
	for index in range(4):
		var sheet:Node3D=view.group(root,Vector3(index*.23-.35,.035+index*.008,sin(index*2.0)*.19));sheet.rotation.y=index*.47
		view.box(sheet,Vector3.ZERO,Vector3(.33,.009,.43),linen)
		for line in range(3):view.box(sheet,Vector3(-.025,.006,-.1+line*.065),Vector3(.18-line*.025,.004,.012),ink)
