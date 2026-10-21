extends Node
var directory: String
var checks: Array[Dictionary]=[]
var failures := 0

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition: Callable,limit:=400) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func record(title: String,passed: bool,details: Dictionary={}) -> void:
	checks.append({"test":title,"passed":passed,"details":details})
	if not passed:
		failures+=1
		push_error("ARCHIVE_FAILED "+title+" "+JSON.stringify(details))

func key(code: int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new()
		event.physical_keycode=code;event.pressed=down
		get_viewport().push_input(event,true)

func click(at: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=at;event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		get_viewport().push_input(event,true)

func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func open_gate(room: Node2D) -> void:
	room.state.first_latched=true
	room.state.receiver_latched=true
	room.state.rail_position=room.State.RAIL_LENGTH
	room.state.switch_world(1)
	await until(func():return room.gate_ready)
	await frames(4)

func run(app: Node2D) -> void:
	directory=app.current.artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(5)
	var music_id: int=app.ambience.music.get_instance_id()
	app.show_hub(false);await frames(5)
	record("manual_return_does_not_play_success_archive",not app.returning and app.completed_runs==0 and app.return_effect==null)
	app.show_tutorial();await frames(5)
	var room=app.current
	await open_gate(room)
	record("opening_gate_alone_does_not_start_return",not app.returning and app.completed_runs==0 and room.gate_ready)
	room.player.teleport_for_reset(room.portal_position+Vector2(-78,0));await frames(3)
	room.queue_destination(room.portal_position)
	record("walking_to_exit_starts_archive",await until(func():return app.returning))
	await until(func():return app.return_effect!=null)
	record("finished_room_frozen_and_one_completion_count",app.completed_runs==1 and room.finished and room.process_mode==Node.PROCESS_MODE_DISABLED and room.player.controls_locked)
	app._on_completed();app.show_tutorial();app.show_hub(false)
	record("duplicate_completion_and_scene_requests_are_ignored",app.completed_runs==1 and app.current==room)
	await until(func():return app.return_effect.active)
	var effect=app.return_effect
	record("record_uses_owned_room_image",DisplayServer.get_name()=="headless" or (effect.image!=null and effect.image is ImageTexture and effect.image.get_width()==1280))
	record("record_number_matches_run",effect.number==1 and effect.layer==100)
	var elapsed:=0.0
	var count:=0
	var stamp_checked:=false
	var filed_checked:=false
	var hub_checked:=false
	while app.returning and count<180:
		await frames(1)
		count+=1
		if not is_instance_valid(effect):break
		elapsed=effect.age
		if count==8:
			var rail: float=room.state.rail_position
			key(KEY_R);key(KEY_1);click(Vector2(110,163));click(Vector2(110,90))
			record("reset_world_and_return_buttons_blocked",app.current==room and room.state.rail_position==rail and room.state.world==1 and app.returning)
			key(KEY_M)
			record("mute_remains_available_during_animation",app.ambience.muted and AudioServer.is_bus_mute(0))
			key(KEY_M)
		if elapsed>=0.76 and not stamp_checked:
			stamp_checked=true
			record("stamp_plays_before_filing",effect.stamped and not effect.filed and app.ambience.archive_events==["stamp"])
		if elapsed>=1.23 and not filed_checked:
			filed_checked=true
			record("file_sound_follows_stamp_once",effect.filed and app.ambience.archive_events==["stamp","file"])
		if elapsed>=1.62 and not hub_checked:
			hub_checked=true
			record("hub_swapped_under_cover_and_waits_for_input",effect.revealed and app.current!=room and app.current.cleared and app.current.process_mode==Node.PROCESS_MODE_DISABLED and app.current.player.controls_locked)
		if count%2==0:await snapshot("archive-%03d"%count)
	await frames(4)
	var hub=app.current
	record("animation_finishes_in_about_two_seconds",not app.returning and elapsed>=1.90 and elapsed<2.02,{"effect_seconds":elapsed,"sampled_frames":count})
	record("archive_releases_overlay_and_starts_spatial_arrival",app.return_effect==null and hub.process_mode==Node.PROCESS_MODE_INHERIT and hub.player.controls_locked and hub.arrival_busy() and app.ambience.toggle_button.visible)
	record("arrival_sound_follows_filing_once",app.ambience.archive_events==["stamp","file","arrived"])
	record("music_identity_persists_through_return",app.ambience.music.get_instance_id()==music_id and (DisplayServer.get_name()=="headless" or app.ambience.music.playing) and not app.ambience.muted)
	record("hub_title_starts_after_transition",hub.return_age>0 and hub.return_age<0.15)
	for i in range(26):
		await frames(1)
		if i%2==0:await snapshot("arrival-%02d"%i)
	await until(func():return not hub.arrival_busy())
	record("character_steps_to_clear_hub_spawn",hub.player.position.distance_to(hub.spawn_point)<2 and hub.actor_position_is_clear(hub.player.position) and hub.player.modulate.a>0.99)
	await snapshot("hub-arrival")
	var start: Vector2=hub.player.position
	Input.action_press("walk_right");await frames(8);Input.action_release("walk_right");await frames(2)
	record("WASD_control_restored",hub.player.position.x>start.x+8)
	await frames(30)
	record("arrival_rift_cleans_itself",hub.return_age<0 and not is_instance_valid(hub.arrival.visual))
	app.show_tutorial();await frames(4)
	room=app.current
	record("replay_starts_with_clean_tutorial",not room.finished and not room.gate_ready and room.state.rail_position==0 and not app.returning)
	await open_gate(room)
	room.player.teleport_for_reset(room.portal_position+Vector2(-78,0));await frames(2)
	room.queue_destination(room.portal_position)
	await until(func():return app.return_effect!=null and app.return_effect.active)
	record("second_run_has_new_archive_record",app.return_effect!=null and app.return_effect.number==2 and app.completed_runs==2)
	await until(func():return not app.returning)
	await frames(3)
	record("second_return_has_no_stale_overlay_or_audio",app.return_effect==null and app.current.cleared and app.ambience.music.get_instance_id()==music_id and app.ambience.archive_events==["stamp","file","arrived","stamp","file","arrived"])
	var file:=FileAccess.open(directory.path_join("archive-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks.size(),"failures":failures,"results":checks},"\t"));file.close()
	print("ARCHIVE_TEST_REPORT ",JSON.stringify({"checks":checks.size(),"failures":failures}))
	await app.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
