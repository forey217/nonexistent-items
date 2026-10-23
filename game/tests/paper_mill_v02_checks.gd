extends Node
var app:Node
var room:Node
var directory:=""
var results:Array[Dictionary]=[]
var samples:Array[Dictionary]=[]
var failures:=0

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition:Callable,limit:=900) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func check(title:String,passed:bool) -> void:
	results.append({"test":title,"passed":passed});print("MILL_V02 ",title," ",passed)
	if not passed:failures+=1;push_error("MILL_V02_FAILED "+title)
	var f:=FileAccess.open(directory.path_join("v02-report.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":results,"failures":failures,"samples":samples,"native_render":DisplayServer.get_name()!="headless"},"  "))
	if not passed:get_tree().quit(1)

func click(at:Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;get_viewport().push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=pressed
		get_viewport().push_input(event,true)

func key(code:int,pressed:bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
	Input.parse_input_event(event)

func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func landing(layer:int) -> void:
	var saved:Dictionary=room.snapshot();saved.player_layer=layer
	var at:Vector2=room.stairs_position(layer)+Vector2(0,.98 if layer==0 else -1.3)
	saved.player=[at.x,at.y];room.restore(saved);await frames(5)

func run(flow:Node) -> void:
	app=flow;room=app.current
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://mill-v02-check")
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(20);room.story_time=0
	var ui=room.hud;var view=room.view
	check("default_panels_are_collapsed",not ui.record.visible and not ui.menu.visible and not ui.help_panel.visible and not ui.destination_panel.visible)
	var logical:Vector2=get_viewport().get_visible_rect().size
	var area:float=ui.worlds.size.x*ui.worlds.size.y+ui.badges.size.x*ui.badges.size.y+ui.objective.size.x*ui.objective.size.y+ui.bag.size.x*40+ui.tools.size.x*40+72*40
	check("persistent_panels_below_fifteen_percent",area/(logical.x*logical.y)<.15)
	check("no_legacy_white_audio_or_title_button",not app.return_menu_button.visible and not app.ambience.toggle_button.visible)
	ui.toggle_record();await frames(60)
	check("record_provides_stage_hint",ui.record.visible and ui.hint.text.contains("线索"))
	var actor_screen:Vector2=view.screen(room.player_plan(),room.player_layer,1.0)
	check("record_camera_keeps_actor_in_safe_region",ui.safe_rect().has_point(actor_screen))
	await shot("01-record-safe-framing");ui.toggle_record();await frames(30)
	var zoom:float=view.target_zoom
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;wheel.position=ui.worlds.position+Vector2(40,20)
	get_viewport().push_input(wheel,true);await frames(4)
	check("world_bar_blocks_map_scroll",view.target_zoom==zoom)
	ui.toggle_menu();var clock:float=room.state.clock;var actor:Vector2=room.player_plan();await frames(30)
	check("pause_stops_mechanisms_and_player",is_equal_approx(room.state.clock,clock) and room.player_plan()==actor)
	check("four_audio_channels_available",ui.channel_sliders.size()==4)
	check("pause_hides_subtitle_and_toast",not ui.subtitle_panel.visible and not ui.footer.visible)
	await shot("02-options");ui.toggle_menu()
	# Physical keyboard input approaches the actual trigger; no interaction API is used.
	await landing(0);view.angle=45;await frames(3)
	var desired:=Vector2(0,-1);var best_dot:=-2.0;var direction_key:=KEY_D
	for item in [[KEY_D,Vector2.RIGHT],[KEY_A,Vector2.LEFT],[KEY_S,Vector2.DOWN],[KEY_W,Vector2.UP]]:
		var motion:Vector2=room.player.input_basis.basis_xform(item[1]);var dot:=motion.normalized().dot(desired)
		if dot>best_dot:best_dot=dot;direction_key=item[0]
	key(direction_key,true)
	var entered:bool=await until(func():return room.transition_age>0,180)
	if not entered:print("STAIR_DEBUG key=",direction_key," position=",room.player_plan()," input=",Input.get_vector("walk_left","walk_right","walk_up","walk_down")," basis=",room.player.input_basis," locked=",room.player.controls_locked," armed=",room.stairs_armed)
	key(direction_key,false);check("keyboard_walk_starts_stairs",entered)
	var stable:Dictionary=room.stable_snapshot()
	check("stair_transition_does_not_save_midway",int(stable.player_layer)==0)
	await frames(55)
	await shot("03-continuous-stairs")
	check("keyboard_stairs_reach_lower_floor",await until(func():return room.player_layer==1 and not room.arrival_busy(),240))
	await frames(150)
	check("standing_at_exit_never_bounces_back",room.player_layer==1 and not room.arrival_busy() and not room.stairs_armed)
	var edge:Dictionary=room.snapshot();edge.player=[room.State.LOWER_STAIRS.x,room.State.LOWER_STAIRS.y];room.restore(edge);await frames(120)
	check("restore_on_landing_waits_for_new_entry",room.player_layer==1 and not room.arrival_busy())
	check("leave_exit_is_walkable",room.walk_to(room.State.LOWER_STAIRS+Vector2(0,-1.3)))
	await until(func():return not room.player.is_navigating());await frames(3)
	var at:Vector2=view.screen(room.State.LOWER_STAIRS,1,0)
	click(at)
	var ascended:bool=await until(func():return room.player_layer==0 and not room.arrival_busy())
	if not ascended:print("CLICK_DEBUG screen=",at," position=",room.player_plan()," armed=",room.stairs_armed," menu=",ui.menu.visible," shade=",ui.menu_shade.visible," hovered=",get_viewport().gui_get_hovered_control())
	check("left_click_stairs_ascends",ascended)
	check("right_click_no_longer_controls_stairs",not room.request_interaction("stairs"))
	room.observe(1);await frames(30)
	check("observation_only_never_triggers_stairs",room.player_layer==0 and not room.arrival_busy());room.observe(0)
	room.restart();room.story_time=0;ui.message_time=0
	# Keep comparisons deterministic: same scene, focal point and angle at every size.
	for window_size in [Vector2i(1280,800),Vector2i(1920,1080),Vector2i(2560,1440)]:
		if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(window_size)
		await frames(45);view.set_focus(Vector2(12,9));view.frame_to_ui=false;view.safe_center=get_viewport().get_visible_rect().size*.5
		view.angle=0;view.zoom=.7;view.target_zoom=.7
		await frames(20)
		var size:Vector2=get_viewport().get_visible_rect().size
		var scale:Vector2=get_viewport().get_screen_transform().get_scale().abs()
		var pixels:Vector2=Vector2(view.viewport.size)
		samples.append({"requested_window":[window_size.x,window_size.y],"actual_window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"logical":[size.x,size.y],"screen_scale":[scale.x,scale.y],"render_pixels":[pixels.x,pixels.y],"fps":Engine.get_frames_per_second()})
		check("native_resolution_%s"%window_size,pixels.x>=size.x*scale.x-.5 and pixels.y>=size.y*scale.y-.5)
		var resizes:int=view.resize_count;await frames(6);check("render_target_not_reallocated_each_frame_%s"%window_size,view.resize_count==resizes)
		await shot("04-upper-wide-%dx%d"%[window_size.x,window_size.y])
		for pair in [[.55,-45.0],[1.0,0.0],[1.6,45.0]]:
			view.zoom=pair[0];view.target_zoom=pair[0];view.angle=pair[1];await frames(8)
			var p:=Vector2(8,6);check("projection_%s_%s"%[window_size,pair],view.ground(view.screen(p,0,0),0).distance_to(p)<.005)
			await shot("05-zoom-%dx%d-%.2f-%d"%[window_size.x,window_size.y,pair[0],pair[1]])
		room.observe(1);view.set_focus(Vector2(13,8));view.zoom=1;view.target_zoom=1;view.angle=0;room.story_time=0;await frames(25)
		await shot("06-lower-unobstructed-%dx%d"%[window_size.x,window_size.y]);room.observe(0)
		view.return_to_actor();await frames(30)
		var destination:Vector2=room.player_plan()+Vector2(1.2,0)
		click(view.screen(destination,0,0))
		check("resized_window_real_click_%s"%window_size,await until(func():return room.player_plan().distance_to(destination)<.12))
		room.restart();room.story_time=0;ui.message_time=0
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);await frames(60)
		check("fullscreen_keeps_projection",view.ground(view.screen(Vector2(8,6),0,0),0).distance_to(Vector2(8,6))<.005)
		await shot("07-fullscreen")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);await frames(15)
	print("MILL_V02_FINISHED checks=",results.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
