extends Node
var enabled := true
var voices: Array[AudioStreamPlayer] = []
var events: Array[String]=[]
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
	selected.stream=STREAMS[event]
	selected.pitch_scale=pitch
	selected.volume_db=-20.0 if event=="world_set" else (-14.0 if event in ["star","moon","success"] else -18.0)
	selected.play()

func stop_effects() -> void:
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
	for voice in voices:
		voice.stop()
		voice.stream=null
	voices.clear()
