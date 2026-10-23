extends Node
## Persistent music and independent Music/SFX/Dialogue gains under Master.
signal volume_changed(percent: float)
signal channel_volume_changed(channel: String,percent: float)
const CHANNEL_BUSES={"music":"Music","sfx":"SFX","dialogue":"Dialogue"}
var preferences=preload("res://scripts/audio_preferences.gd").new()
var save_age := -1.0
var settings_error := OK
var music := AudioStreamPlayer.new()
var ui_voice := AudioStreamPlayer.new()
var muted := false
var toggle_button: Button
var target_db := -24.0
var dialogue_active := false
var archive_events: Array[String]=[]

func _ready() -> void:
	for bus_name in CHANNEL_BUSES.values():
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name),"Master")
	var args:=OS.get_cmdline_user_args()
	if Array(args).any(func(arg):return arg.ends_with("-check") or arg.ends_with("-self-test") or arg.ends_with("-demo") or arg.contains("capture")):
		preferences.path=""
	for arg in args:
		if arg.begins_with("--audio-settings="):preferences.path=arg.trim_prefix("--audio-settings=")
	preferences.load_settings()
	_apply_volume()
	for channel in CHANNEL_BUSES:_apply_channel(channel)
	var stream: AudioStreamOggVorbis=preload("res://assets/audio/music/magic_puzzle.ogg").duplicate()
	stream.loop=true
	music.stream=stream
	music.bus="Music"
	music.volume_db=-55.0
	add_child(music)
	if DisplayServer.get_name()!="headless":music.play()
	ui_voice.stream=preload("res://assets/audio/sfx/ui.ogg")
	ui_voice.bus="SFX"
	ui_voice.volume_db=-18.0
	add_child(ui_voice)
	var layer:=CanvasLayer.new()
	layer.layer=2
	add_child(layer)
	toggle_button=Button.new();toggle_button.text="声音：开   M";toggle_button.position=Vector2(22,378);toggle_button.size=Vector2(184,28)
	preload("res://scripts/instrument_theme.gd").apply_button(toggle_button,12);layer.add_child(toggle_button)
	toggle_button.add_theme_font_size_override("font_size",12)
	toggle_button.pressed.connect(toggle_mute)
	_apply_volume()

func _process(delta: float) -> void:
	music.volume_db=move_toward(music.volume_db,target_db-(6.0 if dialogue_active else 0.0),delta*24.0)
	if save_age>=0:
		save_age-=delta
		if save_age<=0:save_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_M:
		toggle_mute()
		get_viewport().set_input_as_handled()

func toggle_mute() -> void:
	set_volume(preferences.audible_volume if muted else 0.0)
	if not muted:play_ui()

func set_volume(percent: float) -> void:
	if not is_finite(percent):return
	preferences.volume=clampf(percent,0.0,100.0)
	if preferences.volume>0:preferences.audible_volume=preferences.volume
	_apply_volume()
	volume_changed.emit(preferences.volume)
	save_age=0.2

func _apply_volume() -> void:
	var master:=AudioServer.get_bus_index("Master")
	muted=preferences.volume<=0.0
	AudioServer.set_bus_volume_db(master,linear_to_db(maxf(preferences.volume/100.0,0.0001)))
	AudioServer.set_bus_mute(master,muted)
	if is_instance_valid(toggle_button):toggle_button.text="声音：关   M" if muted else "声音：开   M"

func set_channel_volume(channel: String,percent: float) -> void:
	if not CHANNEL_BUSES.has(channel) or not is_finite(percent):return
	preferences.channels[channel]=clampf(percent,0.0,100.0)
	_apply_channel(channel)
	channel_volume_changed.emit(channel,preferences.channels[channel])
	save_age=0.2

func _apply_channel(channel: String) -> void:
	var bus:=AudioServer.get_bus_index(CHANNEL_BUSES[channel])
	var percent: float=preferences.channels[channel]
	AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(percent/100.0,0.0001)))
	AudioServer.set_bus_mute(bus,percent<=0.0)

func save_settings() -> void:
	settings_error=preferences.save_settings()
	save_age=-1.0

func play_ui() -> void:
	ui_voice.stream=preload("res://assets/audio/sfx/ui.ogg")
	ui_voice.pitch_scale=1.0
	ui_voice.volume_db=-18.0
	ui_voice.play()

func play_globe_awaken() -> void:
	ui_voice.stream=preload("res://assets/audio/sfx/star.ogg")
	ui_voice.pitch_scale=0.94;ui_voice.volume_db=-25.0;ui_voice.play()

func play_world_gate(cue: String) -> void:
	ui_voice.stream=preload("res://assets/audio/sfx/fold.ogg") if cue=="fold" else preload("res://assets/audio/sfx/world_set.ogg")
	ui_voice.pitch_scale=0.85 if cue=="fold" else 1.15
	ui_voice.volume_db=-16.0
	ui_voice.play()

func play_archive(cue: String) -> void:
	archive_events.append(cue)
	if archive_events.size()>24:archive_events.pop_front()
	match cue:
		"stamp":
			ui_voice.stream=preload("res://assets/audio/sfx/stop.ogg")
			ui_voice.pitch_scale=0.78;ui_voice.volume_db=-13.0
		"file":
			ui_voice.stream=preload("res://assets/audio/sfx/fold.ogg")
			ui_voice.pitch_scale=0.85;ui_voice.volume_db=-16.0
		"arrived":
			ui_voice.stream=preload("res://assets/audio/sfx/star.ogg")
			ui_voice.pitch_scale=1.16;ui_voice.volume_db=-17.0
	ui_voice.play()

func stop_all() -> void:
	if save_age>=0:save_settings()
	set_process(false)
	music.stop();music.stream=null
	ui_voice.stop();ui_voice.stream=null

func _exit_tree() -> void:
	stop_all()
