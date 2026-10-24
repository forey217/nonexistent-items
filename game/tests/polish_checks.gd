extends Node
var room: Node2D
var directory: String
var checks: Array[Dictionary]=[]
var failures := 0

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition: Callable,limit: int=900) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func record(title: String,passed: bool,details: Dictionary={}) -> void:
	checks.append({"test":title,"passed":passed,"details":details})
	if not passed:
		failures+=1
		push_error("POLISH_FAILED "+title+" "+JSON.stringify(details))

func point(at: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=at;event.global_position=at
	get_viewport().push_input(event,true)

func key(code: int) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code;event.pressed=true
	get_viewport().push_input(event,true)
	event=InputEventKey.new()
	event.physical_keycode=code;event.pressed=false
	get_viewport().push_input(event,true)

func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func ready_skill() -> void:
	await until(func():return not room.casting and room.world_cooldown<=0.001)

func run(app: Node2D) -> void:
	room=app.current
	directory=room.artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(280)
	var audio=app.ambience
	var view=room.orbit_view
	var fx=view.feedback
	var air=view.atmosphere
	record("music_is_looping_and_playing_on_separate_bus",audio.music.playing and audio.music.stream.loop and audio.music.bus=="Music" and audio.music.stream.get_length()>30,{"seconds":audio.music.stream.get_length(),"db":audio.music.volume_db})
	record("all_effects_are_loaded_with_finite_lengths",room.sound.STREAMS.size()==9 and room.sound.STREAMS.values().all(func(s):return s.get_length()>0.01 and s.get_length()<5))
	key(KEY_M);await frames(2)
	record("M_mutes_all_audio",audio.muted and AudioServer.is_bus_mute(0) and audio.music.playing)
	key(KEY_M);await frames(2)
	record("M_restores_audio_without_restarting_music",not audio.muted and not AudioServer.is_bus_mute(0) and audio.music.playing)
	for angle in [-45.0,0.0,45.0]:
		view.set_angle(angle);await frames(3)
		point(view.weight_screen_rect().get_center());await frames(18)
		record("weight_hover_at_angle_%d"%int(angle),view.weight_hovered and view.hover_strength>0.99 and view.hover_age<2.8)
		await snapshot("hover-%d"%int(angle))
		point(Vector2(950,680));await frames(12)
	view.set_angle(0);await frames(3)
	point(view.weight_screen_rect().get_center());await frames(185)
	record("hover_text_times_out_but_outline_remains",view.weight_hovered and view.hover_age>2.8 and view.hover_strength>0.99)
	point(room.hud.task_tracker.main_area.get_global_rect().get_center());await frames(15)
	record("hover_does_not_leak_through_task_UI",not view.weight_hovered and view.hover_strength<0.01)
	point(Vector2(950,680));await frames(15)
	var grain_start: Vector3=air.grains[0].position
	await frames(30)
	record("ice_grains_slide_on_floor",air.grains[0].position.x>grain_start.x and is_equal_approx(air.grains[0].position.y,0.065) and air.groups[0].visible and not air.groups[1].visible)
	record("gauge_starts_dark",fx.gauge_lit_count==0)
	room.request_push()
	record("push_reaches_first_stop",await until(func():return room.state.rail_position>=room.State.FIRST_STOP))
	room.change_world(1);await until(func():return not room.casting)
	record("star_sound_matches_actual_latch",room.state.first_latched and "star" in room.sound.events)
	await frames(90)
	record("heavy_pendulum_settles_taut",air.groups[1].visible and absf(air.pendulums[1].rotation.z)<0.002 and not air.groups[0].visible)
	await snapshot("heavy-pendulum")
	await ready_skill();room.change_world(0);await until(func():return not room.casting);room.request_push()
	record("push_reaches_end",await until(func():return room.state.rail_position>=room.State.RAIL_LENGTH))
	await ready_skill();room.change_world(2);await until(func():return not room.casting)
	var paper_start: Vector3=air.papers[0].position
	await until(func():return room.state.elevation>room.State.CEILING*0.45)
	await frames(1)
	record("gauge_fills_during_ascent",fx.gauge_lit_count>3 and fx.gauge_lit_count<12)
	record("inverted_papers_float_up",air.papers[0].position.y>paper_start.y and air.groups[2].visible and not air.groups[1].visible)
	await snapshot("gauge-half")
	record("moon_contacts_receiver",await until(func():return room.state.receiver_latched))
	await frames(2)
	record("moon_stamp_once_at_contact",fx.stamp_count==1 and fx.stamp_left>0 and fx.stamp_ring.visible and "moon" in room.sound.events)
	record("gauge_full_at_receiver",fx.gauge_lit_count==12)
	await snapshot("moon-stamp")
	await frames(35)
	record("stamp_fades_and_does_not_retrigger",fx.stamp_count==1 and not fx.stamp_ring.visible)
	await ready_skill();room.change_world(1)
	record("final_pressure_starts_completion",await until(func():return room.seal_active))
	record("door_still_blocks_during_completion",not room.gate_ready and not room.gate_collision.disabled and room.player.controls_locked and not room.navigation.is_safe(room.portal_position))
	var start_age: float=room.seal_age
	var sequence_start:float=room.task_feedback.clock-start_age
	record("world_switch_cannot_interrupt_seal",not room.change_world(0) and room.state.world==1)
	var locked := true
	var count := 0
	while room.seal_active and count<80:
		await frames(1)
		count+=1
		if room.seal_active:locked=locked and not room.gate_ready and room.player.controls_locked
		if count%2==0:await snapshot("seal-%02d"%count)
	await frames(4)
	record("one_second_completion_then_opens_gate",room.gate_ready and room.seal_completed and room.gate_collision.disabled and locked and absf(float(room.task_feedback.history.filter(func(item):return item.id=="seal")[0].at)-sequence_start-room.SEAL_DURATION)<.035,{"frames":count,"start_age":start_age})
	record("finished_seal_visual_and_navigation_match",view.landmarks.seal.visible and not view.landmarks.crack.visible and room.navigation.is_safe(room.portal_position) and not room.player.controls_locked)
	var events: Array=room.sound.events.duplicate()
	var index: int=events.find("seal_begin")
	record("completion_sound_order_and_no_duplicates",index>=0 and events.slice(index)==["seal_begin","star","moon","success","resonance:anchor"],{"events":events})
	await snapshot("gate-stable")
	var successes: int=events.count("success")
	room.state.switch_world(0);await frames(4)
	record("removing_pressure_recloses_collision",not room.gate_ready and not room.gate_collision.disabled)
	room.state.switch_world(1);await frames(4)
	record("restoring_pressure_does_not_replay_completion",room.gate_ready and not room.seal_active and room.sound.events.count("success")==successes)
	room.reset_tutorial();await frames(4)
	record("reset_clears_stamp_gauge_and_completion",not room.seal_active and not room.seal_completed and not room.gate_ready and fx.stamp_count==0 and fx.gauge_lit_count==0 and not room.hud.completion_label.visible)
	room.state.first_latched=true;room.state.receiver_latched=true;room.state.rail_position=room.State.RAIL_LENGTH;room.state.switch_world(1)
	await frames(20);room.reset_tutorial();await frames(70)
	record("reset_during_sequence_cancels_pending_open_and_sound",not room.gate_ready and not room.gate_collision.disabled and not room.seal_completed and not ("success" in room.sound.events))
	var id: int=audio.music.get_instance_id()
	app.show_hub(false);await frames(4)
	record("music_survives_return_to_hub",audio.music.get_instance_id()==id and audio.music.playing)
	app.show_tutorial();room=app.current;await frames(4)
	record("one_music_player_survives_reentry",app.ambience.music.get_instance_id()==id and audio.music.playing and audio.get_children().filter(func(child):return child is AudioStreamPlayer and child.bus=="Music").size()==1)
	var file:=FileAccess.open(directory.path_join("polish-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks.size(),"failures":failures,"results":checks},"\t"));file.close()
	print("POLISH_TEST_REPORT ",JSON.stringify({"checks":checks.size(),"failures":failures}))
	await app.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
