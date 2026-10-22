extends Node2D
var current: Node2D
var completed_runs := 0
var ambience: Node
var closing := false
var returning := false
var return_effect: CanvasLayer
var level_menu: CanvasLayer
var menu_revealing := false
var title_entry: CanvasLayer
var return_menu_button: Button
var title_return_pending := false
var dialogue: Node
var hall_entered := false
var save_book=preload("res://scripts/save_book.gd").new()
var checkpoint_codec=preload("res://scripts/save_checkpoint.gd").new()
var save_picker: CanvasLayer
var active_slot:=0
var active_record: Dictionary={}
var saving_enabled:=true
var play_seconds:=0.0
var saved_signature:=""
var save_error:=""
var save_retry_age:=0.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	saving_enabled="--save-check" in args or not Array(args).any(func(arg):return arg.ends_with("-check") or arg.ends_with("-self-test") or arg.ends_with("-demo") or arg.contains("capture"))
	for arg in args:
		if arg.begins_with("--save-dir="):save_book.directory=arg.trim_prefix("--save-dir=")
	for legacy in ["--self-test","--capture","--capture-gait","--walk-demo"]:
		if legacy in args:
			current=load("res://scenes/movement_test.tscn").instantiate()
			add_child(current)
			return
	get_tree().auto_accept_quit=false
	ambience=preload("res://scripts/bureau_audio.gd").new()
	add_child(ambience)
	_build_title_navigation()
	dialogue=preload("res://scripts/bureau_dialogue.gd").new()
	dialogue.flow=self
	# Legacy suites exercise mechanics without waiting on story pages. The dedicated
	# dialogue suite keeps the real presentation and input routing enabled.
	dialogue.enabled="--dialogue-check" in args or not Array(args).any(func(arg):return arg.ends_with("-check") or arg.ends_with("-self-test") or arg.ends_with("-demo") or arg.contains("capture"))
	add_child(dialogue)
	if "--hub" in args or "--hub-check" in args or "--paperweight-preview" in args or "--teaching-preview" in args:show_hub(false)
	elif Array(args).any(func(arg):return arg in ["--tutorial","--tutorial-capture","--skill-capture","--tutorial-self-test","--orbit-self-test","--tutorial-demo","--hud-check","--task-check","--pad-guide-check","--film-check","--polish-check","--archive-check","--interaction-check","--wall-self-test"]):show_tutorial()
	else:show_menu()
	if "--menu-self-test" in args:
		var suite=load("res://tests/menu_tests.gd").new()
		add_child(suite)
		suite.run.call_deferred(self)
	if "--dialogue-check" in args:
		var suite=load("res://tests/dialogue_checks.gd").new()
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
	if "--save-check" in args:
		var suite=load("res://tests/save_flow_checks.gd").new();add_child(suite)
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
	_save_progress(true)
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
	return_menu_button.tooltip_text = "保存稳定检查点并返回主界面。"
	return_menu_button.pressed.connect(request_title_return)
	return_menu_button.hide()
	ui.free()

func _process(_delta: float) -> void:
	save_retry_age=maxf(0.0,save_retry_age-_delta)
	if active_slot>0 and is_instance_valid(current) and not current.has_signal("start_requested") and not menu_revealing and level_menu==null and not returning:
		play_seconds+=_delta
		_save_progress()
	if not is_instance_valid(return_menu_button) or not is_instance_valid(current): return
	var playable := not current.has_signal("start_requested")
	var full_hall: bool=current.get("hall_camera")!=null
	return_menu_button.position=Vector2(1054,22) if full_hall else Vector2(1054,655)
	ambience.toggle_button.position=Vector2(22,22) if full_hall else Vector2(22,378)
	var busy := closing or returning or menu_revealing or title_return_pending or level_menu != null
	if current.has_method("arrival_busy") and current.arrival_busy(): busy = true
	return_menu_button.visible = playable and not busy

func request_title_return() -> bool:
	if closing or returning or menu_revealing or title_return_pending or level_menu != null: return false
	if not is_instance_valid(current) or current.has_signal("start_requested"): return false
	if current.has_method("arrival_busy") and current.arrival_busy(): return false
	title_return_pending = true
	_save_progress(true)
	return_menu_button.hide()
	ambience.play_ui()
	show_menu.call_deferred()
	return true

func _start_from_menu() -> void:
	if closing or menu_revealing:return
	if saving_enabled:
		await _start_with_save_picker();return
	menu_revealing=true
	ambience.toggle_button.hide()
	title_entry=preload("res://scripts/bureau_entry_transition.gd").new()
	add_child(title_entry)
	await title_entry.play(current,self)
	title_entry.queue_free()
	title_entry=null
	var entry:=preload("res://scripts/hall_entry.gd").new()
	current.entry_effect=entry
	add_child(entry)
	entry.begin(current,not hall_entered,true)
	hall_entered=true
	await entry.finished
	entry.queue_free()
	menu_revealing=false
	ambience.toggle_button.show()

func _activate_slot(slot: int) -> bool:
	var result: Dictionary=save_book.inspect(slot)
	var data: Dictionary=save_book.create(slot) if result.status=="empty" else result.data
	if data.is_empty() or result.status=="damaged":return false
	dialogue.clear()
	active_slot=slot;active_record=data.duplicate(true);play_seconds=float(data.play_seconds)
	completed_runs=int(data.completed_runs)
	hall_entered=bool(data.story.intro_seen) or completed_runs>0
	dialogue.intro_seen=bool(data.story.intro_seen);dialogue.debrief_seen=bool(data.story.debrief_seen)
	dialogue.tutorial_runs=int(data.story.get("tutorial_runs",0))
	saved_signature="";save_error="";save_book.remember(slot)
	return true

func _start_with_save_picker() -> void:
	menu_revealing=true;ambience.toggle_button.hide()
	var menu=current
	var tween:=create_tween()
	tween.tween_method(menu.set_entry_progress,0.0,1.0,0.48 if menu.motion_enabled else 0.18)
	await tween.finished
	save_picker=preload("res://scripts/save_select.gd").new()
	save_picker.book=save_book;save_picker.motion_enabled=menu.motion_enabled
	save_picker.approach_from=menu._scene_point(Vector2(0.8897,0.503))
	add_child(save_picker)
	while true:
		var slot: int=await save_picker.chosen
		if slot==0:
			save_picker.queue_free();save_picker=null;menu_revealing=false;show_menu();return
		if _activate_slot(slot):break
		save_picker.retry(save_book.last_error if not save_book.last_error.is_empty() else "无法读取记录，原文件已保留。")
	var entry: CanvasLayer
	if active_record.scene=="tutorial":
		show_tutorial()
		checkpoint_codec.restore(current,int(active_record.checkpoint))
		dialogue.tutorial_runs=maxi(2,int(active_record.story.get("tutorial_runs",1)))
		dialogue.clear();dialogue.seen.clear();dialogue.phase=-1
		current.start_rift_arrival()
	else:
		show_hub(completed_runs>0)
		entry=preload("res://scripts/hall_entry.gd").new();current.entry_effect=entry;add_child(entry)
		entry.begin(current,not hall_entered,true)
	await save_picker.reveal_scene()
	save_picker.queue_free();save_picker=null
	if is_instance_valid(entry) and entry.active:await entry.finished
	if is_instance_valid(entry):entry.queue_free()
	while current.arrival_busy():await get_tree().physics_frame
	hall_entered=true;menu_revealing=false;ambience.toggle_button.show()
	_save_progress(true)

func _record_snapshot(force: bool) -> Dictionary:
	if active_slot==0 or not is_instance_valid(current) or current.has_signal("start_requested"):return {}
	var data:=active_record.duplicate(true)
	data.saved_at=int(Time.get_unix_time_from_system());data.play_seconds=play_seconds;data.completed_runs=completed_runs
	data.story={"intro_seen":dialogue.intro_seen,"debrief_seen":dialogue.debrief_seen,"tutorial_runs":dialogue.tutorial_runs}
	if dialogue.modal:
		if dialogue.segment=="opening":data.story.intro_seen=active_record.story.intro_seen
		if dialogue.segment=="debrief":data.story.debrief_seen=active_record.story.debrief_seen
	if current.get("state")!=null and not current.finished and not returning:
		var checkpoint: int=checkpoint_codec.stable(current)
		if checkpoint<0:
			if not force:return {}
			checkpoint=int(active_record.checkpoint) if active_record.scene=="tutorial" else 0
		data.scene="tutorial";data.checkpoint=checkpoint
	else:data.scene="hub";data.checkpoint=0
	return data

func _save_progress(force:=false) -> bool:
	if not saving_enabled or active_slot==0:return false
	if not force and save_retry_age>0:return false
	if not force and (menu_revealing or level_menu!=null or returning or dialogue.modal):return false
	var data:=_record_snapshot(force)
	if data.is_empty():return false
	var signature:=JSON.stringify([data.scene,data.checkpoint,data.completed_runs,data.story])
	if not force and signature==saved_signature:return true
	if not save_book.write(active_slot,data):
		save_error=save_book.last_error
		save_retry_age=5.0
		if current.get("hud")!=null:
			if current.hud.has_method("message"):current.hud.message("记录尚未写入："+save_error)
			else:current.hud.set_status("记录尚未写入："+save_error,true)
		return false
	active_record=data;saved_signature=signature;save_error="";save_retry_age=0.0
	return true

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
	if is_instance_valid(dialogue):dialogue.clear()
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
	dialogue.bind(current,"tutorial")
	current.dialogue_hint.connect(dialogue.hint)
	current.dialogue_reset.connect(dialogue.reset_tutorial)
	current.dialogue_notice.connect(dialogue.notice)
	for item in current.hud.menu_buttons:item.pressed.connect(ambience.play_ui)

func _on_completed() -> void:
	if returning:return
	completed_runs+=1
	if "--tutorial-self-test" in OS.get_cmdline_user_args() or "--orbit-self-test" in OS.get_cmdline_user_args(): return
	returning=true
	_save_progress(true)
	_begin_archive_return.call_deferred()

func _begin_archive_return() -> void:
	var room=current
	dialogue.archive()
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
	current.dialogue_requested.connect(dialogue.talk_to_tesla)
	add_child(current)
	dialogue.bind(current,"hub")

func open_level_menu() -> void:
	if returning or level_menu!=null or dialogue.modal:return
	dialogue.begin_selection()
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
	dialogue.clear()
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
