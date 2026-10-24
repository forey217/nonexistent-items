extends Node
var app:Node
var room:Node
var comm:Node
var directory:=""
var checks:Array[Dictionary]=[]
var failures:=0
const Lines=preload("res://scripts/paper_mill_lines.gd")

func check(title:String,value:bool) -> void:
	checks.append({"test":title,"passed":value});print("PAPER_STORY ",title," ",value)
	if not value:failures+=1

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func capture(title:String) -> void:
	room.hud.refresh(0)
	if DisplayServer.get_name()=="headless":return
	await frames(22);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(title+".png"))

func reset() -> void:
	room.arrival_age=0;room.transition_age=0;room.interacting=false;room.world_cast_time=0;room.finished=false
	room.state=room.State.new();room.player_layer=0;room.view_layer=0
	room.player.controls_locked=false;room.player.walking=false;room.player.cancel_navigation();room.player.teleport_for_reset(Vector2(6,4)*55)
	room.hud.menu.hide();room.hud.record.hide();room.hud.record_pinned=false;room.view.paper_unfold=0
	comm.restore({});comm.history.clear()

func tick(seconds:float) -> void:comm.tick(seconds)
func finish_current() -> void:
	var size:=int(comm.active.get("lines",[]).size())
	for i in range(size):tick(comm.remaining+.01)
func discard_intro() -> void:comm.stop();comm.done["P2-01"]=true

func run(flow:Node) -> void:
	app=flow;room=flow.current;comm=room.communications
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://paper-story-check")
	DirAccess.make_dir_recursive_absolute(directory)
	room.set_physics_process(false)
	reset();room.start_rift_arrival();tick(12)
	check("no_voice_during_rift",comm.active.is_empty() and room.story_time==0)
	room.arrival_age=0;room.player.controls_locked=false;room.view.actor.modulate.a=1
	if is_instance_valid(room.arrival_gate):room.arrival_gate.stop();room.arrival_gate.queue_free()
	tick(1.4)
	check("entry_waits_after_unlock",comm.active.is_empty());tick(.11)
	check("entry_opens_with_real_voice",comm.active.get("key")=="P2-01" and comm.voice.duration>6 and room.hud.portrait.texture!=null)
	check("subtitle_matches_mp3_duration",absf(comm.total-comm.voice.duration-.25)<.001)
	await capture("01-进入纸坊")
	var age:float=comm.remaining;room.hud.menu.show();tick(20)
	check("pause_freezes_subtitle_and_voice",is_equal_approx(age,comm.remaining) and comm.voice.player.stream_paused)
	room.hud.menu.hide();tick(.01);check("resume_unpauses_voice",not comm.voice.player.stream_paused)
	var id:String=comm.active.lines[0].id;var mid:Dictionary=room.snapshot()
	check("unheard_line_not_marked_read",not mid.communications.seen.has(id))
	comm.restore(mid.communications);tick(.81)
	check("interrupted_valid_line_resumes",comm.active.get("lines",[{}])[0].get("id")==id)
	tick(comm.remaining+.01);check("finished_line_marked_read",comm.seen.has(id))
	var saved:Dictionary=comm.snapshot();comm.restore(saved);tick(.81)
	check("reload_skips_finished_line",comm.active.get("lines",[{}])[0].get("id")!=id)
	finish_current();check("opening_has_only_three_lines",comm.done.has("P2-01"))
	reset();discard_intro();room.player.teleport_for_reset(Vector2(5,9.4)*55);tick(4.9)
	check("missing_corridor_observation_delayed",comm.active.is_empty());tick(.11);tick(.01)
	check("missing_corridor_observation_local",comm.active.get("key")=="P2-02")
	room.state.switch_world(0,3);tick(.01)
	check("manifest_cancels_missing_corridor",comm.active.is_empty())
	room.state.acquire_clip();tick(.79);check("acquisition_waits_for_feedback",comm.active.is_empty());tick(.02)
	check("real_pickup_plays_tool_rule",comm.active.get("key")=="P2-03")
	await capture("02-留影夹能力")
	finish_current();room.state.set_clip("catch");tick(1)
	check("failed_clip_does_not_say_success",comm.active.is_empty() and comm.first_target.is_empty())
	room.state.set_clip("bridge");tick(.61)
	check("first_bridge_is_valid_first_use",comm.active.get("key")=="P2-04-bridge")
	finish_current();room.state.switch_world(0,0);tick(.61)
	check("confirm_only_after_retained_world_switch",comm.active.get("key")=="P2-04-confirm" and room.state.bridge_solid())
	finish_current();room.state.catch_height=1;room.state.set_clip("catch");tick(.01);tick(.61)
	check("first_target_change_explains_limit",comm.active.get("key")=="clip-limit")
	reset();discard_intro();room.state.worlds[0]=3;room.state.acquire_clip();tick(.81);finish_current()
	room.state.catch_height=1;room.state.set_clip("catch");tick(.01);tick(.61)
	check("first_catch_plays_matching_line",comm.active.get("key")=="P2-04-catch")
	await capture("03-首次固定接物台")
	finish_current();room.state.hatch_broken=true;room.state.weights[0].mode="fall";tick(1)
	check("falling_is_not_landing",comm.active.is_empty())
	room.state.weights[0].layer=1;room.state.weights[0].mode="rest";room.state.weights[0].station="catch";tick(.81)
	check("actual_cross_layer_rest_plays_landing",comm.active.get("key")=="P2-05")
	check("landing_goal_does_not_spoil_waterwheel",room.state.objective()=="将山纹镇纸送回上层锚座")
	finish_current();tick(2);check("landing_not_repeated",comm.active.is_empty())
	room.state.weights[0].layer=0;room.state.weights[0].station="lift";room.state.lifted_once=true;room.state.lift_height=room.State.HEIGHT;tick(.01);tick(1.01)
	check("upper_return_goal_reaffirmed",comm.active.get("key")=="P2-06")
	finish_current();room.state.upper_anchored=true;tick(.81)
	check("upper_anchor_moves_goal_to_lower",comm.active.get("key")=="P2-07")
	room.state.lower_anchored=true;tick(1.5)
	check("fast_completion_cancels_old_goal",comm.active.is_empty())
	check("paper_unfold_does_not_count_as_stagnation",comm.idle==0)
	room.view.paper_unfold=1;tick(.99);check("final_waits_after_paper_unfold",comm.active.is_empty());tick(.02)
	check("dual_anchor_closes_story",comm.active.get("key")=="P2-08")
	await capture("04-双锚完成通讯")
	finish_current();check("no_unbuilt_third_level_forecast",not JSON.stringify(comm.history).contains("瓯江孤屿"))
	reset();discard_intro();tick(34.9);check("no_early_automatic_solution",comm.active.is_empty());tick(.11);tick(.01)
	check("idle_35s_only_invites_H",comm.active.get("key")=="idle" and comm.active.lines[0].text=="如果需要一起分析，按 H 联系我。")
	finish_current();tick(70);check("idle_once_per_context",comm.active.is_empty())
	reset();discard_intro();room.transition_age=2;tick(80);check("stairs_do_not_count_as_idle",comm.idle==0)
	room.transition_age=0;room.world_cast_time=.5;tick(80);check("world_cast_does_not_count_as_idle",comm.idle==0)
	room.world_cast_time=0;tick(30);comm.notify_attempt();tick(10);check("real_attempt_grants_new_observation_time",comm.active.is_empty())
	room.show_hint();check("H_works_without_waiting",comm.active.key=="hint:tool:1")
	room.show_hint();room.show_hint();room.show_hint()
	check("repeated_H_replaces_clamps_three",comm.active.key=="hint:tool:3" and comm.pending.size()==0 and room.hint_level==3)
	room.state.worlds[0]=3;room.state.acquire_clip();tick(.01)
	check("phase_change_cancels_old_hint",not str(comm.active.get("key","")).begins_with("hint:tool"))
	room.state.lifted_once=true;room.state.weights[0].station="dock";room.state.clip_target="bridge";tick(.01);room.show_hint()
	check("fixed_bridge_hints_transport_instead_of_reclamp",comm.active.key=="hint:transport-upper:1")
	room.observe(1);tick(.01);check("observing_other_layer_keeps_valid_speech",comm.active.key=="hint:transport-upper:1")
	room.world_cooldown=0;room.change_world(0,0);tick(.01)
	check("normal_world_change_keeps_valid_goal",comm.active.key=="hint:transport-upper:1")
	var stable:Dictionary=room.stable_snapshot();room.interacting=true;comm.seen["test_finished"]=true
	check("busy_physical_snapshot_keeps_latest_read_progress",room.stable_snapshot().communications.seen.has("test_finished"));room.interacting=false
	comm.restore({},true);tick(2);check("legacy_save_does_not_replay_opening",comm.active.is_empty())
	check("legacy_save_keeps_future_nodes_available",not comm.done.has("P2-07") and not comm.done.has("P2-08"))
	room.world_cast_time=0;room.state.upper_anchored=true;tick(.81)
	check("legacy_save_can_play_new_future_progress",comm.active.get("key")=="P2-07")
	reset();discard_intro();tick(20);room.state.catch_height=.1;tick(20)
	check("moving_mechanism_resets_stagnation",comm.idle==0 and comm.active.is_empty())
	room.hud.message_time=0;room.hud.deferred_notice={};comm._begin({"key":"P2-01","priority":10})
	room.hud.message("观察层已调整。");room.hud.refresh(0)
	check("low_priority_toast_waits_behind_dialogue",not room.hud.footer.visible and not room.hud.deferred_notice.is_empty())
	comm.stop();room.hud.refresh(0)
	check("deferred_valid_toast_returns_after_dialogue",room.hud.footer.visible and room.hud.deferred_notice.is_empty())
	reset();discard_intro();app.save_book.directory=directory.path_join("isolated-saves");app.active_slot=1
	app.active_record=app.save_book.create(1)
	if app.active_record.is_empty():app.active_record=app.save_book.inspect(1).data
	app.saving_enabled=true;app.saved_signature="";app._save_progress(true)
	comm._begin({"key":"P2-01","priority":10});var spoken_id:String=comm.active.lines[0].id
	tick(comm.remaining+.01);app._save_progress(false)
	var persisted:Dictionary=app.save_book.inspect(1).data
	check("read_progress_writes_without_physics_change",persisted.get("paper_state",{}).get("communications",{}).get("seen",[]).has(spoken_id))
	app.saving_enabled=false
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/paper_dialogue_v01/manifest.json"))
	check("original_80_clips_and_updated_instructions_present",manifest.items.size()>=80 and comm.voice.entries.size()==manifest.items.size())
	var approved:Array=[]
	for node in Lines.NODES:approved.append_array(Lines.sequence(node))
	for hints in Lines.hint_cases().values():
		for text:String in hints:approved.append(Lines.line("tesla",text))
	check("every_current_line_has_matching_exact_text_audio",approved.all(func(line):return comm.voice.entries.has(line.id) and comm.voice.entries[line.id].display_text==line.text))
	var valid_audio:=true;var fit:=true
	for record in manifest.items:
		var stream:AudioStream=load("res://assets/audio/paper_dialogue_v01/"+record.file)
		# Mutagen counts MP3 encoder padding; Godot reports the decoded gapless duration.
		valid_audio=valid_audio and stream!=null and stream.get_length()>1 and absf(stream.get_length()-float(record.duration_seconds))<.1
		valid_audio=valid_audio and record.voice==("zh-CN-XiaoyiNeural" if record.speaker=="yanyue" else "zh-CN-YunyangNeural")
		room.hud.communicate(record.speaker,record.display_text,float(record.duration_seconds))
		fit=fit and room.hud.subtitle_body.get_line_count()<=2 and record.display_text.length()<=56
	check("all_clips_decode_and_match_approved_voices",valid_audio)
	check("all_subtitles_fit_two_lines_without_shrinking",fit)
	comm.stop();room.hud.refresh(0)
	check("no_dialogue_hides_entire_panel",not room.hud.subtitle_panel.visible)
	var out:=FileAccess.open(directory.path_join("paper-story-report.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify({"suite":"paper_story","native_render":DisplayServer.get_name()!="headless","failures":failures,"checks":checks},"  "))
	print("PAPER_STORY_FINISHED checks=",checks.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
