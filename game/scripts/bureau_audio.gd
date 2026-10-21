extends Node
## Persistent music, separate music/SFX buses, and an unobtrusive mute control.
var music := AudioStreamPlayer.new()
var ui_voice := AudioStreamPlayer.new()
var muted := false
var toggle_button: Button
var target_db := -24.0
var archive_events: Array[String]=[]

func _ready() -> void:
	for bus_name in ["Music","SFX"]:
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),false)
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
	var ui=preload("res://scripts/tutorial_hud.gd").new()
	ui.font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	var layer:=CanvasLayer.new()
	layer.layer=2
	add_child(layer)
	toggle_button=ui.button(layer,"声音：开   M",Vector2(22,378),Vector2(184,28))
	toggle_button.add_theme_font_size_override("font_size",12)
	toggle_button.pressed.connect(toggle_mute)
	ui.free()

func _process(delta: float) -> void:
	music.volume_db=move_toward(music.volume_db,target_db,delta*16.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_M:
		toggle_mute()
		get_viewport().set_input_as_handled()

func toggle_mute() -> void:
	muted=not muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),muted)
	toggle_button.text="声音：关   M" if muted else "声音：开   M"
	if not muted:play_ui()

func play_ui() -> void:
	ui_voice.stream=preload("res://assets/audio/sfx/ui.ogg")
	ui_voice.pitch_scale=1.0
	ui_voice.volume_db=-18.0
	ui_voice.play()

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
	set_process(false)
	music.stop();music.stream=null
	ui_voice.stop();ui_voice.stream=null

func _exit_tree() -> void:
	stop_all()
