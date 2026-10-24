extends Node
var app:Node
var room:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0
var movie_frame:=0
var record_movie:=false
var movie_active:=false
var movie_events:Array[Dictionary]=[]

func place(at:Vector2,law:=0,owned:=false,layer:=0) -> void:
	var s=room.State.new();s.worlds[0]=law;s.worlds[1]=0;s.clip_owned=owned
	room.restore({"state":s.snapshot(),"player_layer":layer,"player":[at.x,at.y]})
	room.communications.enabled=false;room.world_cast_time=0;room.hud.message_time=0;room.story_time=0
	room.hud.record.hide();room.hud.destination_panel.hide()
	room.view.set_focus(Vector2(5,11));room.view.auto_follow=false;room.view.frame_to_ui=false;room.view.angle=0
	room.view.zoom=1.6;room.view.target_zoom=1.6
	await frames(8)

func key(code:int,down:bool) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down;Input.parse_input_event(e)

func keys_for(direction:Vector2,arrows:=false) -> Array[int]:
	var screen:Vector2=room.player.input_basis.basis_xform_inv(direction)
	var codes:Array=[KEY_RIGHT,KEY_LEFT,KEY_DOWN,KEY_UP] if arrows else [KEY_D,KEY_A,KEY_S,KEY_W]
	var result:Array[int]=[]
	if absf(screen.x)>.2:result.append(codes[0 if screen.x>0 else 1])
	if absf(screen.y)>.2:result.append(codes[2 if screen.y>0 else 3])
	return result

func movie_frames(count:int) -> void:
	if not movie_active or DisplayServer.get_name()=="headless":await frames(count);return
	for i in range(0,count,4):
		await frames(mini(4,count-i));await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("frames/frame-%04d.png"%movie_frame));movie_frame+=1

func walk_keys(direction:Vector2,count:int,arrows:=false) -> void:
	var codes:=keys_for(direction,arrows)
	for code in codes:key(code,true)
	await movie_frames(count)
	for code in codes:key(code,false)
	await frames(3)

func click(at:Vector2) -> void:
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.pressed=down;e.button_index=MOUSE_BUTTON_LEFT;get_viewport().push_input(e,true)

func until(condition:Callable,limit:=500) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func topology_checks() -> void:
	for law in range(3):
		for owned in [false,true]:
			await place(Vector2(5,9.3),law,owned)
			check("no_hidden_support_%d_%s"%[law,owned],not room.is_walkable(Vector2(5,11)) and not room.view.side_bridge.visible)
			check("no_side_bypass_%d_%s"%[law,owned],room.path_to(Vector2(5,12.4)).is_empty() and room.path_to(room.State.TOOL).is_empty())
			check("interaction_cannot_reach_through_gap_%d_%s"%[law,owned],not room.request_interaction("tool") and room.pending.is_empty())
			var start:=Vector2(5,9.3);var stopped:Vector2=start+room.guard_motion(start*room.SCALE,Vector2(0,5)*room.SCALE)/room.SCALE
			check("large_motion_cannot_tunnel_%d_%s"%[law,owned],stopped.y<10-room.player.FOOT_RADIUS/room.SCALE+.001 and room.is_walkable(stopped))
			await place(Vector2(5,12.4),law,owned)
			check("reverse_no_bypass_%d_%s"%[law,owned],room.path_to(Vector2(5,9.3)).is_empty())
			start=Vector2(5,12.4);stopped=start+room.guard_motion(start*room.SCALE,Vector2(0,-5)*room.SCALE)/room.SCALE
			check("reverse_motion_stops_before_unsupported_edge_%d_%s"%[law,owned],stopped.y>12+room.player.FOOT_RADIUS/room.SCALE-.001 and room.is_walkable(stopped))
	for target in ["bridge","catch"]:
		await place(Vector2(5,9.3),0,true);room.state.clip_target=target;room._rebuild_navigation();await frames(2)
		check("fixing_other_object_does_not_fix_corridor_"+target,not room.state.old_corridor_solid() and not room.is_walkable(Vector2(5,11)) and not room.view.side_bridge.visible)
		if target=="bridge":check("real_clampable_bridge_still_solid",room.state.bridge_solid() and room.is_walkable(Vector2(18,11.5)))
		room.recall_clip();await frames(2)
		check("recall_does_not_unlock_corridor_"+target,not room.state.old_corridor_solid() and room.state.clip_target.is_empty())
	await place(Vector2(5,9.3));room.state.worlds[1]=3;room.observe(1);room._rebuild_navigation();await frames(3)
	check("observing_revealed_lower_floor_does_not_unlock_upper",room.player_layer==0 and room.view_layer==1 and not room.state.old_corridor_solid() and not room.is_walkable(Vector2(5,11),0))
	await place(Vector2(5,9.3),3);room.observe(1);await frames(3)
	check("observing_lower_floor_does_not_remove_upper_support",room.is_walkable(Vector2(5,11),0) and room.view.side_bridge.visible and room.state.worlds[1]==0)
	await place(Vector2(5,9.3),0,false,1)
	check("lower_fixed_crossing_still_available",room.is_walkable(Vector2(5,10.5),1))
	for at in [Vector2(1.5,10.5),Vector2(8.5,10.5),Vector2(5,9.3),Vector2(5,12.4),Vector2(8.5,12.4)]:
		check("ordinary_stone_stays_walkable_"+str(at),room.is_walkable(at,0))

func movement_checks() -> void:
	for reverse in [false,true]:
		for arrows in [false,true]:
			await place(Vector2(5,12.45) if reverse else Vector2(5,9.3))
			await walk_keys(Vector2.UP if reverse else Vector2.DOWN,95,arrows)
			check("held_keyboard_blocked_%s_%s"%[reverse,arrows],room.player_plan().y>12.23 if reverse else room.player_plan().y<9.77)
	for direction in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
		await place(Vector2(5,9.3) if direction.y>0 else Vector2(5,12.45))
		await walk_keys(direction,60)
		check("diagonal_does_not_cross_"+str(direction),room.player_plan().y<9.77 if direction.y>0 else room.player_plan().y>12.23)
	for reverse in [false,true]:
		await place(Vector2(5,12.45) if reverse else Vector2(5,9.3),3)
		await walk_keys(Vector2.UP if reverse else Vector2.DOWN,68)
		check("revealed_WASD_crosses_"+str(reverse),room.player_plan().y<9.7 if reverse else room.player_plan().y>12.2)
		await place(Vector2(5,12.45) if reverse else Vector2(5,9.3),3)
		var goal:=Vector2(5,9.3) if reverse else Vector2(5,12.45)
		click(room.view.screen(goal,0,0))
		check("revealed_real_click_crosses_"+str(reverse),await until(func():return room.player_plan().distance_to(goal)<.12))

func switching_checks() -> void:
	await place(Vector2(5,9.3),3)
	check("revealed_route_can_be_planned",room.walk_to(Vector2(5,12.45)) and room.player.is_navigating())
	check("bank_rule_switch_cancels_old_route",room.change_world(0,0) and not room.player.is_navigating() and room.path_to(Vector2(5,12.45)).is_empty())
	await frames(80);check("old_route_does_not_resume",room.player_plan().y<9.77)
	for owned in [false,true]:
		await place(Vector2(5,11),3,owned)
		if owned:room.state.clip_target="bridge"
		var at:Vector2=room.player_plan()
		check("support_removal_rejected_while_standing_%s"%owned,not room.change_world(0,0) and room.state.worlds[0]==3 and room.player_plan()==at)
		check("other_floor_can_still_change_from_corridor_%s"%owned,room.change_world(1,1) and room.state.worlds[0]==3)
	await place(Vector2(5,9.3),3);room.walk_to(Vector2(5,12.45));room.state.switch_world(0,0);await frames(2)
	check("external_topology_change_invalidates_route",not room.player.is_navigating() and room.player_plan().y<9.77)
	for at in [Vector2(5,10.2),Vector2(5,11.8)]:
		await place(Vector2(5,9.3));var data:Dictionary=room.snapshot();data.player=[at.x,at.y];room.restore(data);await frames(2)
		check("legacy_unsupported_save_repaired_on_near_bank_"+str(at),room.player_layer==0 and room.is_walkable(room.player_plan()) and not room.player.is_navigating() and (room.player_plan().y<10 if at.y<11 else room.player_plan().y>12))
	await place(Vector2(5,11),3);var snapshot:Dictionary=room.snapshot();room.restore(snapshot);await frames(3)
	check("revealed_corridor_save_stays_on_correct_support",room.player_plan().distance_to(Vector2(5,11))<.001 and room.state.old_corridor_solid())
	var path:=directory.path_join("corridor-fixture.json");var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(snapshot));f.close()
	room.restore(JSON.parse_string(FileAccess.get_file_as_string(path)));await frames(2)
	check("disk_roundtrip_preserves_corridor_support",room.is_walkable(room.player_plan()) and room.player_layer==0 and room.view.side_bridge.visible)

func projection_checks() -> void:
	for law in [0,3]:
		await place(Vector2(5,9.3),law)
		for zoom in [.55,1.0,1.6]:
			for yaw in [-45.0,0.0,45.0]:
				room.view.zoom=zoom;room.view.target_zoom=zoom;room.view.angle=yaw;await frames(12)
				var point:=Vector2(5,11);var pixel:Vector2=room.view.screen(point,0,0)
				check("projection_%.2f_%d_%d"%[zoom,yaw,law],room.view.ground(pixel,0).distance_to(point)<.005)
				click(pixel);await frames(3)
				check("map_click_respects_support_%.2f_%d_%d"%[zoom,yaw,law],room.player.is_navigating() if law==3 else not room.player.is_navigating())
				room.player.cancel_navigation();room.player.teleport_for_reset(Vector2(5,9.3)*room.SCALE)
				if yaw==0:await shot("law%d-zoom%.2f"%[law,zoom])
	await place(Vector2(5,9.3),3);room.view.zoom=1;room.view.target_zoom=1;room.view.return_to_actor();await frames(20)
	check("clip_can_still_be_acquired_by_walking",room.request_interaction("tool") and await until(func():return room.state.clip_owned))
	check("acquiring_clip_does_not_grant_permanent_support",room.state.old_corridor_solid() and room.state.worlds[0]==3)
	check("can_leave_tool_room_by_legal_corridor",room.walk_to(Vector2(5,9.3)) and await until(func():return room.player_plan().distance_to(Vector2(5,9.3))<.12))
	await until(func():return room.world_cooldown<=0)
	check("after_pickup_non_reveal_remains_closed",room.change_world(0,0) and not room.state.old_corridor_solid() and not room.is_walkable(Vector2(5,11)))

func movie() -> void:
	if DisplayServer.get_name()=="headless" or not record_movie:return
	DirAccess.make_dir_recursive_absolute(directory.path_join("frames"))
	movie_active=true
	await place(Vector2(5,9.3),0,true)
	room.hud.message("实机对照：冰晶世界，旧廊没有支撑。")
	movie_events.append({"frame":movie_frame,"action":"non_reveal_keyboard_blocked"})
	await movie_frames(60);await walk_keys(Vector2.DOWN,110);await shot("non-reveal-blocked");await movie_frames(45)
	click(room.view.screen(Vector2(5,12.45),0,0));await movie_frames(60)
	check("movie_click_does_not_bypass",room.player_plan().y<9.77 and not room.player.is_navigating())
	await shot("non-reveal-click-rejected")
	room.change_world(3,0);room.hud.message("实机对照：切至显影世界，沿原位置走过旧廊。")
	movie_events.append({"frame":movie_frame,"action":"switch_reveal_then_click_walk"})
	await movie_frames(80);click(room.view.screen(Vector2(5,12.45),0,0));await movie_frames(90)
	check("movie_revealed_click_reaches_tool_bank",room.player_plan().distance_to(Vector2(5,12.45))<.12)
	await shot("reveal-crossed");await movie_frames(45)
	click(room.view.screen(Vector2(5,11),0,0));await movie_frames(50)
	room.world_cooldown=0;var rejected:bool=not room.change_world(0,0)
	movie_events.append({"frame":movie_frame,"action":"standing_on_corridor_switch_rejected"});await movie_frames(70)
	check("movie_standing_switch_keeps_support",rejected and room.state.worlds[0]==3)
	click(room.view.screen(Vector2(5,9.3),0,0));await movie_frames(70)
	room.world_cooldown=0;room.change_world(0,0);await movie_frames(55);await walk_keys(Vector2.DOWN,70)
	check("movie_return_and_switch_closes_again",room.state.worlds[0]==0 and room.player_plan().y<9.77)
	var f:=FileAccess.open(directory.path_join("movie-events.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"fps":15,"frames":movie_frame,"events":movie_events},"\t"))

func comparison_shots() -> void:
	for law in [0,3]:
		await place(Vector2(5,9.3),law,true)
		room.view.safe_center=Vector2(640,400);room.view.torso_offset=0;room.view.framing_height=room.State.HEIGHT
		await frames(35);await shot("comparison-law%d"%law)
		check("comparison_support_matches_visible_deck_"+str(law),room.view.side_bridge.visible==room.is_walkable(Vector2(5,11)))

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func check(label:String,passed:bool) -> void:
	results.append({"test":label,"passed":passed});print("CORRIDOR_CHECK ",label," ",passed)
	if not passed:failures+=1;push_error("CORRIDOR_FAILED "+label)
	var file:=FileAccess.open(directory.path_join("corridor-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"native_render":DisplayServer.get_name()!="headless","checks":results,"failures":failures},"\t"))

func run(flow:Node) -> void:
	app=flow;room=flow.current
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
		if arg=="--record-corridor":record_movie=true
	DirAccess.make_dir_recursive_absolute(directory)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	await frames(30);room.communications.enabled=false;room.story_time=0;room.hud.message_time=0
	room.hud.entry_hint.offer();room.hud.entry_hint.dismiss();await frames(45)
	if "--corridor-baseline" in OS.get_cmdline_user_args():
		room.player.teleport_for_reset(Vector2(5,9.1)*room.SCALE);room.view.set_focus(Vector2(5,11));room.view.zoom=1.6;room.view.target_zoom=1.6;room.view.frame_to_ui=false
		await frames(25);await shot("before-non-reveal")
		var old_path:PackedVector2Array=room.path_to(Vector2(5,12.3))
		check("reproduced_non_reveal_bypass_to_tool_door",not old_path.is_empty())
		room.state.clip_owned=true;room._rebuild_navigation();await frames(3)
		check("reproduced_clip_ownership_unlocks_wrong_corridor",room.is_walkable(Vector2(5,10.5)) and room.view.side_bridge.visible)
		await shot("before-clip-owned")
		var f:=FileAccess.open(directory.path_join("baseline-path.json"),FileAccess.WRITE);f.store_string(JSON.stringify(Array(old_path)))
		await app.shutdown_audio();get_tree().quit();return
	await topology_checks();await movement_checks();await switching_checks();await projection_checks();await comparison_shots();await movie()
	print("CORRIDOR_FINISHED checks=",results.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
