extends Node2D
var current: Node2D
var completed_runs := 0
var ambience: Node
var closing := false
var returning := false
var return_effect: CanvasLayer
var level_menu: CanvasLayer
var menu_revealing := false
var return_menu_button: Button
var title_return_pending := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for legacy in ["--self-test","--capture","--capture-gait","--walk-demo"]:
		if legacy in args:
			current=load("res://scenes/movement_test.tscn").instantiate()
			add_child(current)
			return
	get_tree().auto_accept_quit=false
	ambience=preload("res://scripts/bureau_audio.gd").new()
	add_child(ambience)
	_build_title_navigation()
	if "--hub" in args or "--hub-check" in args:show_hub(false)
	elif Array(args).any(func(arg):return arg in ["--tutorial","--tutorial-capture","--skill-capture","--tutorial-self-test","--orbit-self-test","--tutorial-demo","--hud-check","--task-check","--pad-guide-check","--film-check","--polish-check","--archive-check","--interaction-check","--wall-self-test"]):show_tutorial()
	else:show_menu()
	if "--menu-self-test" in args:
		var suite=load("res://tests/menu_tests.gd").new()
		add_child(suite)
		suite.run.call_deferred(self)
	if "--tutorial-demo" in args:
		var demo=load("res://tests/tutorial_demo.gd").new()
		add_child(demo)
		demo.run.call_deferred(self)
	if "--hud-check" in args:
		var suite=load("res://tests/hud_checks.gd").new()
		add_child(suite)
		suite.run.call_deferred(self)
	if "--task-check" in args:
		var suite=load("res://tests/task_checks.gd").new()
		add_child(suite)
		suite.run.call_deferred(self)
	if "--pad-guide-check" in args:
		var suite=load("res://tests/pad_guide_checks.gd").new()
		add_child(suite)
		suite.run.call_deferred(self)
	if "--film-check" in args:
		var suite=load("res://tests/film_checks.gd").new()
		add_child(suite)
		suite.run.call_deferred(self)
	if "--polish-check" in args:
		var suite=load("res://tests/polish_checks.gd").new()
		add_child(suite)
		suite.run.call_deferred(self)
	if "--archive-check" in args:
		var suite=load("res://tests/archive_checks.gd").new()
		add_child(suite)
		suite.run.call_deferred(self)
	if "--interaction-check" in args:
		var suite=load("res://tests/interaction_checks.gd").new()
		add_child(suite)
		suite.run.call_deferred(self)
	if "--hub-check" in args:
		var suite=load("res://tests/hub_flow_checks.gd").new()
		add_child(suite)
		suite.run.call_deferred(self)

func shutdown_audio() -> void:
	if is_instance_valid(ambience):ambience.stop_all()
	if is_instance_valid(current) and current.get("sound")!=null:current.sound.stop_effects()
	# Audio playback is released on the audio thread, before the tree is freed.
	var release_at:=Time.get_ticks_msec()+150
	while Time.get_ticks_msec()<release_at:
		await get_tree().process_frame

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and not closing:
		quit_game()

func quit_game() -> void:
	if closing:return
	closing=true
	process_mode=Node.PROCESS_MODE_DISABLED
	await shutdown_audio()
	get_tree().quit()

func show_menu() -> void:
	if returning or level_menu!=null or menu_revealing:
		title_return_pending=false
		return
	title_return_pending=false
	clear_scene()
	current=load("res://scenes/start_menu.tscn").instantiate()
	current.start_requested.connect(_start_from_menu.call_deferred)
	current.quit_requested.connect(quit_game)
	add_child(current)
	ambience.toggle_button.hide()
	return_menu_button.hide()

func _build_title_navigation() -> void:
	var navigation := CanvasLayer.new()
	navigation.layer = 3
	add_child(navigation)
	var ui = preload("res://scripts/tutorial_hud.gd").new()
	ui.font.font_names = PackedStringArray(["Microsoft YaHei", "Arial"])
	return_menu_button = ui.button(navigation, "返回主界面  F10", Vector2(1054, 655), Vector2(204, 40))
	return_menu_button.add_theme_font_size_override("font_size", 16)
	return_menu_button.tooltip_text = "返回启动画面；重新进入关卡会重置当前关卡。"
	return_menu_button.pressed.connect(request_title_return)
	return_menu_button.hide()
	ui.free()

func _process(_delta: float) -> void:
	if not is_instance_valid(return_menu_button) or not is_instance_valid(current): return
	var playable := not current.has_signal("start_requested")
	var busy := closing or returning or menu_revealing or title_return_pending or level_menu != null
	if current.has_method("arrival_busy") and current.arrival_busy(): busy = true
	return_menu_button.visible = playable and not busy

func request_title_return() -> bool:
	if closing or returning or menu_revealing or title_return_pending or level_menu != null: return false
	if not is_instance_valid(current) or current.has_signal("start_requested"): return false
	if current.has_method("arrival_busy") and current.arrival_busy(): return false
	title_return_pending = true
	return_menu_button.hide()
	ambience.play_ui()
	show_menu.call_deferred()
	return true

func _start_from_menu() -> void:
	if closing or menu_revealing:return
	menu_revealing=true
	show_hub(false)
	current.process_mode=Node.PROCESS_MODE_DISABLED
	ambience.toggle_button.hide()
	var cover:=CanvasLayer.new()
	cover.layer=45
	var veil:=ColorRect.new()
	veil.size=Vector2(1280,800)
	veil.color=Color("102632")
	cover.add_child(veil)
	add_child(cover)
	var reveal:=create_tween()
	reveal.tween_property(veil,"modulate:a",0.0,0.3)
	await reveal.finished
	cover.queue_free()
	menu_revealing=false
	current.process_mode=Node.PROCESS_MODE_INHERIT
	ambience.toggle_button.show()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_F11 or event.keycode==KEY_F11:
		var fullscreen:=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode!=KEY_F10 and event.keycode!=KEY_F10:return
	if request_title_return(): get_viewport().set_input_as_handled()

func clear_scene() -> void:
	if is_instance_valid(current):
		remove_child(current)
		current.queue_free()

func show_tutorial() -> void:
	if returning:return
	clear_scene()
	current=load("res://scenes/tutorial.tscn").instantiate()
	current.completed.connect(_on_completed)
	current.hub_requested.connect(func(): show_hub.call_deferred(false))
	add_child(current)
	for item in current.hud.menu_buttons:item.pressed.connect(ambience.play_ui)

func _on_completed() -> void:
	if returning:return
	completed_runs+=1
	if "--tutorial-self-test" in OS.get_cmdline_user_args() or "--orbit-self-test" in OS.get_cmdline_user_args(): return
	returning=true
	_begin_archive_return.call_deferred()

func _begin_archive_return() -> void:
	var room=current
	room.process_mode=Node.PROCESS_MODE_DISABLED
	room.player.controls_locked=true
	room.player.cancel_navigation()
	room.orbit_view.cancel_drag()
	return_effect=preload("res://scripts/archive_return.gd").new()
	add_child(return_effect)
	return_effect.sound_cue.connect(ambience.play_archive)
	return_effect.reveal_hub.connect(_reveal_returned_hub)
	return_effect.finished.connect(_end_archive_return)
	ambience.toggle_button.hide()
	# A brief last step into the repaired doorway precedes the frozen record.
	var start: Vector2=room.player.position
	var elapsed:=0.0
	while elapsed<0.14:
		await get_tree().process_frame
		elapsed+=get_process_delta_time()
		var previous: Vector2=room.player.position
		room.player.position=start.lerp(room.portal_position,clampf(elapsed/0.14,0,1))
		room.player.walking=true
		room.player._walk_time+=room.player.position.distance_to(previous)
		room.orbit_view.actor.modulate.a=1.0-smoothstep(0.02,0.14,elapsed)
		room.hud.get_child(0).modulate.a=1.0-smoothstep(0.0,0.14,elapsed)
		room.orbit_view._sync_state(get_process_delta_time())
	var snapshot: Texture2D
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		snapshot=ImageTexture.create_from_image(room.orbit_view.viewport.get_texture().get_image())
	return_effect.begin(snapshot,completed_runs)

func _reveal_returned_hub() -> void:
	show_hub(true)
	current.prepare_return_arrival()
	current.process_mode=Node.PROCESS_MODE_DISABLED

func _end_archive_return() -> void:
	return_effect.queue_free()
	return_effect=null
	returning=false
	current.process_mode=Node.PROCESS_MODE_INHERIT
	current.start_return_arrival()
	ambience.play_world_gate("fold")
	ambience.toggle_button.show()

func show_hub(cleared: bool) -> void:
	if returning and not cleared:return
	clear_scene()
	current=load("res://scripts/tutorial_hub.gd").new()
	current.cleared=cleared
	current.levels_requested.connect(open_level_menu)
	add_child(current)

func open_level_menu() -> void:
	if returning or level_menu!=null:return
	current.player.cancel_navigation()
	current.process_mode=Node.PROCESS_MODE_DISABLED
	ambience.toggle_button.hide()
	ambience.play_ui()
	level_menu=preload("res://scripts/fractured_level_select.gd").new()
	add_child(level_menu)
	level_menu.dismissed.connect(_close_level_menu)
	level_menu.level_committed.connect(_enter_selected_level)
	level_menu.finished.connect(_finish_level_entry)
	level_menu.cue.connect(ambience.play_world_gate)

func _close_level_menu() -> void:
	if level_menu==null:return
	level_menu.queue_free();level_menu=null
	current.process_mode=Node.PROCESS_MODE_INHERIT
	ambience.toggle_button.show()
	ambience.play_ui()

func _enter_selected_level() -> void:
	show_tutorial()
	current.start_rift_arrival()

func _finish_level_entry() -> void:
	if level_menu==null:return
	level_menu.queue_free();level_menu=null
	ambience.toggle_button.show()
