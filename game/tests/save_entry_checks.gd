extends SceneTree
## Render the real title-to-picker flow and capture its uninterrupted frames.
var app: Node
var directory := ""
var results: Array[Dictionary] = []
var failures := 0
var samples: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(label: String, passed: bool) -> void:
	results.append({"test":label,"passed":passed})
	if not passed:
		failures += 1
		push_error("ENTRY_FAILED " + label)

func key(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode=code;event.keycode=code;event.pressed=down
		root.push_input(event,true)

func click(at: Vector2) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=at;event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true)

func frames(count: int) -> void:
	for i in range(count):await process_frame

func until(condition: Callable) -> bool:
	for i in range(600):
		await process_frame
		if condition.call():return true
	return false

func snapshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	check("write_"+filename,root.get_texture().get_image().save_png(directory.path_join(filename))==OK)

func run() -> void:
	# Keep desktop input from interfering with the deterministic injected events.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():
		push_error("Use an explicit --artifacts directory");quit(1);return
	DirAccess.make_dir_recursive_absolute(directory.path_join("frames"))
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await frames(5)
	app.saving_enabled=true;app.dialogue.enabled=false
	var menu=app.current
	var painting: TextureRect=menu.background_rect
	var ink: ShaderMaterial=painting.material
	var music_id: int=app.ambience.music.get_instance_id()
	# Include a nonzero pointer offset in the captured starting camera.
	menu.pointer_offset=Vector2(0.001,-0.001);menu._apply_motion()
	await RenderingServer.frame_post_draw
	var original_zoom: float=1.06+0.014*sin(menu.elapsed*0.45)
	var last_zoom:=original_zoom
	var monotonic:=true
	var covered:=true
	var fixed_during_cards:=true
	var has_midpoint:=false
	var transferred:=false
	var final_zoom:=0.0
	var final_focus:=Vector2.ZERO
	var early_choice_checked:=false
	for frame in range(90):
		if frame==10:
			original_zoom=1.06+0.014*sin(menu.elapsed*0.45)
			click(menu.start_button.get_global_rect().get_center())
			# Deferred signal starts the real tween on the following idle frame.
		if frame==13:
			menu.begin();click(Vector2(640,452));key(KEY_ENTER);key(KEY_ESCAPE)
			check("duplicate_click_and_early_keys_keep_one_entry",app.menu_revealing and app.active_slot==0)
			var painted_time: float=ink.get_shader_parameter("motion_time")
			check("entry_starts_from_displayed_camera",is_equal_approx(menu.entry_start_zoom,1.06+0.014*sin(painted_time*0.45)))
			key(KEY_M)
			check("M_works_during_push",app.ambience.muted)
			key(KEY_M)
		await RenderingServer.frame_post_draw
		var error:=root.get_texture().get_image().save_png(directory.path_join("frames/frame-%03d.png"%frame))
		if error!=OK:check("write_recording_frame",false);break
		if menu.save_entry:
			var zoom: float=ink.get_shader_parameter("camera_zoom")
			var focus: Vector2=ink.get_shader_parameter("camera_focus")
			monotonic=monotonic and zoom+0.00001>=last_zoom
			last_zoom=zoom
			var low:=focus-Vector2.ONE*0.5/zoom
			var high:=focus+Vector2.ONE*0.5/zoom
			covered=covered and low.x>=0.0 and low.y>=0.0 and high.x<=1.0 and high.y<=1.0
			samples.append({"frame":frame,"progress":menu.entry_progress,"zoom":zoom,"focus":[focus.x,focus.y]})
			if menu.entry_progress>0.1 and menu.entry_progress<0.9:
				has_midpoint=true
			if is_instance_valid(app.save_picker):
				var picker=app.save_picker
				if not transferred:
					transferred=true;final_zoom=zoom;final_focus=focus
					check("same_background_node_and_material_cross_boundary",picker.background==painting and picker.background.material==ink)
					check("picker_starts_with_completed_camera",is_equal_approx(menu.entry_progress,1.0) and is_equal_approx(zoom,menu.SAVE_ENTRY_ZOOM))
				fixed_during_cards=fixed_during_cards and is_equal_approx(zoom,final_zoom) and focus.is_equal_approx(final_focus)
				if not picker.ready_for_input() and not early_choice_checked:
					early_choice_checked=true
					key(KEY_RIGHT);key(KEY_ENTER);key(KEY_ESCAPE);click(Vector2(640,500))
					check("picker_blocks_input_until_fade_finishes",app.active_slot==0 and not picker.busy and picker.selected==1)
	check("one_monotonic_push_without_zoom_back",monotonic and has_midpoint and transferred)
	check("every_camera_sample_covers_the_viewport",covered)
	check("camera_stays_fixed_through_card_fade",fixed_during_cards)
	check("all_cards_ready_and_stationary",app.save_picker.ready_for_input() and app.save_picker.cards.all(func(card):return card.modulate.a==1.0) and app.save_picker.cards[0].position==Vector2(326,502))
	check("music_instance_survives_transition",app.ambience.music.get_instance_id()==music_id)
	await snapshot("01-picker.png")
	for window_size in [Vector2i(1440,810),Vector2i(960,800)]:
		DisplayServer.window_set_size(window_size);await frames(6)
		check("resize_keeps_camera_"+str(window_size),is_equal_approx(float(ink.get_shader_parameter("camera_zoom")),final_zoom) and ink.get_shader_parameter("camera_focus")==final_focus)
		await snapshot("resize-%dx%d.png"%[window_size.x,window_size.y])
	key(KEY_F11);await frames(8)
	check("F11_works_in_picker",DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN)
	await snapshot("fullscreen.png")
	key(KEY_F11);await frames(4)
	key(KEY_ESCAPE)
	check("return_recreates_initial_title",await until(func():return app.save_picker==null and not app.current.starting))
	check("return_restores_title_and_initial_camera",app.current.root.modulate.a==1.0 and not app.current.save_entry and app.current.background_rect.get_parent()==app.current)
	menu=app.current;menu.motion_enabled=false
	var still_time: float=menu.elapsed
	menu.begin()
	check("motion_off_opens_picker",await until(func():return is_instance_valid(app.save_picker)))
	var still_ink: ShaderMaterial=app.save_picker.background.material
	check("motion_off_does_not_zoom",is_equal_approx(float(still_ink.get_shader_parameter("camera_zoom")),1.06+0.014*sin(still_time*0.45)))
	await until(func():return app.save_picker.ready_for_input())
	await snapshot("02-motion-off.png")
	key(KEY_ESCAPE);await until(func():return app.save_picker==null and not app.current.starting)
	app.current.begin()
	check("repeat_entry_opens_picker",await until(func():return is_instance_valid(app.save_picker)))
	await until(func():return app.save_picker.ready_for_input())
	check("repeat_entry_has_same_final_composition",app.save_picker.globe_center().distance_to(Vector2(640,300))<0.01)
	# Use the isolated --save-dir to exercise each physical card and scene entry.
	for slot in range(1,4):
		var picker=app.save_picker
		click(picker.cards[slot-1].to_global(Vector2(0,-20)))
		check("card_body_enters_slot_%d"%slot,await until(func():return app.active_slot==slot and app.save_picker==null and not app.menu_revealing))
		if slot<3:
			key(KEY_F10);await until(func():return app.current.has_signal("start_requested"))
			app.current.begin();await until(func():return is_instance_valid(app.save_picker))
			await until(func():return app.save_picker.ready_for_input())
	var report:=FileAccess.open(directory.path_join("entry-report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results,"camera_samples":samples},"\t"));report.close()
	print("ENTRY_REPORT ",results.size()," checks, ",failures," failures")
	await app.shutdown_audio();quit(0 if failures==0 else 1)
