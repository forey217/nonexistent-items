extends Node
var app:Node
var room:Node
var directory:=""
var checks:Array[Dictionary]=[]
var failures:=0

func check(title:String,passed:bool) -> void:
	checks.append({"test":title,"passed":passed})
	print("RESONANCE ",title," ",passed)
	if not passed:failures+=1;push_error("RESONANCE_FAILED "+title)

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func capture(title:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await frames(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(title+".png"))

func paper_tick(delta:float) -> void:
	room.hud.refresh(0);room.task_feedback.tick(delta)

func count_id(id:String) -> int:
	return room.task_feedback.history.filter(func(item):return item.id==id and item.completed).size()

func run(flow:Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://task-resonance-check")
	DirAccess.make_dir_recursive_absolute(directory)
	app.show_tutorial();room=app.current;app.dialogue.enabled=false;room.set_physics_process(false)
	await frames(2)
	var f=room.task_feedback;var s=room.state
	check("fresh_tutorial_is_quiet",f.history.is_empty() and f.effects.is_empty())
	s.rail_position=s.FIRST_STOP;s.world=s.World.HEAVY;s.step(.02)
	room.hud.refresh(s);f.tick(.01)
	check("actual_star_latch_confirms_once",s.first_latched and count_id("star")==1)
	room.hud.task_tracker.pinned=true;room.hud.task_tracker._show_steps()
	f.tick(.40)
	check("latest_goal_updates_during_receipt",room.hud.task_tracker.current_step==1 and room.hud.task_tracker.current_label.text==room.hud.task_tracker.STEPS[1])
	check("open_task_list_stays_open",room.hud.task_tracker.popup.visible)
	await capture("01-星位机关与任务签")
	for i in range(10):f.tick(.02)
	check("held_latch_does_not_repeat",count_id("star")==1)
	s.rail_position=s.RAIL_LENGTH;s.world=s.World.INVERTED;s.elevation=s.CEILING;s.step(.01)
	room.hud.refresh(s);f.tick(.01)
	check("moon_only_after_real_contact",s.receiver_latched and count_id("moon")==1)
	check("both_progress_updates_keep_latest_goal",room.hud.task_tracker.current_step==2)
	f.tick(2)
	check("finished_effects_release_render_nodes",f.effects.is_empty() and room.hud.task_tracker.get_meta("task_transition").age>=1.5)
	app.checkpoint_codec.restore(room,4);f.tick(.05)
	check("restored_tutorial_does_not_replay",f.effects.is_empty())
	app.dialogue.suppress_restored_confirmations()
	check("restored_tutorial_does_not_reconfirm_speech",app.dialogue.phase==4 and app.dialogue.seen.has("stage-4"))
	room.reset_tutorial();check("full_tutorial_restart_resets_first_records",f.seen.is_empty())
	app.show_paper_mill();room=app.current;room.set_physics_process(false)
	room.communications.enabled=true;room.communications.stop();room.communications.done["P2-01"]=true
	await frames(2);f=room.task_feedback;s=room.state
	check("fresh_paper_is_quiet",f.history.is_empty())
	# Real independent waterwheel / empty lift motion. Never manufacture lifted_once.
	s.weights[1].station="sluice";s.weights[1].pos=s.SLUICE;s.worlds[1]=1
	s.step(.01);paper_tick(.01)
	check("waterwheel_is_mechanical_only",f.history.any(func(item):return item.id=="wheel" and not item.completed) and not f.seen.has("lift"))
	for i in range(500):s.step(.012);paper_tick(.012)
	check("empty_lift_arrives_without_cargo_completion",s.lift_docked(0) and not s.lifted_once and count_id("lift")==0 and count_id("lift_top")==0)
	var log_count:int=f.history.size()
	for i in range(60):s.step(.016);paper_tick(.016)
	check("running_waterwheel_does_not_loop_completion",f.history.size()==log_count)
	# Prepare a real catch, support and falling mountain through production state.step.
	s.worlds[0]=3;s.acquire_clip();paper_tick(.01);s.catch_height=1;s.set_clip("catch");paper_tick(.01)
	check("fixed_raised_catch_has_one_completion",count_id("clamp")==1)
	f.tick(.39);room.view_layer=1;room.view.link_time=0;room.view.set_focus(s.DROP,false);room.view._sync(0)
	await capture("02-接物台黄铜扣合")
	s.support_released=true;s.worlds[0]=1;s.step(.02);paper_tick(.01)
	check("falling_is_not_received",s.weights[0].mode=="fall" and count_id("land")==0)
	check("falling_task_does_not_claim_arrival",s.objective()=="让山纹镇纸安全落到下层接物区")
	for i in range(150):s.step(.012);paper_tick(.012)
	check("received_only_at_lower_rest",s.weights[0].mode=="rest" and int(s.weights[0].layer)==1 and count_id("land")==1)
	var saved:Dictionary=room.snapshot();var event_count:int=f.history.size()
	room.restore(saved);paper_tick(.02)
	check("load_clears_effects_and_historical_receipt",f.effects.is_empty() and f.history.size()==event_count and room.hud.objective.get_meta("task_transition").age>=1.5)
	check("event_ids_are_saved",saved.task_feedback.has("clamp") and saved.task_feedback.has("land"))
	check("load_suppresses_unheard_historical_confirmations",room.communications.acknowledged.has("P2-05"))
	s.clip_target="";paper_tick(.01);s.clip_target="catch";paper_tick(.01)
	check("refixed_catch_has_no_repeat_task_completion",count_id("clamp")==1)
	# A passenger alone never sets the mountain event; cargo layer must be real.
	s.lifted_once=true;s.weights[0].mode="rest";s.weights[0].station="lift";s.weights[0].layer=1;s.lift_height=s.HEIGHT
	paper_tick(.01);check("upper_dock_with_lower_cargo_is_not_arrival",count_id("lift")==0)
	s.weights[0].layer=0;paper_tick(.01)
	check("aligned_upper_cargo_confirms_once",count_id("lift")==1)
	# H has priority; delayed observation expires instead of interrupting it.
	var comm=room.communications
	comm.restore({});comm.stop();comm.done["P2-01"]=true;comm.previous=comm._physical()
	comm._begin({"key":"hint:"+comm.Lines.hint_key(s)+":1","priority":100,"lines":[comm.Lines.line("tesla",comm.Lines.hint_cases()[comm.Lines.hint_key(s)][0])]})
	comm._schedule("P2-06",.4,70);comm.tick(.6)
	check("confirmation_does_not_interrupt_H",str(comm.active.get("key","")).begins_with("hint:"))
	comm.remaining=30;comm.tick(8.1)
	check("stale_confirmation_is_discarded",not comm.pending.any(func(item):return item.key=="P2-06"))
	comm.stop();comm.done.clear();comm.acknowledged.clear();comm._schedule("P2-06",.4,70);comm.tick(.41)
	check("return_confirmation_uses_exact_new_voice",comm.active.get("key","")=="P2-06" and comm.voice.current.speaker=="yanyue" and comm.voice.current.display_text=="回来了，这次没走错地方。")
	comm.request_hint();comm.tick(1)
	check("interrupted_confirm_is_not_replayed",comm.acknowledged.has("P2-06") and not comm.pending.any(func(item):return item.key=="P2-06"))
	comm.stop();s.upper_anchored=true;s.lower_anchored=false;paper_tick(.01)
	check("upper_does_not_light_final_exit",count_id("upper")==1 and count_id("dual")==0)
	s.lower_anchored=true;paper_tick(.01);paper_tick(.48)
	room.hud.record.hide();room.hud.record_pinned=false
	room.view_layer=0;room.view.link_time=0;room.view.set_focus(s.UPPER_ANCHOR,false);room.view._sync(0)
	check("dual_anchor_responds_only_with_both_locked",count_id("dual")==1)
	await capture("03-双锚与归位门回应")
	var age:float=f.effects[0].age
	var material_voice:AudioStreamPlayer=room.sound.voices[0]
	material_voice.stream=load("res://assets/audio/resonance_v01/anchor.wav");material_voice.play()
	room.hud.menu.show();room.set_physics_process(true);await frames(6)
	check("pause_freezes_completion_effects",is_equal_approx(f.effects[0].age,age))
	check("pause_freezes_material_audio",material_voice.stream_paused and material_voice.get_playback_position()<.05)
	room.set_physics_process(false);room.hud.menu.hide();paper_tick(3)
	check("rapid_updates_never_restore_old_target",room.hud.objective_body.text==s.objective() and s.objective().contains("归位门"))
	check("quiet_render_after_completion",f.effects.is_empty())
	room.restore(room.snapshot());paper_tick(.1)
	check("stable_final_restore_stays_quiet",f.effects.is_empty())
	room.restart();check("full_paper_restart_resets_completion_records",f.seen.is_empty() and comm.acknowledged.is_empty())
	# No hidden overlays consume map input, and all audio uses existing channels.
	check("task_animation_does_not_block_mouse",room.hud.objective.get_meta("task_transition").mouse_filter==Control.MOUSE_FILTER_IGNORE)
	check("material_and_voice_use_separate_existing_buses",room.sound.voices[0].bus=="SFX" and comm.voice.player.bus=="Dialogue")
	var file:=FileAccess.open(directory.path_join("resonance-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"native":DisplayServer.get_name()!="headless"},"  "))
	print("RESONANCE_FINISHED checks=",checks.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
