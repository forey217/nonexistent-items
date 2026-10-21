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
	check("quit_uses_shared_audio_cleanup",menu.quit_requested.is_connected(app.quit_game))
	await snapshot("01-title-screen")
	for i in range(3):
		click(menu.selectors[i].get_global_rect().get_center());await frames(2)
		check("world_preview_%d"%i,menu.world==i and menu.world_label.text.contains(menu.WORLD_NAMES[i]))
	key(KEY_1);await frames(2)
	check("number_key_changes_preview",menu.world==0)
	click(menu.motion_button.get_global_rect().get_center());await frames(2)
	var still:float=menu.elapsed
	await frames(10)
	check("motion_setting_pauses_particles",not menu.motion_enabled and is_equal_approx(menu.elapsed,still))
	click(menu.motion_button.get_global_rect().get_center());await frames(3)
	check("motion_setting_resumes_particles",menu.motion_enabled and menu.elapsed>still)
	click(Vector2(140,587));await frames(2)
	check("manual_opens_as_input_blocking_overlay",menu.help_panel.visible and menu.help_shade.visible and menu.start_button.focus_mode==Control.FOCUS_NONE)
	check("manual_matches_current_controls",not menu.help_copy.text.contains("Q /") and menu.help_copy.text.contains("1.5秒") and menu.help_copy.text.contains("星系仪"))
	await snapshot("02-current-manual")
	click(menu.selectors[2].get_global_rect().get_center());key(KEY_3);await frames(2)
	check("manual_blocks_background_mouse_and_world_keys",menu.world==0 and app.current==menu)
	key(KEY_ESCAPE);await frames(3)
	check("escape_closes_manual_and_restores_focus",not menu.help_panel.visible and not menu.help_shade.visible and menu.start_button.has_focus())
	click(menu.mute_button.get_global_rect().get_center());await frames(3)
	check("title_mute_button_controls_shared_audio",app.ambience.muted and menu.mute_button.text.contains("关"))
	key(KEY_M);await frames(3)
	check("M_unmutes_on_title",not app.ambience.muted and menu.mute_button.text.contains("开"))
	menu.select_world(2)
	click(menu.start_button.get_global_rect().get_center());menu.begin()
	check("start_blocks_repeated_requests",menu.starting and menu.start_button.disabled and menu.fade.mouse_filter==Control.MOUSE_FILTER_STOP)
	await until(func():return app.current!=menu)
	check("start_enters_latest_hub_not_old_direct_tutorial",app.current.get_script().resource_path.ends_with("tutorial_hub.gd") and app.menu_revealing)
	key(KEY_F10);await frames(2)
	check("F10_cannot_interrupt_title_reveal",not app.current.has_signal("start_requested"))
	await until(func():return not app.menu_revealing)
	var hub=app.current
	check("hub_keeps_latest_NPC_and_removed_chest",hub.npc_art.texture!=null and hub.props.size()==3 and app.ambience.toggle_button.visible)
	check("title_to_hub_keeps_music_instance",app.ambience.music.get_instance_id()==music_id)
	await snapshot("03-title-to-hub")
	key(KEY_F10);await frames(4)
	menu=app.current
	check("F10_returns_to_fresh_title",menu.has_signal("start_requested") and not menu.starting and not app.ambience.toggle_button.visible)
	key(KEY_M);await frames(2)
	click(menu.start_button.get_global_rect().get_center())
	await until(func():return app.current!=menu)
	await until(func():return not app.menu_revealing)
	hub=app.current
	check("mute_survives_title_and_scene_switch",app.ambience.muted and app.ambience.music.get_instance_id()==music_id)
	key(KEY_M)
	click(hub.globe.art.to_global(Vector2.ZERO));await frames(4)
	check("hub_globe_opens_current_crystal_map",app.level_menu!=null and app.current==hub)
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
	await snapshot("04-title-to-level")
	key(KEY_F10);await frames(5)
	check("F10_returns_from_gameplay_without_orphan_menu",app.current.has_signal("start_requested") and app.level_menu==null and app.return_effect==null)
	check("music_survives_round_trip",app.ambience.music.get_instance_id()==music_id and not app.ambience.muted)
	var file:=FileAccess.open(directory.path_join("menu-checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"));file.close()
	print("MENU_RESULT ",results.size()," checks, ",failures," failures")
	await app.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
