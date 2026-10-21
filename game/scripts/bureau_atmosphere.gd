extends Node3D
## A few world-specific visual clues; no extra colliders or puzzle objects.
var view: Node2D
var groups: Array[Node3D]=[]
var grains: Array[MeshInstance3D]=[]
var papers: Array[MeshInstance3D]=[]
var pendulums: Array[Node3D]=[]
var clock := 0.0
var settle := 0.0
var last_world := -1
var frost_age := 0.0
var crack_age := 0.0
var frost: Array[Node3D]=[]
var frost_sparkles: Array[Node3D]=[]
var frost_mist: Array[Node3D]=[]
var mist_ink: StandardMaterial3D
var crack_strokes: Array[Node3D]=[]
var crack_delays: Array[float]=[]
var floating_files: Array[Node3D]=[]
var builder=preload("res://scripts/calibration_scene_builder.gd").new()

func _ready() -> void:
	for index in range(3):
		var group:=Node3D.new();add_child(group);groups.append(group)
		builder.configure(index,group)
		var pivot:=Node3D.new();group.add_child(pivot)
		pivot.position=Vector3(3.3,1.4,0.34)
		builder.box(Vector3(0,0,-0.05),Vector3(0.18,0.12,0.08),builder.brass,pivot)
		var swinging:=Node3D.new();pivot.add_child(swinging)
		pendulums.append(swinging)
		var length:=0.97 if index==1 else (0.62 if index==2 else 0.75)
		var sign_y:=1.0 if index==2 else -1.0
		builder.cylinder(Vector3(0,sign_y*length*0.5,0.08),0.009,length,builder.brass,swinging)
		var bob:=builder.cylinder(Vector3(0,sign_y*length,0.08),0.075,0.13,builder.metal,swinging)
		bob.rotation.z=PI*0.5
		if index==0:
			var ice:=builder.material(Color("b5e5ed"),true)
			for i in range(14):
				var grain:=builder.cylinder(Vector3.ZERO,0.025+float(i%3)*0.009,0.018,ice,group)
				grain.scale=Vector3(1.8,0.7,0.7)
				grain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				grains.append(grain)
			_build_frost(group)
		if index==1:_build_cracks(group)
		if index==2:
			var cream:=builder.material(Color("f3e8ca"))
			cream.cull_mode=BaseMaterial3D.CULL_DISABLED
			for i in range(8):
				var paper:=MeshInstance3D.new()
				var quad:=QuadMesh.new();quad.size=Vector2(0.13,0.09)
				paper.mesh=quad;paper.material_override=cream
				paper.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				group.add_child(paper);papers.append(paper)
			for i in range(3):
				var file:=builder.box(Vector3.ZERO,Vector3(0.24,0.012,0.17),cream,group)
				file.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				floating_files.append(file)
		view._assign_render_layer(group,1<<index)

func _build_frost(group: Node3D) -> void:
	var ice:=builder.material(Color("63b8d8"),true)
	ice.roughness=0.2
	ice.emission_energy_multiplier=0.12
	var white:=builder.material(Color("e1faff"),true)
	white.emission_energy_multiplier=0.18
	for side in range(2):
		for i in range(32):
			var piece:=Node3D.new();group.add_child(piece)
			piece.position=Vector3(2.02+float(i)*7.46/31.0,0.230,[4.54,5.06][side])
			builder.box(Vector3.ZERO,Vector3(0.242,0.022,0.17),ice,piece)
			builder.box(Vector3(0,0.009,0),Vector3(0.245,0.010,0.105),white,piece)
			if i%2==1:
				var shard:=builder.box(Vector3(0.035,0.040,-0.11 if side==0 else 0.11),Vector3(0.060,0.10,0.055),ice,piece)
				shard.rotation.z=0.58
			frost.append(piece)
	for i in range(10):
		var sparkle:=builder.box(Vector3.ZERO,Vector3(0.045,0.065,0.045),white,group)
		sparkle.rotation.z=0.65;sparkle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frost_sparkles.append(sparkle)
	var gradient:=Gradient.new()
	gradient.colors=PackedColorArray([Color(1,1,1,1),Color(1,1,1,0)])
	var texture:=GradientTexture2D.new()
	texture.gradient=gradient;texture.width=64;texture.height=64
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(0.5,0.5);texture.fill_to=Vector2(1.0,0.5)
	mist_ink=builder.material(Color(0.65,0.90,1.0,0.38))
	mist_ink.albedo_texture=texture
	mist_ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_ink.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	mist_ink.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
	for i in range(10):
		var puff:=MeshInstance3D.new()
		var quad:=QuadMesh.new();quad.size=Vector2(0.40,0.26)
		puff.mesh=quad;puff.material_override=mist_ink
		puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(puff);frost_mist.append(puff)

func _build_cracks(group: Node3D) -> void:
	var ink:=builder.material(Color("806b59"))
	ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var feet: Array[Vector2]=[
		Vector2(1.43,1.20),Vector2(2.77,1.20),
		Vector2(5.95,1.27),Vector2(7.65,1.27)]
	for i in range(feet.size()):
		var sign_x: float=-1.0 if i%2==0 else 1.0
		var a:=feet[i]
		var b:=a+Vector2(sign_x*0.13,0.17)
		var c:=b+Vector2(sign_x*0.16,0.11)
		var d:=c+Vector2(sign_x*0.07,0.15)
		var branch:=b+Vector2(-sign_x*0.13,0.16)
		_crack_line(a,b,0.00+float(i)*0.025,ink,group)
		_crack_line(b,c,0.10+float(i)*0.025,ink,group)
		_crack_line(c,d,0.23+float(i)*0.025,ink,group)
		_crack_line(b,branch,0.18+float(i)*0.025,ink,group)

func _crack_line(a: Vector2,b: Vector2,delay: float,ink: Material,parent: Node3D) -> void:
	var pivot:=Node3D.new();parent.add_child(pivot)
	pivot.position=Vector3(a.x,0.031,a.y)
	var direction:=b-a
	pivot.rotation.y=atan2(-direction.y,direction.x)
	var length:=direction.length()
	var line:=builder.box(Vector3(length*0.5,0,0),Vector3(length,0.003,0.013),ink,pivot)
	line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crack_strokes.append(pivot);crack_delays.append(delay)

func reset_effects() -> void:
	frost_age=0.0
	crack_age=0.0
	settle=0.0
	last_world=-1

func sync(delta: float) -> void:
	clock+=delta
	if last_world!=view.room.state.world:
		last_world=view.room.state.world
		settle=0.0
		if last_world==0:frost_age=0.0
		if last_world==1:crack_age=0.0
	settle+=delta
	if last_world==0:frost_age+=delta
	if last_world==1:crack_age+=delta
	for i in range(3):groups[i].visible=view.themes[i].root.visible
	pendulums[0].rotation.z=sin(clock*1.2)*0.09
	pendulums[1].rotation.z=sin(settle*9.0)*0.12*exp(-settle*3.0)
	pendulums[2].rotation.z=sin(clock*0.85)*0.06
	for i in range(frost.size()):
		var growth:=smoothstep(0.0,0.20,frost_age-float(i%32)*0.018-float(i/32)*0.055)
		frost[i].visible=growth>0.001
		frost[i].scale=Vector3(maxf(0.001,growth),maxf(0.001,growth),maxf(0.001,growth))
	for i in range(frost_sparkles.size()):
		var progress:=clampf(frost_age/0.83,0,1)
		frost_sparkles[i].visible=frost_age>0.05 and frost_age<0.83
		frost_sparkles[i].position=Vector3(2.02+progress*7.46,0.28+absf(sin(clock*8+i))*0.09,[4.54,5.06][i%2]+sin(clock*6+i)*0.08)
	mist_ink.albedo_color.a=0.38*(1.0-smoothstep(0.75,1.15,frost_age))
	for i in range(frost_mist.size()):
		var progress:=clampf((frost_age-float(i/2)*0.025)/0.83,0,1)
		frost_mist[i].visible=frost_age>0.04 and frost_age<1.15
		frost_mist[i].position=Vector3(2.02+progress*7.46,0.34+sin(clock*3+i)*0.04,[4.54,5.06][i%2])
		frost_mist[i].scale=Vector3.ONE*(1.0+0.14*sin(clock*4+i))
	for i in range(crack_strokes.size()):
		var growth:=smoothstep(0.0,0.24,crack_age-crack_delays[i])
		crack_strokes[i].visible=growth>0.001
		crack_strokes[i].scale.x=maxf(0.001,growth)
	for i in range(grains.size()):
		grains[i].position=Vector3(0.9+fposmod(float(i)*0.79+clock*0.18,10.1),0.065,5.72+float(i%5)*0.34)
	for i in range(papers.size()):
		papers[i].position=Vector3(1.0+float(i)*1.23+sin(clock*0.6+i)*0.12,0.12+fposmod(clock*0.30+float(i)*0.31,2.05),2.2+float(i%4)*1.3)
		papers[i].rotation=Vector3(-0.45+sin(clock+i)*0.18,clock*0.24+i,sin(clock*0.8+i)*0.22)
	for i in range(floating_files.size()):
		floating_files[i].position=Vector3(6.2+float(i)*0.5,1.18+sin(clock*1.3+i)*0.08,1.25+cos(clock*0.9+i)*0.07)
		floating_files[i].rotation=Vector3(sin(clock+i)*0.12,sin(clock*0.5+i)*0.20,cos(clock+i)*0.08)
