extends Node
var app:Node
var source:Node
var demo:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0
var before:=""
var disk_hash:=""
var deadline:=0

func _process(_delta:float) -> void:
	if deadline>0 and Time.get_ticks_msec()>deadline:
		deadline=0;push_error("DEMO_TEST_TIMEOUT");get_tree().quit(1)

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func check(title:String,passed:bool) -> void:
	results.append({"test":title,"passed":passed});print("DEMO_CHECK ",title," ",passed)
	if not passed:failures+=1;push_error("DEMO_FAILED "+title)
	var file:=FileAccess.open(directory.path_join("demo-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results,"failures":failures,"native":DisplayServer.get_name()!="headless"},"  "))

func fingerprint() -> String:
	return JSON.stringify({"state":source.state.snapshot(),"weights":source.state.weights,"clock":source.state.clock,"elapsed":source.elapsed,
		"player":source.player.position,"velocity":source.player.velocity,"route":source.player.route,"layer":source.player_layer,
		"view":source.view_layer,"focus":source.view.focus,"angle":source.view.angle,"zoom":source.view.zoom,
		"communications":source.communications.snapshot(),"history":source.communications.history,"feedback":source.task_feedback.snapshot()})

func until(condition:Callable,seconds:=180.0) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		await frames(1)
		if condition.call():return true
	return false

func capture(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func click(at:Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.pressed=down;event.button_index=MOUSE_BUTTON_LEFT
		get_viewport().push_input(event,true)

func run(flow:Node) -> void:
	app=flow;deadline=Time.get_ticks_msec()+300000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://paper-demo-check")
	DirAccess.make_dir_recursive_absolute(directory)
	app.show_paper_mill();source=app.current;await frames(8)
	AudioServer.set_bus_mute(0,true)
	app.save_book.directory=directory.path_join("isolated-saves");app.active_slot=1;app.active_record=app.save_book.create(1)
	if app.active_record.is_empty():app.active_record=app.save_book.inspect(1).data
	app.saving_enabled=true;app._save_progress(true)
	check("demo_entry_exists_only_in_second_level",source.hud.menu.buttons.has("demo"))
	source.state.cage_open=true;source.state.push_direction(1,Vector2.RIGHT);source.hud.menu.open();await frames(2)
	check("can_enter_from_real_mid_slide",source.state.weights[1].mode=="slide")
	await capture("01-menu-demo-entry")
	var menu=source.hud.menu
	check("menu_panel_and_exit_fit_viewport",menu.panel.get_global_rect().end.y<=get_viewport().get_visible_rect().size.y-20 and menu.buttons.has("quit"))
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(Vector2i(960,540));await frames(8)
		# A short logical viewport exercises the scroll fallback, beyond ordinary scaled windows.
		menu.panel.size.y=350;menu.menu_scroll.size.y=294;await frames(2);menu.buttons.quit.grab_focus();await frames(8)
		check("small_menu_scroll_reaches_exit",menu.menu_scroll.scroll_vertical>0 and menu.menu_scroll.get_global_rect().encloses(menu.buttons.quit.get_global_rect()))
		await capture("03-small-window-scrolled-menu")
		DisplayServer.window_set_size(Vector2i(1280,800));await frames(8);menu._layout();menu.menu_scroll.scroll_vertical=0
	# Capture after closing the normal menu, just as dispatch does, without a physics tick.
	source.hud.menu.close();before=fingerprint();disk_hash=FileAccess.get_sha256(app.save_book.path_for(1))
	var record_before:Dictionary=app.active_record.duplicate(true);var counters:Array=[app.paper_runs,app.completed_runs,app.play_seconds]
	source.hud.menu.buttons.demo.pressed.emit();demo=app.paper_demo
	check("original_scene_is_retained",is_instance_valid(source) and source.is_inside_tree() and app.current!=source)
	check("new_demonstration_is_pristine",not demo.room.state.clip_owned and not demo.room.state.hatch_broken and demo.room.state.worlds==[0,0])
	check("all_manual_input_is_owned",demo.room.player.automation_owned and demo.root.mouse_filter==Control.MOUSE_FILTER_STOP)
	check("forced_autosave_is_blocked",not app._save_progress(true) and app._record_snapshot(true).is_empty())
	await frames(30)
	if DisplayServer.get_name()=="headless":demo.toggle_pause()
	else:click(demo.pause_button.get_global_rect().get_center())
	var physical:String=JSON.stringify(demo.room.state.snapshot());var step:int=demo.index;var age:float=demo.elapsed
	await frames(15)
	check("pause_freezes_state_schedule_and_clock",physical==JSON.stringify(demo.room.state.snapshot()) and step==demo.index and is_equal_approx(age,demo.elapsed))
	check("pause_preserves_scene_picture",demo.room.visible and demo.room.hud.visible)
	check("control_bar_stays_inside_viewport",get_viewport().get_visible_rect().encloses(demo.panel.get_global_rect()))
	demo.toggle_pause();await frames(3)
	check("source_mid_motion_remains_exact",fingerprint()==before)
	demo.stop()
	check("early_exit_restores_same_live_instance",app.current==source and fingerprint()==before and source.process_mode!=Node.PROCESS_MODE_DISABLED)
	check("exit_restores_time_scale",is_equal_approx(Engine.time_scale,1.0))
	# Freeze the original in its menu again while the next session starts.
	source.hud.menu.open();source.hud.menu.close();before=fingerprint()
	app.start_paper_demo();demo=app.paper_demo
	var last_index:=-1
	var archive_pause_checked:=false
	var limit:=Time.get_ticks_msec()+180000
	while Time.get_ticks_msec()<limit and demo.mode not in ["done","error"]:
		await frames(1)
		if demo.mode=="archiving" and not archive_pause_checked and is_instance_valid(demo.archive):
			archive_pause_checked=true;demo.toggle_pause();var archive_age:float=demo.archive.age;await frames(8)
			check("archive_can_pause_without_finishing_in_background",is_equal_approx(archive_age,demo.archive.age));demo.toggle_pause()
		if demo.index!=last_index:
			last_index=demo.index;print("DEMO_STAGE ",last_index," seconds=",snappedf(demo.elapsed,.01)," ",demo.status.text)
			if last_index in [12,17,23,33,40]:await capture("stage-%02d"%last_index)
	check("complete_real_route_without_error",demo.mode=="done")
	if demo.mode=="done":
		check("four_short_confirmations_use_original_female_voice",demo.spoken_lines.size()==4 and demo.spoken_lines.all(func(line):return str(line.id).begins_with("vo_yanyue_")))
		check("final_worlds_and_both_anchors_are_real",demo.final_state.upper_anchored and demo.final_state.lower_anchored and demo.final_state.worlds==[1,2])
		check("archive_and_return_to_bureau_complete",is_instance_valid(demo.hub) and not demo.hub.arrival_busy() and demo.history[-1].op=="exit")
		check("roadshow_finishes_within_90_seconds",demo.finished_seconds<=90 and demo.finished_seconds>30)
		await capture("02-demo-completed-in-bureau")
		check("voice_keeps_original_pitch",demo.spoken_lines.all(func(line):return float(line.get("pitch_scale",0))==1.0))
		var timing:=FileAccess.open(directory.path_join("timing.json"),FileAccess.WRITE)
		timing.store_string(JSON.stringify({"wall_seconds":demo.finished_seconds,"steps":demo.history,"final_state":demo.final_state,"speech":demo.spoken_lines},"  "))
	check("no_source_state_or_record_was_changed",fingerprint()==before and app.active_record==record_before)
	check("no_progress_counters_were_incremented",app.paper_runs==counters[0] and app.completed_runs==counters[1])
	check("real_save_file_unchanged",FileAccess.get_sha256(app.save_book.path_for(1))==disk_hash)
	# A repeat must create a new pristine room, and exiting must cancel its old schedule.
	var completed_fixture:Dictionary=demo.final_state.duplicate(true)
	demo.repeat_button.pressed.emit();check("repeat_starts_from_initial_state",demo.index==0 and not demo.room.state.clip_owned and not demo.room.state.lower_anchored)
	if "--demo-repeat-full" in OS.get_cmdline_user_args():
		check("second_full_run_completes_without_residual_state",await until(func():return demo.mode in ["done","error"],150) and demo.mode=="done" and demo.runs_finished==2)
		check("second_run_preserves_four_normal_voice_lines",demo.spoken_lines.size()==4 and fingerprint()==before)
	await frames(10);demo.stop();check("final_exit_restores_original_motion_exactly",fingerprint()==before and app.current==source)
	app.saving_enabled=false
	check("no_controller_or_queued_actions_survive_exit",not is_instance_valid(app.paper_demo) and is_equal_approx(Engine.time_scale,1))
	# A finished source is also retained, rather than replacing it with a checkpoint.
	if not completed_fixture.is_empty():source.state.restore(completed_fixture)
	source.hud.menu.close();source.hud.refresh(0);before=fingerprint();Engine.time_scale=.8
	app.start_paper_demo();demo=app.paper_demo
	check("finished_source_starts_pristine_demo",not demo.room.state.lower_anchored and demo.room.state.checkpoint==0)
	demo.stop();check("custom_simulation_speed_is_restored",is_equal_approx(Engine.time_scale,.8) and fingerprint()==before);Engine.time_scale=1
	app.start_paper_demo();demo=app.paper_demo
	demo.steps.clear();demo.steps.append({"op":"interact","title":"通路异常检查","id":"unreachable-test","rate":2.0})
	await until(func():return demo.mode=="error",10)
	check("unreachable_step_stops_without_forging_completion",demo.mode=="error" and not demo.room.state.upper_anchored and not demo.room.state.lower_anchored)
	demo.stop();check("failure_exit_preserves_original",fingerprint()==before)
	app.start_paper_demo();demo=app.paper_demo
	demo._archive(demo.generation);demo.stop();await frames(2)
	check("exit_during_archive_capture_cancels_late_callbacks",not is_instance_valid(app.paper_demo) and app.current==source)
	app.start_paper_demo();app.request_title_return();await frames(5)
	check("title_return_cleans_demo_before_normal_navigation",not is_instance_valid(app.paper_demo) and app.current.has_signal("start_requested") and is_equal_approx(Engine.time_scale,1))
	app.show_tutorial();await frames(3)
	check("first_level_has_no_second_level_demo_entry",not app.current.hud.menu.buttons.has("demo"))
	print("DEMO_REPORT checks=",results.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
