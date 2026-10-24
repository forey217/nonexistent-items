extends Node
var results:Array[Dictionary]=[]
var failures:=0
var directory:=""

func frames(count:int) -> void:
	for index in range(count):await get_tree().physics_frame

func until(condition:Callable) -> bool:
	for index in range(600):
		await frames(1)
		if condition.call():return true
	return false

func check(label:String,passed:bool) -> void:
	results.append({"test":label,"passed":passed})
	if not passed:failures+=1;push_error("WARM_GATE_FAILED "+label)

func run(app:Node) -> void:
	directory=ProjectSettings.globalize_path("res://../showcase/checks/warm-gate-v01")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifacts="):directory=argument.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	var audio:Node=app.ambience
	check("chosen_B_files_have_original_duration",is_equal_approx(audio.GATE_ENTRY.get_length(),3.6) and is_equal_approx(audio.GATE_SELECT.get_length(),2.9))
	check("nonlooping_original_pitch_and_sfx_bus",audio.GATE_ENTRY.loop_mode==AudioStreamWAV.LOOP_DISABLED and audio.GATE_SELECT.loop_mode==AudioStreamWAV.LOOP_DISABLED and audio.gate_voice.bus=="SFX" and audio.gate_voice.pitch_scale==1.0)
	app.current.begin();await frames(2)
	check("start_button_plays_B_entry",audio.gate_voice.stream==audio.GATE_ENTRY and audio.gate_voice.playing)
	await frames(10);var position:float=audio.gate_voice.get_playback_position()
	audio.play_entry();await frames(2)
	check("same_entry_animation_does_not_restart_sound",audio.gate_voice.get_playback_position()>=position)
	audio.play_ui();await frames(2)
	check("UI_click_does_not_cut_transition_tail",audio.gate_voice.stream==audio.GATE_ENTRY and audio.gate_voice.playing and audio.ui_voice.stream.resource_path.ends_with("ui.ogg"))
	check("real_start_reaches_hall",await until(func():return not app.menu_revealing and app.current.get("hall_camera")!=null))
	app.open_level_menu();await frames(2)
	check("globe_open_plays_B_selection",app.level_menu!=null and audio.gate_voice.stream==audio.GATE_SELECT and audio.gate_voice.playing)
	app.level_menu.expand_crystal();await frames(2)
	check("crystal_expansion_plays_B_selection",audio.gate_voice.stream==audio.GATE_SELECT and audio.gate_voice.playing)
	check("crystal_reaches_selection",await until(func():return app.level_menu.phase==2))
	app.level_menu.choose_shard(0);await frames(2)
	check("choose_world_plays_B_selection",audio.gate_voice.stream==audio.GATE_SELECT and audio.gate_voice.playing)
	check("world_enters_through_normal_transition",await until(func():return app.level_menu==null and app.current.get("orbit_view")!=null))
	check("arrival_preserves_B_tail_without_old_glass_sound",audio.gate_voice.stream==audio.GATE_SELECT and audio.gate_voice.playing)
	audio.set_channel_volume("sfx",0)
	check("SFX_slider_mutes_gate_bus",AudioServer.is_bus_mute(AudioServer.get_bus_index(audio.gate_voice.bus)))
	audio.set_channel_volume("sfx",100);audio.set_volume(0)
	check("master_mute_still_applies",AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	audio.set_volume(100)
	await app.shutdown_audio()
	check("shutdown_releases_gate_stream",not audio.gate_voice.playing and audio.gate_voice.stream==null)
	var report:=FileAccess.open(directory.path_join("warm-gate-report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":results,"failures":failures,"native_render":DisplayServer.get_name()!="headless"},"\t"));report.close()
	print("WARM_GATE_REPORT ",results.size()," checks, ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
