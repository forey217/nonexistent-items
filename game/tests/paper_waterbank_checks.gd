extends Node
var app:Node
var room:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0
var baseline:=false

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func check(label:String,passed:bool) -> void:
	results.append({"test":label,"passed":passed});print("WATERBANK_CHECK ",label," ",passed)
	if not passed:failures+=1;push_error("WATERBANK_FAILED "+label)
	var f:=FileAccess.open(directory.path_join("waterbank-report.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":results,"failures":failures,"native_render":DisplayServer.get_name()!="headless"},"\t"))

func shot(label:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func pose(at:Vector2,layer:int,actor:Vector2,yaw:=0.0,zoom:=1.6) -> void:
	room.player.cancel_navigation();room.player_layer=layer;room.view_layer=layer;room.player.teleport_for_reset(actor*room.SCALE)
	room.view.film.cancel();room.view.link_time=0;room.world_cast_time=0;room.story_time=0;room.hud.message_time=0
	room.hud.record.hide();room.hud.destination_panel.hide();room.hud.hover_target=""
	room.view.set_focus(at);room.view.auto_follow=false;room.view.frame_to_ui=false;room.view.safe_center=Vector2(640,420)
	room.view.angle=yaw;room.view.zoom=zoom;room.view.target_zoom=zoom
	await frames(14)

func navigation_audit() -> void:
	var audit:Array=[]
	for layer in [0,1]:
		for law in range(4):
			room.state.worlds[0]=law;room.state.worlds[1]=law;room.state.clip_target="";room.state.upper_anchored=false;room.state.lowpass_open=true
			var cells:=PackedByteArray()
			for y in range(73):
				for x in range(97):cells.append(1 if room.is_walkable(Vector2(x,y)*.25,layer,true) else 0)
			audit.append({"layer":layer,"law":law,"walkable_cells":cells.count(1),"sha256":cells.hex_encode().sha256_text()})
	var f:=FileAccess.open(directory.path_join("navigation-audit.json"),FileAccess.WRITE);f.store_string(JSON.stringify(audit,"\t"))

func visual_checks() -> void:
	room.state.lowpass_open=true;room.state.cage_open=true;room.state.clip_target="bridge"
	for layer in [0,1]:
		room.state.worlds[0]=0;room.state.worlds[1]=0
		await pose(Vector2(17,11.5),layer,Vector2(16.2,10.2));await shot("main-banks-%d"%layer)
		await pose(Vector2(5,11),layer,Vector2(6,9.2));await shot("west-banks-%d"%layer)
		room.state.worlds[0]=3;room.state.worlds[1]=3;await pose(Vector2(5,11),layer,Vector2(6,9.2));await shot("west-revealed-%d"%layer)
		for law in range(4):
			room.state.worlds[0]=law;room.state.worlds[1]=law;room.state.clip_target=""
			for yaw in [-45.0,0.0,45.0]:
				for zoom in [.55,1.0,1.6]:
					await pose(Vector2(12,11),layer,Vector2(16,10.1),yaw,zoom)
					await shot("layer-%d-law-%d-yaw-%d-zoom-%.2f"%[layer,law,yaw,zoom])

func walk_keys(direction:Vector2,count:int) -> void:
	var input_direction:Vector2=room.player.input_basis.basis_xform_inv(direction)
	var actions:Array[String]=[]
	if absf(input_direction.x)>.2:actions.append("walk_right" if input_direction.x>0 else "walk_left")
	if absf(input_direction.y)>.2:actions.append("walk_down" if input_direction.y>0 else "walk_up")
	for action:String in actions:Input.action_press(action)
	await frames(count)
	for action:String in actions:Input.action_release(action)
	await frames(10)

func functional_checks() -> void:
	var guards=room.view.waterbank_guards
	check("both_layers_have_supported_guard_sections",guards.sections.size()==32)
	check("no_new_2d_collisions",guards.sections.all(func(item):return item.root.find_children("*","CollisionObject2D",true,false).is_empty()))
	check("ray_bodies_cannot_block_gameplay",guards.sections.all(func(item):return item.body.collision_layer==64 and item.body.collision_mask==0))
	check("not_added_to_eastern_walkable_water",guards.sections.all(func(item):return maxf(item.a.x,item.b.x)<22.0))
	check("bridge_rails_inherit_actual_deck",guards.sections.filter(func(item):return item.layer==0 and item.kind.ends_with("bridge_side")).all(func(item):return item.deck in [room.view.bridge,room.view.side_bridge] and item.root.get_parent()==item.deck))
	for layer in [0,1]:
		for law in range(4):
			room.state.worlds[0]=law;room.state.worlds[1]=law;room.state.clip_target="";room.state.upper_anchored=false;room.view._sync(0)
			for kind in ["main_bridge_side","west_bridge_side"]:
				var expected:bool=layer==1 or law==3
				check("bridge_side_visibility_%d_%d_%s"%[layer,law,kind],guards.sections.filter(func(item):return item.layer==layer and item.kind==kind).all(func(item):return item.root.is_visible_in_tree()==(expected and room.view_layer==layer)))
			await pose(Vector2(15.4,10.8),layer,Vector2(15.4,10.0));await walk_keys(Vector2.DOWN,40)
			check("keyboard_stops_at_main_bank_%d_%d"%[layer,law],room.player_plan().y>10.7 and room.player_plan().y<=10.81)
			await pose(Vector2(5,11),layer,Vector2(3.8,9.25));await walk_keys(Vector2.DOWN,38)
			var limit:=9.77 if layer==0 else 9.81
			check("keyboard_stops_at_west_bank_%d_%d"%[layer,law],room.player_plan().y<limit and room.player_plan().y>9.5)
			check("bank_click_destination_stays_unreachable_%d_%d"%[layer,law],not room.walk_to(Vector2(15.4,11.5)))
	room.state.worlds[0]=3;room.state.worlds[1]=3;room.state.clip_target="bridge"
	for layer in [0,1]:
		await pose(Vector2(5,11),layer,Vector2(5,9.2));await walk_keys(Vector2.DOWN,60)
		check("real_west_bridge_mouth_stays_open_%d"%layer,room.player_plan().y>(12.25 if layer==0 else 11.25))
		await pose(Vector2(18,11.5),layer,Vector2(18,10.0));await walk_keys(Vector2.DOWN,60)
		check("real_main_bridge_mouth_stays_open_%d"%layer,room.player_plan().y>12.5)
	# The native film must include guards from their real parent, not permanently
	# leave hidden upper bridge rails in the old/new environment copy.
	room.state.worlds[0]=0;room.state.worlds[1]=0;room.state.clip_target="";await pose(Vector2(5,11),0,Vector2(6,9.2))
	room.view.film.begin(0,0,3);room.view.film.sync(0)
	var pairs=room.view.film.copies[0].filter(func(item):return guards.sections.any(func(section):return section.kind=="west_bridge_side" and section.layer==0 and section.meshes.has(item.source)))
	check("world_film_carries_dynamic_bank_sides",pairs.size()>0 and pairs.all(func(item):return not item.old.visible and item.new.visible))
	await shot("film-bridge-side-appears");room.view.film.cancel()
	var snapshot:Dictionary=room.state.snapshot();guards.sync(.016)
	check("fading_does_not_change_simulation",snapshot==room.state.snapshot())
	# Seek an actual native occlusion and ensure the fade is local and reversible.
	var faded:=false
	for yaw in [-45.0,0.0,45.0]:
		await pose(Vector2(16,11.5),0,Vector2(16,10.65),yaw);await frames(20)
		if guards.sections.any(func(item):return item.fade>.15):faded=true;await shot("foreground-fades-%d"%yaw)
	check("foreground_guard_fades_for_actor",faded)

func run(flow:Node) -> void:
	app=flow;app.show_paper_mill();await frames(20);room=app.current
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	baseline="--waterbank-baseline" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(directory)
	room.communications.stop();room.communications.enabled=false;room.hud.entry_hint.offer();room.hud.entry_hint.dismiss()
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	navigation_audit();await visual_checks()
	if not baseline:await functional_checks()
	print("WATERBANK_FINISHED checks=",results.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
