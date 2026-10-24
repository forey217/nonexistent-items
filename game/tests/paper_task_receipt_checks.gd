extends Node
const S=preload("res://scripts/paper_mill_state.gd")
var app:Node
var room:Node
var card:Control
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0
var frame_index:=0

func check(label:String,passed:bool) -> void:
	results.append({"test":label,"passed":passed});print("RECEIPT ",label," ",passed)
	if not passed:failures+=1;push_error("RECEIPT_FAILED "+label)
	var f:=FileAccess.open(directory.path_join("task-receipt-report.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"native":DisplayServer.get_name()!="headless","results":results},"  "))

func frames(n:int) -> void:
	for i in range(n):await get_tree().process_frame

func update(dt:float,simulate:=false) -> void:
	if simulate:room.state.step(dt)
	room.hud.refresh(0);card.tick(dt);room.view._sync(dt)

func fixture() -> void:
	var s=S.new();s.clip_owned=true;s.clip_target="catch";s.catch_height=1.0;s.checkpoint=2
	room.restore({"state":s.snapshot(),"player_layer":1,"player":[8.4,12.5]})
	room.set_physics_process(false);room.player.controls_locked=true
	room.communications.stop();room.communications.enabled=false
	room.hud.entry_hint.offer();room.hud.entry_hint.dismiss();room.hud.message_time=0;room.story_time=0
	room.view.set_process(false);room.view.begin_manual_observation();room.view.frame_to_ui=false
	room.view.framing_height=0;room.view.torso_offset=0;room.view.focus=Vector2(10.8,10.4)
	room.view.zoom=1.15;room.view.target_zoom=1.15;room.view.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	room.view.paper_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;room.view._sync(0)
	card=room.hud.objective_feedback

func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await frames(3)
	RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(true)
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func fall_to_rest() -> void:
	room.state.release_support();room.state.switch_world(0,1)
	for i in range(500):
		update(1.0/120.0,true)
		if room.state.weights[0].station=="catch" and room.state.weights[0].mode=="rest":return
	check("fall_completed_within_physics_limit",false)

func checks() -> void:
	fixture()
	check("loaded_current_task_is_quiet",card.phase=="idle" and card.pending.is_empty())
	check("loaded_checkpoint_keeps_existing_number",card.current.number==3 and card.current.text=="让山纹镇纸安全落到下层接物区")
	room.state.checkpoint=3;update(.01)
	check("checkpoint_increment_is_not_completion",card.phase=="idle" and card.history.is_empty())
	room.state.checkpoint=2;room.state.worlds.assign([3,0]);room.observe(0);room.view.angle=45;update(.01)
	check("world_camera_observation_never_stamp",card.history.is_empty())
	fixture();await shot("01-before")
	room.state.release_support();room.state.switch_world(0,1);update(.02,true)
	check("falling_cannot_claim_arrival",room.state.weights[0].mode=="fall" and card.phase=="idle" and card.history.is_empty())
	for i in range(500):
		update(1.0/120.0,true)
		if room.state.weights[0].mode=="rest" and room.state.weights[0].station=="catch":break
	check("real_landing_starts_one_receipt",card.phase=="stamp" and card.history==[2])
	check("completed_text_and_old_number_are_retained",card.body.text=="让山纹镇纸安全落到下层接物区" and card.current.number==3)
	var home:Vector2=room.hud.objective.position
	update(.20);await shot("02-completed-stamp")
	check("stamp_is_readable_and_panel_expands",card.stamp.visible and card.stamp.modulate.a>.99 and room.hud.objective.size.y>110)
	check("stamp_fits_under_wrapped_body",card.stamp.position.y>=card.body.position.y+card.body.size.y and card.stamp.position.x+card.stamp.size.x<=room.hud.objective.size.x-10)
	update(1.19)
	check("holds_complete_state_for_full_1p2_seconds",card.phase=="stamp" and card.body.text.contains("安全落到"))
	update(.03)
	check("old_page_fades_before_next",card.phase=="out")
	update(.15)
	check("next_text_and_number_change_together",card.phase=="in" and card.current.number==4 and card.body.text=="将山纹镇纸送回上层锚座")
	update(.15);await shot("03-next-task")
	check("next_tag_appears_without_old_stamp",card.next_tag.visible and not card.stamp.visible and card.phase=="idle")
	update(1.01);check("next_tag_fades_after_one_second",not card.next_tag.visible)
	check("panel_origin_stays_fixed",room.hud.objective.position==home)
	for i in range(10):update(.02)
	check("refreshes_do_not_repeat",card.history==[2])
	check("panel_and_all_feedback_pass_mouse",room.hud.objective.mouse_filter==Control.MOUSE_FILTER_IGNORE and card.mouse_filter==Control.MOUSE_FILTER_IGNORE and card.page.mouse_filter==Control.MOUSE_FILTER_IGNORE)
	check("task_panel_removed_from_map_blocking",not room.hud.blocks_map(Vector2(42,120)))
	fixture();fall_to_rest();update(.1)
	var pause_age:float=card.age;room.hud.menu.show();card.tick(1)
	check("pause_freezes_exact_phase_and_age",card.phase=="stamp" and card.age==pause_age)
	room.hud.menu.hide();update(.1);check("resume_continues_from_same_phase",card.age>pause_age)
	var saved:Dictionary=room.snapshot();room.restore(saved)
	check("restore_discards_receipt_and_queue",card.phase=="idle" and card.pending.is_empty() and card.history.is_empty() and not card.stamp.visible)
	check("restore_shows_current_task_immediately",card.body.text==room.state.objective())
	check("snapshot_has_no_new_fields",room.snapshot().keys()==saved.keys())
	fixture();room.hud.audio.preferences.motion_enabled=false;fall_to_rest();update(.08)
	check("reduced_motion_keeps_stamp_without_scaling_or_shift",card.stamp.visible and card.stamp.scale==Vector2.ONE and card.page.position.y==0)
	await shot("04-reduced-motion");room.hud.audio.preferences.motion_enabled=true
	fixture();fall_to_rest();room.state.lifted_once=true;room.state.lift_height=S.HEIGHT
	room.state.weights[0]=room.state.make_weight("mountain",0,S.LIFT,"lift");update(.01)
	room.state.upper_anchored=true;room.state.checkpoint=5;update(.01)
	# The full, longest objective has to fit with a stamp, not merely at idle.
	var long_text:String=card.TITLES[5]
	room.state.lower_anchored=true;room.state.checkpoint=6;update(.01)
	check("consecutive_real_facts_are_queued_in_order",card.pending.map(func(item):return item.id)==[3,4,5] and card.pending.size()<=7)
	for i in range(80):update(.10)
	check("queue_reaches_latest_task_without_repeats",card.phase=="idle" and card.pending.is_empty() and card.history==[2,3,4,5] and card.body.text==room.state.objective())
	check("long_task_is_not_truncated",card.body.max_lines_visible==-1 and card.body.size.y>=48)
	card.phase="stamp";card.age=.2;card._show({"stage":5,"number":6,"text":long_text});card._pose()
	check("long_completed_task_reserves_separate_stamp_row",card.body.size.y>=60 and card.stamp.position.y>=card.body.position.y+card.body.size.y)
	await shot("05-long-completed-task")
	card.phase="idle";card.age=2;card._show(card.model(6));card._pose()
	room.finished=true;room.hud.refresh(0);card.tick(2)
	check("last_task_keeps_completed_receipt",card.phase=="final" and card.stamp.visible and not card.next_tag.visible and card.pending.is_empty())
	room.finished=false;room.restart()
	check("restart_clears_all_prior_receipts",card.phase=="idle" and card.history.is_empty() and card.pending.is_empty() and card.stage==0)
	for dimensions in [Vector2i(960,540),Vector2i(1920,1080)]:
		DisplayServer.window_set_size(dimensions);await frames(5);room.hud._layout()
		fixture();fall_to_rest();update(.2)
		check("layout_safe_%dx%d"%[dimensions.x,dimensions.y],room.hud.objective.position==Vector2(24,20) and card.stamp.position.y+card.stamp.size.y<=room.hud.objective.size.y)
		await shot("window-%dx%d"%[dimensions.x,dimensions.y])
	DisplayServer.window_set_size(Vector2i(1280,800));await frames(5)

func video_frame() -> void:
	RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(true)
	get_viewport().get_texture().get_image().save_jpg(directory.path_join("frame-%04d.jpg"%frame_index),.95);frame_index+=1

func video() -> void:
	fixture()
	for i in range(24):update(1.0/30);video_frame();await frames(1)
	room.state.release_support();room.state.switch_world(0,1)
	for i in range(180):update(1.0/30,true);video_frame();await frames(1)

func run(flow:Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory);app.show_paper_mill();await frames(5);room=app.current
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	if "--task-receipt-video-check" in OS.get_cmdline_user_args():await video()
	else:await checks()
	print("RECEIPT_FINISHED checks=",results.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
