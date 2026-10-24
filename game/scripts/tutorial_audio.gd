extends Node
var enabled := true
var voices: Array[AudioStreamPlayer] = []
var events: Array[String]=[]
const FOOTSTEP_DB:=-32.0
const FOOTSTEP_STREAMS:=[
	preload("res://assets/audio/footsteps_soft_v01/step-01.wav"),
	preload("res://assets/audio/footsteps_soft_v01/step-02.wav"),
	preload("res://assets/audio/footsteps_soft_v01/step-03.wav"),
	preload("res://assets/audio/footsteps_soft_v01/step-04.wav"),
	preload("res://assets/audio/footsteps_soft_v01/step-05.wav"),
	preload("res://assets/audio/footsteps_soft_v01/step-06.wav"),
	preload("res://assets/audio/footsteps_soft_v01/step-07.wav"),
	preload("res://assets/audio/footsteps_soft_v01/step-08.wav")
]
var footstep_voice:=AudioStreamPlayer.new()
var footstep_index:=0
const STREAMS={
	"push":preload("res://assets/audio/sfx/push.ogg"),
	"stop":preload("res://assets/audio/sfx/stop.ogg"),
	"land":preload("res://assets/audio/sfx/land.ogg"),
	"fold":preload("res://assets/audio/sfx/fold.ogg"),
	"world_set":preload("res://assets/audio/sfx/world_set.ogg"),
	"star":preload("res://assets/audio/sfx/star.ogg"),
	"moon":preload("res://assets/audio/sfx/moon.ogg"),
	"seal_begin":preload("res://assets/audio/sfx/seal_begin.ogg"),
	"success":preload("res://assets/audio/sfx/success.ogg")
}

func _ready() -> void:
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -18.0
		voice.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master"
		add_child(voice)
		voices.append(voice)
	footstep_voice.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master"
	footstep_voice.volume_db=FOOTSTEP_DB;add_child(footstep_voice)

func play_footstep(dialogue_active:=false) -> void:
	if not enabled:return
	events.append("footstep")
	if events.size()>64:events.pop_front()
	# One quiet voice prevents footsteps stacking; the eight authored variants
	# provide variation without raising pitch or reusing a metal landing effect.
	footstep_voice.stream=FOOTSTEP_STREAMS[footstep_index]
	footstep_index=(footstep_index+3)%FOOTSTEP_STREAMS.size()
	footstep_voice.pitch_scale=1.0
	footstep_voice.volume_db=FOOTSTEP_DB-(6.0 if dialogue_active else 0.0)
	footstep_voice.play()

func play_event(event: String,pitch:=1.0) -> void:
	if not STREAMS.has(event):return
	events.append(event)
	if events.size()>64:events.pop_front()
	if not enabled or voices.is_empty():return
	var selected: AudioStreamPlayer=voices[0]
	for voice in voices:
		if not voice.playing:
			selected=voice
			break
	if event in ["star","moon","success"]:return # Settled-state resonance supplies the material sound.
	selected.stream=STREAMS[event]
	selected.pitch_scale=pitch
	selected.volume_db=-20.0 if event=="world_set" else (-14.0 if event in ["star","moon","success"] else -18.0)
	selected.play()

func play_resonance(kind:String) -> void:
	if not enabled:return
	var path:="res://assets/audio/resonance_v01/"+kind+".wav"
	if not ResourceLoader.exists(path):return
	events.append("resonance:"+kind)
	if events.size()>64:events.pop_front()
	for selected in voices:
		if not selected.playing:
			selected.stream=load(path);selected.pitch_scale=1.0;selected.volume_db=-23.0;selected.play();return

func play_archive_paper() -> void:
	if not enabled:return
	for selected in voices:
		if not selected.playing:
			selected.stream=STREAMS.fold;selected.pitch_scale=1.0;selected.volume_db=-29.0;selected.play();return

func stop_effects() -> void:
	footstep_voice.stop()
	for voice in voices:
		voice.stop()
		voice.stream=null
	events.clear()

func tone(frequency: float, duration: float=0.12) -> void:
	if not enabled or voices.is_empty(): return
	var pcm := PackedByteArray()
	var count := int(22050*duration)
	pcm.resize(count*2)
	for i in range(count):
		var t := float(i)/22050.0
		var envelope := minf(t/0.008,1.0)*pow(1.0-float(i)/count,2.0)
		pcm.encode_s16(i*2,int(sin(t*TAU*frequency)*envelope*15000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = pcm
	for voice in voices:
		if not voice.playing:
			voice.stream = stream
			voice.play()
			return

func _exit_tree() -> void:
	footstep_voice.stop();footstep_voice.stream=null
	for voice in voices:
		voice.stop()
		voice.stream=null
	voices.clear()
