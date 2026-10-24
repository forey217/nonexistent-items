extends Node
## Real inputs, actual collision movement, and identical before/after movie choreography.
const ACTIONS=["walk_left","walk_right","walk_up","walk_down"]
var app: Node
var directory:=""
var failures:=0
var checks: Array[Dictionary]=[]
var measurements: Dictionary={}

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func record(name: String,passed: bool,details: Dictionary={}) -> void:
	checks.append({"test":name,"passed":passed,"details":details})
	if not passed:failures+=1;push_error("SMOOTH_MOVE_FAILED "+name+" "+JSON.stringify(details))

func release() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):Input.action_release(action)

func press(direction: Vector2) -> void:
	release()
	if direction.x<0:Input.action_press("walk_left",absf(direction.x))
	if direction.x>0:Input.action_press("walk_right",absf(direction.x))
	if direction.y<0:Input.action_press("walk_up",absf(direction.y))
	if direction.y>0:Input.action_press("walk_down",absf(direction.y))

func key(code: int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
		get_viewport().push_input(event,true)

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func wait_route(player: Node,clear: Callable,limit:=1000) -> Dictionary:
	var safe:=true;var arrived:=false
	for i in range(limit):
		await frames(1);safe=safe and clear.call()
		if not player.is_navigating():arrived=true;break
	return {"safe":safe,"arrived":arrived}

func run(flow: Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://movement-smooth-checks")
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(5)
	if "--movement-smooth-demo" in OS.get_cmdline_user_args():await movie();return
	app.show_hub(false);await frames(8)
	var hub=app.current;var p=hub.player
	var start:Vector2=hub.iso(7,7)
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second=rate;release();p.teleport_for_reset(start);await frames(3)
		press(Vector2.RIGHT);await frames(2)
		var first:float=p.position.x-start.x
		record("first_input_moves_promptly_%d"%rate,first>0 and first<p.DEFAULT_SPEED*2.1/rate,{"distance":first})
		await frames(ceili(rate*.12))
		record("reaches_configured_top_speed_%d"%rate,absf(p.velocity.length()-p.DEFAULT_SPEED)<.1 and p.speed==p.DEFAULT_SPEED)
		await frames(ceili(rate*.20));var before:Vector2=p.position
		release();await frames(ceili(rate*.10)+2)
		var coast:float=p.position.distance_to(before)
		record("release_stops_within_100ms_and_short_distance_%d"%rate,p.velocity.length()<.01 and coast<=p.DEFAULT_SPEED*.044,{"distance":coast})
		var phase:float=p._walk_time;await frames(ceili(rate*.16)+2)
		record("idle_keeps_gait_phase_and_settles_feet_%d"%rate,phase>0 and p._walk_time==phase and not p.walking and p._art._locomotion_weight<.001)
		press(Vector2.RIGHT);await frames(ceili(rate*.14));before=p.position
		press(Vector2.LEFT);await frames(2)
		record("reverse_immediately_moves_in_new_direction_%d"%rate,p.position.x<before.x and p.velocity.x<0)
		release();p.cancel_navigation();p.teleport_for_reset(start);await frames(2)
		press(Vector2(1,1));await frames(roundi(rate*.40));var diagonal:float=p.position.distance_to(start)
		record("diagonal_speed_is_normalized_%d"%rate,p.velocity.length()<=p.DEFAULT_SPEED+.01)
		release();p.teleport_for_reset(start);await frames(2);press(Vector2.RIGHT);await frames(roundi(rate*.40))
		var straight:float=p.position.distance_to(start)
		record("equal_duration_diagonal_and_straight_match_%d"%rate,absf(straight-diagonal)<.25)
		measurements[str(rate)]={"straight_distance":straight,"stop_distance":coast}
		release();p.cancel_navigation()
	Engine.physics_ticks_per_second=60
	var span:Array=[]
	for value in measurements.values():span.append(value.straight_distance)
	record("physics_rates_keep_travel_consistent",span.max()-span.min()<p.DEFAULT_SPEED*.027,{"samples":measurements})
	p.teleport_for_reset(start);await frames(3)
	for i in range(4):press(Vector2.RIGHT);await frames(2);release();await frames(8)
	record("short_taps_allow_precise_positioning",p.position.x>start.x+1 and p.position.x<start.x+20)
	press(Vector2.RIGHT);await frames(15);var phase_before:float=p._walk_time
	release();await frames(17);var resting_phase:float=p._walk_time
	press(Vector2.RIGHT);await frames(3)
	record("restart_continues_previous_step_instead_of_resetting",p._walk_time>resting_phase and resting_phase>phase_before and p._art.gait_phase>0)
	release();p.cancel_navigation();p.teleport_for_reset(start);await frames(3)
	var arrivals:=[0];p.navigation_finished.connect(func():arrivals[0]+=1)
	p.follow_path(PackedVector2Array([start+Vector2(90,0)]))
	var speed_samples:Array=[]
	while p.is_navigating():
		await frames(1)
		if p.position.distance_to(start+Vector2(90,0))<9:speed_samples.append(p.velocity.length())
	record("click_arrival_is_accurate_and_emits_once",arrivals[0]==1 and p.position.distance_to(start+Vector2(90,0))<=.5)
	record("click_arrival_brakes_before_target",speed_samples.any(func(value):return value>1 and value<140),{"speeds":speed_samples})
	await frames(12);record("arrival_does_not_oscillate_or_repeat",arrivals[0]==1 and p.velocity==Vector2.ZERO)
	p.follow_path(PackedVector2Array([p.position+Vector2(90,0)]));await frames(12)
	var takeover:int=p.manual_takeovers;press(Vector2.DOWN);await frames(2)
	record("keyboard_takes_over_route_without_zero_speed_frame",p.manual_takeovers==takeover+1 and not p.is_navigating() and p.velocity.y>0)
	release();p.cancel_navigation();p.teleport_for_reset(start);await frames(3)
	p.follow_path(PackedVector2Array([start+Vector2(100,0)]));await frames(15)
	p.follow_path(PackedVector2Array([start+Vector2(0,80)]))
	var reroute:Dictionary=await wait_route(p,func():return hub.actor_position_is_clear(p.position))
	record("new_destination_replaces_route_safely",reroute.safe and reroute.arrived and p.position.distance_to(start+Vector2(0,80))<.5)
	var desk:Node=hub.props.filter(func(prop):return prop.name=="Desk")[0]
	var destination:Vector2=desk.position+Vector2(180,50)
	p.teleport_for_reset(desk.position+Vector2(-180,50));await frames(3)
	hub.queue_destination(destination);await frames(3)
	var desk_route:Dictionary=await wait_route(p,func():return hub.actor_position_is_clear(p.position))
	record("rounded_route_around_desk_preserves_full_collision",desk_route.safe and desk_route.arrived and p.position.distance_to(destination)<.6)
	hub.queue_destination(desk.position);await frames(3)
	record("invalid_destination_stops_and_reports_failure",not hub.last_request_succeeded and not p.is_navigating() and p.velocity==Vector2.ZERO)
	p.teleport_for_reset(start);press(Vector2.RIGHT);await frames(12)
	p.controls_locked=true;var locked_at:Vector2=p.position;await frames(5)
	record("control_lock_stops_immediately",p.position==locked_at and p.velocity==Vector2.ZERO and not p.is_navigating())
	release();p.controls_locked=false;await frames(4)
	record("unlock_has_no_old_route_or_residual_motion",p.position==locked_at and p.velocity==Vector2.ZERO)
	press(Vector2.RIGHT);await frames(8);p.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);locked_at=p.position;await frames(8)
	record("focus_loss_releases_keys_and_stops_without_coast",p.position==locked_at and p.velocity==Vector2.ZERO)
	p.face_toward(p.global_position+Vector2(1,-.2));var facing:int=p.facing_row
	for i in range(20):p._update_facing(Vector2(1,.07 if i%2==0 else -.07))
	record("small_direction_jitter_cannot_flip_facing",p.facing_row==facing)
	p._update_facing(Vector2(-1,-1));record("clear_reverse_direction_changes_facing_immediately",p.facing_row==3)
	p.teleport_for_reset(start+Vector2(20,20));record("teleport_resets_display_position_and_phase",p.display_position()==p.position and p._walk_time==0 and p._art.position==Vector2.ZERO)
	press(Vector2.RIGHT);await frames(5)
	record("display_position_stays_between_physics_samples",p.display_position().distance_to(p.position)<=p.DEFAULT_SPEED/60.0+.1)
	release();p.cancel_navigation();await shot("01-hall")
	# Real tutorial collision + pause, with its existing 3D actor and shadow.
	app.show_tutorial();await frames(8)
	var lab=app.current;p=lab.player
	p.teleport_for_reset(lab.spawn_point);press(Vector2.RIGHT);await frames(12)
	record("tutorial_uses_same_acceleration_and_full_speed",absf(p.velocity.length()-p.DEFAULT_SPEED)<.1)
	release();lab.hud.toggle_menu();locked_at=p.position;await frames(8)
	record("tutorial_pause_clears_motion_and_route",p.position==locked_at and p.velocity==Vector2.ZERO and not p.is_navigating())
	lab.hud.toggle_menu();await frames(6)
	record("tutorial_unpause_does_not_resume_old_motion",p.position==locked_at)
	for angle in [-45.0,0.0,45.0]:
		lab.orbit_view.set_angle(angle);p.face_toward(p.global_position+Vector2(-1,-1));lab.orbit_view._sync_state(.016)
		var actor:Vector3=lab.orbit_view.actor.position
		var foot:Vector3=lab.orbit_view.actor_shadow.position
		record("tutorial_actor_shadow_share_position_%d"%int(angle),Vector2(actor.x,actor.z).distance_to(Vector2(foot.x,foot.z))<.0001)
		var projected:Vector2=lab.orbit_view.logic_to_screen(p.position+p._last_direction)-lab.orbit_view.logic_to_screen(p.position)
		var row:int=(0 if projected.x>=0 else 1) if projected.y>=0 else (2 if projected.x>=0 else 3)
		record("tutorial_facing_matches_rotated_camera_%d"%int(angle),lab.orbit_view.paper.facing_row==row)
	await shot("02-tutorial")
	app.show_paper_mill();await frames(10)
	var mill=app.current;p=mill.player
	for layer in [0,1]:
		var data:Dictionary=mill.snapshot();var approach:Vector2=mill.stairs_position(layer)+Vector2(1.1,0)
		data.player_layer=layer;data.player=[approach.x,approach.y];mill.restore(data);await frames(3)
		record("mill_stair_route_accepted_%d"%layer,mill.walk_to(mill.stairs_position(layer)))
		var started:=false;var safe:=true
		for i in range(300):
			await frames(1)
			if mill.transition_age>0:started=true;break
			safe=safe and mill.is_walkable(mill.player_plan())
		record("mill_stair_approach_remains_safe_%d"%layer,safe and started)
		while mill.transition_age>0:await frames(1)
		await frames(10)
		record("mill_stair_exit_has_no_residual_velocity_%d"%layer,mill.player_layer==1-layer and p.velocity==Vector2.ZERO and not p.controls_locked and not p.is_navigating())
		var exit_layer:int=mill.player_layer;await frames(35)
		record("mill_stair_exit_never_retriggers_%d"%layer,mill.player_layer==exit_layer and mill.transition_age==0)
	release();await shot("03-mill")
	await finish()

func movie() -> void:
	# Fixed input schedule, identical scenes, materials, framing and destinations.
	var layer:=CanvasLayer.new();layer.layer=210;add_child(layer)
	var title:=Label.new();title.position=Vector2(25,72);title.size=Vector2(1000,34)
	title.add_theme_font_override("font",preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf"))
	title.add_theme_font_size_override("font_size",23);title.add_theme_color_override("font_color",Color("203b4a"))
	title.add_theme_color_override("font_outline_color",Color("f2e9d4"));title.add_theme_constant_override("outline_size",3);layer.add_child(title)
	var before:bool="--comparison-before" in OS.get_cmdline_user_args()
	var prefix:="优化前" if before else "优化后"
	for scene in ["hall","lab","mill"]:
		release()
		if scene=="hall":app.show_hub(false)
		elif scene=="lab":app.show_tutorial()
		else:app.show_paper_mill()
		await frames(12)
		var room=app.current;var player=room.player
		var start:Vector2=room.iso(7,7) if scene=="hall" else (room.spawn_point if scene=="lab" else Vector2(6,4)*room.SCALE)
		player.teleport_for_reset(start)
		title.text=prefix+" · "+{"hall":"接待大厅","lab":"新手校准室","mill":"纸山叠影"}[scene]+" · 起步 / 停步 / 反向 / 点击寻路"
		await frames(18)
		press(Vector2.RIGHT);await frames(30);release();await frames(24)
		press(Vector2.RIGHT);await frames(18);press(Vector2.LEFT);await frames(30);release();await frames(24)
		press(Vector2(1,-.2));await frames(24);release();await frames(24)
		if scene=="mill":room.walk_to(start/room.SCALE)
		else:room.queue_destination(start)
		await frames(96)
		if scene=="mill":
			title.text=prefix+" · 纸山叠影 · 自动楼梯与到站"
			var data:Dictionary=room.snapshot();var approach:Vector2=room.stairs_position(0)+Vector2(1.1,0)
			data.player_layer=0;data.player=[approach.x,approach.y];room.restore(data);await frames(18)
			room.walk_to(room.stairs_position(0));await frames(210)
		await shot("movie-"+scene)
	release();await app.shutdown_audio();get_tree().quit()

func finish() -> void:
	release();Engine.physics_ticks_per_second=60
	var out:=FileAccess.open(directory.path_join("movement-smooth-report.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks":checks.size(),"failures":failures,"measurements":measurements,"results":checks},"\t"));out.close()
	print("SMOOTH_MOVE_REPORT ",JSON.stringify({"checks":checks.size(),"failures":failures,"measurements":measurements}))
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
