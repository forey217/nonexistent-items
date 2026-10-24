extends Node
## Native-render visual fixtures are distinct from the real complete-route regression.
var app:Node
var room:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0
var before:=false

func frames(n:int) -> void:
	for i in range(n):await get_tree().physics_frame

func seconds(n:float) -> void:await get_tree().create_timer(n).timeout

func until(condition:Callable,timeout:=6.0) -> bool:
	var limit:=Time.get_ticks_msec()+int(timeout*1000)
	while Time.get_ticks_msec()<limit:
		await frames(1)
		if condition.call():return true
	return false

func check(id:String,ok:bool) -> void:
	results.append({"test":id,"passed":ok});print("SCROLL_GATE_CHECK ",id," ",ok)
	if not ok:failures+=1;push_error("SCROLL_GATE_FAILED "+id)

func capture(id:String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(id+".png"))

func frame_gate(z:=1.0,a:=0.0) -> void:
	room.view_layer=0;room.view.auto_follow=false;room.view.frame_to_ui=true
	room.view.focus=room.State.EXIT;room.view.torso_offset=1.35;room.view.angle=a;room.view.zoom=z;room.view.target_zoom=z
	room.view.framing_height=room.State.HEIGHT;room.view._camera()

func run(flow:Node) -> void:
	app=flow
	var args:=OS.get_cmdline_user_args()
	before="--gate-before" in args
	for arg in args:
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("res://../showcase/checks/scroll-gate-v01/native")
	DirAccess.make_dir_recursive_absolute(directory)
	app.show_paper_mill();room=app.current;await frames(8)
	if "--gate-record" in args:
		await record_real_route();return
	room.communications.enabled=false;room.communications.stop();room.story_time=0;room.hud.subtitle_duration=0
	room.set_physics_process(false);room.player.teleport_for_reset((room.State.EXIT+Vector2(0,-1.0))*room.SCALE);room.player.controls_locked=true
	frame_gate();await frames(30)
	await capture("01-closed")
	if before:
		room.state.upper_anchored=true;room.state.lower_anchored=true;room.state.checkpoint=6;room.hud.refresh(0)
		await frames(100);await capture("03-open")
		await app.shutdown_audio();get_tree().quit();return
	var gate=room.view.portal
	check("fresh_gate_closed_without_aperture",not gate.opened and not gate.paper_surface.visible and not gate.floor_glow.visible)
	check("exit_is_same_upper_floor_position",gate.position==room.view.point(room.State.EXIT) and gate.get_parent()==room.view.roots[0])
	check("gate_uses_real_geometry_and_font",gate.find_children("*","MeshInstance3D",true,false).size()>=15 and gate.label.font!=null and gate.label.text.contains("归"))
	room.state.upper_anchored=true;await frames(6)
	await capture("02-single-anchor")
	check("single_anchor_lights_only_mountain",not gate.opened and gate.emblem_materials[0].albedo_color.r>gate.emblem_materials[1].albedo_color.r+.1)
	room.state.lower_anchored=true;room.state.checkpoint=6;room.hud.refresh(0)
	await frames(37);await capture("opening-060")
	check("paper_unrolls_from_fixed_roller",gate.animating and gate.bottom_bar.position.y<2.7 and gate.bottom_bar.position.y>.2)
	await frames(28);await capture("opening-110")
	await frames(45);await capture("03-open")
	check("dual_opens_once_and_settles",gate.ready_for_entry() and gate.openings==1 and is_equal_approx(gate.progress,1.0))
	check("paper_center_is_real_shader_aperture",gate.sheet_material.get_shader_parameter("opening")>.99 and not gate.sheet_material.shader.code.contains("SCREEN_TEXTURE"))
	check("clear_passage_does_not_change_navigation",room.is_walkable(room.State.EXIT) and room.segment_clear(room.State.EXIT+Vector2(0,-.9),room.State.EXIT))
	check("opening_audio_respects_sfx_pool",gate.audio_stages==2 and room.sound.voices.all(func(v):return v.bus=="SFX" and is_equal_approx(v.pitch_scale,1)))
	for zoom in [.55,1.0,1.6]:
		for angle in [-45.0,0.0,45.0]:
			frame_gate(zoom,angle);await frames(10)
			var top:Vector2=room.view.to_ui(room.view.camera.unproject_position(gate.to_global(Vector3(0,3.15,0))))
			var bottom:Vector2=room.view.to_ui(room.view.camera.unproject_position(gate.to_global(Vector3.ZERO)))
			check("door_fits_safe_height_z%.2f_a%d"%[zoom,angle],top.y>115 and bottom.y<710)
			check("render_input_roundtrip_z%.2f_a%d"%[zoom,angle],room.view.ground(room.view.screen(room.State.EXIT,0,0.0)).distance_to(room.State.EXIT)<.002)
			await capture("zoom-%.2f-angle-%d"%[zoom,angle])
	frame_gate();room.hud.menu.open();await frames(5)
	var age:float=gate.clock;await frames(12)
	check("pause_freezes_gate_clock",is_equal_approx(age,gate.clock))
	await capture("05-pause")
	room.hud.menu.options.open();await frames(12);await capture("06-settings")
	room.hud.menu.options.close();room.hud.menu.close();room.player.controls_locked=true
	var saved:Dictionary=room.snapshot()
	gate.baseline(room.State.new());room.restore(saved);room.set_physics_process(false);frame_gate();room.player.controls_locked=true;await frames(4)
	check("restore_open_has_no_replayed_animation",gate.ready_for_entry() and gate.openings==1 and gate.audio_stages==0)
	check("observe_other_layer_never_resets_door",gate.opened);room.observe(1);await frames(5);room.observe(0);frame_gate();await frames(5)
	check("return_to_upper_keeps_open",gate.opened and not gate.animating)
	room.state.upper_anchored=false;room.state.lower_anchored=false;gate.baseline(room.state)
	app.ambience.set_motion_enabled(false)
	room.state.upper_anchored=true;room.state.lower_anchored=true;await frames(16)
	check("reduced_motion_static_entry_under_quarter_second",gate.ready_for_entry() and gate.audio_stages==0 and gate.sheet_material.get_shader_parameter("still_time")==0.0)
	await capture("07-reduced-motion");app.ambience.set_motion_enabled(true)
	room.hud.record.show();room.hud.record_pinned=true;frame_gate();await frames(18);await capture("08-record-safe-framing")
	room.hud.record.hide();room.hud.record_pinned=false
	for dimensions in [Vector2i(1920,1080),Vector2i(960,600),Vector2i(1280,800)]:
		DisplayServer.window_set_size(dimensions);await frames(15);frame_gate();await frames(12)
		check("render_size_and_input_%dx%d"%[dimensions.x,dimensions.y],room.view.viewport.size.x>=dimensions.x and room.view.ground(room.view.screen(room.State.EXIT,0,0.0)).distance_to(room.State.EXIT)<.002)
		await capture("window-%dx%d"%[dimensions.x,dimensions.y])
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);await frames(20);frame_gate();await frames(12);await capture("09-fullscreen")
	check("fullscreen_has_valid_native_render",DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN and room.view.viewport.size.x>1280)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,800));await frames(20)
	frame_gate();await capture("10-final")
	# Exercise the real mover and room completion signal without replacing scene ownership.
	for connection in room.completed.get_connections():room.completed.disconnect(connection.callable)
	var completions:Dictionary={"count":0};room.completed.connect(func():completions.count+=1)
	room.state.upper_anchored=false;room.state.lower_anchored=false;room.state.checkpoint=0;gate.baseline(room.state)
	room.set_physics_process(true);room.player.controls_locked=false;room.player.teleport_for_reset((room.State.EXIT+Vector2(0,-1))*room.SCALE)
	room.view.return_to_actor();await frames(4)
	var start:Vector2=room.player_plan()
	Input.action_press("walk_down");await frames(24);Input.action_release("walk_down");await frames(12)
	check("keyboard_moves_without_premature_completion",room.player_plan().distance_to(start)>.35 and completions.count==0 and not room.finished)
	room.player.teleport_for_reset((room.State.EXIT+Vector2(0,-.8))*room.SCALE);room.view.return_to_actor();await frames(5)
	room.player.controls_locked=false
	var accepted:bool=room.walk_to(room.State.EXIT)
	await until(func():return not room.player.is_navigating())
	print("EXIT_ROUTE accepted=",accepted," position=",room.player_plan()," locked=",room.player.controls_locked)
	check("closed_exit_click_route_cannot_complete",room.player_plan().distance_to(room.State.EXIT)<.2 and completions.count==0)
	room.state.upper_anchored=true;room.state.lower_anchored=true;await frames(10)
	check("standing_at_exit_waits_for_unroll",completions.count==0 and gate.animating)
	await until(func():return room.finished)
	check("real_arrival_completes_once_after_unroll",room.finished and completions.count==1)
	await frames(12);check("completion_does_not_repeat",completions.count==1)
	var file:=FileAccess.open(directory.path_join("scroll-gate-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results,"failures":failures,"native":DisplayServer.get_name()!="headless","fixtures":"Gate visual states are staged; real completion is covered by paper-mill and complete-demo regressions."},"  "));file.close()
	print("SCROLL_GATE_REPORT ",results.size()," checks ",failures," failures")
	if "--gate-preview" in args:
		room.player.controls_locked=false;room.set_physics_process(true);room.view.return_to_actor();return
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)

func record_real_route() -> void:
	app.start_paper_demo()
	var demo:Node=app.paper_demo
	var begin_frame:int=Engine.get_frames_drawn();var gate_frame:=-1;var limit:=Time.get_ticks_msec()+240000
	while Time.get_ticks_msec()<limit and demo.mode not in ["done","error"]:
		await frames(1)
		if is_instance_valid(demo.room) and demo.room.state.lower_anchored and gate_frame<0:
			gate_frame=Engine.get_frames_drawn()-begin_frame;print("GATE_MOVIE_START_FRAME ",gate_frame)
			await capture("real-dual-anchor")
	check("movie_follows_real_complete_demo",demo.mode=="done")
	check("real_final_both_anchors",demo.mode=="done" and demo.final_state.upper_anchored and demo.final_state.lower_anchored)
	await frames(45);await capture("real-returned-bureau")
	var file:=FileAccess.open(directory.path_join("movie-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results,"failures":failures,"native":DisplayServer.get_name()!="headless","gate_frame":gate_frame,"begin_frame":begin_frame,"end_frame":Engine.get_frames_drawn(),"seconds":demo.finished_seconds,"history":demo.history},"  "));file.close()
	demo.stop();await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
