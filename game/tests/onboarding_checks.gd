extends Node
var app: Node
var results: Array[Dictionary]=[]
var failures:=0
var directory:=""
var elapsed:=0.0
var timing: Dictionary={}
func _physics_process(delta: float) -> void:elapsed+=delta
func check(name: String,passed: bool) -> void:
	results.append({"test":name,"passed":passed})
	if not passed:failures+=1;push_error("ONBOARDING_FAILED "+name)
func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame
func until(condition: Callable,limit:=1400) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false
func click(at: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		get_viewport().push_input(event,true)
func key(code: int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
		get_viewport().push_input(event,true)
func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))
func read_story() -> void:
	var pages:=0
	while app.dialogue.modal and pages<20:
		# A reproducible reading benchmark, not a claim of human usability testing.
		await frames(ceili(maxf(1.2,app.dialogue.active.text.length()/12.0+0.25)*60))
		if pages==0:await snapshot("story-"+app.dialogue.segment+"-full-text")
		app.dialogue.view.advance();await frames(2);pages+=1
func run(flow: Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty() or not Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--save-dir=")):
		push_error("Onboarding tests need isolated --save-dir and --artifacts");get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(5)
	var d=app.dialogue
	check("approved_story_lengths",d.Lines.opening().size()==8 and d.Lines.debrief().size()==5)
	var sample: Dictionary=d.Lines.opening()[0]
	check("voice_id_stable_across_context_and_order",sample.id==d.Lines.line(sample.speaker,sample.text,"subtitle").id)
	check("voice_id_changes_when_exact_text_changes",sample.id!=d.Lines.line(sample.speaker,sample.text+"。").id)
	var legacy=preload("res://scripts/save_book.gd").new();legacy.directory=app.save_book.directory.path_join("legacy-profile")
	var data: Dictionary=legacy.create(1);data.version=1;data.erase("paper_runs");data.erase("paper_progress")
	var old_file:=FileAccess.open(legacy.path_for(1),FileAccess.WRITE);old_file.store_string(JSON.stringify(data));old_file.close()
	check("previous_v39_profile_remains_readable",legacy.inspect(1).status=="ready" and legacy.inspect(1).data.version==1)
	var start_time:=Time.get_ticks_msec();var start_sim:=elapsed
	click(app.current.start_button.get_global_rect().get_center())
	check("title_opens_save_picker",await until(func():return app.save_picker!=null and app.save_picker.ready_for_input()))
	click(app.save_picker.cards[0].to_global(Vector2.ZERO))
	check("new_record_reaches_hub",await until(func():return app.save_picker==null and not app.menu_revealing and app.current.get("hall_camera")!=null))
	var hub=app.current
	click(hub.world_to_screen(hub.desk_beacon.position))
	check("real_walk_to_desk_starts_opening",await until(func():return d.modal))
	await snapshot("01-world-bureau-opening")
	await read_story()
	check("full_read_restores_player_controls",not d.modal and not hub.player.controls_locked and d.intro_seen)
	click(hub.world_to_screen(hub.globe.art.to_global(Vector2.ZERO)))
	check("globe_opens_crystal_selection",await until(func():return app.level_menu!=null))
	click(app.level_menu.CENTER)
	check("crystal_expands",await until(func():return app.level_menu.phase==2))
	key(KEY_ENTER)
	check("first_level_arrives",await until(func():return app.level_menu==null and app.current.get("state")!=null and not app.current.arrival_busy()))
	var room=app.current
	check("interaction_guidance_is_immediately_available",d.Lines.tutorial(0)[0].cue.contains("E") and not room.player.controls_locked)
	room.request_push()
	check("first_push_uses_actual_navigation_and_contact",await until(func():return absf(room.state.rail_speed)>0.1))
	timing={"wall_seconds_to_first_push":(Time.get_ticks_msec()-start_time)/1000.0,"simulation_seconds_to_first_push":elapsed-start_sim,"reading_model":"12中文字符/秒，每页额外0.25秒，至少1.2秒；全读8句开场；真实桌前寻路与镇纸接触；未跳过对白"}
	print("FIRST_PUSH_TIMING ",JSON.stringify(timing))
	check("first_push_within_45_second_simulation_target",float(timing.simulation_seconds_to_first_push)<=45.0)
	check("star_arrival",await until(func():return room.state.stage()==1))
	while room.casting or room.world_cooldown>0:await frames(1)
	room.change_world(1)
	check("star_rule_taught_then_latched",await until(func():return room.state.first_latched and not room.casting))
	await frames(8)
	var toast=app.save_feedback
	check("successful_checkpoint_commit_has_feedback",toast.commits>0)
	toast.clock+=2.0;app._save_progress(true);await frames(15)
	check("save_feedback_nonblocking_and_visible",toast.ink.visible and toast.ink.mouse_filter==Control.MOUSE_FILTER_IGNORE)
	await snapshot("02-checkpoint-saved")
	var commits: int=toast.commits;var displays: int=toast.displays
	app._save_progress();check("unchanged_snapshot_has_no_false_save_feedback",toast.commits==commits)
	app._save_progress(true);check("back_to_back_real_writes_share_one_display",toast.commits==commits+1 and toast.displays==displays)
	var good_dir: String=app.save_book.directory
	var blocker:=FileAccess.open(good_dir.path_join("not-a-directory"),FileAccess.WRITE);blocker.store_string("test");blocker.close()
	app.save_book.directory=good_dir.path_join("not-a-directory/child")
	commits=toast.commits
	var print_errors:=Engine.print_error_messages;Engine.print_error_messages=false
	var failed: bool=not app._save_progress(true)
	Engine.print_error_messages=print_errors
	check("failed_write_cannot_show_saved",failed and toast.commits==commits)
	app.save_book.directory=good_dir;app.save_retry_age=0
	check("failed_write_keeps_previous_real_record",app.save_book.inspect(1).data.checkpoint==2)
	# Isolate the timer: no real player record and no mutation of gameplay rules.
	d.set_process(false);d.clear();d.phase=2;d.idle=0
	d._tick_idle(0);d._tick_idle(34.9)
	check("no_automatic_answer_before_35_effective_seconds",d.active.is_empty())
	d.play("reading-test",d.Lines.event("reminder"),false)
	d._tick_idle(90);check("reading_story_does_not_count_as_idle",is_equal_approx(d.idle,34.9))
	d.clear();d.play("reading-subtitle",d.Lines.event("first-push"),false)
	d._tick_idle(90);check("reading_nonmodal_subtitle_does_not_count_as_idle",is_equal_approx(d.idle,34.9))
	d.clear();room.arrival.active=true;d._tick_idle(90);room.arrival.active=false
	check("arrival_does_not_count_as_idle",is_equal_approx(d.idle,34.9))
	room.casting=true;d._tick_idle(90);room.casting=false
	check("world_animation_does_not_count_as_idle",is_equal_approx(d.idle,34.9))
	room.interacting=true;d._tick_idle(90);room.interacting=false
	check("interaction_animation_does_not_count_as_idle",is_equal_approx(d.idle,34.9))
	room.seal_active=true;d._tick_idle(90);room.seal_active=false
	check("seal_animation_does_not_count_as_idle",is_equal_approx(d.idle,34.9))
	room.state.rail_speed=1;d._tick_idle(90);room.state.rail_speed=0
	check("sliding_does_not_count_as_idle",is_equal_approx(d.idle,34.9))
	room.state.vertical_speed=1;d._tick_idle(90);room.state.vertical_speed=0
	check("floating_does_not_count_as_idle",is_equal_approx(d.idle,34.9))
	d._tick_idle(.2)
	check("automatic_reminder_only_offers_H",d.segment=="idle" and d.active.text=="需要帮助时，按 H 联系特斯拉。" and d.pending.is_empty())
	d.clear();d._tick_idle(90)
	check("automatic_reminder_once_per_stage",d.active.is_empty())
	d.idle=20;key(KEY_A)
	check("fresh_input_resets_effective_idle",d.idle==0)
	d.idle=20;room.player.position+=Vector2(1,0);d._tick_idle(.1)
	check("exploration_resets_effective_idle",d.idle==0)
	for stage in [2,3,4]:
		check("stage_%d_default_does_not_name_next_world"%stage,d.Lines.tutorial(stage).all(func(item):return not item.text.contains("切到") and not item.text.contains("重力世界") and not item.text.contains("倒悬世界") and not item.cue.contains("3")))
	app.checkpoint_codec.restore(room,3);d.phase=3;d.clear();room._hint_level=0;room._hint_stage=-1
	for level in range(1,4):
		room.show_hint()
		check("requested_hint_%d_replaces_queue"%level,d.segment=="hint" and d.pending.is_empty() and d.active.text==room.state.hint(level))
	check("only_last_requested_hint_gives_exact_solution",d.active.text.contains("按3"))
	await snapshot("03-requested-third-hint")
	app.checkpoint_codec.restore(room,4);room.show_hint()
	check("new_stage_restarts_hint_at_observation",room._hint_level==1 and d.active.text==room.state.hint(1))
	app.checkpoint_codec.restore(room,0);d.phase=1;d.clear();d.seen.clear();d.first_float=false
	room.state.world=2;room.state.elevation=5;d._tick_tutorial(0)
	check("early_float_observes_location_without_prescribing_world",d.segment=="early-float" and d.pending.all(func(item):return not item.text.contains("切到")))
	d.set_process(true)
	app.checkpoint_codec.restore(room,3);d.phase=-1;d.seen.clear();await frames(3)
	while room.casting or room.world_cooldown>0:await frames(1)
	room.change_world(2);check("actual_moon_latches",await until(func():return room.state.receiver_latched))
	while room.casting or room.world_cooldown>0:await frames(1)
	room.change_world(1);check("actual_seal_stabilizes",await until(func():return room.gate_ready))
	await frames(6);room.queue_destination(room.portal_position)
	check("archive_and_return_reach_short_debrief",await until(func():return not app.returning and d.modal and d.segment=="debrief"))
	await snapshot("04-five-line-debrief")
	await read_story();await frames(5)
	check("completion_persists_and_controls_unlock",app.save_book.inspect(1).data.completed_runs==1 and not app.current.player.controls_locked)
	d.intro_seen=false;d.talk_to_tesla();await frames(9);key(KEY_ESCAPE);await frames(3)
	check("skipping_new_opening_unlocks_and_keeps_destination",not d.modal and d.intro_seen and d.active.text.contains("星系仪"))
	var file:=FileAccess.open(directory.path_join("onboarding-checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"timing":timing,"results":results},"\t"));file.close()
	print("ONBOARDING_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures,"timing":timing}))
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
