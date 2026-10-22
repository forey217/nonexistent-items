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
	click(menu.options_button.get_global_rect().get_center());await frames(2)
	check("options_opens_and_blocks_main_menu",menu.options_shade.visible and menu.start_button.focus_mode==Control.FOCUS_NONE)
	menu.begin();await frames(1)
	check("options_prevents_starting_game_behind_overlay",not menu.starting and app.current==menu)
	await snapshot("01b-options")
	for i in range(3):
		click(menu.selectors[i].get_global_rect().get_center());await frames(2)
		check("world_preview_%d"%i,menu.world==i and menu.world_label.text.contains(menu.WORLD_NAMES[i]))
	key(KEY_1);await frames(2)
	check("number_key_changes_preview",menu.world==0)
	click(menu.motion_button.get_global_rect().get_center());await frames(2)
	var still:float=menu.elapsed
	var still_title:Transform2D=menu.title_group.get_transform()
	var still_clock:float=menu.background_material.get_shader_parameter("motion_time")
	var still_title_clock:float=menu.title_material.get_shader_parameter("motion_time")
	var still_pointer:Vector2=menu.background_material.get_shader_parameter("pointer_offset")
	await frames(10)
	check("motion_setting_pauses_particles",not menu.motion_enabled and is_equal_approx(menu.elapsed,still))
	check("motion_setting_freezes_title_and_background",menu.title_group.get_transform()==still_title and menu.title_material.get_shader_parameter("motion_time")==still_title_clock and menu.background_material.get_shader_parameter("motion_time")==still_clock and menu.background_material.get_shader_parameter("pointer_offset")==still_pointer)
	click(menu.motion_button.get_global_rect().get_center());await frames(3)
	check("motion_setting_resumes_particles",menu.motion_enabled and menu.elapsed>still)
	click(menu.manual_button.get_global_rect().get_center());await frames(2)
	check("manual_opens_as_input_blocking_overlay",menu.help_panel.visible and menu.help_shade.visible and menu.start_button.focus_mode==Control.FOCUS_NONE)
	check("manual_matches_current_controls",not menu.help_copy.text.contains("Q /") and menu.help_copy.text.contains("1.5秒") and menu.help_copy.text.contains("星系仪"))
	await snapshot("02-current-manual")
	click(menu.selectors[2].get_global_rect().get_center());key(KEY_3);await frames(2)
	check("manual_blocks_background_mouse_and_world_keys",menu.world==0 and app.current==menu)
	key(KEY_ESCAPE);await frames(3)
	check("escape_closes_manual_and_returns_to_options",not menu.help_panel.visible and not menu.help_shade.visible and menu.options_shade.visible and menu.manual_button.has_focus())
	click(menu.mute_button.get_global_rect().get_center());await frames(3)
	check("title_mute_button_controls_shared_audio",app.ambience.muted and menu.mute_button.text.contains("关"))
	key(KEY_M);await frames(3)
	check("M_unmutes_on_title",not app.ambience.muted and menu.mute_button.text.contains("开"))
	key(KEY_ESCAPE);await frames(2)
	check("escape_closes_options_and_restores_main_focus",not menu.options_shade.visible and menu.options_button.has_focus() and menu.start_button.focus_mode==Control.FOCUS_ALL)
	menu.select_world(2)
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
	check("level_has_visible_return_button",app.return_menu_button.is_visible_in_tree())
	await snapshot("04-title-to-level")
	click(app.return_menu_button.get_global_rect().get_center());await frames(5)
	check("level_button_returns_without_orphan_menu",app.current.has_signal("start_requested") and app.level_menu==null and app.return_effect==null and not app.return_menu_button.visible)
	check("music_survives_round_trip",app.ambience.music.get_instance_id()==music_id and not app.ambience.muted)
	app.show_hub(false);await frames(3)
	key(KEY_F10);await frames(4)
	check("F10_shortcut_still_returns_to_title",app.current.has_signal("start_requested"))
	var file:=FileAccess.open(directory.path_join("menu-checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"));file.close()
	print("MENU_RESULT ",results.size()," checks, ",failures," failures")
	await app.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
