extends Node
## Real input + real puzzle, with the production dialogue director enabled.
var app: Node
var results: Array[Dictionary]=[]
var failures := 0
var directory := ""

func check(title: String,passed: bool,details: Dictionary={}) -> void:
	results.append({"test":title,"passed":passed,"details":details})
	if not passed:failures+=1;push_error("DIALOGUE_FAILED "+title)

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition: Callable,limit: int=1000) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func key(code: int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
		get_viewport().push_input(event,true)

func click(at: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;get_viewport().push_input(event,true)

func snapshot(title: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(title+".png"))

func ready_world(room: Node) -> void:
	await until(func():return not room.casting and room.world_cooldown<=0.001 and not room.interacting)

func run(flow: Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://dialogue-checks")
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(8)
	var d=app.dialogue
	check("dialogue_suite_uses_real_enabled_director",d.enabled)
	app.current.begin()
	check("title_starts_room_arrival_before_story",await until(func():return app.menu_revealing))
	# The illustrated-globe camera transition precedes the actor's entry beat.
	await until(func():return is_instance_valid(app.current.get("entry_effect")) and app.current.entry_effect.active)
	var hub=app.current
	var first_entry_duration: float=hub.entry_effect.duration
	check("first_arrival_uses_full_establishing_beat",hub.entry_effect.first_visit and first_entry_duration>=1.5 and hub.player.controls_locked and not d.modal)
	await frames(28)
	key(KEY_F10);key(KEY_E)
	click(hub.world_to_screen(hub.npc_art.to_global(Vector2(0,-70))))
	check("arrival_blocks_return_and_early_conversation",app.current==hub and not d.modal and not app.request_title_return())
	await snapshot("00a-hall-fade-in")
	await frames(60)
	check("arrival_shows_location_and_walks_in_without_dialogue",hub.arrival_title.visible and hub.arrival.age>0 and hub.player.position.distance_to(hub.arrival.origin)>5 and not d.modal)
	await snapshot("00b-rift-arrival")
	check("arrival_finishes_and_releases_movement",await until(func():return not app.menu_revealing) and not hub.arrival_busy() and not hub.player.controls_locked)
	await frames(120)
	check("looking_around_never_starts_opening_on_a_timer",not d.modal and not d.intro_seen and d.active.is_empty() and hub.desk_beacon.visible)
	check("desk_beacon_marks_walkable_conversation_ground",hub.navigation.is_safe(hub.desk_beacon.position) and hub.actor_position_is_clear(hub.desk_beacon.position) and hub.desk_beacon.position.distance_to(hub.npc.position)<=145)
	check("movement_guide_floats_at_bottom_center_without_panel",hub.movement_hint.visible and hub.movement_hint.opacity>0.99 and hub.movement_hint.position.x+hub.movement_hint.size.x*0.5==640 and hub.movement_hint.mouse_filter==Control.MOUSE_FILTER_IGNORE and not hub.movement_hint is Panel)
	var mouse_motion:=InputEventMouseMotion.new();mouse_motion.position=Vector2(800,650)
	get_viewport().push_input(mouse_motion,true);await frames(2)
	check("moving_pointer_keeps_movement_guide_visible",not hub.movement_hint.dismissed and hub.movement_hint.visible)
	await snapshot("00c-free-exploration")
	var before_exploring: Vector2=hub.player.position
	Input.action_press("walk_left");await frames(12);Input.action_release("walk_left")
	check("player_can_explore_before_first_conversation",hub.player.position.distance_to(before_exploring)>10 and not d.modal)
	check("WASD_gradually_fades_movement_guide",hub.movement_hint.dismissed and hub.movement_hint.opacity>0 and hub.movement_hint.opacity<0.99)
	await snapshot("00d-movement-hint-fading")
	await frames(55)
	check("movement_guide_stays_gone_after_first_movement",not hub.movement_hint.visible and hub.movement_hint.opacity==0)
	hub.reset_player()
	await frames(3)
	check("reset_does_not_replay_movement_guide",not hub.movement_hint.visible)
	click(hub.world_to_screen(hub.npc_art.to_global(Vector2(0,-70))));await frames(3)
	check("clicking_tesla_starts_initial_story",d.modal and d.segment=="opening" and not hub.desk_beacon.visible)
	var original: Vector2=hub.player.position
	check("opening_actor_faces_tesla",hub.player.facing_row==2 and hub.player._last_direction.dot(hub.player.global_position.direction_to(hub.npc.global_position))>0.99)
	Input.action_press("walk_right");await frames(12);Input.action_release("walk_right")
	check("opening_blocks_movement_and_world_input",hub.process_mode==Node.PROCESS_MODE_DISABLED and hub.player.position.distance_to(original)<0.1 and app.level_menu==null)
	d.view.body.visible_characters=-1
	check("tesla_portrait_on_right_with_text_clear",d.view.portrait.position.x>d.view.body.position.x+d.view.body.size.x and d.view.name_label.text=="特斯拉")
	check("story_controls_do_not_cover_portrait",not d.view.portrait.get_global_rect().intersects(d.view.next_button.get_global_rect()) and not d.view.portrait.get_global_rect().intersects(d.view.skip_button.get_global_rect()))
	check("story_body_fits_two_lines",d.view.body.get_line_count()<=2 and d.view.body.get_line_height()*d.view.body.get_line_count()<=d.view.body.size.y)
	await snapshot("01-tesla-story")
	await frames(9);key(KEY_SPACE);await frames(2)
	check("space_advances_to_yanyue",d.active.speaker=="yanyue" and d.view.portrait.position.x<d.view.body.position.x)
	d.view.body.visible_characters=-1;await snapshot("02-yanyue-story")
	check("ordinary_story_does_not_show_item",not d.view.item_exhibit.visible)
	while d.active.get("visual","")!="overlap":d.advance()
	check("overlap_waits_for_spoken_world_name",not d.view.world_overlap.visible)
	d.view.body.visible_characters=-1;await frames(35)
	check("overlap_introduction_shows_three_worlds",d.view.world_overlap.active and d.view.world_overlap.layer_offsets.size()==3 and not d.view.item_exhibit.visible)
	var initial_separation: float=d.view.world_overlap.layer_offsets[0].distance_to(d.view.world_overlap.layer_offsets[2])
	await snapshot("02a-worlds-separated")
	await frames(100)
	check("parallel_world_layers_converge",d.view.world_overlap.layer_offsets[0].distance_to(d.view.world_overlap.layer_offsets[2])<initial_separation*0.25)
	await snapshot("02aa-worlds-overlapping")
	var overlap_age: float=d.view.world_overlap.age
	d.advance();await frames(2)
	check("short_opening_clears_overlap_on_next_ordinary_line",not d.view.world_overlap.active and d.active.text=="那该怎么修？" and overlap_age>0)
	while d.active.get("exhibit","").is_empty():d.advance()
	check("item_waits_until_name_is_revealed",not d.view.item_exhibit.visible)
	d.view.body.visible_characters=-1;await frames(38)
	check("first_paperweight_mention_reveals_real_model",d.view.item_exhibit.visible and d.view.item_exhibit.active_item=="paperweight" and d.view.item_exhibit.model.get_child_count()>10 and d.view.item_exhibit.modulate.a>0.99)
	check("item_display_leaves_story_text_and_portrait_clear",d.view.item_exhibit.position.y+d.view.item_exhibit.size.y<d.view.paper.position.y and d.view.item_exhibit.position.x+d.view.item_exhibit.size.x<d.view.portrait.position.x)
	await snapshot("02b-paperweight-introduction")
	d.advance();await frames(2)
	check("continuing_hides_item_and_stops_rendering",not d.view.item_exhibit.visible and d.view.item_exhibit.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	d.play("exhibit-skip",[d.Lines.opening().filter(func(item):return item.exhibit=="paperweight")[0]],false)
	d.view.body.visible_characters=-1;await frames(2)
	key(KEY_M);await frames(2)
	check("mute_still_works_during_modal_story",app.ambience.muted)
	key(KEY_M);key(KEY_ESCAPE);await frames(2)
	check("skip_restores_hub_and_keeps_next_destination",not d.modal and hub.process_mode==Node.PROCESS_MODE_INHERIT and not hub.player.controls_locked and d.active.text.contains("星系仪"))
	check("skipping_story_clears_item_exhibit",not d.view.item_exhibit.visible)
	hub.player.face_toward(hub.player.global_position+Vector2(-100,100))
	click(hub.world_to_screen(hub.npc_art.to_global(Vector2(0,-70))));await frames(3)
	check("click_tesla_reopens_contextual_conversation",d.modal and d.active.text.contains("星系仪"))
	check("reopened_conversation_turns_actor_back_to_tesla",hub.player.facing_row==2 and hub.player._last_direction.dot(hub.player.global_position.direction_to(hub.npc.global_position))>0.99)
	key(KEY_ESCAPE);await frames(2)
	app.open_level_menu();await frames(3)
	check("selection_has_unboxed_subtitles",d.view.mode=="subtitle" and not d.modal and app.level_menu!=null)
	check("starfield_subtitles_use_light_ink_and_speaker_avatar",d.view.subtitle_dark_background and d.view.subtitle.get_theme_color("default_color")==Color("f5f1e6") and d.view.subtitle_avatar.visible and d.view.subtitle_avatar.speaker==d.active.speaker)
	check("starfield_dialogue_draws_above_opaque_selection_background",d.view.layer>app.level_menu.layer)
	await frames(8);await snapshot("02c-chibi-starfield")
	app.level_menu.select_level()
	await until(func():return app.level_menu.phase==2)
	await frames(2)
	check("split_uses_one_brief_menu_hint_without_duplicate_npc_lines",d.active.is_empty() and app.level_menu.subtitle.text.contains("世界碎片"))
	app.level_menu.select_level()
	check("selection_clears_old_dialogue_during_flight",await until(func():return d.active.is_empty()))
	check("real_rift_enters_tutorial",await until(func():return app.level_menu==null and app.current.get("state")!=null and not app.current.arrival_busy()))
	var room=app.current
	await frames(3)
	check("entry_uses_subtitles_without_locking_gameplay",d.view.mode=="subtitle" and not d.modal and not room.player.controls_locked)
	check("calibration_subtitles_use_warm_text_on_glass_plate",d.view.level_subtitle_plate.visible and d.view.subtitle.get_theme_color("default_color")==preload("res://scripts/instrument_theme.gd").TEXT)
	var guide=room.orbit_view.teaching
	for i in range(8):
		if d.active.get("visual","")=="anchors":break
		d.timer=0;await frames(1)
	check("three_anchor_cue_is_driven_by_actual_dialogue",d.active.get("visual","")=="anchors" and guide.mode=="anchors")
	await frames(40)
	check("anchor_sequence_starts_at_star",guide.anchor_index==0 and room.orbit_view.landmarks.teaching_index==0 and not room.player.controls_locked)
	await snapshot("03a-anchor-star")
	await frames(78)
	check("anchor_sequence_then_targets_moon",guide.anchor_index==1)
	await snapshot("03b-anchor-moon")
	await frames(78)
	check("anchor_sequence_ends_at_seal_pad",guide.anchor_index==2 and guide.anchor_history==[0,1,2])
	await snapshot("03c-anchor-seal")
	room.orbit_view.set_anchor_highlight(1)
	d.play("test-ice-lesson",[d.Lines.tutorial(0).filter(func(item):return item.visual=="law-ice")[0]],false)
	await frames(3)
	check("teaching_cleanup_preserves_user_hover",room.orbit_view.landmarks.hovered_index==1 and room.orbit_view.landmarks.teaching_index==-1)
	room.orbit_view.set_anchor_highlight(-1)
	check("ice_rule_annotates_real_object_without_simulating_it",guide.mode=="law-ice" and guide.law_world==0 and room.state.rail_position==0 and not d.modal)
	var rule_label: Rect2=guide.safe_label_rect(guide.target_position()+Vector2(-115,-115))
	check("rule_label_avoids_actor_mechanisms_and_HUD",guide.occupied_rects().all(func(area):return not rule_label.intersects(area)))
	var guide_target: Vector2=guide.target_position()
	room.orbit_view.set_angle(45);await frames(3)
	check("law_arrows_follow_camera_projection",guide.target_position().distance_to(guide_target)>8 and guide.target_position().distance_to(room.orbit_view.logic_to_screen(room.block_ground_position(),0.22+room.state.elevation/room.orbit_view.HEIGHT_PIXELS))<0.1)
	room.orbit_view.reset_view();await frames(3)
	await snapshot("03d-ice-rule")
	room.show_hint();await frames(2)
	check("new_hint_clears_previous_scene_annotation",guide.mode.is_empty())
	check("H_uses_tesla_light_frame_above_world_instruments",d.view.mode=="light" and not d.modal and d.view.paper.instrument and d.view.paper.get_global_rect().end.y<room.hud.skill_panel.position.y and not room.hud.footer.visible and room.hud.skill_panel.visible)
	await snapshot("03-tesla-light")
	room.request_push()
	check("real_push_reaches_first_plate",await until(func():return room.state.rail_position>=room.State.FIRST_STOP))
	await frames(3)
	check("first_plate_uses_yanyue_light_frame",d.phase==1 and d.view.mode=="light" and d.active.speaker=="yanyue")
	await snapshot("04-yanyue-light")
	for i in range(5):
		if d.active.get("visual","")=="law-heavy":break
		d.timer=0;await frames(1)
	check("heavy_lesson_previews_the_requested_rule",guide.mode=="law-heavy" and guide.law_world==1 and room.state.world==0)
	await frames(5);await snapshot("04a-heavy-preview")
	for value in [-45.0,45.0]:
		room.orbit_view.set_angle(value);await frames(3)
		var safe:=true
		for target in [room.first_plate,room.rail_end,room.portal_position]:
			safe=safe and not d.view.paper.get_global_rect().has_point(room.orbit_view.logic_to_screen(target))
		check("light_panel_clears_mechanisms_at_%d"%int(value),safe)
		await snapshot("05-light-angle-%d"%int(value))
	room.orbit_view.reset_view()
	await ready_world(room);room.change_world(1)
	check("heavy_activates_star",await until(func():return room.state.first_latched))
	await frames(32)
	check("stage_progress_replaces_stale_weight_instruction",d.phase==2 and d.segment=="stage-2" and d.active.style=="aside" and d.pending.all(func(item):return not item.text.contains("切到重力世界")))
	check("heavy_confirmation_shows_actual_pressure",guide.mode=="law-heavy" and room.state.world==1)
	await snapshot("06-yanyue-aside")
	await ready_world(room);room.change_world(0);await until(func():return not room.casting)
	room.request_push();check("real_transport_reaches_end",await until(func():return room.state.rail_position>=room.State.RAIL_LENGTH))
	check("moon_default_prompts_leave_rule_choice_to_player",d.phase==3 and ([d.active]+d.pending).all(func(item):return not item.text.contains("倒悬") and not item.cue.contains("3")))
	room.show_hint();room.show_hint();await frames(2)
	check("requested_second_hint_previews_upward_gravity",guide.mode=="law-inverted" and guide.law_world==2 and room.state.world==0)
	await frames(4);await snapshot("06a-inverted-preview")
	await ready_world(room);room.change_world(2)
	await until(func():return room.state.elevation>5 and guide.mode=="law-inverted")
	check("first_float_connects_upward_arrows_to_real_movement",guide.mode=="law-inverted" and room.state.world==2 and room.state.elevation>5)
	await snapshot("06b-inverted-actual")
	check("real_inverted_world_completes_moon",await until(func():return room.state.receiver_latched))
	await frames(32)
	check("moon_uses_unboxed_subtitle",d.phase==4 and d.view.mode=="subtitle" and not d.modal)
	await snapshot("07-moon-subtitle")
	await ready_world(room);room.change_world(1)
	check("real_seal_finishes_before_success_dialogue",await until(func():return room.gate_ready and d.segment=="stage-5"))
	d.timer=0;await frames(2)
	check("tesla_confirmation_uses_small_aside",d.active.speaker=="tesla" and d.view.mode=="aside")
	await snapshot("08-tesla-aside")
	await ready_world(room);room.change_world(0);await until(func():return not room.casting);await frames(3)
	check("lost_pressure_explains_reclosed_gate",not room.gate_ready and d.segment=="gate-lost" and d.pending.size()==1)
	await ready_world(room);room.change_world(1)
	await until(func():return room.gate_ready);await frames(3)
	check("restore_pressure_does_not_repeat_full_success_scene",d.segment=="gate-restored" and d.pending.is_empty())
	await ready_world(room);await frames(3);room.queue_destination(room.portal_position)
	check("real_walk_starts_archive",await until(func():return app.returning))
	check("archive_only_shows_subtitle",d.view.mode=="subtitle" and not d.modal)
	check("return_arrival_finishes_before_debrief",await until(func():return d.modal and d.segment=="debrief"))
	hub=app.current
	check("debrief_locks_after_rift_not_during_it",hub.cleared and not hub.arrival_busy() and hub.process_mode==Node.PROCESS_MODE_DISABLED)
	d.view.body.visible_characters=-1;await snapshot("09-return-debrief")
	key(KEY_ESCAPE);await frames(3)
	app.open_level_menu();await frames(2)
	app.level_menu.select_level();await until(func():return app.level_menu.phase==2)
	app.level_menu.select_level();await until(func():return app.level_menu==null and not app.current.arrival_busy())
	room=app.current;await frames(3)
	check("replay_uses_short_entry_without_opening_story",d.context=="tutorial" and d.tutorial_runs==2 and d.active.text.begins_with("还是这三个步骤") and not d.modal)
	room.reset_tutorial();await frames(3)
	check("R_clears_old_lines_and_uses_short_reset",d.phase==0 and d.segment=="reset" and d.pending.is_empty() and room.state.world==0)
	check("reset_clears_scene_teaching",room.orbit_view.teaching.mode.is_empty() and room.orbit_view.landmarks.teaching_index==-1)
	d.clear();await frames(2)
	check("transient_hud_restored_when_dialogue_hides",not room.hud.dialogue_occupied and not d.view.root.visible)
	# All approved long dialogue lines must fit the real modal body, not just the first page.
	var fitting:=true
	for item in d.Lines.opening()+d.Lines.debrief():
		d.view.present(item.speaker,item.text,"story");await frames(1)
		fitting=fitting and d.view.body.get_line_count()<=2 and d.view.body.get_line_height()*d.view.body.get_line_count()<=d.view.body.size.y
	check("all_opening_and_debrief_lines_fit_at_runtime",fitting)
	var light_fits:=true
	for stage in range(6):
		for item in d.Lines.tutorial(stage):
			if item.style not in ["light","aside"]:continue
			d.view.present(item.speaker,item.text,item.style,item.cue);await frames(1)
			light_fits=light_fits and d.view.body.get_line_count()<=2 and d.view.body.get_line_height()*d.view.body.get_line_count()<=d.view.body.size.y
	check("all_tutorial_light_and_aside_lines_fit_two_lines",light_fits)
	room.state.world=1
	d.play("dynamic-rule",[d.Lines.line("tesla","现在是冰晶世界。导轨的摩擦很小。","light")],false)
	check("pending_rule_uses_actual_world_when_displayed",d.active.text.begins_with("先试试冰晶世界"))
	d.clear()
	# Verify the real serif font's wrapping and BBCode preserve all spoken content.
	var subtitle_lines: Array=d.Lines.selection(false)+d.Lines.selection(true)
	for stage in range(6):subtitle_lines.append_array(d.Lines.tutorial(stage))
	var subtitle_fits:=true
	var subtitle_text_preserved:=true
	var subtitle_glyphs:=true
	var speaker_avatars:=true
	for item in subtitle_lines:
		if item.style!="subtitle":continue
		d.view.present(item.speaker,item.text,"subtitle");await frames(1)
		subtitle_text_preserved=subtitle_text_preserved and ("".join(d.view.caption_pages)==item.text if d.view.level_hud_layout else d.view.subtitle.get_parsed_text()==item.text)
		speaker_avatars=speaker_avatars and d.view.subtitle_avatar.visible and d.view.subtitle_avatar.speaker==item.speaker and d.view.subtitle_avatar.texture!=null and d.view.name_label.visible==d.view.level_hud_layout
		subtitle_fits=subtitle_fits and d.view.subtitle.get_line_count()<=2 and d.view.subtitle.get_content_height()<=d.view.subtitle.size.y
		for character in item.text:
			if not character.strip_edges().is_empty():subtitle_glyphs=subtitle_glyphs and d.view.subtitle_font.has_char(character.unicode_at(0))
	check("serif_subtitles_fit_two_lines_without_clipping",subtitle_fits)
	check("paged_subtitles_preserve_complete_spoken_text",subtitle_text_preserved)
	check("speaker_portrait_and_level_name_are_consistent",speaker_avatars)
	check("subtitle_avatar_leaves_clear_text_gap_and_does_not_block_input",d.view.subtitle_avatar.get_global_rect().end.x+12<=d.view.subtitle.get_global_rect().position.x and d.view.subtitle_avatar.mouse_filter==Control.MOUSE_FILTER_IGNORE and d.view.subtitle.mouse_filter==Control.MOUSE_FILTER_IGNORE)
	check("packaged_serif_covers_all_subtitle_characters",subtitle_glyphs)
	d.play("subtitle-specimen",[d.Lines.line("tesla","先定星位，再压月痕，最后封界缝。这一片区域就能稳定下来。")],false)
	await frames(9);await snapshot("10-tesla-chibi-subtitle")
	d.play("subtitle-yanyue-specimen",[d.Lines.line("yanyue","原来同一个物品，在不同世界里真的会有不同的作用。")],false)
	await frames(9);await snapshot("11-yanyue-chibi-subtitle")
	d.clear()
	key(KEY_F10);await frames(4)
	d.intro_seen=false
	app.current.begin()
	await until(func():return app.menu_revealing)
	await until(func():return is_instance_valid(app.current.get("entry_effect")) and app.current.entry_effect.active)
	hub=app.current
	check("returning_from_title_uses_short_arrival",not hub.entry_effect.first_visit and hub.entry_effect.duration<first_entry_duration)
	await until(func():return not app.menu_revealing)
	await frames(55)
	click(hub.world_to_screen(hub.player.position+Vector2(-20,0)));await frames(15)
	check("ground_click_gradually_dismisses_movement_guide",hub.movement_hint.dismissed and hub.movement_hint.opacity>0 and hub.movement_hint.opacity<0.99)
	await frames(50)
	check("mouse_dismissed_guide_never_reappears",not hub.movement_hint.visible)
	var approach: Vector2=hub.desk_beacon.position
	check("tesla_has_reachable_conversation_approach",not hub.navigation.find_path(hub.player.position,approach).is_empty())
	click(hub.world_to_screen(approach))
	check("walking_near_tesla_starts_initial_story",await until(func():return d.modal) and d.segment=="opening" and hub.player.position.distance_to(hub.npc.position)<=145)
	key(KEY_ESCAPE);await frames(90)
	check("staying_near_tesla_does_not_repeat_opening",not d.modal and d.intro_seen and not hub.desk_beacon.visible)
	d.clear()
	var report:={"checks":results.size(),"failures":failures,"results":results,"dialogue_history":d.history}
	var file:=FileAccess.open(directory.path_join("dialogue-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("DIALOGUE_TEST_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
