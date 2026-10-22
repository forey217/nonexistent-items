extends RefCounted
## Three independent local records. Commit through a flushed temporary file and backup.
const VERSION:=1
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
	if int(data.get("version",0))!=VERSION or int(data.get("slot",0))!=slot:return false
	if data.get("scene","") not in ["hub","tutorial"]:return false
	if not data.get("checkpoint") is float and not data.get("checkpoint") is int:return false
	if float(data.checkpoint)!=int(data.checkpoint) or int(data.checkpoint)<0 or int(data.checkpoint)>5:return false
	if not data.get("story") is Dictionary:return false
	for key in ["intro_seen","debrief_seen"]:
		if not data.story.get(key) is bool:return false
	if not data.story.get("tutorial_runs") is float and not data.story.get("tutorial_runs") is int:return false
	if not is_finite(float(data.story.tutorial_runs)) or float(data.story.tutorial_runs)<0:return false
	for key in ["completed_runs","play_seconds","created_at","saved_at"]:
		if not data.get(key) is float and not data.get(key) is int:return false
		if not is_finite(float(data[key])) or float(data[key])<0:return false
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

func location(data: Dictionary) -> String:
	return "新手校准室" if data.get("scene")=="tutorial" else "接待大厅"

func progress(data: Dictionary) -> String:
	if data.get("scene")!="tutorial":return "已完成 %d 次校准"%int(data.get("completed_runs",0)) if int(data.get("completed_runs",0))>0 else "等待开始观测"
	return ["等待定位星位","镇纸抵达星位","星位已定","镇纸抵达末端","月痕已稳","界缝已封"][clampi(int(data.get("checkpoint",0)),0,5)]
