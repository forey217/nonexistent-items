extends RefCounted
## Visible explanation of existing 2D water boundaries. Ray bodies only support
## occlusion fading; navigation, collision clearance and mechanisms are unchanged.
const RAY_MASK:=64
const HEIGHT:=.78
const MAIN_LEFT:=13.04
const MAIN_RIGHT:=21.96
const MAIN_NORTH:=11.04
const MAIN_SOUTH:=11.96
const MAIN_MOUTH:=Vector2(17.20,18.80)
var sections:Array[Dictionary]=[]
var view:Node

func build(owner_view:Node) -> void:
	view=owner_view
	var timber:StandardMaterial3D=view.mat("75604a",load("res://assets/paper_mill/wood.png"))
	timber.uv1_scale=Vector3.ONE*.35
	var copper:StandardMaterial3D=view.mat("887344");copper.metallic=.35;copper.roughness=.73
	for layer in [0,1]:
		# Fixed banks stop beside the real 1.2-wide path; the .2 inset on either
		# side matches the player's footprint, never a new restriction.
		for z in [MAIN_NORTH,MAIN_SOUTH]:
			section(layer,"main_bank",Vector2(MAIN_LEFT,z),Vector2(MAIN_MOUTH.x,z),timber,copper)
			section(layer,"main_bank",Vector2(MAIN_MOUTH.y,z),Vector2(MAIN_RIGHT,z),timber,copper)
		for x in [MAIN_LEFT,MAIN_RIGHT]:section(layer,"main_end",Vector2(x,MAIN_NORTH),Vector2(x,MAIN_SOUTH),timber,copper)
		var lo:=Vector2(2.50,10.0) if layer==0 else Vector2(3.04,10.04)
		var hi:=Vector2(7.50,12.0) if layer==0 else Vector2(6.96,10.96)
		for z in [lo.y,hi.y]:
			section(layer,"west_bank",Vector2(lo.x,z),Vector2(4.20,z),timber,copper)
			section(layer,"west_bank",Vector2(5.80,z),Vector2(hi.x,z),timber,copper)
		for x in [lo.x,hi.x]:section(layer,"west_end",Vector2(x,lo.y),Vector2(x,hi.y),timber,copper)
		# Side rails sit on deck edges, not across the north/south entry mouths.
		# Upper sections inherit the actual bridge's state, including film copies.
		for x in [MAIN_MOUTH.x,MAIN_MOUTH.y]:
			section(layer,"main_bridge_side",Vector2(x,10.78),Vector2(x,12.22),timber,copper,view.bridge if layer==0 else null)
		for x in [4.20,5.80]:
			section(layer,"west_bridge_side",Vector2(x,9.80 if layer==1 else 9.73),Vector2(x,11.20 if layer==1 else 12.27),timber,copper,view.side_bridge if layer==0 else null)
	for item:Dictionary in sections:
		preload("res://scripts/static_mesh_batch.gd").compact(item.root)
		item.meshes=preload("res://scripts/paper_mill_stair_guards.gd")._meshes(item.root)
		for mesh:GeometryInstance3D in item.meshes:mesh.material_override=mesh.material_override.duplicate()

func section(layer:int,kind:String,a:Vector2,b:Vector2,timber:Material,copper:Material,deck:Node3D=null) -> void:
	var root:=Node3D.new();root.name="WaterbankGuard%d"%sections.size()
	var parent:Node3D=deck if deck!=null else view.roots[layer]
	parent.add_child(root)
	# Geometry is expressed in floor coordinates; bridge group has a local offset.
	if deck!=null:root.position=-deck.position
	var body:=StaticBody3D.new();body.collision_layer=RAY_MASK;body.collision_mask=0
	body.set_meta("waterbank_guard",sections.size());root.add_child(body)
	var item:Dictionary={"root":root,"body":body,"layer":layer,"kind":kind,"a":a,"b":b,"deck":deck,"meshes":[],"fade":0.0}
	sections.append(item)
	var count:=maxi(1,ceili(a.distance_to(b)/1.15))
	for i in range(count+1):
		var at:Vector3=view.point(a.lerp(b,float(i)/count))
		# Narrow stone seats extend the existing coping slightly over the water,
		# so every timber foot has a visible foundation instead of floating.
		view.box(root,at+Vector3.UP*.015,Vector3(.24,.07,.24),view.stone)
		view.box(root,at+Vector3.UP*(HEIGHT*.5),Vector3(.115,HEIGHT,.115),timber)
		for y in [.12,HEIGHT-.10]:view.box(root,at+Vector3.UP*y,Vector3(.135,.04,.135),copper)
		view.box(root,at+Vector3.UP*(HEIGHT+.025),Vector3(.15,.05,.15),timber)
	for y in [.34,HEIGHT-.04]:
		var from:Vector3=view.point(a,y);var to:Vector3=view.point(b,y)
		var width:=.075 if y>.5 else .055
		view.beam(root,from,to,width,timber)
		var shape:=BoxShape3D.new();shape.size=Vector3(absf(to.x-from.x)+.14,HEIGHT+.08,absf(to.z-from.z)+.14)
		var collision:=CollisionShape3D.new();collision.shape=shape;collision.position=view.point((a+b)*.5,HEIGHT*.5);body.add_child(collision)
	# The thin dark coping hides the gap between individual supported feet.
	view.beam(root,view.point(a,-.025),view.point(b,-.025),.16,view.stone)

func sync(delta:float) -> void:
	var excluded:Array[RID]=[]
	for item:Dictionary in sections:
		if not item.root.is_visible_in_tree():excluded.append(item.body.get_rid())
	var covered:Dictionary={}
	if view.room.player_layer==view.room.view_layer or view.room.transition_age>0:
		var space:PhysicsDirectSpaceState3D=view.viewport.find_world_3d().direct_space_state
		for height in [.25,.65,1.2,1.65]:
			var target:Vector3=view.point(view.room.player_plan(),view.room.actor_height()+height)
			var origin:Vector3=view.camera.project_ray_origin(view.camera.unproject_position(target))
			var query:=PhysicsRayQueryParameters3D.create(origin,target,RAY_MASK,excluded)
			var hit:Dictionary=space.intersect_ray(query)
			if not hit.is_empty():covered[int(hit.collider.get_meta("waterbank_guard"))]=true
	for i in range(sections.size()):
		var item:Dictionary=sections[i]
		var target:=.70 if covered.has(i) else 0.0
		item.fade=lerpf(item.fade,target,1.0-exp(-delta*12.0))
		if absf(item.fade-target)<.001:item.fade=target
		for mesh:GeometryInstance3D in item.meshes:
			var material:StandardMaterial3D=mesh.material_override
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if item.fade>0 else BaseMaterial3D.TRANSPARENCY_DISABLED
			material.albedo_color.a=1.0-item.fade
