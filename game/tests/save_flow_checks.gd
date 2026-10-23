extends Node
var app: Node
var results: Array[Dictionary]=[]
var failures:=0
var directory:=""
var checked_continuous_entry:=false

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition: Callable,limit:=1000) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func check(title: String,passed: bool) -> void:
	results.append({"test":title,"passed":passed})
	if not passed:failures+=1;push_error("SAVE_FAILED "+title)

func key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
		get_viewport().push_input(event,true)

func click(at: Vector2) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		get_viewport().push_input(event,true)

func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func open_picker(motion_off:=false) -> void:
	if motion_off:app.current.motion_enabled=false
	var painting: TextureRect=app.current.background_rect
	var material: ShaderMaterial=painting.material
	app.current.begin()
	check("title_zoom_opens_save_picker",await until(func():return is_instance_valid(app.save_picker)))
	var center: Vector2=app.save_picker.globe_center()
	if not checked_continuous_entry:
		checked_continuous_entry=true
		var picker=app.save_picker
		key(KEY_ENTER);key(KEY_RIGHT)
		click(Vector2(640,500))
		check("card_fade_blocks_early_choice",not picker.ready_for_input() and app.active_slot==0 and not picker.busy)
		check("picker_inherits_actual_painting_and_material",picker.background==painting and picker.background.material==material and painting.texture.resource_path.ends_with("bureau-interior-v4.png"))
		check("continuous_entry_ends_at_final_globe_composition",center.distance_to(Vector2(640,300))<0.5 and picker.background.size==Vector2(1280,800))
		await snapshot("00-continuous-entry-card-fade")
	await until(func():return app.save_picker.ready_for_input())
	check("save_cards_fade_in_without_background_reframing",app.save_picker.cards.all(func(card):return card.modulate.a>0.98) and app.save_picker.globe_center().distance_to(center)<0.01)

func enter_slot(slot: int,card_body:=false) -> void:
	if card_body:
		# Use the record's title area, well outside the action button, including tilted cards.
		var point: Vector2=app.save_picker.cards[slot-1].to_global(Vector2(0,-20))
		click(point);click(point)
	else:
		app.save_picker.select(slot);key(KEY_ENTER)
	check("slot_selection_finishes_scene_entry",await until(func():return app.save_picker==null and not app.menu_revealing and not app.current.has_signal("start_requested")))
	await frames(4)

func storage_checks() -> void:
	var book=preload("res://scripts/save_book.gd").new()
	book.directory=app.save_book.directory.path_join("io-probes")
	check("fresh_store_has_three_empty_slots",[1,2,3].all(func(slot):return book.inspect(slot).status=="empty"))
	var one: Dictionary=book.create(1)
	check("create_record_writes_valid_json",not one.is_empty() and book.inspect(1).status=="ready")
	one.scene="tutorial";one.checkpoint=3;one.story.intro_seen=true
	check("record_progress_can_be_updated",book.write(1,one))
	var reader=preload("res://scripts/save_book.gd").new();reader.directory=book.directory
	check("new_store_instance_reads_previous_progress",int(reader.inspect(1).data.checkpoint)==3 and reader.inspect(1).data.story.intro_seen)
	var two: Dictionary=book.create(2)
	check("profiles_do_not_share_story_or_progress",not two.is_empty() and int(two.checkpoint)==0 and not two.story.intro_seen and int(book.inspect(1).data.checkpoint)==3)
	check("creating_existing_slot_cannot_overwrite_it",book.create(1).is_empty() and int(book.inspect(1).data.checkpoint)==3)
	one.checkpoint=100
	check("invalid_checkpoint_does_not_replace_record",not book.write(1,one) and int(book.inspect(1).data.checkpoint)==3)
	one.checkpoint=2;book.write(1,one)
	var broken:=FileAccess.open(book.path_for(1),FileAccess.WRITE);broken.store_string("{");broken.close()
	check("interrupted_or_corrupt_write_recovers_last_valid_backup",reader.inspect(1).status=="ready" and reader.inspect(1).recovered and int(reader.inspect(1).data.checkpoint)==3)
	broken=FileAccess.open(book.path_for(3),FileAccess.WRITE);broken.store_string('{"version":[1],"slot":"bad"}');broken.close()
	check("malformed_types_are_reported_without_overwriting",book.inspect(3).status=="damaged" and book.create(3).is_empty() and FileAccess.get_file_as_string(book.path_for(3)).contains("bad"))
	check("invalid_slot_numbers_cannot_create_files",book.create(0).is_empty() and book.create(4).is_empty())
	book.remember(2);check("last_used_slot_survives_reload",reader.last_slot()==2)

func run(flow: Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://save-checks")
	DirAccess.make_dir_recursive_absolute(directory)
	if not Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--save-dir=")):
		push_error("Save tests require their own --save-dir");get_tree().quit(1);return
	await frames(5)
	if "--save-reopen" in OS.get_cmdline_user_args():
		await open_picker();check("reopened_process_shows_completed_record",int(app.save_picker.cards[1].record.data.completed_runs)==1)
		await snapshot("05-reopened-records");await enter_slot(2)
		check("fresh_process_restores_completed_hub",app.active_slot==2 and app.completed_runs==1 and app.current.cleared)
		check("other_slot_remains_a_fresh_story",not app.save_book.inspect(1).data.story.intro_seen and int(app.save_book.inspect(1).data.completed_runs)==0)
		await finish();return
	await storage_checks()
	await open_picker()
	check("all_three_live_cards_are_empty",app.save_picker.cards.all(func(card):return card.record.status=="empty"))
	await snapshot("01-empty-save-slots")
	key(KEY_RIGHT);check("keyboard_selects_second_card",app.save_picker.selected==2)
	check("selecting_card_does_not_create_a_save",app.save_book.inspect(2).status=="empty" and app.active_slot==0)
	key(KEY_M);await frames(2);check("mute_shortcut_works_in_save_picker",app.ambience.muted);key(KEY_M)
	await enter_slot(2,true)
	check("empty_slot_starts_fresh_hub",app.active_slot==2 and app.current.get("state")==null and app.completed_runs==0 and not app.dialogue.intro_seen)
	app.dialogue.enabled=true
	click(app.current.world_to_screen(app.current.npc_art.to_global(Vector2(0,-70))))
	check("new_record_can_start_opening_story",await until(func():return app.dialogue.modal))
	await frames(9);key(KEY_ESCAPE);await frames(4);app._save_progress(true)
	check("seen_story_is_written_to_selected_slot",app.save_book.inspect(2).data.story.intro_seen)
	app.dialogue.enabled=false;app.dialogue.clear()
	app.open_level_menu();await frames(3);app.level_menu.select_level()
	await until(func():return app.level_menu.phase==2);app.level_menu.select_level()
	check("profile_enters_real_tutorial",await until(func():return app.level_menu==null and app.current.get("state")!=null and not app.current.arrival_busy()))
	var room=app.current
	var checkpoints_valid:=true
	for stage in range(6):
		app.checkpoint_codec.restore(room,stage);await frames(4)
		checkpoints_valid=checkpoints_valid and room.state.stage()==stage and room.actor_position_is_clear(room.player.position) and room.state.rail_speed==0 and room.state.vertical_speed==0
	check("all_six_checkpoints_restore_consistent_puzzle_state",checkpoints_valid)
	app.checkpoint_codec.restore(room,0);await frames(3)
	room.request_push();check("real_push_reaches_first_checkpoint",await until(func():return room.state.stage()==1))
	await frames(4);check("stable_transport_checkpoint_autosaves",int(app.save_book.inspect(2).data.checkpoint)==1)
	room.change_world(1);check("real_heavy_world_sets_star",await until(func():return room.state.first_latched and not room.casting))
	await frames(4);app._save_progress(true)
	check("star_checkpoint_and_playtime_are_saved",int(app.save_book.inspect(2).data.checkpoint)==2 and float(app.save_book.inspect(2).data.play_seconds)>0)
	key(KEY_F10);await frames(5);await open_picker()
	check("existing_slot_shows_real_checkpoint_summary",app.save_picker.cards[1].record.status=="ready" and app.save_picker.cards[1].progress=="星位已定")
	await snapshot("02-existing-record")
	var before: String=FileAccess.get_file_as_string(app.save_book.path_for(2))
	key(KEY_ESCAPE);await frames(4)
	check("cancel_returns_to_menu_without_rewriting_save",app.current.has_signal("start_requested") and not app.current.starting and FileAccess.get_file_as_string(app.save_book.path_for(2))==before)
	await open_picker(true)
	await enter_slot(1,true)
	check("another_empty_slot_has_independent_story_and_progress",app.active_slot==1 and not app.dialogue.intro_seen and app.completed_runs==0 and int(app.save_book.inspect(2).data.checkpoint)==2)
	key(KEY_F10);await frames(5);await open_picker();await snapshot("03-two-independent-records")
	await enter_slot(2,true);room=app.current
	check("continue_restores_scene_and_star_checkpoint",room.get("state")!=null and room.state.first_latched and room.state.stage()==2 and app.dialogue.intro_seen and not room.player.controls_locked)
	await snapshot("04-restored-star-checkpoint")
	while room.world_cooldown>0 or room.casting:await frames(1)
	room.change_world(0);await until(func():return not room.casting);room.request_push()
	check("loaded_game_can_continue_to_rail_end",await until(func():return room.state.stage()==3))
	while room.world_cooldown>0 or room.casting:await frames(1)
	room.change_world(2);check("loaded_game_can_activate_moon",await until(func():return room.state.receiver_latched))
	while room.world_cooldown>0 or room.casting:await frames(1)
	room.change_world(1);check("loaded_game_can_complete_seal",await until(func():return room.gate_ready))
	await frames(4)
	room.queue_destination(room.portal_position)
	check("loaded_game_returns_through_archive",await until(func():return app.returning))
	check("success_is_saved_before_archive_finishes",app.save_book.inspect(2).data.scene=="hub" and int(app.save_book.inspect(2).data.completed_runs)==1)
	await until(func():return not app.returning and not app.current.arrival_busy())
	app._save_progress(true)
	check("completion_does_not_modify_other_slot",int(app.save_book.inspect(1).data.completed_runs)==0 and not app.save_book.inspect(1).data.story.intro_seen)
	await finish()

func finish() -> void:
	var file:=FileAccess.open(directory.path_join("save-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"));file.close()
	print("SAVE_TEST_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
