extends Node
var enabled := true
var voices: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in range(4):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -18.0
		add_child(voice)
		voices.append(voice)

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
