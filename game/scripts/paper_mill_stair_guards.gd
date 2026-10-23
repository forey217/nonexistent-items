extends RefCounted
## Shared world-space boundary for the rendered stairwell and 2D movement.
const OPENING:=Rect2(2.5,3.0,2.0,5.5)
const POST_SIZE:=.24
const UPPER_LINES:=[Vector4(2.4,2.9,2.4,8.4),Vector4(4.6,2.9,4.6,8.4),Vector4(2.4,2.9,4.6,2.9)]
const LOWER_POSTS:=[Vector2(2.65,2.5),Vector2(4.35,2.5)]

static func boundaries(layer:int) -> Array[Rect2]:
	var result:Array[Rect2]=[]
	if layer==0:
		for line in UPPER_LINES:
			var a:=Vector2(line.x,line.y);var b:=Vector2(line.z,line.w)
			result.append(Rect2(a.min(b)-Vector2.ONE*POST_SIZE*.5,(b-a).abs()+Vector2.ONE*POST_SIZE))
	else:
		for at in LOWER_POSTS:result.append(Rect2(at-Vector2.ONE*.11,Vector2.ONE*.22))
	return result

static func blocks(at:Vector2,layer:int,clearance:float) -> bool:
	for rect in boundaries(layer):
		# Distance to the solid rectangle matches a circular character footprint.
		var closest:=at.clamp(rect.position,rect.end)
		if at.distance_squared_to(closest)<clearance*clearance:return true
	return false

static func build(view:Node) -> Array[Dictionary]:
	var sections:Array[Dictionary]=[]
	var timber:StandardMaterial3D=view.mat("75604a",load("res://assets/paper_mill/wood.png"))
	timber.uv1_scale=Vector3.ONE*.35
	for line in UPPER_LINES:
		var section:=_section(view,sections,true)
		var a:=Vector3(line.x,view.S.HEIGHT,line.y);var b:=Vector3(line.z,view.S.HEIGHT,line.w)
		# A stone edge cap and short lining give the posts a supported foundation.
		_bar(view,section,a-Vector3.UP*.14,b-Vector3.UP*.14,.22,view.stone)
		var count:=ceili(a.distance_to(b)/1.2)
		for i in range(count+1):
			if line.x!=line.z and i in [0,count]:continue # Corners belong to the long sides.
			_post(view,section,a.lerp(b,float(i)/count),1.0,timber)
		for height in [.53,.99]:_bar(view,section,a+Vector3.UP*height,b+Vector3.UP*height,.085 if height>.9 else .055,timber)
	# Side handrails have posts resting on real treads; neither rail crosses a mouth.
	for side in [0,1]:
		var section:=_section(view,sections,false)
		var x:float=LOWER_POSTS[side].x
		var bases:Array[Vector3]=[Vector3(x,0,2.5)]
		for i in range(5):bases.append(Vector3(x,.24+i*.96,3.0+i*1.16))
		for at in bases:_post(view,section,at,.98,timber)
		for i in range(bases.size()-1):
			for height in [.52,.97]:_bar(view,section,bases[i]+Vector3.UP*height,bases[i+1]+Vector3.UP*height,.085 if height>.9 else .05,timber)
		var top:=Vector3(2.4 if side==0 else 4.6,view.S.HEIGHT+.99,8.4)
		_bar(view,section,bases[-1]+Vector3.UP*.97,top,.085,timber)
	for section in sections:
		preload("res://scripts/static_mesh_batch.gd").compact(section.root)
		section.meshes=_meshes(section.root)
		# Compatibility rendering needs real alpha materials for occlusion fades;
		# GeometryInstance transparency alone is not supported on this renderer.
		for mesh in section.meshes:mesh.material_override=mesh.material_override.duplicate()
	return sections

static func _section(view:Node,sections:Array[Dictionary],upper:bool) -> Dictionary:
	var root:=Node3D.new();root.name="StairGuard%d"%sections.size();view.world_root.add_child(root)
	var body:=StaticBody3D.new();body.collision_layer=32;body.collision_mask=0;body.set_meta("stair_guard",sections.size());root.add_child(body)
	var section:Dictionary={"root":root,"body":body,"upper":upper,"fade":0.0,"meshes":[]}
	sections.append(section);return section

static func _post(view:Node,section:Dictionary,base:Vector3,height:float,timber:Material) -> void:
	view.box(section.root,base+Vector3.UP*.045,Vector3(.24,.09,.24),view.stone)
	view.box(section.root,base+Vector3.UP*.11,Vector3(.17,.06,.17),view.brass)
	view.box(section.root,base+Vector3.UP*(height*.5+.04),Vector3(.115,height,.115),timber)
	for y in [.18,height-.09]:view.box(section.root,base+Vector3.UP*y,Vector3(.13,.045,.13),view.brass)
	view.box(section.root,base+Vector3.UP*(height+.045),Vector3(.15,.06,.15),timber)
	# Small projecting pins make the rail-to-post join readable at close zoom.
	for sign_value in [-1,1]:view.cylinder(section.root,base+Vector3(sign_value*.075,height-.1,0),.018,.025,view.brass)
	var shape:=BoxShape3D.new();shape.size=Vector3(.24,height+.09,.24)
	var collision:=CollisionShape3D.new();collision.shape=shape;collision.position=base+Vector3.UP*(height+.09)*.5;section.body.add_child(collision)

static func _bar(view:Node,section:Dictionary,a:Vector3,b:Vector3,width:float,timber:Material) -> void:
	view.beam(section.root,a,b,width,timber)
	var shape:=CapsuleShape3D.new();shape.radius=width*.55;shape.height=a.distance_to(b)+width
	var collision:=CollisionShape3D.new();collision.shape=shape;collision.position=(a+b)*.5
	collision.quaternion=Quaternion(Vector3.UP,(b-a).normalized());section.body.add_child(collision)

static func _meshes(root:Node) -> Array[GeometryInstance3D]:
	var result:Array[GeometryInstance3D]=[]
	for child in root.get_children():
		if child is GeometryInstance3D:result.append(child)
		result.append_array(_meshes(child))
	return result
