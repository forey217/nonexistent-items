extends Node
const S=preload("res://scripts/paper_mill_state.gd")
const Driver=preload("res://tests/paper_push_driver.gd")
var app:Node
var room:Node
var directory:=""
var checks:Array[Dictionary]=[]
var failures:=0

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition:Callable,limit:=1800) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func check(title:String,passed:bool) -> void:
	checks.append({"test":title,"passed":passed});print("DIRECTION_CHECK ",title," ",passed)
	if not passed:failures+=1;push_error("DIRECTION_FAILED "+title)
	var file:=FileAccess.open(directory.path_join("direction-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"native_render":DisplayServer.get_name()!="headless"},"\t"))

func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func state_fixture(index:int,layer:int,station:String) -> RefCounted:
	var s:=S.new();s.clip_owned=true;s.clip_target="bridge";s.cage_open=true;s.lowpass_open=true
	s.weights[index]=s.make_weight("mountain" if index==0 else "water",layer,s.stops(index)[station],station)
	if index==0:
		s.hatch_broken=true
		if layer==0:
			s.lift_height=S.HEIGHT;s.weights[1]=s.make_weight("water",1,S.SLUICE,"sluice");s.worlds[1]=1;s.lifted_once=true
	return s

func state_checks() -> void:
	var matrix:Array=[]
	for index in range(2):
		for layer in ([0,1] if index==0 else [1]):
			var seed=state_fixture(index,layer,"lift" if index==0 else "cage")
			var stations:Array=[]
			for edge in seed.edges(index):
				for station in edge:
					if station not in stations:stations.append(station)
			for station:String in stations:
				for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
					var s=state_fixture(index,layer,station);var w:Dictionary=s.weights[index]
					var plan:Dictionary=s.push_route(index,direction)
					if not plan.error.is_empty():continue
					var events:Array=[];s.event.connect(func(kind):events.append(kind))
					s.push_direction(index,direction)
					var path:Array=[w.pos]+plan.points.duplicate();var follows:=true;var uninterrupted:=true
					var total_distance:float=w.slide_remaining
					for frame in range(2400):
						s.step(1.0/120.0)
						var nearest:=INF
						for j in range(path.size()-1):nearest=minf(nearest,Geometry2D.get_closest_point_to_segment(w.pos,path[j],path[j+1]).distance_to(w.pos))
						follows=follows and nearest<.0001
						if w.mode=="rest":break
						if events.count("stop")>0:uninterrupted=false
						if total_distance-float(w.slide_remaining)>.8 and float(w.slide_remaining)>1.0 and float(w.slide_speed)<3.4:uninterrupted=false
					check("rail_%d_%d_%s_%s"%[index,layer,station,str(direction)],w.mode=="rest" and w.station==plan.target and w.pos==s.stops(index)[plan.target] and follows and uninterrupted and events.count("push")==1 and events.count("stop")==1)
					matrix.append({"index":index,"layer":layer,"origin":station,"direction":[direction.x,direction.y],"via":plan.stations,"stop":plan.target,"reason":plan.reason})
	var s=state_fixture(1,1,"cage")
	check("cage_elbow_passes_without_another_command",s.push_route(1,Vector2.RIGHT).stations==["cage_turn","catch"])
	check("water_plain_junction_passes_but_real_fork_stops",state_fixture(1,1,"catch").push_route(1,Vector2.RIGHT).stations==["junction","guide_turn"])
	check("water_sluice_elbow_passes",state_fixture(1,1,"guide_turn").push_route(1,Vector2.RIGHT).stations==["sluice_turn","sluice"])
	check("water_guide_elbow_passes",state_fixture(1,1,"guide_turn").push_route(1,Vector2.DOWN).stations==["guide_bend","guide"])
	check("mountain_lower_plain_and_elbow_pass",state_fixture(0,1,"catch").push_route(0,Vector2.RIGHT).stations==["junction","lift_turn","lift"])
	check("fixed_bridge_and_anchor_elbow_pass",state_fixture(0,0,"dock").push_route(0,Vector2.DOWN).stations==["bridge","anchor_turn","anchor"])
	s=state_fixture(0,0,"lift");s.clip_target=""
	check("missing_bridge_stops_safely_at_dock",s.push_route(0,Vector2.DOWN).target=="dock" and not s.push_route(0,Vector2.DOWN).blocked_reason.is_empty())
	s=state_fixture(0,1,"catch");s.lift_height=S.HEIGHT
	check("absent_lift_stops_at_last_supported_elbow",s.push_route(0,Vector2.RIGHT).target=="lift_turn" and not s.push_route(0,Vector2.RIGHT).blocked_reason.is_empty())
	s=state_fixture(1,1,"guide_turn");s.lowpass_open=false
	check("locked_lowpass_is_not_previewed_as_available",not s.push_error(1,Vector2.DOWN).is_empty())
	s=state_fixture(0,0,"dock");s.push_direction(0,Vector2.DOWN)
	check("worlds_and_bridge_clip_locked_during_transport",not s.switch_world(0,1) and not s.switch_world(1,0) and s.set_clip("").contains("停稳") and s.clip_target=="bridge")
	for station in ["cage_turn","junction","sluice_turn","guide_bend"]:
		s=state_fixture(1,1,station);var saved:Dictionary=s.snapshot();var restored:=S.new();restored.restore(saved)
		check("legacy_intermediate_save_"+station,restored.weights[1].station==station and restored.weights[1].pos==s.weights[1].pos and not restored.destinations(1).is_empty())
	var file:=FileAccess.open(directory.path_join("stop-audit.json"),FileAccess.WRITE);file.store_string(JSON.stringify(matrix,"\t"))

func fixture(index:=1,layer:=1,station:="cage",actor:=Vector2(8,13.5)) -> void:
	room.communications.stop();room.communications.enabled=false;room.hud.menu.close();room.hud.push_picker.close()
	var s=state_fixture(index,layer,station)
	room.restore({"state":s.snapshot(),"player_layer":layer,"player":[actor.x,actor.y]});room.stairs_armed=true
	room.hud.record.hide();room.hud.entry_hint.offer();room.hud.entry_hint.dismiss();room.story_time=0;room.hud.message_time=0
	room.view.angle=0;room.view.zoom=1;room.view.target_zoom=1;room.view.set_focus(s.weights[index].pos);room.view.frame_to_ui=false;room.view.safe_center=Vector2(640,420)
	await frames(25)

func click(at:Vector2,button:=MOUSE_BUTTON_LEFT) -> void:
	Driver.new().click(room,at,button)

func right_weight(index:int) -> void:
	var w:Dictionary=room.state.weights[index];var h:float=room.state.weight_height(index)-(S.HEIGHT if w.layer==0 else 0.0)+.3
	click(room.view.screen(w.pos,w.layer,h),MOUSE_BUTTON_RIGHT);await frames(3)

func key(code:int) -> void:
	for down in [true,false]:
		var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down;get_viewport().push_input(e,true)

func ui_checks() -> void:
	await fixture()
	var picker=room.hud.push_picker;var actor:Vector2=room.player_plan();room.player.face_toward(room.player.position+Vector2.LEFT*room.SCALE)
	await right_weight(1)
	check("right_click_opens_four_directions_without_moving_actor",picker.visible and picker.selected==1 and picker.arrows.size()==4 and room.player_plan()==actor and not room.player.is_navigating())
	check("invalid_rails_are_disabled_and_real_rail_available",not picker.arrows[0].disabled and picker.arrows.slice(1).all(func(b):return b.disabled))
	check("picker_buttons_and_text_block_map",room.hud.blocks_map(picker.arrows[0].get_global_rect().get_center()) and room.hud.blocks_map(picker.detail.get_global_rect().get_center()))
	check("picker_transparent_center_does_not_block_map",not picker.blocks_map(picker.center))
	var water_route:Dictionary=room.state.push_route(1,Vector2.RIGHT)
	var bend=room.view.rail_networks[1].curves.filter(func(curve):return curve.joint=="cage_turn")[0]
	check("continuous_bend_uses_actual_rail_centerline",water_route.points.size()>10 and water_route.points.any(func(point):return absf(point.distance_to(bend.center)-S.RailGeometry.TURN_RADIUS)<.0001))
	var actor_pixel:Vector2=room.view.screen(room.player_plan(),1,.9)
	check("arrow_buttons_avoid_actor_body",picker.arrows.all(func(b):return not b.get_global_rect().intersects(Rect2(actor_pixel-Vector2(38,60),Vector2(76,116)))))
	await shot("01-four-direction-picker")
	picker.hovered=0;await frames(2);await shot("02-legal-route-hover")
	check("preview_includes_bend_and_actual_functional_stop",picker.options[0].stations==["cage_turn","catch"] and picker.detail_label.text.contains("接物踏板"))
	key(KEY_ESCAPE);await frames(2)
	check("escape_closes_picker_without_opening_pause",not picker.visible and not room.hud.menu.visible)
	await right_weight(1);click(picker.arrows[1].get_global_rect().get_center());await frames(2)
	check("disabled_arrow_does_not_move_actor_or_weight",picker.visible and room.player_plan()==actor and room.state.weights[1].station=="cage" and room.pending.is_empty());picker.close()
	await right_weight(1);await right_weight(1);check("right_same_weight_toggles_closed",not picker.visible)
	await right_weight(1);click(Vector2(1200,500),MOUSE_BUTTON_RIGHT);check("right_blank_closes_picker",not picker.visible)
	await right_weight(1);click(room.view.screen(Vector2(9,14),1,0));check("closing_picker_does_not_leak_same_click_to_movement",not picker.visible and not room.player.is_navigating())
	click(room.view.screen(Vector2(9,14),1,0));check("next_ground_click_walks_normally",room.player.is_navigating())
	room.player.cancel_navigation()
	await right_weight(1);click(picker.arrows[0].get_global_rect().get_center());await frames(2)
	check("left_arrow_starts_real_approach_without_instant_weight_move",not picker.visible and room.pending.has("direction") and room.player.is_navigating() and room.state.weights[1].mode=="rest" and room.player_plan().distance_to(actor)<.3)
	key(KEY_A);await frames(4);check("manual_move_cancels_deferred_push",room.pending.is_empty() and room.state.weights[1].mode=="rest")
	await frames(50);check("cancelled_command_never_executes_later",room.state.weights[1].station=="cage" and room.state.weights[1].mode=="rest")
	await fixture();await right_weight(1);click(picker.arrows[0].get_global_rect().get_center());await frames(2);room.hud.menu.open();await frames(12)
	check("pause_clears_approach_and_picker",room.pending.is_empty() and not picker.visible and room.state.weights[1].mode=="rest");room.hud.menu.close()
	await fixture();await right_weight(1);click(picker.arrows[0].get_global_rect().get_center());await frames(2);room.observe(0);await frames(2)
	check("observing_other_floor_cancels_deferred_push",room.pending.is_empty() and not picker.visible and room.state.weights[1].station=="cage")
	await fixture();await right_weight(1);click(picker.arrows[0].get_global_rect().get_center());await frames(2);room.state.worlds[1]=1;await frames(3)
	check("changed_rule_invalidates_pending_command",room.pending.is_empty() and room.state.weights[1].mode=="rest")
	await fixture();var driver:=Driver.new();var accepted:bool=await driver.start(room,1,Vector2.RIGHT)
	check("wrong_initial_facing_is_automatically_corrected",accepted and await until(func():return room.state.weights[1].mode=="slide"))
	check("repeat_click_during_slide_cannot_queue",not room.request_interaction("w1") and room.pending.is_empty())
	check("actual_slide_finishes_at_plate_after_one_command",await until(func():return room.state.weights[1].station=="catch" and room.state.weights[1].mode=="rest"))
	check("actor_control_and_old_path_restored",not room.interacting and not room.player.controls_locked and room.pending.is_empty() and not room.player.is_navigating())
	await shot("03-one-push-through-elbow-to-plate")
	room.state.worlds[1]=1;await frames(70);check("real_pressure_plate_still_raises_catch",room.state.catch_height>.98)
	await fixture(0,1,"catch",Vector2(7,7));room.state.catch_height=1;room.state.clip_target="catch"
	check("receiving_opening_uses_reachable_bank_not_walk_inside_hole",room.push_preview(0,Vector2.RIGHT).valid)
	await fixture(0,0,"dock",Vector2(20,8.5));room.state.clip_target="";await right_weight(0);picker.hovered=1;await frames(3)
	check("missing_bridge_disabled_with_actual_reason",picker.arrows[1].disabled and picker.options[1].error.contains("桥"));await shot("04-missing-bridge-disabled")
	await fixture();room.player_layer=0;room.view_layer=1;room._rebuild_navigation()
	check("cannot_push_observed_other_floor",not room.request_interaction("w1") and room.state.weights[1].mode=="rest")
	await fixture();room.player.teleport_for_reset(Vector2(3,10)*room.SCALE);room.player_layer=0;room.view_layer=0;room._rebuild_navigation()
	check("unrevealed_corridor_is_still_blocked",not room.is_walkable(Vector2(5,11),0))
	await fixture();room.player.teleport_for_reset(Vector2(3.7,12.2)*room.SCALE);room.player.face_toward(room.player.position+Vector2.DOWN*room.SCALE);key(KEY_E);await frames(3)
	check("e_opens_same_picker_without_facing_requirement",picker.visible and picker.selected==1 and room.state.weights[1].mode=="rest")
	var saved:Dictionary=room.snapshot();room.restore(saved);await frames(3)
	check("restore_clears_all_temporary_picker_and_command_state",not picker.visible and room.pending.is_empty() and not room.interacting)
	await fixture();room.state.weights[0]=S.new().make_weight("mountain",1,S.DROP,"catch");room.view.zoom=.55;room.view.target_zoom=.55;room.view.set_focus(Vector2(10,10));await frames(15)
	await right_weight(1);await right_weight(0)
	check("right_other_weight_switches_single_picker",picker.visible and picker.selected==0 and picker.arrows.size()==4)
	await fixture();await right_weight(1);picker.arrows[0].grab_focus();key(KEY_ENTER);await frames(3)
	check("keyboard_focus_activates_same_direction_action",room.pending.has("direction") or room.interacting or room.state.weights[1].mode=="slide")
	room.cancel_push_command()

func visual_checks() -> void:
	var picker=room.hud.push_picker
	for zoom in [.55,1.0,1.6]:
		for yaw in [-45.0,0.0,45.0]:
			await fixture();room.view.angle=yaw;room.view.zoom=zoom;room.view.target_zoom=zoom;await frames(12);await right_weight(1)
			check("picker_projection_and_hit_size_%.2f_%.0f"%[zoom,yaw],picker.visible and picker.arrows.all(func(b):return b.size.x>=50 and get_viewport().get_visible_rect().encloses(b.get_global_rect()) and not b.get_global_rect().has_point(picker.origin)) and picker.arrows[0].vector.dot((room.view.screen(room.state.weights[1].pos+Vector2.RIGHT,1,.4)-room.view.screen(room.state.weights[1].pos,1,.4)).normalized())>.999)
			picker.hovered=0;await frames(2);await shot("zoom-%.2f-yaw-%.0f"%[zoom,yaw])
			if zoom!=1.0 and yaw!=0.0:
				click(picker.arrows[0].get_global_rect().get_center())
				check("actual_click_at_rotation_boundary_%.2f_%.0f"%[zoom,yaw],await until(func():return room.state.weights[1].station=="catch" and room.state.weights[1].mode=="rest"))
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(Vector2i(1920,1080));await frames(15);await shot("wide-1920")
		check("wide_picker_inside_actual_canvas",get_viewport().get_visible_rect().encloses(picker.occupied_rect()))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);await frames(15);await shot("fullscreen")
		check("fullscreen_picker_inside_actual_canvas",get_viewport().get_visible_rect().encloses(picker.occupied_rect()))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,800));await frames(10)

func movie() -> void:
	await fixture();room.view.zoom=1.1;room.view.target_zoom=1.1
	room.state.clip_target="";room.state.lowpass_open=false
	await frames(60);await right_weight(1)
	room.communications.enabled=true;room.communications.pending.clear();room.hint_level=3
	var text:String=preload("res://scripts/paper_mill_lines.gd").hint_cases()["water-to-catch"][2]
	room.communications._begin({"key":"hint:water-to-catch:3","priority":100,"lines":[preload("res://scripts/paper_mill_lines.gd").line("tesla",text)]})
	await frames(70);room.hud.push_picker.hovered=0;await frames(490)
	click(room.hud.push_picker.arrows[0].get_global_rect().get_center());await frames(60)
	check("movie_real_input_reaches_first_plate",await until(func():return room.state.weights[1].station=="catch" and room.state.weights[1].mode=="rest"))
	await frames(180);room.communications.stop();room.communications.enabled=false
	var driver:=Driver.new()
	var reached:bool=await driver.segment(room,1,"guide_turn")
	if not reached:
		print("MOVIE_DRIVER_ERROR ",driver.error," actor=",room.player_plan()," pending=",room.pending," navigating=",room.player.is_navigating()," weight=",room.state.weights[1]);await shot("movie-driver-failure")
	check("movie_continues_to_actual_branch",reached)
	if not reached:return
	await frames(80)
	await right_weight(1);room.hud.push_picker.hovered=0;await frames(90)
	click(room.hud.push_picker.arrows[0].get_global_rect().get_center())
	check("movie_passes_sluice_bend_and_stops_on_real_plate",await until(func():return room.state.weights[1].station=="sluice" and room.state.weights[1].mode=="rest"))
	await frames(120);room.change_world(1,1);await frames(120)
	await shot("movie-final-sluice")

func run(flow:Node) -> void:
	app=flow
	if app.current.get("level_id")!="paper_mill":app.show_paper_mill()
	room=app.current
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	await frames(10)
	if "--direction-movie" in OS.get_cmdline_user_args():await movie()
	else:state_checks();await ui_checks();await visual_checks()
	print("DIRECTION_FINISHED checks=",checks.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
