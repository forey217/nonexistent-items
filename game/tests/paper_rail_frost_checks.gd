extends Node
const S=preload("res://scripts/paper_mill_state.gd")
var app:Node
var room:Node
var directory:=""
var checks:Array[Dictionary]=[]
var failures:=0
var video_frame:=0

func frames(count:int) -> void:
	for i in range(count):await get_tree().process_frame

func check(label:String,passed:bool) -> void:
	checks.append({"test":label,"passed":passed});print("FROST ",label," ",passed)
	if not passed:failures+=1;push_error("FROST_FAILED "+label)
	var file:=FileAccess.open(directory.path_join("rail-frost-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks.size(),"failures":failures,"native":DisplayServer.get_name()!="headless","results":checks},"  "))

func shot(label:String) -> void:
	if DisplayServer.get_name()=="headless":return
	RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(true)
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
	room.view.viewport.get_texture().get_image().save_png(directory.path_join(label+"-world.png"))

func fixture(layer:=1) -> void:
	room.restore({"state":S.new().snapshot(),"player_layer":layer,"player":[8.5,12.8]})
	room.communications.stop();room.communications.enabled=false
	room.hud.entry_hint.offer();room.hud.entry_hint.dismiss();room.hud.message_time=0;room.hud.saved_time=0
	var v=room.view;v.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;v.paper_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	v.begin_manual_observation();v.frame_to_ui=false;v.safe_center=Vector2(640,400)
	v.framing_height=S.HEIGHT if layer==0 else 0.0;v.torso_offset=0.0
	v.focus=Vector2(10,10) if layer==1 else Vector2(18,11.8);v.angle=0;v.zoom=1.25;v.target_zoom=1.25;v._sync(0)

func mechanical_checks() -> void:
	var v=room.view;var frost=v.rail_frost
	fixture();v.set_process(false)
	check("fresh_entry_replays_both_initial_ice_layers",frost.starts[0]>=1 and frost.starts[1]>=1)
	check("small_bounded_mesh_pool",frost.batches.size()<=30 and frost.batches.size()>=12)
	check("skin_only_has_visual_leaves",frost.batches.all(func(item):return item.node is MeshInstance3D and item.node.get_child_count()==0))
	check("all_pooled_meshes_have_real_geometry",frost.batches.all(func(item):return item.node.mesh.get_surface_count()>0))
	var count:int=frost.batches.size();var snapshot:=JSON.stringify(room.state.snapshot())
	frost.baseline(room.state.worlds,true)
	for i in range(9):frost.sync(.05,room.state.worlds,true)
	check("growth_has_real_midpoint",frost.ages[1]>.4 and frost.ages[1]<.5)
	var stamp:float=frost.ages[1];frost.sync(0,room.state.worlds,true)
	check("pause_freezes_all_visual_clocks",frost.ages[1]==stamp)
	for i in range(20):frost.sync(.05,room.state.worlds,true)
	check("growth_finishes_with_static_ice",frost.ages[1]>=frost.DURATION+frost.TAIL-.001 and frost.strengths[1]==1)
	var starts:Array=frost.starts.duplicate()
	v.angle=45;v.zoom=.55;room.observe(0);frost.sync(.03,room.state.worlds,true)
	check("camera_and_observation_never_replay",frost.starts==starts)
	room.state.worlds[0]=1;frost.sync(.05,room.state.worlds,true)
	check("leaving_ice_fades_only_owner_floor",frost.strengths[0]<1 and frost.strengths[1]==1 and frost.starts==starts)
	for i in range(5):frost.sync(.05,room.state.worlds,true)
	check("leaving_ice_finishes_cleanly",frost.strengths[0]==0)
	room.state.worlds[0]=0;frost.sync(.01,room.state.worlds,true)
	check("returning_to_ice_replays_only_owner",frost.starts[0]==starts[0]+1 and frost.starts[1]==starts[1] and frost.ages[0]<.02)
	frost.sync(.01,room.state.worlds,false)
	check("reduced_motion_has_complete_frost_without_front",frost.ages[0]>=frost.DURATION+frost.TAIL)
	for layer in range(2):
		for rule in range(4):
			room.state.worlds[layer]=rule;frost.sync(.05,room.state.worlds,true)
			for i in range(25):frost.sync(.05,room.state.worlds,true)
			check("floor_%d_rule_%d_ice_only"%[layer,rule],frost.strengths[layer]==(1.0 if rule==0 else 0.0))
	fixture();v.set_process(false)
	var saved:Dictionary=room.snapshot();frost.baseline([0,0],true);room.restore(saved)
	check("load_restores_completed_frost",frost.ages[0]>1 and frost.ages[1]>1 and frost.worlds==[0,0])
	check("no_visual_state_added_to_save",JSON.stringify(saved)==JSON.stringify(room.snapshot()))
	check("visual_updates_do_not_step_simulation",snapshot==JSON.stringify(room.state.snapshot()))
	room.observe(0);v._sync(0)
	var bridge_skin:Node3D=null
	for item:Dictionary in frost.batches:
		if item.node.get_parent()==v.bridge and item.kind==0:bridge_skin=item.node
	check("bridge_skin_uses_actual_bridge_parent",bridge_skin!=null)
	room.state.clip_target="";room.state.worlds.assign([0,0]);v._sync(0)
	check("missing_bridge_cannot_leave_floating_frost",not bridge_skin.is_visible_in_tree())
	room.state.clip_target="bridge";v._sync(0)
	check("fixed_bridge_carries_its_frost",bridge_skin.is_visible_in_tree())
	check("film_hides_frost_in_all_non_ice_rules",[1,2,3].all(func(rule):return not v.film._visible(bridge_skin,rule)))
	room.world_cooldown=0;room.change_world(1,0);v._sync(.01)
	check("outgoing_film_keeps_its_ice_material",v.film.copies[0].any(func(item):return item.source==bridge_skin and item.old.material_override!=frost.materials[0][0]))
	check("outgoing_film_has_no_ice_in_new_rule",v.film._visible(bridge_skin,0) and not v.film._visible(bridge_skin,1))
	v.film.cancel();room.world_cooldown=0;room.change_world(0,0);v._sync(.01)
	check("incoming_film_uses_live_progress",v.film.copies[0].any(func(item):return item.source==bridge_skin and item.new.material_override==frost.materials[0][0]))
	v.film.cancel()
	for layer in range(2):
		room.state.lift_height=S.HEIGHT if layer==0 else 0.0;room.state.worlds.assign([0,0]);v._sync(0)
		check("lift_dock_%d_follows_real_floor"%layer,frost.lift_layer==layer and v.lift_rail_tongues.visible)
	room.state.lift_height=S.HEIGHT*.5;v._sync(0)
	check("lift_in_transit_has_neutral_rail_and_no_tongue",frost.lift_layer==-1 and not v.lift_rail_tongues.visible and frost.materials[2][0].get_shader_parameter("strength")==0.0)
	var delays:=0;var corners:=0
	for network in v.rail_networks:
		corners+=network.curves.size()
	for item:Dictionary in frost.batches:
		var colors:PackedColorArray=item.node.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		if Array(colors).any(func(color):return color.r>.3):delays+=1
	check("progress_baked_into_real_straights_and_curves",corners>8 and delays>=6)
	for i in range(60):
		room.state.worlds[0]=i%4;room.state.worlds[1]=(i+1)%4;frost.sync(.01,room.state.worlds,true)
	check("rapid_switch_reuses_entire_pool",frost.batches.size()==count)
	room.restart();v._sync(0)
	check("restart_replays_initial_frost",frost.ages[0]<.01 and frost.ages[1]<.01)
	v.set_process(true)

func presentation() -> void:
	fixture();var v=room.view;var frost=v.rail_frost;v.set_process(false)
	for layer in range(2):
		room.observe(layer);v.focus=Vector2(10,10) if layer==1 else Vector2(18,12);v.zoom=1.25;v.target_zoom=1.25
		room.state.clip_target="bridge";v._sync(0)
		frost.baseline([0,0]);frost.strengths.assign([0.0,0.0]);frost._publish();await frames(3);await shot("floor-%d-before"%layer)
		frost.baseline([0,0],true)
		for step in [0.0,.22,.5,.92,1.2]:
			frost.ages[layer]=step;frost._publish();await frames(2);await shot("floor-%d-frost-%.2f"%[layer,step])
		for yaw in [-45.0,0.0,45.0]:
			for zoom in [.55,1.0,1.6]:
				v.angle=yaw;v.zoom=zoom;v.target_zoom=zoom;v._sync(0);await frames(2)
				await shot("floor-%d-yaw-%d-zoom-%.2f"%[layer,yaw,zoom])
	v.set_process(true)

func capture_frame() -> void:
	RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(true)
	get_viewport().get_texture().get_image().save_jpg(directory.path_join("frame-%04d.jpg"%video_frame),.94)
	video_frame+=1

func video() -> void:
	fixture();room.set_physics_process(false);var v=room.view;v.set_process(false)
	room.state.clip_target="bridge";room.state.worlds.assign([1,1]);v.rail_frost.baseline([1,1]);v._sync(0)
	for layer in [1,0]:
		room.observe(layer);v.focus=Vector2(10,10) if layer==1 else Vector2(18,12)
		v.framing_height=S.HEIGHT if layer==0 else 0.0;v.torso_offset=0.0
		v.zoom=1.3;v.target_zoom=1.3;v.angle=0;v._sync(0)
		room.hud.refresh(0)
		for i in range(24):capture_frame();await frames(1)
		room.world_cooldown=0;room.change_world(0,layer)
		room.hud.refresh(0)
		for i in range(66):v._sync(1.0/30.0);capture_frame();await frames(1)
		room.world_cooldown=0;room.change_world(1,layer)
		room.hud.refresh(0)
		for i in range(30):v._sync(1.0/30.0);capture_frame();await frames(1)

func run(flow:Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	app.show_paper_mill();await frames(5);room=app.current
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	if "--rail-frost-video-check" in OS.get_cmdline_user_args():await video()
	else:
		await mechanical_checks()
		await presentation()
	print("FROST_REPORT checks=",checks.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
