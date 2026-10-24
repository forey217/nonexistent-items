extends Node
var app:Node
var room:Node
var checks:Array[Dictionary]=[]
var failures:=0
var directory:=""

func check(title:String,passed:bool) -> void:
	checks.append({"test":title,"passed":passed});print("YARD_CHECK ",title," ",passed)
	if not passed:failures+=1;push_error("YARD_FAILED "+title)

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func meshes(node:Node) -> Array[MeshInstance3D]:
	var list:Array[MeshInstance3D]=[]
	for child in node.get_children():
		if child is MeshInstance3D:list.append(child)
		list.append_array(meshes(child))
	return list

func hits(mesh:MeshInstance3D,a:Vector3,b:Vector3) -> bool:
	var inverse:=mesh.global_transform.affine_inverse()
	return mesh.get_aabb().intersects_segment(inverse*a,inverse*b)!=null

func capture(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func run(flow:Node) -> void:
	app=flow;room=app.current
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://paper-yard-checks")
	DirAccess.make_dir_recursive_absolute(directory)
	room.communications.enabled=false;room.communications.stop();room.hud.entry_hint.dismiss()
	await frames(30)
	var v=room.view
	check("four_complete_workshops_remain_as_peripheral_scenery",v.yard.buildings.size()==4)
	var outside:=true;var grouped:=true;var no_shadows:=true
	for building in v.yard.buildings:
		outside=outside and not building.footprint.intersects(Rect2(.65,.65,22.7,16.7))
		var leaves:=meshes(building.root);grouped=grouped and leaves.size()>=4
		for mesh in leaves:no_shadows=no_shadows and mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	check("buildings_furniture_and_racks_outside_walkable_bounds",outside and grouped)
	check("peripheral_roofs_do_not_cast_shadows_over_puzzle",no_shadows)
	var memories_outside:=true
	for entry in v.memory_props.entries:
		memories_outside=memories_outside and entry.root.position.z<-.65
	check("developing_chairs_and_domestic_props_also_move_outside",memories_outside)
	for layer in [0,1]:
		check("no_roof_over_playable_floor_%d"%layer,v.roofs[layer].get_child_count()==0)
		var detail:Node3D=v.roots[layer].get_node("LowPapermakingDetails")
		var low:=true
		for mesh in meshes(detail):
			var bounds:AABB=mesh.get_aabb()
			for corner in range(8):
				var vertex:Vector3=detail.global_transform.affine_inverse()*mesh.global_transform*bounds.get_endpoint(corner)
				low=low and vertex.y<=.51
		check("all_courtyard_decor_below_half_meter_%d"%layer,low)
		for at in [Vector2(8,15),Vector2(12,16),Vector2(2,9),Vector2(21,16),Vector2(10,14.1),Vector2(10,16.6)]:
			check("old_furniture_collision_cleared_%s_%d"%[at,layer],room.is_walkable(at,layer))
	check("tool_pickup_stays_at_original_coordinate",v.yard.tool_station!=null and room.State.TOOL==Vector2(5,13))
	room.player_layer=0;room.state.worlds[0]=0;room.player.teleport_for_reset(Vector2(5,9)*room.SCALE);room._rebuild_navigation()
	check("missing_corridor_still_prevents_tool_access",room.path_to(room.State.TOOL).is_empty())
	room.state.worlds[0]=3;room._rebuild_navigation()
	check("manifest_corridor_reaches_open_tool_station",not room.path_to(room.State.TOOL).is_empty())
	for at in [Vector2(2.45,14),Vector2(7.55,14),Vector2(5,16.38)]:
		check("low_visible_tool_boundary_remains_solid_%s"%at,not room.is_walkable(at,0))
		check("old_lower_house_wall_is_open_%s"%at,room.is_walkable(at,1))
	# Movement through the former decorative workshop is tested with the real mover.
	room.player_layer=1;room.view_layer=1;room.player.teleport_for_reset(Vector2(9,14)*room.SCALE);room._rebuild_navigation()
	check("newly_open_yard_has_real_navigation",room.walk_to(Vector2(12.8,15.2)))
	for i in range(700):
		await frames(1)
		if not room.player.is_navigating():break
	check("actor_walks_through_former_house_without_invisible_wall",room.player_plan().distance_to(Vector2(12.8,15.2))<.13)
	# Test actual camera rays against the entire relocated building groups, including
	# roofs, furniture and foundations. AABB tests are intentionally conservative.
	var points:Array[Vector2]=[room.State.TOOL,room.State.DROP,room.State.LIFT,room.State.CATCH_PLATE,room.State.SLUICE,room.State.BRIDGE,room.State.UPPER_ANCHOR,room.State.LOWER_ANCHOR,room.State.EXIT]
	for x in [1.0,6.0,12.0,18.0,23.0]:
		for z in [1.0,8.0,13.0,17.0]:points.append(Vector2(x,z))
	var ray_count:=0;var blocked_count:=0
	for layer in [0,1]:
		room.view_layer=layer;room.player_layer=layer
		for yaw in [-45.0,0.0,45.0]:
			v.angle=yaw;v.set_focus(Vector2(12,9));v.frame_to_ui=false;v.framing_height=room.State.HEIGHT if layer==0 else 0.0;v.torso_offset=0
			for zoom in [.55,1.0,1.6]:
				v.zoom=zoom;v.target_zoom=zoom;v._camera()
				var clear:=true
				for at in points:
					for height in [.65,1.65]:
						var target:Vector3=v.point(at,(room.State.HEIGHT if layer==0 else 0.0)+height)
						var origin:Vector3=v.camera.project_ray_origin(v.camera.unproject_position(target))
						for building in v.yard.buildings:
							for mesh in meshes(building.root):
								ray_count+=1
								if hits(mesh,origin,target):clear=false;blocked_count+=1
				check("peripheral_buildings_clear_projection_%d_%s_%s"%[layer,yaw,zoom],clear)
			v.zoom=.65;v.target_zoom=.65;v._camera();await frames(20)
			await capture(("upper" if layer==0 else "lower")+"-yaw-"+str(yaw))
	# Old scene saves retain state and legal same-floor positions.
	var original:Dictionary=room.snapshot();original.player=[10,15.2];original.player_layer=1
	var puzzle:String=JSON.stringify(original.state);room.restore(original)
	check("old_save_preserves_puzzle_and_safe_floor",JSON.stringify(room.state.snapshot())==puzzle and room.player_layer==1 and room.is_walkable(room.player_plan()))
	check("outer_scenery_is_unreachable",not room.is_walkable(Vector2(-9,13),1) and not room.is_walkable(Vector2(17,-6.5),0))
	var file:=FileAccess.open(directory.path_join("yard-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"ray_tests":ray_count,"blocked_rays":blocked_count,"native_render":DisplayServer.get_name()!="headless"},"  "))
	print("YARD_FINISHED checks=",checks.size()," failures=",failures," ray_tests=",ray_count," blocked=",blocked_count)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
