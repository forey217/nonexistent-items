extends Node
## Real movement, collision sweeps, native rendering and both automatic flights.
var app:Node
var room:Node
var view:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0
var samples:Array[Dictionary]=[]

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func check(label:String,passed:bool) -> void:
	results.append({"test":label,"passed":passed});print("GUARD_CHECK ",label," ",passed)
	if not passed:failures+=1;push_error("GUARD_FAILED "+label)
	var file:=FileAccess.open(directory.path_join("guardrail-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results,"failures":failures,"native_render":DisplayServer.get_name()!="headless","samples":samples},"  "))

func until(condition:Callable,limit:=900) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func shot(label:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func place(at:Vector2,layer:=0) -> void:
	var saved:Dictionary=room.snapshot();saved.player_layer=layer;saved.player=[at.x,at.y]
	room.restore(saved);room.hud.record.hide();room.hud.destination_panel.hide();room.hud.message_time=0;room.story_time=0
	await frames(35)

func key(code:int,pressed:bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)

func walk_keys(direction:Vector2,count:int,arrows:=false) -> void:
	var mapping:Array=[KEY_RIGHT,KEY_LEFT,KEY_DOWN,KEY_UP] if arrows else [KEY_D,KEY_A,KEY_S,KEY_W]
	var screen:Vector2=room.player.input_basis.basis_xform_inv(direction)
	var pressed:Array[int]=[]
	if absf(screen.x)>.2:pressed.append(mapping[0 if screen.x>0 else 1])
	if absf(screen.y)>.2:pressed.append(mapping[2 if screen.y>0 else 3])
	for code in pressed:key(code,true)
	await frames(count)
	for code in pressed:key(code,false)
	await frames(3)

func click(at:Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;get_viewport().push_input(event,true)

func run(flow:Node) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://guardrail-check")
	DirAccess.make_dir_recursive_absolute(directory)
	app=flow;await frames(8);room=app.current;view=room.view
	check("five_supported_guard_sections",view.stair_guards.size()==5)
	check("both_floors_have_real_2D_collision",room.stair_bodies.size()==2 and room.stair_bodies.all(func(body):return body.get_child_count()>0))
	var transforms:Array=[]
	for section in view.stair_guards:transforms.append(section.root.global_transform)
	for world in range(4):
		room.state.switch_world(0,world);room.state.switch_world(1,world);await frames(3)
		check("fixed_boundary_in_world_%d"%world,not room.is_walkable(Vector2(4.7,5.5),0) and not room.is_walkable(Vector2(2.3,5.5),0) and not room.is_walkable(Vector2(3.5,2.9),0) and room.is_walkable(room.stairs_position(0),0) and room.is_walkable(room.stairs_position(1),1))
		var unchanged:=true
		for i in range(view.stair_guards.size()):unchanged=unchanged and view.stair_guards[i].root.global_transform==transforms[i]
		check("world_switch_keeps_geometry_%d"%world,unchanged)
	room.state.switch_world(0,0);room.state.switch_world(1,0)
	for item in [[Vector2(5.3,5.8),Vector2.LEFT,"right"],[Vector2(1.7,5.8),Vector2.RIGHT,"left"],[Vector2(3.5,2.0),Vector2.DOWN,"far"]]:
		await place(item[0]);view.angle=45;await frames(4);await walk_keys(item[1],45)
		check("keyboard_stops_before_"+item[2]+"_guard",room.player_layer==0 and not room.arrival_busy() and room.is_walkable(room.player_plan()) and room.player_plan().distance_to(item[0])<.65)
		var start:Vector2=item[0];var swept:Vector2=start+room.guard_motion(start*room.SCALE,item[1]*4*room.SCALE)/room.SCALE
		check("continuous_sweep_blocks_"+item[2]+"_guard",room.is_walkable(swept) and swept.distance_to(start)<.65)
	await place(Vector2(5.4,6.8));view.angle=0;view.zoom=1;view.target_zoom=1;await frames(20)
	check("opening_is_not_a_destination",not room.walk_to(Vector2(3.5,5.5)))
	var destination:=Vector2(1.7,6.8);var route:PackedVector2Array=room.path_to(destination)
	check("opposite_side_has_a_real_route",not route.is_empty())
	click(view.screen(destination,0,0))
	var reached:bool=await until(func():return not room.player.is_navigating() and not room.player.walking)
	check("click_routes_around_guard_without_entering_stairs",reached and room.player_layer==0 and room.player_plan().distance_to(destination)<.12 and not room.arrival_busy())
	await shot("01-route-around-opening")
	# Restoring a formerly legal edge position stays on its original floor.
	for layer in [0,1]:
		await place(Vector2(4.6,8.55) if layer==0 else Vector2(4.35,2.5),layer)
		check("old_edge_save_recovers_legally_%d"%layer,room.player_layer==layer and room.is_walkable(room.player_plan()) and not room.arrival_busy())
	# Physical shape query is independent of the pathfinding guard.
	await place(Vector2(5.3,5.5));await frames(5)
	var query:=PhysicsRayQueryParameters3D.create(Vector3(5.3,5.79,5.5),Vector3(4.0,5.79,5.5),32)
	check("real_3D_guard_collider_blocks_ray",not view.viewport.find_world_3d().direct_space_state.intersect_ray(query).is_empty())
	# Render matrix retains all supported sections and accurate ground picking.
	for layer in [0,1]:
		await place(Vector2(5.5,8.9) if layer==0 else Vector2(4.9,1.8),layer)
		for magnitude in [1.0,1.3,1.6]:
			for yaw in [-45.0,0.0,45.0]:
				view.zoom=magnitude;view.target_zoom=magnitude;view.angle=yaw;view.set_focus(Vector2(3.5,5.8) if layer==0 else Vector2(3.5,3.4));await frames(14)
				check("render_and_pick_%d_%.1f_%d"%[layer,magnitude,yaw],view.ground(view.screen(Vector2(5.2,8.8),layer,0),layer).distance_to(Vector2(5.2,8.8))<.005 and view.stair_guards[3].root.visible and (view.stair_guards[0].root.visible==(layer==0)))
				await shot("02-guards-floor-%d-zoom-%.1f-angle-%d"%[layer,magnitude,yaw])
	# Near-side occlusion fades only visible geometry; solid boundaries stay active.
	var faded:=false;var alpha_visible:=false
	for yaw in [-45.0,0.0,45.0]:
		await place(Vector2(2.02,5.6));view.angle=yaw;view.return_to_actor();await frames(25)
		for section in view.stair_guards:
			faded=faded or section.fade>.1
			for mesh in section.meshes:alpha_visible=alpha_visible or mesh.material_override.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and mesh.material_override.albedo_color.a<.9
	check("near_side_rail_can_fade_without_changing_collision",faded and alpha_visible and not room.is_walkable(Vector2(2.4,5.6),0))
	await shot("03-near-rail-occlusion")
	for layer in [0,1]:
		# Keyboard and clicked approaches share the actual automatic entrance.
		for method in ["keyboard","click"]:
			var label:="%d_%s"%[layer,method];var yaw:=-45.0 if method=="keyboard" else 45.0
			await place(room.stairs_position(layer)+Vector2(0,.95 if layer==0 else -1.0),layer);view.angle=yaw;view.zoom=1.6;view.target_zoom=1.6;await frames(5)
			if method=="keyboard":await walk_keys(Vector2.UP if layer==0 else Vector2.DOWN,15,layer==1)
			else:click(view.screen(room.stairs_position(layer),layer,0))
			var entered:bool=await until(func():return room.transition_age>0,180)
			check("real_entrance_accepts_"+label,entered)
			var visible:=true;var cutaway:=true;var captured:=false
			if entered:
				while room.transition_age>0:
					await frames(1)
					if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
					var pixel:Vector2=view.to_ui(view.camera.unproject_position(view.actor.position+Vector3.UP*.9))
					visible=visible and Rect2(Vector2.ZERO,view.logical_size).has_point(pixel)
					if room.transition_age>0:cutaway=cutaway and not view.stair_floor.visible
					if room.transition_age>0:cutaway=cutaway and room.stair_bodies.all(func(body):return body.collision_layer==0)
					if room.transition_age<1.1 and not captured:captured=true;await shot("04-stairs-from-%d-%s"%[layer,method])
			check("flight_lands_and_keeps_body_visible_"+label,entered and room.player_layer==1-layer and visible and cutaway and view.zoom==1.6 and view.angle==yaw)
			check("leave_arrival_platform_"+label,room.walk_to(room.stairs_position(1-layer)+Vector2(0,.95 if 1-layer==0 else -1.0)))
			await until(func():return not room.player.is_navigating())
			check("arrival_platform_does_not_trap_or_reverse_"+label,room.player_layer==1-layer and room.is_walkable(room.player_plan()) and not room.arrival_busy())
	print("GUARD_FINISHED checks=",results.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
