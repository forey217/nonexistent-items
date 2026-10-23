extends Node
## Integration checks for the contributed title screen and the current game flow.
var results: Array[Dictionary]=[]
var failures:=0
var directory:=""
var app:Node2D

func check(title:String,passed:bool) -> void:
	results.append({"test":title,"passed":passed})
	if not passed:
		failures+=1
		push_error("MENU_FAILED "+title)

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition:Callable,limit:=700) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func key(code:int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=code;event.physical_keycode=code;event.pressed=down
		get_viewport().push_input(event,true)

func click(at:Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		get_viewport().push_input(event,true)

func slider_point(slider: HSlider,percent: float) -> Vector2:
	return slider.global_position+Vector2(10+(slider.size.x-20)*percent/100.0,slider.size.y*0.5)

func drag_slider(slider: HSlider,from: float,to: float) -> void:
	var start:=slider_point(slider,from)
	var press:=InputEventMouseButton.new()
	press.position=start;press.global_position=start;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	get_viewport().push_input(press,true)
	for i in range(1,6):
		var move:=InputEventMouseMotion.new()
		move.position=start.lerp(slider_point(slider,to),i/5.0);move.global_position=move.position
		move.button_mask=MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(move,true);await frames(1)
	var release:=InputEventMouseButton.new()
	release.position=slider_point(slider,to);release.global_position=release.position
	release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
	get_viewport().push_input(release,true)

func finish(filename: String) -> void:
	var file:=FileAccess.open(directory.path_join(filename),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"));file.close()
	print("MENU_RESULT ",results.size()," checks, ",failures," failures")
	await app.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)

func snapshot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func run(flow:Node2D) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory="user://menu-checks"
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(8)
	var menu=app.current
	if "--audio-reopen" in OS.get_cmdline_user_args():
		check("new_process_restores_saved_volume",is_equal_approx(app.ambience.preferences.volume,37))
		check("new_process_restores_master_bus_gain",not app.ambience.muted and is_equal_approx(AudioServer.get_bus_volume_db(0),linear_to_db(0.37)))
		menu.open_options();await frames(20)
		check("new_process_shows_saved_slider_and_percentage",menu.options_page.slider.value==37 and menu.options_page.percentage.text=="37%")
		for channel in ["music","sfx","dialogue"]:
			var expected: float={"music":61.0,"sfx":28.0,"dialogue":83.0}[channel]
			var bus:=AudioServer.get_bus_index(app.ambience.CHANNEL_BUSES[channel])
			check("new_process_restores_"+channel,menu.options_page.channel_sliders[channel].value==expected and menu.options_page.channel_percentages[channel].text=="%d%%"%int(expected) and is_equal_approx(AudioServer.get_bus_volume_db(bus),linear_to_db(expected/100.0)))
		await finish("audio-reopen-checks.json");return
	var music_id:int=app.ambience.music.get_instance_id()
	check("normal_boot_opens_contributed_title",menu.has_signal("start_requested") and menu.scene_art!=null and not app.ambience.toggle_button.visible)
	check("start_has_keyboard_focus",menu.start_button.has_focus())
	var title_start: Vector2=menu.title_group.position
	var initial_clock: float=menu.background_material.get_shader_parameter("motion_time")
	var initial_title_clock: float=menu.title_material.get_shader_parameter("motion_time")
	await frames(24)
	check("title_stays_still_with_fixed_menu_hitboxes",menu.title_group.position==title_start and menu.title_group.rotation==0 and menu.title_group.scale==Vector2.ONE and menu.start_button.position==Vector2(440,426))
	check("background_and_title_sheen_clocks_advance",menu.background_material.get_shader_parameter("motion_time")>initial_clock and menu.title_material.get_shader_parameter("motion_time")>initial_title_clock)
	key(KEY_DOWN);await frames(2)
	check("down_selects_options",menu.options_button.has_focus() and menu.active_index==1)
	key(KEY_UP);await frames(2)
	check("up_selects_start",menu.start_button.has_focus() and menu.active_index==0)
	check("quit_uses_shared_audio_cleanup",menu.quit_requested.is_connected(app.quit_game))
	await snapshot("01-title-screen")
	click(menu.options_button.get_global_rect().get_center());await frames(20)
	var page=menu.options_page
	check("options_opens_and_blocks_main_menu",menu.options_shade.visible and menu.start_button.focus_mode==Control.FOCUS_NONE)
	check("options_has_four_sliders_manual_and_return",page.options_content.get_children().filter(func(node):return node is Button or node is Range).size()==6 and page.channel_sliders.size()==4)
	check("options_matches_archive_fonts",page.heading.get_theme_font("font").resource_path.ends_with("ZCOOLXiaoWei-Regular.ttf") and page.manual_button.get_theme_font("font").base_font.resource_path.ends_with("SourceHanSerifCN-Regular.otf"))
	check("opening_animation_finishes_in_place",page.modulate.a>0.99 and page.sheet.position==page.home and page.slider.has_focus())
	menu.begin();await frames(1)
	check("options_prevents_starting_game_behind_overlay",not menu.starting and app.current==menu)
	await snapshot("01b-options")
	click(slider_point(page.slider,40));await frames(2)
	check("clicking_slider_track_changes_shared_volume",absf(app.ambience.preferences.volume-40)<=1 and page.percentage.text=="%d%%"%roundi(page.slider.value))
	check("slider_controls_master_music_and_effects",is_equal_approx(AudioServer.get_bus_volume_db(0),linear_to_db(app.ambience.preferences.volume/100.0)) and AudioServer.get_bus_send(AudioServer.get_bus_index("Music"))=="Master" and AudioServer.get_bus_send(AudioServer.get_bus_index("SFX"))=="Master")
	var before_key: float=page.slider.value
	key(KEY_RIGHT);await frames(2)
	check("slider_supports_keyboard_arrows",page.slider.value==before_key+1 and app.ambience.preferences.volume==page.slider.value)
	await drag_slider(page.slider,25,72);await frames(2)
	check("dragging_slider_updates_sound_and_percentage",absf(page.slider.value-72)<=1 and app.ambience.preferences.volume==page.slider.value)
	click(slider_point(page.slider,0));await frames(2)
	check("zero_volume_is_completely_muted",page.slider.value==0 and app.ambience.muted and AudioServer.is_bus_mute(0))
	key(KEY_RIGHT);await frames(2)
	check("raising_volume_from_zero_unmutes",page.slider.value==1 and not app.ambience.muted and not AudioServer.is_bus_mute(0))
	app.ambience.set_volume(56);await frames(15)
	for channel in ["music","sfx","dialogue"]:
		var control: HSlider=page.channel_sliders[channel]
		var before: Dictionary=app.ambience.preferences.channels.duplicate()
		click(slider_point(control,45));await frames(2)
		var bus:=AudioServer.get_bus_index(app.ambience.CHANNEL_BUSES[channel])
		check("slider_independently_controls_"+channel,absf(app.ambience.preferences.channels[channel]-45)<=1 and page.slider.value==56 and is_equal_approx(AudioServer.get_bus_volume_db(bus),linear_to_db(control.value/100.0)) and AudioServer.get_bus_send(bus)=="Master")
		var others_unchanged:=true
		for other in before:
			if other!=channel:others_unchanged=others_unchanged and before[other]==app.ambience.preferences.channels[other]
		check("other_channels_unaffected_by_"+channel,others_unchanged)
		var initial: float=control.value
		key(KEY_RIGHT);await frames(2)
		check("keyboard_adjusts_"+channel,control.value==initial+1 and page.channel_percentages[channel].text=="%d%%"%int(control.value))
		click(slider_point(control,0));await frames(2)
		check("channel_zero_mutes_only_"+channel,AudioServer.is_bus_mute(bus) and not AudioServer.is_bus_mute(0))
		key(KEY_RIGHT);await frames(2)
		check("channel_raises_from_zero_"+channel,not AudioServer.is_bus_mute(bus) and control.value==1)
	app.ambience.set_channel_volume("music",61)
	app.ambience.set_channel_volume("sfx",28)
	app.ambience.set_channel_volume("dialogue",83)
	check("master_and_channel_gains_combine",is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0))*db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))),0.56*0.61))
	page.slider.grab_focus();key(KEY_DOWN);await frames(2)
	check("keyboard_focus_reaches_background_slider",page.channel_sliders.music.has_focus())
	await snapshot("01c-volume-adjusted")
	click(menu.manual_button.get_global_rect().get_center());await frames(2)
	check("manual_replaces_options_on_same_sheet",menu.help_panel.visible and not page.options_content.visible and menu.start_button.focus_mode==Control.FOCUS_NONE and page.heading.text=="操作说明")
	var manual_copy: String="\n".join(page.manual_lines)
	check("manual_matches_current_controls",not manual_copy.contains("Q /") and manual_copy.contains("1.5秒") and manual_copy.contains("星系仪") and manual_copy.contains("F10"))
	await snapshot("02-current-manual")
	click(slider_point(page.slider,0));key(KEY_3);menu.begin();await frames(2)
	check("manual_blocks_hidden_slider_world_keys_and_start",page.slider.value==56 and menu.world==0 and not menu.starting and app.current==menu)
	key(KEY_ESCAPE);await frames(3)
	check("escape_closes_manual_and_returns_to_options",not menu.help_panel.visible and page.options_content.visible and menu.options_shade.visible and menu.manual_button.has_focus() and page.slider.value==56)
	key(KEY_M);await frames(3)
	check("M_mutes_and_synchronizes_slider",app.ambience.muted and page.slider.value==0 and page.percentage.text=="0%")
	key(KEY_M);await frames(3)
	check("M_restores_previous_audible_volume",not app.ambience.muted and page.slider.value==56 and page.percentage.text=="56%")
	check("M_preserves_all_channel_levels",page.channel_sliders.music.value==61 and page.channel_sliders.sfx.value==28 and page.channel_sliders.dialogue.value==83)
	key(KEY_ESCAPE);await frames(2)
	check("options_close_keeps_input_shield_during_fade",page.visible and page.closing and menu.start_button.focus_mode==Control.FOCUS_NONE)
	await until(func():return not page.visible)
	check("escape_closes_options_and_restores_main_focus",menu.options_button.has_focus() and menu.start_button.focus_mode==Control.FOCUS_ALL)
	click(menu.options_button.get_global_rect().get_center());await frames(20)
	check("reopening_options_preserves_volume",page.slider.value==56)
	click(page.back_button.get_global_rect().get_center())
	await until(func():return not page.visible)
	check("return_button_closes_options",menu.options_button.has_focus() and page.slider.value==56)
	var menu_id: int=menu.get_instance_id()
	click(menu.start_button.get_global_rect().get_center());menu.begin()
	check("start_blocks_repeated_requests",menu.starting and menu.start_button.disabled and menu.fade.mouse_filter==Control.MOUSE_FILTER_STOP)
	await until(func():return app.title_entry!=null and app.title_entry.stage=="departure" and app.title_entry.progress>=0.40)
	check("entry_approaches_illustrated_globe_without_blue_cover",menu.entry_progress>0.0 and menu.root.modulate.a<0.1 and menu.fade.modulate.a==0.0)
	check("dialogue_waits_for_entry_camera",not app.dialogue.modal and app.menu_revealing)
	await snapshot("02a-globe-approach")
	await until(func():return app.current.get_instance_id()!=menu_id)
	check("start_enters_latest_hub_not_old_direct_tutorial",app.current.get_script().resource_path.ends_with("tutorial_hub.gd") and app.menu_revealing)
	var entry_spawn: Vector2=app.current.player.position
	check("arrival_camera_matches_live_globe",app.title_entry!=null and app.title_entry.ink.center.distance_to(app.current.world_to_screen(app.current.globe.to_global(app.current.globe_fx.core)))<2.0)
	click(Vector2(640,600));key(KEY_E);key(KEY_R)
	check("entry_blocks_movement_and_selection",app.current.player.controls_locked and app.current.player.position==entry_spawn and app.level_menu==null)
	key(KEY_M);await frames(1)
	check("mute_shortcut_works_during_entry",app.ambience.muted)
	key(KEY_M)
	await until(func():return app.title_entry!=null and app.title_entry.progress>=0.35)
	await snapshot("02b-globe-to-hall")
	key(KEY_F10);await frames(2)
	check("F10_cannot_interrupt_title_reveal",not app.current.has_signal("start_requested"))
	check("return_button_hidden_during_title_reveal",not app.return_menu_button.visible)
	await until(func():return not app.menu_revealing)
	var hub=app.current
	await frames(2)
	check("hall_has_visible_return_button",app.return_menu_button.is_visible_in_tree())
	check("hub_keeps_latest_NPC_and_removed_chest",hub.npc_art.texture!=null and hub.props.size()==3 and app.ambience.toggle_button.visible)
	check("title_to_hub_keeps_music_instance",app.ambience.music.get_instance_id()==music_id)
	check("entry_restores_camera_and_releases_its_layer",hub.hall_camera.zoom==Vector2.ONE and app.title_entry==null and not hub.player.controls_locked)
	check("actor_entry_keeps_room_visible",hub.entry_effect==null or not is_instance_valid(hub.entry_effect) or hub.entry_effect.veil.modulate.a==0.0)
	await snapshot("03-title-to-hub")
	click(app.return_menu_button.get_global_rect().get_center())
	check("return_button_blocks_repeated_requests",not app.request_title_return())
	await frames(4)
	menu=app.current
	check("hall_button_returns_to_fresh_title",menu.has_signal("start_requested") and not menu.starting and not app.ambience.toggle_button.visible and not app.return_menu_button.visible)
	key(KEY_M);await frames(2)
	menu.motion_enabled=false
	menu_id=menu.get_instance_id()
	click(menu.start_button.get_global_rect().get_center())
	await until(func():return app.current.get_instance_id()!=menu_id)
	check("motion_off_uses_still_crossfade",app.title_entry!=null and not app.title_entry.motion_enabled and not app.title_entry.ink.animated and app.current.hall_camera.zoom==Vector2.ONE and app.current.hall_camera.position==Vector2(640,400))
	await until(func():return app.title_entry!=null and app.title_entry.stage=="arrival" and app.title_entry.progress>=0.35)
	check("motion_off_fades_illustration_without_radial_motion",app.title_entry.reveal_material.get_shader_parameter("opacity")<0.9 and app.title_entry.reveal_material.get_shader_parameter("reveal")==0.0)
	await snapshot("03b-motion-off-crossfade")
	await until(func():return not app.menu_revealing)
	hub=app.current
	check("mute_survives_title_and_scene_switch",app.ambience.muted and app.ambience.music.get_instance_id()==music_id)
	key(KEY_M)
	click(hub.world_to_screen(hub.globe.art.to_global(Vector2.ZERO)));await frames(4)
	check("hub_globe_opens_current_crystal_map",app.level_menu!=null and app.current==hub)
	check("return_button_hidden_during_level_selection",not app.return_menu_button.visible)
	key(KEY_F10);await frames(2)
	check("F10_does_not_discard_open_level_map",app.current==hub and app.level_menu!=null)
	click(app.level_menu.CENTER);await frames(4)
	check("whole_crystal_opens_fragments_before_selection",app.level_menu.selection_age<0 and app.level_menu.phase==app.level_menu.Phase.OPENING)
	await until(func():return app.level_menu.phase==app.level_menu.Phase.EXPANDED)
	click(app.level_menu.shards[0].global_position);await frames(4)
	check("crystal_selection_runs_existing_convergence",app.level_menu.selection_age>=0)
	await until(func():return app.level_menu==null)
	await until(func():return not app.current.arrival_busy())
	check("title_hub_crystal_enters_tutorial_in_default_world",app.current.has_signal("completed") and app.current.state.world==0 and not app.current.player.controls_locked)
	await frames(2)
	check("level_return_is_in_pause_menu_without_legacy_button",not app.return_menu_button.is_visible_in_tree() and app.current.hud.menu_button.is_visible_in_tree())
	await snapshot("04-title-to-level")
	click(app.current.hud.menu_button.get_global_rect().get_center());await frames(2)
	click(app.current.hud.menu.buttons.title.get_global_rect().get_center());await frames(5)
	check("pause_menu_returns_without_orphan_menu",app.current.has_signal("start_requested") and app.level_menu==null and app.return_effect==null and not app.return_menu_button.visible)
	check("music_survives_round_trip",app.ambience.music.get_instance_id()==music_id and not app.ambience.muted)
	app.show_hub(false);await frames(3)
	key(KEY_F10);await frames(4)
	check("F10_shortcut_still_returns_to_title",app.current.has_signal("start_requested"))
	app.ambience.set_volume(37)
	app.ambience.save_settings()
	check("volume_saved_without_applying_or_confirming",app.ambience.settings_error==OK)
	if not app.ambience.preferences.path.is_empty():
		var reloaded=preload("res://scripts/audio_preferences.gd").new()
		reloaded.path=app.ambience.preferences.path;reloaded.load_settings()
		check("audio_preferences_survive_reloading_from_disk",reloaded.volume==37 and reloaded.audible_volume==37)
		check("all_channel_settings_saved",reloaded.channels=={"music":61.0,"sfx":28.0,"dialogue":83.0})
		var legacy:=ConfigFile.new()
		var legacy_path: String=app.ambience.preferences.path+".legacy"
		legacy.set_value("audio","volume",42.0);legacy.set_value("audio","audible_volume",42.0);legacy.save(legacy_path)
		var migrated=preload("res://scripts/audio_preferences.gd").new()
		migrated.path=legacy_path;migrated.load_settings()
		check("old_single_slider_settings_migrate_without_changing_loudness",migrated.volume==42 and migrated.channels=={"music":100.0,"sfx":100.0,"dialogue":100.0})
	await finish("menu-checks.json")
