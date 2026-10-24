extends Node
## One voice at a time; identity requires both the exact text and the speaker.
const ROOT := "res://assets/audio/dialogue_v01/"
var library_root:=ROOT
var enabled := true
var unscaled_clock:=false
var player := AudioStreamPlayer.new()
var entries: Dictionary={}
var current: Dictionary={}
var current_id := ""
var duration := 0.0
var age := 0.0
var completed := false
var history: Array[Dictionary]=[]
var missing_ids: Array[String]=[]

func _ready() -> void:
	player.bus="Dialogue" if AudioServer.get_bus_index("Dialogue")>=0 else "Master"
	player.volume_db=-1.0
	add_child(player)
	player.finished.connect(func():completed=true)
	var manifest_path:=library_root+"manifest.json"
	if not FileAccess.file_exists(manifest_path):return
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not data is Dictionary:return
	for item in data.get("items",[]):
		if item is Dictionary and item.has("id"):entries[item.id]=item

func start_line(item: Dictionary) -> float:
	stop()
	if not enabled:return 0.0
	var id: String=item.get("id","")
	if not entries.has(id):
		if not missing_ids.has(id):missing_ids.append(id)
		return 0.0
	var record: Dictionary=entries[id]
	if record.get("speaker")!=item.get("speaker") or record.get("display_text")!=item.get("text"):return 0.0
	var expected_voice: String="zh-CN-XiaoyiNeural" if item.speaker=="yanyue" else "zh-CN-YunyangNeural"
	if record.get("voice")!=expected_voice:return 0.0
	var file: String=library_root+record.get("file","")
	if not ResourceLoader.exists(file):return 0.0
	var stream: AudioStream=load(file)
	if stream==null:return 0.0
	current=record;current_id=id;duration=stream.get_length()
	player.stream=stream;player.play()
	history.append({"id":id,"speaker":item.speaker,"voice":record.voice,"file":record.file})
	if history.size()>250:history.pop_front()
	return duration

func stop() -> void:
	player.stop();player.stream=null;player.stream_paused=false
	current={};current_id="";duration=0;age=0;completed=false

func _process(delta: float) -> void:
	if current_id.is_empty() or player.stream_paused:return
	age+=delta/maxf(Engine.time_scale,.01) if unscaled_clock else delta
	if DisplayServer.get_name()=="headless" and age>=duration:completed=true

func position_seconds() -> float:
	if current_id.is_empty():return 0.0
	if completed:return duration
	if DisplayServer.get_name()=="headless":return minf(age,duration)
	return clampf(player.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency(),0,duration)

func cue_time(keyword: String) -> float:
	return float(current.get("cue_seconds",{}).get(keyword,-1.0))

func speaking() -> bool:
	return not current_id.is_empty() and not completed and player.playing
