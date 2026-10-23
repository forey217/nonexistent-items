extends Node
var app: Node2D
var room: Node2D
var directory: String
var results: Array[Dictionary] = []
var failures := 0

func frames(count: int) -> void:
	for i in range(count): await get_tree().physics_frame

func record(title: String,passed: bool) -> void:
	results.append({"test":title,"passed":passed})
	if not passed:
		failures+=1
		push_error("HUD_CHECK_FAILED "+title)

func snapshot(title: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(title+".png"))

func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode=code
		event.pressed=down
		get_viewport().push_input(event,true)

func click(button: Button) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=button.get_global_rect().get_center()
		event.global_position=event.position
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		get_viewport().push_input(event,true)

func run(flow: Node2D) -> void:
	app=flow
	room=app.current
	room.sound.enabled=false
	directory=room.artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(50)
	var title: Control=room.hud.arrival_title
	record("arrival_title_centered_visible",title.visible and title.modulate.a>0.99 and absf(title.get_global_rect().get_center().x-640)<1)
	record("title_does_not_capture_mouse",title.mouse_filter==Control.MOUSE_FILTER_IGNORE and title.caption.mouse_filter==Control.MOUSE_FILTER_IGNORE)
	await snapshot("01-arrival-title")
	var before: Vector2=room.player.position
	Input.action_press("walk_right");await frames(6);Input.action_release("walk_right");await frames(2)
	record("movement_available_while_title_visible",room.player.position.distance_to(before)>5 and title.visible)
	key(KEY_Q);await frames(2)
	record("q_has_no_action_when_ready",room.state.world==0 and room.world_cooldown==0 and not room.casting)
	var right_column := true
	room.hud.toggle_menu()
	for i in range(4):
		var rect: Rect2=room.hud.menu_buttons[i].get_global_rect()
		right_column=right_column and rect.position.x>900 and rect.end.x<=1258
		if i>0:right_column=right_column and rect.position.y>room.hud.menu_buttons[i-1].get_global_rect().end.y
	record("four_actions_in_collapsible_right_menu",right_column)
	room.hud.toggle_menu()
	var skill_rect: Rect2=room.hud.skill_panel.get_global_rect()
	record("world_instruments_compact_and_bottom_centered",skill_rect.size.x<=300 and skill_rect.size.y==64 and room.hud.worlds.size()==3 and skill_rect.position.y>700)
	record("world_buttons_fit_inside_instrument_group",skill_rect.encloses(room.hud.worlds[0].get_global_rect()) and skill_rect.encloses(room.hud.worlds[2].get_global_rect()))
	while title.age<3.2:await frames(1)
	record("title_gradually_fading",title.visible and title.modulate.a>0.2 and title.modulate.a<0.8)
	await snapshot("02-title-fading")
	while title.age<4.4:await frames(1)
	record("title_fully_disappears",not title.visible and title.modulate.a==0)
	await snapshot("03-clean-play-view")
	click(room.hud.worlds[1]);await frames(17)
	record("second_tile_selects_heavy_world",room.state.world==1 and room.world_cooldown>1.0)
	key(KEY_Q);key(KEY_3);await frames(1)
	record("q_and_other_inputs_cannot_bypass_cooldown",room.state.world==1 and room.world_cooldown>1.0 and room.pending_world!=2)
	await snapshot("04-world-cooldown")
	while room.world_cooldown>0:await frames(1)
	key(KEY_3);await frames(40)
	record("key_three_selects_inverted_world",room.state.world==2)
	while room.world_cooldown>0:await frames(1)
	key(KEY_1);await frames(40)
	record("key_one_selects_ice_world",room.state.world==0)
	record("switching_world_does_not_replay_title",not title.visible)
	room.hud.toggle_menu();click(room.hud.menu_buttons[3]);await frames(2)
	record("left_hint_button_works",room._hint_level==1)
	room.orbit_view.set_angle(32)
	room.hud.toggle_menu();click(room.hud.menu_buttons[0]);await frames(2)
	record("left_reset_view_button_works",room.orbit_view.angle==0)
	room.hud.toggle_menu();click(room.hud.menu_buttons[2]);await frames(2)
	click(room.hud.menu.confirm_button);await frames(3)
	record("left_reset_button_works_without_replaying_title",room.player.position==room.spawn_point and room.world_cooldown==0 and not title.visible)
	room.hud.toggle_menu();click(room.hud.menu_buttons[1]);await frames(50)
	record("left_return_button_opens_hub",app.current.get_script().resource_path.ends_with("tutorial_hub.gd"))
	await snapshot("05-hub-arrival")
	# Reenter through the globe and its single level crystal.
	var hub=app.current
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=hub.globe.art.to_global(Vector2.ZERO)
		event.global_position=event.position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		get_viewport().push_input(event,true)
	await frames(4)
	app.level_menu.select_level()
	while app.level_menu.phase!=app.level_menu.Phase.EXPANDED:await frames(1)
	app.level_menu.select_level()
	while app.level_menu!=null:await frames(1)
	await frames(22)
	record("reentering_map_replays_arrival_title",app.current.get_script().resource_path.ends_with("tutorial_room.gd") and app.current.hud.arrival_title.modulate.a>0.99)
	await snapshot("06-reenter-title")
	var file := FileAccess.open(directory.path_join("hud-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"));file.close()
	print("HUD_TEST_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	await get_tree().current_scene.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
