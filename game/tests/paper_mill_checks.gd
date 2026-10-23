extends Node
var app:Node
var room:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0
var stages:Array[Dictionary]=[]
var snapshots:Array[Dictionary]=[]
var started:=0
var start_frame:=0
var demo:=false

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition:Callable,limit:=2400) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func report() -> void:
	var data:={"suite":"paper_mill","native_render":DisplayServer.get_name()!="headless","failures":failures,"checks":results,"stages":stages,"elapsed_seconds":float(Time.get_ticks_msec()-started)/1000.0}
	var file:=FileAccess.open(directory.path_join("paper-mill-report.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(data,"  "))

func check(title:String,passed:bool) -> void:
	results.append({"test":title,"passed":passed})
	print("MILL_CHECK ",title," ",passed)
	if not passed:failures+=1;push_error("MILL_FAILED "+title)
	report()
	if not passed:get_tree().quit(1)

func capture(title:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(title+".png"))

func key(code:int) -> void:
	for pressed in [true,false]:
		var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;get_viewport().push_input(e,true)

func click(at:Vector2) -> void:
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;get_viewport().push_input(e,true)

func camera_input_checks() -> void:
	# Pointer-anchored zoom is the stationary contract; moving zoom follows torso.
	await until(func():return not room.player.is_navigating() and not room.player.walking)
	await frames(3)
	var previous:float=room.view.target_zoom
	var before:Vector2=room.view.ground(Vector2(740,400));var rules:Array=room.state.worlds.duplicate()
	var wheel:=InputEventMouseButton.new();wheel.position=Vector2(740,400);wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
	get_viewport().push_input(wheel,true);await frames(35)
	check("wheel_event_zoom_in",room.view.target_zoom>previous)
	check("zoom_preserves_pointer_ground",room.view.ground(Vector2(740,400)).distance_to(before)<.03)
	check("zoom_does_not_change_world_rules",room.state.worlds==rules)
	var old_focus:Vector2=room.view.focus;var old_player:Vector2=room.player_plan()
	var press:=InputEventMouseButton.new();press.position=Vector2(740,400);press.button_index=MOUSE_BUTTON_MIDDLE;press.pressed=true;get_viewport().push_input(press,true)
	var drag:=InputEventMouseMotion.new();drag.position=Vector2(770,420);drag.relative=Vector2(30,20);get_viewport().push_input(drag,true)
	press.pressed=false;get_viewport().push_input(press,true);await frames(3)
	check("middle_drag_pans_only_view",room.view.focus.distance_to(old_focus)>.1 and room.player_plan().distance_to(old_player)<.01 and not room.player.is_navigating())
	press=InputEventMouseButton.new();press.position=Vector2(740,400);press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.alt_pressed=true;get_viewport().push_input(press,true)
	drag.relative=Vector2(600,0);get_viewport().push_input(drag,true);press.pressed=false;get_viewport().push_input(press,true);await frames(3)
	check("alt_drag_rotates_with_limit",is_equal_approx(room.view.angle,45.0) and not room.view.rotating)

func run_reopened() -> void:
	app.saving_enabled=true;app.show_menu();await frames(4);app.current.begin()
	check("fresh_process_opens_picker",await until(func():return app.save_picker!=null))
	await until(func():return app.save_picker.ready_for_input());app.save_picker.select(1);key(KEY_ENTER)
	check("fresh_process_restores_paper_scene",await until(func():return app.save_picker==null and not app.menu_revealing and app.current.get("level_id")=="paper_mill" and not app.current.arrival_busy()))
	room=app.current
	var expected_path:String=app.save_book.directory.path_join("expected.json")
	if FileAccess.file_exists(expected_path):
		var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(expected_path))
		var expected_state=preload("res://scripts/paper_mill_state.gd").new()
		expected_state.restore(expected.state)
		check("fresh_process_preserves_complete_checkpoint",JSON.stringify(room.state.snapshot())==JSON.stringify(expected_state.snapshot()))
	else:
		check("fresh_process_preserves_cross_layer_milestone",room.state.checkpoint==3 and room.state.hatch_broken and room.state.weights[0].layer==1 and room.state.clip_target=="catch")
	check("fresh_process_rebuilds_navigation",not room.path_to(room.stairs_position(room.player_layer)).is_empty())
	await capture("reopened-second-level");report();await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)

func resume_through_title() -> void:
	var before:Dictionary=room.stable_snapshot();app._save_progress(true)
	key(KEY_F10)
	check("second_level_can_return_to_title",await until(func():return app.current.has_signal("start_requested")))
	app.current.begin();await until(func():return app.save_picker!=null)
	await until(func():return app.save_picker.ready_for_input())
	check("save_card_names_second_level",app.save_book.location(app.save_picker.cards[0].record.data)=="纸山叠影")
	app.save_picker.select(1);key(KEY_ENTER)
	check("continue_routes_to_second_level",await until(func():return app.save_picker==null and not app.menu_revealing and app.current.get("level_id")=="paper_mill" and not app.current.arrival_busy()))
	room=app.current
	check("continue_preserves_physical_progress",JSON.stringify(room.state.snapshot())==JSON.stringify(before.state))
	check("continue_restores_legal_player_position",room.is_walkable(room.player_plan()))

func action(id:String,destination:="") -> void:
	if failures>0:return
	await until(func():return not room.arrival_busy() and not room.interacting)
	if id=="stairs":
		var origin_layer:int=room.player_layer
		if not room.stairs_armed:
			var exit:Vector2=room.stairs_position(origin_layer)+Vector2(0,.98 if origin_layer==0 else -1.2)
			check("leave_stair_exit",room.walk_to(exit))
			await until(func():return not room.player.is_navigating() and room.stairs_armed)
		var at:Vector2=room.view.screen(room.stairs_position(origin_layer),origin_layer,0)
		room.view.return_to_actor();await frames(8)
		at=room.view.screen(room.stairs_position(origin_layer),origin_layer,0)
		# Following the actor may place the far landing outside the screen.
		# Use the same objective-focus entry as the HUD before clicking it.
		if not room.hud.safe_rect().has_point(at) or room.hud.blocks_map(at):
			room.focus_target("stairs");await frames(25)
			at=room.view.screen(room.stairs_position(origin_layer),origin_layer,0)
		click(at)
		check("walk_into_stairs_%d"%origin_layer,await until(func():return room.player_layer!=origin_layer and not room.arrival_busy()))
		await frames(25)
		check("stair_exit_stays_on_arrival_layer",room.player_layer!=origin_layer and not room.arrival_busy())
		return
	var accepted:bool=room.request_interaction(id,destination)
	check("reachable_action_"+id+"_"+destination,accepted)
	if not accepted:return
	check("completed_action_"+id+"_"+destination,await until(func():return room.pending.is_empty() and not room.interacting and not room.arrival_busy()))
	await frames(4)

func rule(layer:int,world:int) -> void:
	if failures>0:return
	await until(func():return room.world_cooldown<=0 and not room.interacting and not room.arrival_busy())
	if room.state.worlds[layer]!=world:check("switch_%d_%d"%[layer,world],room.change_world(world,layer))
	await frames(3)

func push_weight(index:int,destination:String) -> void:
	if failures>0:return
	await until(func():return room.state.weights[index].mode=="rest" and float(room.state.weights[index].elevation)<.03)
	await action("w%d"%index,destination)
	check("transport_to_"+destination,await until(func():return room.state.weights[index].mode=="rest" and room.state.weights[index].station==destination))

func milestone(title:String) -> void:
	if failures>0:return
	await frames(8)
	var saved:Dictionary=room.stable_snapshot()
	check("valid_save_"+title,app.save_book.valid_paper(saved))
	check("snapshot_has_current_checkpoint_"+title,int(saved.state.checkpoint)==room.state.checkpoint)
	snapshots.append(saved.duplicate(true));stages.append({"name":title,"game_seconds":room.elapsed,"demo_seconds":float(Engine.get_physics_frames()-start_frame)/60.0,"checkpoint":room.state.checkpoint})
	app._save_progress(true)
	check("disk_save_"+title,app.save_book.inspect(1).status=="ready")
	var fixture=preload("res://scripts/save_book.gd").new();fixture.directory=directory.path_join("checkpoint-saves").path_join(title)
	fixture.write(1,app.save_book.inspect(1).data)
	var expected:=FileAccess.open(fixture.directory.path_join("expected.json"),FileAccess.WRITE)
	if expected!=null:expected.store_string(JSON.stringify(saved))
	await capture(title)

func run(flow:Node) -> void:
	app=flow;started=Time.get_ticks_msec();start_frame=Engine.get_physics_frames();demo="--paper-mill-demo" in OS.get_cmdline_user_args()
	if not demo and DisplayServer.get_name()!="headless":Engine.max_fps=60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://paper-mill-checks")
	DirAccess.make_dir_recursive_absolute(directory)
	if "--paper-mill-resume-check" in OS.get_cmdline_user_args():
		await run_reopened();return
	# Never touch the normal player directory, even if caller omitted --save-dir.
	app.save_book.directory=directory.path_join("isolated-saves");app.saving_enabled=true
	var seed_record:Dictionary=app.save_book.create(1)
	if seed_record.is_empty():seed_record=app.save_book.inspect(1).data
	seed_record.scene="hub";seed_record.checkpoint=0;seed_record.completed_runs=1;seed_record.paper_runs=0;seed_record.erase("paper_progress");seed_record.erase("paper_state")
	seed_record.story={"intro_seen":true,"debrief_seen":true,"tutorial_runs":1};app.save_book.write(1,seed_record)
	app.show_menu();await frames(4);app.current.begin()
	check("title_opens_save_picker",await until(func():return app.save_picker!=null))
	await until(func():return app.save_picker.ready_for_input());app.save_picker.select(1);key(KEY_ENTER)
	check("saved_slot_enters_hall",await until(func():return app.save_picker==null and not app.menu_revealing and app.current.get("hall_camera")!=null and not app.current.arrival_busy()))
	if failures>0:return
	app.open_level_menu();await frames(3);app.level_menu.expand_crystal()
	await until(func():return app.level_menu.phase==2)
	check("second_shard_unlocked_after_tutorial",app.level_menu.paper_unlocked and app.level_menu.shards[1].available)
	await capture("00-selection")
	app.level_menu.choose_shard(1)
	check("selection_routes_to_paper_mill",await until(func():return app.level_menu==null and app.current.get("level_id")=="paper_mill" and not app.current.arrival_busy()))
	room=app.current
	check("distinct_layers_initially_independent",room.state.worlds==[0,0])
	await milestone("01-entry")
	room.view.set_focus(Vector2(12,9));await frames(4);await capture("01-upper-overview")
	var original:Vector2=room.player_plan();room.observe(1);await frames(3)
	check("observe_does_not_teleport_player",room.player_layer==0 and room.player_plan().distance_to(original)<.01)
	room.observe(0)
	room.view.return_to_actor();await frames(4)
	var click_destination:Vector2=room.player_plan()+Vector2(1.5,0)
	click(room.view.screen(click_destination,0,0))
	check("real_click_moves_character",await until(func():return room.player_plan().distance_to(click_destination)<.1))
	if not demo:await camera_input_checks()
	for angle in ([] if demo else [-45.0,0.0,45.0]):
		room.view.angle=angle
		for zoom in [.55,1.0,1.6]:
			room.view.zoom_at(Vector2(740,400),zoom/room.view.target_zoom);await frames(2)
			var at:=Vector2(8,6);var screen:Vector2=room.view.screen(at,0,0)
			check("projection_roundtrip_%s_%s"%[angle,zoom],room.view.ground(screen,0).distance_to(at)<.005)
	room.view.angle=0;room.view.zoom=1;room.view.target_zoom=1;room.view.return_to_actor()
	await rule(0,3)
	check("remote_rule_preserves_other_layer",room.state.worlds[1]==0)
	await action("tool");check("clip_collected_from_real_location",room.state.clip_owned);await milestone("02-clip-acquired")
	await action("stairs");check("stairs_change_player_layer",room.player_layer==1)
	await rule(1,2)
	check("ceiling_contact_unlocks_cage",await until(func():return room.state.cage_open))
	await rule(1,0);await until(func():return float(room.state.weights[1].elevation)<.02)
	await action("w1","catch")
	if not demo:
		await frames(12);await rule(1,1)
		var stopped:Vector2=room.state.weights[1].pos;await frames(15)
		check("wrong_world_pauses_transport_without_losing_position",room.state.weights[1].mode=="slide" and room.state.weights[1].pos.distance_to(stopped)<.001)
		await rule(1,0)
	check("transport_recovers_after_switch_back",await until(func():return room.state.weights[1].station=="catch" and room.state.weights[1].mode=="rest"))
	await rule(1,1)
	check("heavy_plate_raises_catch",await until(func():return room.state.catch_height>=.99))
	await action("catch");await rule(1,0)
	check("clip_preserves_platform_after_rule_switch",room.state.clip_target=="catch" and room.state.catch_height>=.98)
	await milestone("03-catch-fixed")
	await action("stairs");await action("support");await rule(0,1)
	check("hatch_breaks_by_actual_weight",await until(func():return room.state.hatch_broken))
	await capture("04-cross-layer-fall")
	check("paperweight_lands_in_other_layer",await until(func():return room.state.weights[0].layer==1 and room.state.weights[0].mode=="rest"))
	check("paperweights_remain_unique",room.state.weights.size()==2 and room.state.weights[0].id!=room.state.weights[1].id)
	await milestone("05-lower-received")
	var fixture=preload("res://scripts/save_book.gd").new();fixture.directory=directory.path_join("reopen-save");fixture.write(1,app.active_record)
	if not demo:await resume_through_title()
	await action("stairs");await push_weight(0,"junction");await push_weight(0,"lift")
	await push_weight(1,"junction");await push_weight(1,"sluice");await rule(1,1)
	check("waterwheel_drives_loaded_lift",await until(func():return room.state.weights[0].layer==0 and room.state.lift_height>=4.79))
	await capture("06-waterwheel-lift")
	await action("stairs");await rule(0,0);await push_weight(0,"dock");await milestone("07-upper-dock")
	room.recall_clip();await rule(0,3);await action("bridge");await rule(0,0)
	check("clamped_bridge_keeps_walkable_geometry",room.state.bridge_solid() and room.is_walkable(Vector2(18,11.5),0))
	if not demo:
		check("bridge_is_reachable_by_real_navigation",room.walk_to(Vector2(18,11.5)))
		await until(func():return room.player_plan().distance_to(Vector2(18,11.5))<.12)
		room.recall_clip();check("occupied_bridge_cannot_lose_its_support",room.state.clip_target=="bridge")
	await push_weight(0,"bridge");await push_weight(0,"anchor");await rule(0,1)
	check("upper_anchor_opens_lower_cover",await until(func():return room.state.upper_anchored))
	check("anchored_upper_cannot_be_switched",not room.state.switch_world(0,0))
	await milestone("08-upper-anchored")
	await action("stairs");await rule(1,0);await push_weight(1,"junction");await push_weight(1,"guide");await rule(1,2)
	check("opposite_gravity_completes_dual_anchor",await until(func():return room.state.lower_anchored))
	check("final_rules_are_simultaneous",room.state.worlds==[1,2])
	await milestone("09-dual-anchor")
	# Round-trip every milestone produced by actual play, with no invented completion flags.
	var codec=preload("res://scripts/paper_mill_state.gd")
	for i in range(snapshots.size()):
		var restored=codec.new();restored.restore(snapshots[i].state)
		check("milestone_roundtrip_%d"%i,JSON.stringify(restored.snapshot())==JSON.stringify(snapshots[i].state))
	var legacy:Dictionary=seed_record.duplicate(true);legacy.version=1
	check("legacy_v1_records_remain_valid",app.save_book.valid(legacy,1))
	var malformed:Dictionary=room.snapshot();malformed.state.worlds=[-1,2]
	check("invalid_paper_payload_rejected",not app.save_book.valid_paper(malformed))
	await action("stairs")
	check("can_walk_into_unlocked_door",room.walk_to(room.State.EXIT))
	check("door_crossing_triggers_archive",await until(func():return app.returning))
	check("archive_returns_to_hall",await until(func():return not app.returning and app.current.get("hall_camera")!=null and not app.current.arrival_busy()))
	check("completion_is_separate_from_tutorial",app.paper_runs==1 and app.completed_runs==1)
	check("completed_record_persists",int(app.save_book.inspect(1).data.paper_runs)==1 and app.save_book.inspect(1).data.scene=="hub")
	await capture("10-returned-hall")
	stages.append({"name":"10-returned-hall","demo_seconds":float(Engine.get_physics_frames()-start_frame)/60.0})
	check("completion_archives_dual_anchor_snapshot",bool(app.save_book.inspect(1).data.paper_progress.state.lower_anchored))
	if not demo:
		app.open_level_menu();await frames(3);app.level_menu.expand_crystal()
		await until(func():return app.level_menu.phase==2);app.level_menu.choose_shard(1)
		check("completed_level_can_be_entered_again",await until(func():return app.level_menu==null and app.current.get("level_id")=="paper_mill" and not app.current.arrival_busy()))
		check("completed_level_restarts_cleanly",app.current.state.checkpoint==0 and not app.current.state.clip_owned and not app.current.state.lower_anchored)
		await capture("11-reentered-second-level")
	report();print("MILL_FINISHED checks=",results.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
