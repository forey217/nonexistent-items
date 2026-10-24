extends Node
var app:Node
var room:Node
var capture:=AudioEffectCapture.new()
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0

func check(label:String,passed:bool) -> void:
	results.append({"test":label,"passed":passed});print("FOOTSTEP_CHECK ",label," ",passed)
	if not passed:failures+=1
	var file:=FileAccess.open(directory.path_join("footstep-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results,"failures":failures,"native_audio":DisplayServer.get_name()!="headless"},"\t"))

func wait_wall(milliseconds:int) -> void:
	var end:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<end:await get_tree().physics_frame

func peak() -> float:
	var buffer:=capture.get_buffer(capture.get_frames_available());var value:=0.0
	for frame:Vector2 in buffer:value=maxf(value,maxf(absf(frame.x),absf(frame.y)))
	return value

func run(flow:Node) -> void:
	app=flow;app.show_paper_mill();room=app.current
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	room.communications.stop();room.communications.enabled=false
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	await wait_wall(200)
	check("footsteps_follow_sfx_slider",room.sound.footstep_voice.bus=="SFX")
	check("quiet_gain_has_headroom",room.sound.footstep_voice.volume_db<=-30)
	# Capture the real native audio mixer after player gain. Sending this test bus
	# through a muted Master keeps verification silent on the user's speakers.
	AudioServer.add_bus();var bus:=AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,"FootstepQA");AudioServer.set_bus_send(bus,"Master")
	capture.buffer_length=4;AudioServer.add_bus_effect(bus,capture)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)
	room.sound.footstep_voice.bus="FootstepQA"
	for voice:AudioStreamPlayer in room.sound.voices:voice.bus="FootstepQA"
	room.sound.stop_effects();capture.clear_buffer()
	room.sound.play_event("land",1.6);await wait_wall(650);var old_peak:=peak()
	room.sound.stop_effects();capture.clear_buffer();room.sound.footstep_index=0
	room.sound.play_footstep(false);await wait_wall(500);var soft_peak:=peak()
	room.sound.stop_effects();capture.clear_buffer();room.sound.footstep_index=0
	room.sound.play_footstep(true);await wait_wall(500);var speech_peak:=peak()
	check("native_mixer_captured_audio",old_peak>.0001 and soft_peak>.0001)
	check("soft_steps_much_quieter_than_old_metal",soft_peak<old_peak*.5)
	check("speech_ducks_footsteps_further",speech_peak<soft_peak*.60 and speech_peak>soft_peak*.4)
	check("no_raised_pitch",is_equal_approx(room.sound.footstep_voice.pitch_scale,1))
	var variants:Array=[]
	for i in range(8):room.sound.play_footstep();variants.append(room.sound.footstep_voice.stream.resource_path)
	check("eight_variants_avoid_one_repeated_sample",variants.size()==8 and variants.all(func(path):return variants.count(path)==1))
	room.sound.stop_effects();room.sound.events.clear()
	room.player.teleport_for_reset(Vector2(8,5)*room.SCALE);room.player.controls_locked=false
	Input.action_press("walk_down");await wait_wall(1100);Input.action_release("walk_down")
	check("actual_walking_uses_soft_steps",room.sound.events.count("footstep")>0 and not "land" in room.sound.events)
	await wait_wall(250);var stopped:int=room.sound.events.count("footstep");await wait_wall(650)
	check("standing_still_stops_steps",stopped==room.sound.events.count("footstep"))
	room.sound.play_footstep();room.hud.menu.open();await wait_wall(80)
	check("pause_stops_step_tail",not room.sound.footstep_voice.playing)
	room.hud.menu.close();room.sound.stop_effects()
	check("stop_effects_clears_step_player",not room.sound.footstep_voice.playing)
	var file:=FileAccess.open(directory.path_join("mixer-peaks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"old_metal_peak":old_peak,"soft_peak":soft_peak,"during_speech_peak":speech_peak,"gain_db":-32,"duck_db":6},"\t"))
	print("FOOTSTEP_FINISHED checks=",results.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
