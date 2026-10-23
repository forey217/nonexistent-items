extends Node
## Uses real input, navigation and stair triggers; no rendered actor teleporting.
var app:Node
var room:Node
var view:Node
var directory:=""
var results:Array[Dictionary]=[]
var samples:Array[Dictionary]=[]
var failures:=0
var maximum_error:=0.0
var all_visible:=true
var started:=0

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func check(label:String,passed:bool) -> void:
	results.append({"test":label,"passed":passed});print("CAMERA_CHECK ",label," ",passed)
	if not passed:failures+=1;push_error("CAMERA_FAILED "+label)
	var file:=FileAccess.open(directory.path_join("camera-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results,"failures":failures,"native_render":DisplayServer.get_name()!="headless","samples":samples,"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0},"  "))
	if not passed:get_tree().quit(1)

func key(code:int,pressed:bool) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e)

func button(at:Vector2,index:int,pressed:bool,alt:=false) -> void:
	var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=index;e.pressed=pressed;e.alt_pressed=alt
	get_viewport().push_input(e,true)

func click(at:Vector2) -> void:
	button(at,MOUSE_BUTTON_LEFT,true);button(at,MOUSE_BUTTON_LEFT,false)

func drag(index:int,offset:Vector2,alt:=false) -> void:
	var at:=Vector2(680,340);button(at,index,true,alt)
	var motion:=InputEventMouseMotion.new();motion.position=at+offset;motion.relative=offset;get_viewport().push_input(motion,true)
	button(at+offset,index,false,alt)

func torso() -> Vector2:
	return view.to_ui(view.camera.unproject_position(view.point(room.player_plan(),room.actor_height()+view.TORSO_HEIGHT)))

func sample() -> void:
	var at:=torso();maximum_error=maxf(maximum_error,at.distance_to(view.safe_center))
	all_visible=all_visible and Rect2(Vector2(24,65),view.logical_size-Vector2(48,165)).has_point(at)

func shot(label:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func setup(layer:int,magnification:float,yaw:float,at:=Vector2(8,5)) -> void:
	var data:Dictionary=room.snapshot();data.player_layer=layer;data.player=[at.x,at.y]
	room.restore(data);room.story_time=0;room.hud.message_time=0;room.hud.record.hide();room.hud.destination_panel.hide()
	view.zoom=magnification;view.target_zoom=magnification;view.angle=yaw
	await frames(45);maximum_error=0;all_visible=true

func navigation_finished(limit:=900) -> bool:
	for i in range(limit):
		await frames(1);sample()
		if not room.player.is_navigating() and not room.player.walking:return true
	return false

func pickup_checks() -> void:
	var previous_mouse:Vector2=get_viewport().get_mouse_position()
	for yaw in [-45.0,0.0,45.0]:
		room.restart();await setup(0,1.6,yaw,Vector2(5,11.7))
		room.change_world(3,0);room.story_time=0;await frames(35)
		var pointer:Vector2=view.screen(room.State.TOOL,0,.5)
		var motion:=InputEventMouseMotion.new();motion.position=get_viewport().get_final_transform()*pointer;motion.global_position=get_viewport().get_screen_transform()*pointer;Input.parse_input_event(motion)
		# Native windows poll the OS cursor again between frames. Exercise the
		# actual hover there, then return the pointer after this short section.
		if DisplayServer.get_name()!="headless":get_viewport().warp_mouse(pointer)
		await frames(3)
		print("HOVER_SAMPLE pointer=",pointer," viewport_mouse=",get_viewport().get_mouse_position()," hit=",room.hit_target(pointer)," highlight=",view.highlight.visible," target=",view.highlight.position)
		check("real_hover_at_zoom_%d"%yaw,room.hit_target(pointer)=="tool" and view.highlight.visible and Vector2(view.highlight.position.x,view.highlight.position.z).distance_to(room.State.TOOL)<.01)
		button(pointer,MOUSE_BUTTON_RIGHT,true);button(pointer,MOUSE_BUTTON_RIGHT,false)
		await frames(45)
		check("real_pickup_at_zoom_%d"%yaw,room.state.clip_owned and view.auto_follow and view.target_zoom==1.6 and view.angle==yaw)
		if yaw==0:await shot("04-tool-pickup-zoom-1.6")
	if DisplayServer.get_name()!="headless":get_viewport().warp_mouse(previous_mouse)

func stair_checks() -> void:
	for layer in [0,1]:
		await setup(layer,1.6,-45,room.stairs_position(layer)+Vector2(1.1,0))
		room.walk_to(room.stairs_position(layer))
		var entered:=false;var cutaway:=true;maximum_error=0;all_visible=true
		var previous:Vector3=view.camera.position;var maximum_step:=0.0;var maximum_normal_step:=0.0;var captured:=false
		var previous_tick:=Time.get_ticks_usec();var delayed_frames:=0
		for i in range(300):
			await frames(1)
			# Read presented geometry after _process has synchronized this physics
			# step, rather than inspecting the previous render during a new flight.
			if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
			var tick:=Time.get_ticks_usec();var interval:float=(tick-previous_tick)/1000000.0;previous_tick=tick
			var step:float=previous.distance_to(view.camera.position)
			sample();maximum_step=maxf(maximum_step,step);previous=view.camera.position
			# PNG encoding deliberately blocks this main thread. Account for that
			# elapsed time instead of treating several simulated ticks as one frame.
			if DisplayServer.get_name()=="headless" or interval<.075:maximum_normal_step=maxf(maximum_normal_step,step)
			else:delayed_frames+=1
			if room.transition_age>0:
				entered=true;cutaway=cutaway and not view.stair_floor.visible
				if room.transition_age<1 and not captured:captured=true;await shot("03-stairs-from-%d"%layer)
			if entered and room.transition_age<=0:break
		samples.append({"kind":"stairs","layer":layer,"entered":entered,"landed":room.player_layer==1-layer,"all_visible":all_visible,"cutaway":cutaway,"maximum_camera_world_step":maximum_step,"maximum_normal_step":maximum_normal_step,"delayed_frames":delayed_frames,"maximum_error_pixels":maximum_error})
		check("continuous_stairs_%d"%layer,entered and room.player_layer==1-layer and all_visible and cutaway and maximum_normal_step<.9 and maximum_error<75 and view.target_zoom==1.6 and view.angle==-45)
		await frames(70)
		check("stair_landing_centered_%d"%layer,torso().distance_to(view.safe_center)<1 and view.auto_follow)

func run(flow:Node) -> void:
	app=flow;room=app.current;view=room.view;started=Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://camera-check")
	DirAccess.make_dir_recursive_absolute(directory);await frames(20)
	if "--camera-pick-only" in OS.get_cmdline_user_args():
		await pickup_checks();await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1);return
	if "--camera-stairs-only" in OS.get_cmdline_user_args():
		await stair_checks();await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1);return
	for layer in [0,1]:
		for magnification in [1.0,1.3,1.6]:
			for yaw in [-45.0,0.0,45.0]:
				await setup(layer,magnification,yaw)
				# Stationary zoom creates exactly the former failure state.
				view.zoom_at(Vector2(950,250),1.0);await frames(45)
				for code in [KEY_D,KEY_DOWN,KEY_LEFT,KEY_W]:
					key(code,true)
					for i in range(28):
						await frames(1);sample()
						if i==14 and code==KEY_D and magnification==1.6 and yaw==0:await shot("00-moving-layer-%d-zoom-1.6"%layer)
					key(code,false)
				check("keyboard_follow_%d_%.1f_%d"%[layer,magnification,yaw],view.auto_follow and all_visible and maximum_error<75)
				samples.append({"kind":"keyboard","layer":layer,"zoom":magnification,"angle":yaw,"maximum_error_pixels":maximum_error})
				await frames(45)
				var stopped:Vector2=view.focus;await frames(25)
				check("stop_stable_%d_%.1f_%d"%[layer,magnification,yaw],view.focus.distance_to(stopped)<.001 and torso().distance_to(view.safe_center)<1)
				drag(MOUSE_BUTTON_MIDDLE,Vector2(70,20));await frames(2)
				var destination:Vector2=room.player_plan()+Vector2(2.4,0)
				var screen:Vector2=view.screen(destination,layer,0)
				check("ground_projection_%d_%.1f_%d"%[layer,magnification,yaw],view.ground(screen,layer).distance_to(destination)<.005 and not room.hud.blocks_map(screen))
				click(screen);maximum_error=0;all_visible=true
				check("click_route_%d_%.1f_%d"%[layer,magnification,yaw],await navigation_finished() and room.player_plan().distance_to(destination)<.08 and view.auto_follow and all_visible and maximum_error<100)
				check("pose_preserved_%d_%.1f_%d"%[layer,magnification,yaw],is_equal_approx(view.target_zoom,magnification) and view.angle==yaw)
				samples.append({"layer":layer,"zoom":magnification,"angle":yaw,"maximum_click_error_pixels":maximum_error})
				if magnification==1.6 and yaw==0:
					await shot("01-follow-layer-%d-zoom-1.6"%layer)
	# Pointer preservation, moving zoom, long click routes, and HUD composition.
	for layer in [0,1]:
		await setup(layer,1.3,0)
		var at:=Vector2(1050,240);var before:Vector2=view.ground(at)
		view.zoom_at(at,1.6/1.3);await frames(70)
		check("stationary_pointer_anchor_%d"%layer,view.ground(at).distance_to(before)<.005)
		key(KEY_D,true);await frames(20);maximum_error=0;all_visible=true
		view.zoom_at(Vector2(1240,160),1.0/1.6)
		for i in range(50):await frames(1);sample()
		view.zoom_at(Vector2(40,400),1.6)
		for i in range(50):await frames(1);sample()
		key(KEY_D,false)
		check("moving_edge_pointer_zoom_%d"%layer,view.auto_follow and all_visible and maximum_error<75)
		await setup(layer,1.6,45,Vector2(6,2))
		# A far destination uses the same accepted click-navigation interface.
		check("long_route_accepted_%d"%layer,room.walk_to(Vector2(21,4)))
		maximum_error=0;all_visible=true
		check("long_route_always_visible_%d"%layer,await navigation_finished() and all_visible and maximum_error<75 and room.player_plan().distance_to(Vector2(21,4))<.08)
		await setup(layer,1.6,0)
		room.hud.toggle_record();await frames(70)
		check("record_framing_%d"%layer,room.hud.safe_rect().has_point(torso()) and torso().distance_to(room.hud.safe_rect().get_center())<1)
		await shot("02-record-layer-%d"%layer);room.hud.toggle_record()
		room.hud.destination_panel.show();await frames(70)
		check("destination_framing_%d"%layer,room.hud.safe_rect().has_point(torso()) and torso().distance_to(room.hud.safe_rect().get_center())<1)
		room.hud.destination_panel.hide()
		drag(MOUSE_BUTTON_MIDDLE,Vector2(160,30));await frames(2)
		var manual:Vector2=view.focus;await frames(40)
		check("manual_view_stays_still_%d"%layer,not view.auto_follow and view.focus==manual)
		key(KEY_UP,true);await frames(35);key(KEY_UP,false);await frames(45)
		check("keyboard_resumes_after_pan_%d"%layer,view.auto_follow and torso().distance_to(view.safe_center)<1)
		drag(MOUSE_BUTTON_LEFT,Vector2(120,0),true);await frames(2)
		check("alt_rotate_enters_manual_%d"%layer,not view.auto_follow and view.angle==24)
		key(KEY_F,true);key(KEY_F,false);await frames(65)
		check("F_smoothly_restores_pose_%d"%layer,view.auto_follow and view.angle==24 and is_equal_approx(view.target_zoom,1.6) and torso().distance_to(view.safe_center)<1)
		var actor:Vector2=room.player_plan();room.observe(1-layer);view.zoom_at(Vector2(800,400),.9);await frames(45)
		check("cross_layer_observation_never_moves_actor_%d"%layer,room.player_layer==layer and room.player_plan()==actor and room.view_layer==1-layer and not view.auto_follow)
		var previous_camera:Vector3=view.camera.position;var largest_return_step:=0.0
		key(KEY_F,true);key(KEY_F,false)
		for i in range(65):
			await frames(1);largest_return_step=maxf(largest_return_step,previous_camera.distance_to(view.camera.position));previous_camera=view.camera.position
		samples.append({"kind":"cross_layer_F","layer":layer,"largest_world_step":largest_return_step,"final_error_pixels":torso().distance_to(view.safe_center)})
		check("cross_layer_F_eases_height_%d"%layer,largest_return_step<3.0 and view.auto_follow and torso().distance_to(view.safe_center)<1)
		var zoom_before:float=view.target_zoom;var yaw_before:float=view.angle
		room.hud.toggle_menu();await frames(10);room.hud.toggle_menu();await frames(10)
		key(KEY_RIGHT,true);await frames(20);key(KEY_RIGHT,false)
		check("menu_close_then_move_%d"%layer,view.auto_follow and view.target_zoom==zoom_before and view.angle==yaw_before)
		room.world_cooldown=0;room.change_world(1,layer);await frames(30)
		check("world_switch_preserves_camera_%d"%layer,view.auto_follow and view.target_zoom==zoom_before and view.angle==yaw_before)
		var weight:Dictionary=room.state.weights[layer]
		check("weight_hit_after_zoom_%d"%layer,room.hit_target(view.screen(weight.pos,weight.layer,.3))=="w%d"%layer)
	# Real pointer hover and right-click acquisition after zoom and rotation.
	await pickup_checks()
	# Both stair flights: actor/camera move continuously, retain scale and cutaway.
	await stair_checks()
	print("CAMERA_FINISHED checks=",results.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
