extends Node
var app:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func check(title:String,passed:bool) -> void:
	results.append({"test":title,"passed":passed});print("INSTRUMENT_HUD ",title," ",passed)
	if not passed:failures+=1;push_error("INSTRUMENT_HUD_FAILED "+title)
	var report:=FileAccess.open(directory.path_join("hud-report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results,"native_render":DisplayServer.get_name()!="headless"},"\t"))

func point(at:Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=at;event.global_position=at;get_viewport().push_input(event,true)

func click(control:Control) -> void:
	var at:=control.get_global_rect().get_center();point(at)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		get_viewport().push_input(event,true)

func key(code:int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;get_viewport().push_input(event,true)

func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func run(flow:Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://instrument-hud-checks")
	DirAccess.make_dir_recursive_absolute(directory)
	var room=app.current;var ui=room.hud
	point(Vector2(750,530));await frames(280)
	check("tutorial_only_three_compact_groups_at_rest",not ui.menu.visible and not ui.task_tracker.popup.visible and not ui.law_popup.visible and not ui.footer.visible and ui.entry_hint.visible)
	check("legacy_audio_and_title_buttons_hidden",not app.ambience.toggle_button.visible and not app.return_menu_button.visible)
	check("world_buttons_centered_and_within_bottom_safe_margin",absf(ui.skill_panel.get_global_rect().get_center().x-get_viewport().get_visible_rect().size.x*.5)<1 and ui.skill_panel.size.y==64 and ui.skill_panel.position.y==get_viewport().get_visible_rect().size.y-88)
	await shot("01-tutorial-entry")
	ui.entry_hint.dismiss();await frames(46)
	check("entry_hint_finishes_fade_after_first_input",not ui.entry_hint.visible and ui.entry_hint.dismissed)
	await shot("02-tutorial-clean")
	point(ui.task_tracker.main_area.get_global_rect().get_center());await frames(15)
	check("task_expands_without_revealing_solution",ui.task_tracker.popup.visible and room._hint_level==0 and ui.task_tracker.step_labels.size()==3)
	await shot("03-task-details")
	point(Vector2(750,530));await frames(18)
	check("task_details_release_map_when_closed",not ui.task_tracker.popup.visible and not ui.task_tracker.hover_bridge.visible)
	var at:Vector2=room.player.position
	click(ui.worlds[1]);await frames(18)
	check("real_world_button_changes_world_without_map_click",room.state.world==1 and room.player.position==at and not room._pending_click)
	var shared:bool=true
	for b in ui.worlds:shared=shared and is_equal_approx(float(b.get("cooldown_remaining")),room.world_cooldown)
	check("all_three_instrument_rings_share_real_cooldown",shared and room.world_cooldown>0)
	await shot("04-shared-cooldown")
	click(ui.menu_button);await frames(3)
	var cooldown:float=room.world_cooldown
	Input.action_press("walk_right");await frames(12);Input.action_release("walk_right")
	check("menu_pauses_mechanisms_and_blocks_walking",ui.menu.visible and room.player.position==at and room.world_cooldown==cooldown)
	await shot("05-compact-menu")
	click(ui.menu.buttons.options);await frames(20)
	check("shared_archive_options_have_four_channels",ui.menu.options.visible and ui.menu.options.channel_sliders.size()==4)
	ui.menu.options.channel_sliders.music.value=37;await frames(2)
	check("in_game_audio_settings_use_existing_buses",app.ambience.preferences.channels.music==37)
	await shot("06-archive-options")
	click(ui.menu.options.manual_button);await frames(3)
	check("manual_opens_inside_existing_paper_page",ui.menu.options.manual_content.visible)
	key(KEY_ESCAPE);await frames(2)
	check("manual_escape_restores_options_focus",not ui.menu.options.manual_content.visible and ui.menu.options.manual_button.has_focus())
	key(KEY_ESCAPE);await frames(18)
	check("options_escape_returns_to_compact_menu",not ui.menu.options.visible and ui.menu.visible and ui.menu.panel.visible)
	key(KEY_ESCAPE);await frames(3)
	check("menu_escape_restores_prior_control_lock_and_focus",not ui.menu.visible and ui.menu_button.has_focus() and room.player.controls_locked==(room.casting or room.seal_active or room.interacting or room.arrival_busy()))
	room.state.rail_position=50;key(KEY_R);await frames(2)
	check("reset_shortcut_requires_confirmation",ui.menu.confirmation.visible and room.state.rail_position==50)
	await shot("07-reset-confirmation")
	click(ui.menu.confirm_button);await frames(3)
	check("confirmed_reset_executes_existing_reset",not ui.menu.visible and room.state.rail_position==0 and room.player.position==room.spawn_point)
	app.dialogue.enabled=true;app.dialogue.voice.enabled=true;app.dialogue.play("hud-subtitle",[app.dialogue.Lines.tutorial(0)[0]],false);await frames(3)
	check("subtitle_uses_reserved_region_above_world_controls",not ui.footer.visible and not ui.entry_hint.visible and not app.dialogue.view.level_subtitle_plate.get_global_rect().intersects(ui.skill_panel.get_global_rect()))
	await shot("08-subtitle-safe-area")
	ui.toggle_menu();var voice_age:float=app.dialogue.voice.age;var caption_time:float=app.dialogue.timer;await frames(8)
	check("menu_pauses_voice_and_caption_together",app.dialogue.voice.player.stream_paused and app.dialogue.voice.age==voice_age and app.dialogue.timer==caption_time)
	ui.toggle_menu();await frames(2)
	check("closing_menu_resumes_current_voice",not app.dialogue.voice.player.stream_paused and app.dialogue.voice.age>voice_age)
	app.dialogue.clear();app.dialogue.enabled=false;app.dialogue.voice.enabled=false
	room.state.first_latched=true;room.state.rail_position=room.State.RAIL_LENGTH;await frames(3)
	check("task_uses_real_puzzle_progress",ui.task_tracker.current_step==1)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(Vector2i(1920,1080));await frames(20)
		check("wide_window_hud_keeps_safe_edges",ui.menu_button.get_global_rect().end.x<=get_viewport().get_visible_rect().size.x-23 and absf(ui.skill_panel.get_global_rect().get_center().x-get_viewport().get_visible_rect().size.x*.5)<1)
		await shot("09-wide-layout");DisplayServer.window_set_size(Vector2i(1280,800));await frames(10)
	app.show_paper_mill();await frames(240);room=app.current;ui=room.hud
	point(Vector2(750,530));await frames(20)
	check("paper_mill_retains_four_worlds_and_two_layers",ui.rule_buttons.size()==4 and ui.layer_selector.get_popup().item_count==2)
	check("paper_mill_inventory_and_helpers_use_edge_strips",not ui.record.visible and ui.tools.is_visible_in_tree() and ui.bag.is_visible_in_tree())
	ui.entry_hint.dismiss();await frames(45);await shot("10-paper-mill-clean")
	at=room.player.position
	ui.layer_selector.get_popup().id_pressed.emit(1);await frames(3)
	check("layer_button_observes_without_teleport_or_route",room.view_layer==1 and room.player_layer==0 and room.player.position==at and room.pending.is_empty())
	click(ui.rule_buttons[3]);await frames(3)
	check("paper_mill_fourth_world_uses_actual_rule",room.state.worlds[1]==3 and ui.law.text.contains("显影"))
	click(ui.menu_button);await frames(2)
	var clock:float=room.state.clock;await frames(10)
	check("paper_mill_menu_preserves_existing_pause",ui.menu.visible and room.state.clock==clock)
	click(ui.menu.buttons.manual);await frames(20)
	check("paper_mill_manual_describes_its_actual_controls",ui.menu.options.manual_lines.any(func(line):return line.contains("1 / 2 / 3 / 4")) and ui.menu.options.manual_lines.any(func(line):return line.contains("Tab")))
	await shot("11-paper-mill-manual")
	key(KEY_ESCAPE);await frames(2);key(KEY_ESCAPE);await frames(18);key(KEY_ESCAPE);await frames(3)
	click(ui.objective);await frames(20)
	check("paper_mill_task_click_locates_real_target_without_moving",not ui.record.visible and room.view.focused_target==room.goal_target() and room.player.position==at)
	key(KEY_H);await frames(30)
	check("expanded_records_clear_subtitle_slot_and_object_badge",not ui.record.get_global_rect().intersects(ui.subtitle_panel.get_global_rect()) and not ui.object_panel.visible)
	await shot("12-paper-mill-records")
	point(Vector2(750,530));key(KEY_ESCAPE);await frames(3)
	check("closed_records_do_not_block_map",not ui.record.visible and not ui.blocks_map(Vector2(200,300)))
	print("INSTRUMENT_HUD_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
