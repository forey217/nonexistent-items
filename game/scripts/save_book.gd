extends RefCounted
## Three independent local records. Commit through a flushed temporary file and backup.
const VERSION:=2
var directory:="user://observatory_saves"
var last_error:=""

func path_for(slot: int) -> String:
	return directory.path_join("record_%d.json"%slot)

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>65536:return {}
	var parser:=JSON.new()
	if parser.parse(file.get_as_text())!=OK:return {}
	var parsed: Variant=parser.data
	return parsed if parsed is Dictionary else {}

func valid(data: Dictionary,slot: int) -> bool:
	for key in ["version","slot","checkpoint"]:
		if not data.get(key) is float and not data.get(key) is int:return false
		if not is_finite(float(data[key])):return false
	if float(data.version)!=int(data.version) or int(data.version) not in [1,VERSION] or int(data.get("slot",0))!=slot:return false
	if data.get("scene","") not in ["hub","tutorial","paper_mill"]:return false
	if not data.get("checkpoint") is float and not data.get("checkpoint") is int:return false
	if float(data.checkpoint)!=int(data.checkpoint) or int(data.checkpoint)<0 or int(data.checkpoint)>(6 if data.scene=="paper_mill" else 5):return false
	if data.scene=="paper_mill":
		if int(data.version)<2 or not valid_paper(data.get("paper_state",{})):return false
	if data.has("paper_progress") and not valid_paper(data.paper_progress):return false
	if data.has("paper_runs") and not finite_number(data.paper_runs,0,10000000):return false
	if not data.get("story") is Dictionary:return false
	for key in ["intro_seen","debrief_seen"]:
		if not data.story.get(key) is bool:return false
	for key in ["globe_awakened","globe_guided"]:
		if data.story.has(key) and not data.story[key] is bool:return false
	if not data.story.get("tutorial_runs") is float and not data.story.get("tutorial_runs") is int:return false
	if not is_finite(float(data.story.tutorial_runs)) or float(data.story.tutorial_runs)<0:return false
	for key in ["completed_runs","play_seconds","created_at","saved_at"]:
		if not data.get(key) is float and not data.get(key) is int:return false
		if not is_finite(float(data[key])) or float(data[key])<0:return false
	return true

func finite_number(value:Variant,minimum:float,maximum:float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=minimum and float(value)<=maximum

func valid_paper(payload:Variant) -> bool:
	if not payload is Dictionary or not payload.get("state") is Dictionary:return false
	if not finite_number(payload.get("player_layer"),0,1):return false
	if float(payload.player_layer)!=int(payload.player_layer):return false
	if not payload.get("player") is Array or payload.player.size()!=2:return false
	for value in payload.player:
		if not finite_number(value,0,24):return false
	var s:Dictionary=payload.state
	for key in ["clip_owned","cage_open","support_released","hatch_broken","lifted_once","upper_anchored","lower_anchored"]:
		if not s.get(key) is bool:return false
	if s.get("clip_target",null) not in ["","catch","bridge"]:return false
	if s.clip_target!="" and not s.clip_owned:return false
	if not finite_number(s.get("checkpoint"),0,6):return false
	if float(s.checkpoint)!=int(s.checkpoint):return false
	if s.has("lowpass_open") and not s.lowpass_open is bool:return false
	if not finite_number(s.get("catch_height"),0,1) or not finite_number(s.get("lift_height"),0,4.801):return false
	if not s.get("worlds") is Array or s.worlds.size()!=2:return false
	for value in s.worlds:
		if not finite_number(value,0,3) or float(value)!=int(value):return false
	if not s.get("weights") is Array or s.weights.size()!=2:return false
	for i in range(2):
		var w:Variant=s.weights[i]
		if not w is Dictionary or not finite_number(w.get("layer"),0,1):return false
		if float(w.layer)!=int(w.layer):return false
		if not w.get("pos") is Array or w.pos.size()!=2:return false
		for value in w.pos:
			if not finite_number(value,0,24):return false
		# Detached lift cargo can remain above the upper landing while the deck
		# returns to the bottom. Its saved height is relative to that moving deck.
		var max_height:float=6.301 if i==0 and w.get("station","")=="lift" else 4.801
		if not finite_number(w.get("elevation"),0,max_height):return false
		if w.get("station",null) not in (["hatch","catch","junction","lift_turn","lift","dock","bridge","anchor_turn","anchor"] if i==0 else ["cage","cage_turn","catch","junction","guide_turn","sluice_turn","sluice","guide_bend","guide"]):return false
	if s.upper_anchored and (int(s.worlds[0])!=1 or s.weights[0].station!="anchor" or int(s.weights[0].layer)!=0):return false
	if s.lower_anchored and (not s.upper_anchored or int(s.worlds[1])!=2 or s.weights[1].station!="guide"):return false
	return true

func inspect(slot: int) -> Dictionary:
	if slot<1 or slot>3:return {"status":"damaged","data":{}}
	var path:=path_for(slot)
	var data:=_json(path)
	if valid(data,slot):return {"status":"ready","data":data,"recovered":false}
	if (data.get("version") is int or data.get("version") is float) and float(data.version)>VERSION:
		return {"status":"damaged","data":{}}
	var backup:=_json(path+".bak")
	if valid(backup,slot):return {"status":"ready","data":backup,"recovered":true}
	return {"status":"damaged" if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak") else "empty","data":{}}

func _commit(path: String,data: Dictionary) -> bool:
	last_error=""
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))!=OK:
		last_error="无法创建本地存档目录。";return false
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:last_error="无法写入本地记录，请检查目录是否可写。";return false
	file.store_string(JSON.stringify(data,"\t"));file.flush();file.close()
	if _json(path+".tmp").is_empty():last_error="记录校验失败，原存档已保留。";return false
	if FileAccess.file_exists(path):
		var existing:=_json(path)
		var backup_existing: bool=valid(existing,int(data.get("slot",0))) if data.has("version") else not existing.is_empty()
		if backup_existing:
			if FileAccess.file_exists(path+".bak"):DirAccess.remove_absolute(path+".bak")
			if DirAccess.rename_absolute(path,path+".bak")!=OK:last_error="无法更新记录备份。";return false
		else:DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:
		last_error="无法完成记录写入，备份已保留。";return false
	return true

func write(slot: int,data: Dictionary) -> bool:
	if slot<1 or slot>3:last_error="档位无效。";return false
	if finite_number(data.get("version",0),VERSION+1,INF):last_error="这是更新版本的记录，当前版本不会覆盖。";return false
	var payload:=data.duplicate(true)
	payload.version=VERSION;payload.slot=slot
	if not valid(payload,slot):last_error="记录内容不完整，原存档已保留。";return false
	return _commit(path_for(slot),payload)

func create(slot: int) -> Dictionary:
	if inspect(slot).status!="empty":last_error="这个档位已经有记录。";return {}
	var now:=int(Time.get_unix_time_from_system())
	var data:={"version":VERSION,"slot":slot,"scene":"hub","checkpoint":0,"completed_runs":0,"play_seconds":0.0,"created_at":now,"saved_at":now,"story":{"intro_seen":false,"debrief_seen":false,"tutorial_runs":0}}
	return data if write(slot,data) else {}

func last_slot() -> int:
	return clampi(int(_json(directory.path_join("recent.json")).get("slot",1)),1,3)

func remember(slot: int) -> void:
	_commit(directory.path_join("recent.json"),{"slot":slot})

func _erase_file(path: String) -> Error:
	return DirAccess.remove_absolute(path)

func _restore_snapshot(snapshot: Dictionary) -> bool:
	var restored:=true
	for path: String in snapshot:
		var data: Variant=snapshot[path]
		if data==null:
			if FileAccess.file_exists(path):restored=(_erase_file(path)==OK) and restored
		else:
			var file:=FileAccess.open(path,FileAccess.WRITE)
			if file==null:restored=false;continue
			file.store_buffer(data);file.flush()
			restored=(file.get_error()==OK) and restored;file.close()
	return restored

func delete_record(slot: int) -> bool:
	last_error=""
	if slot<1 or slot>3:last_error="档位无效。";return false
	var record_path:=path_for(slot)
	var paths: Array[String]=[record_path,record_path+".bak",record_path+".tmp"]
	var recent:=directory.path_join("recent.json")
	var replace_recent: bool=int(_json(recent).get("slot",0))==slot
	if replace_recent:paths.append_array([recent,recent+".bak",recent+".tmp"])
	# Snapshot every affected byte before removal, including damaged records.
	# Only the selected slot's three fixed filenames and recent-selection metadata are touched.
	var snapshot: Dictionary={}
	for path in paths:
		if DirAccess.dir_exists_absolute(path):last_error="删除失败，请重试。";return false
		if not FileAccess.file_exists(path):snapshot[path]=null;continue
		var file:=FileAccess.open(path,FileAccess.READ)
		if file==null:last_error="删除失败，请重试。";return false
		var size:=file.get_length()
		var bytes:=file.get_buffer(size);file.close()
		if bytes.size()!=size:last_error="删除失败，请重试。";return false
		snapshot[path]=bytes
	var touched: Dictionary={}
	for path in [record_path,record_path+".bak",record_path+".tmp"]:
		if not FileAccess.file_exists(path):continue
		if _erase_file(path)!=OK:
			var restored:=_restore_snapshot(touched)
			last_error="删除失败，请重试。" if restored else "删除失败，记录恢复未完成，请检查存档目录。"
			return false
		touched[path]=snapshot[path]
	if replace_recent:
		var next_slot:=1
		for candidate in range(1,4):
			if candidate!=slot and inspect(candidate).status=="ready":next_slot=candidate;break
		for path in [recent,recent+".bak",recent+".tmp"]:touched[path]=snapshot[path]
		var metadata_ok:=_commit(recent,{"slot":next_slot})
		if metadata_ok:
			for path in [recent+".bak",recent+".tmp"]:
				if FileAccess.file_exists(path) and _erase_file(path)!=OK:metadata_ok=false;break
		if not metadata_ok:
			var restored:=_restore_snapshot(touched)
			last_error="删除失败，请重试。" if restored else "删除失败，记录恢复未完成，请检查存档目录。"
			return false
	return true

func location(data: Dictionary) -> String:
	if data.get("scene")=="paper_mill":return "纸山叠影"
	return "新手校准室" if data.get("scene")=="tutorial" else "接待大厅"

func progress(data: Dictionary) -> String:
	if data.get("scene")=="paper_mill":
		return ["寻找留影夹","准备接物台","接物台已固定","镇纸已到下层","镇纸已回上层","上层已锚定","双锚已稳定"][clampi(int(data.get("checkpoint",0)),0,6)]
	if data.get("scene")!="tutorial":return "已完成 %d 次校准"%int(data.get("completed_runs",0)) if int(data.get("completed_runs",0))>0 else "等待开始观测"
	return ["等待定位星位","镇纸抵达星位","星位已定","镇纸抵达末端","月痕已稳","界缝已封"][clampi(int(data.get("checkpoint",0)),0,5)]
