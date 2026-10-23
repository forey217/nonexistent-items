extends SceneTree
const Lines=preload("res://scripts/dialogue_script.gd")
const State=preload("res://scripts/tutorial_state.gd")
var entries: Dictionary={}
func add(lines: Array,scene: String,trigger: String,category: String) -> void:
	for item: Dictionary in lines:
		var id: String=item.id
		if entries.has(id):
			if not entries[id].triggers.has(trigger):entries[id].triggers.append(trigger)
			continue
		entries[id]={"id":id,"scene":scene,"category":category,"speaker":item.speaker,"role":"衍月" if item.speaker=="yanyue" else "特斯拉","text":item.text,"triggers":[trigger],"audio_file":id+".wav","emotion":"好奇、冷静，轻微吐槽；保持自然交流。" if item.speaker=="yanyue" else "沉稳、熟悉工作，带一点幽默；提示不催促。"}
func _initialize() -> void:
	add(Lines.opening(),"接待大厅","首次靠近/点击特斯拉，或点击桌前光标后抵达","主线")
	add(Lines.debrief(),"接待大厅","首次完成第一关归档并抵达大厅","主线")
	for expanded in [false,true]:add(Lines.selection(expanded),"星系仪选关","水晶展开" if expanded else "打开星系仪","选关")
	for stage in range(6):
		for world in range(3):
			for replay in [false,true]:add(Lines.tutorial(stage,world,replay),"第一关","阶段%d，世界%d，%s"%[stage,world,"重玩/续玩" if replay else "初次"],"默认教学")
	for name in ["after-skip","reminder","reset","archive","gate-lost","gate-restored","first-push","first-float","early-float","idle"]:
		add(Lines.event(name),"大厅" if name in ["after-skip","reminder"] else "第一关",name,"自动求助入口" if name=="idle" else "事件回应")
	for text in Lines.notices():add([Lines.line("tesla",text)],"第一关","点击未稳定出口，或在太重/悬空状态尝试推动","操作回应")
	for stage in range(6):
		var state:=State.new()
		state.first_latched=stage>=2;state.receiver_latched=stage>=4
		state.rail_position=0 if stage==0 else (State.FIRST_STOP if stage<=2 else State.RAIL_LENGTH)
		state.world=State.World.HEAVY if stage in [2,5] else (State.World.INVERTED if stage==4 else State.World.ICE)
		state.elevation=State.CEILING if stage==4 else 0.0;state._update_contacts()
		for level in range(1,4):add([Lines.line("tesla",state.hint(level))],"第一关","阶段%d，玩家主动按H第%d层"%[stage,level],"主动H提示")
	for kind in ["early-airborne","moon-away"]:
		var state:=State.new();state.elevation=20
		state.receiver_latched=kind=="moon-away"
		for level in range(1,4):add([Lines.line("tesla",state.hint(level))],"第一关","%s，玩家主动按H第%d层"%[kind,level],"主动H提示")
	var folder:="res://docs/voice-v43"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):folder=arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var ignore:=FileAccess.open(folder.path_join(".gdignore"),FileAccess.WRITE);ignore.close()
	var json:=FileAccess.open(folder.path_join("配音台词清单-v43.json"),FileAccess.WRITE)
	json.store_string(JSON.stringify({"game":"世界不按说明书","bureau":"世界观察局","scope":"主界面至第一关归档及复盘；不包含第二关独立对白","id_rule":"vo_角色_角色与精确文本的SHA256前16位；文字修改生成新ID，排序变化不变","lines":entries.values()},"\t"));json.close()
	var csv:=FileAccess.open(folder.path_join("配音台词清单-v43.csv"),FileAccess.WRITE)
	csv.store_string("\ufeff")
	csv.store_csv_line(PackedStringArray(["台词编号","场景","分类","角色","最终文字","触发条件","建议音频文件名","情绪备注"]))
	for row: Dictionary in entries.values():csv.store_csv_line(PackedStringArray([row.id,row.scene,row.category,row.role,row.text,"；".join(row.triggers),row.audio_file,row.emotion]))
	csv.close()
	var md:=FileAccess.open(folder.path_join("配音交付说明-v43.md"),FileAccess.WRITE)
	md.store_string("# 配音交付说明 v43\n\n机构为世界观察局，游戏名为《世界不按说明书》。\n\nJSON和CSV共%d条独立台词，文件名使用清单中的稳定编号。一句一文件，干净人声；优先WAV单声道44.1或48kHz/16位，MP3、OGG也可交付。不要混入音乐和环境混响。先各制作3—5句试听，确认音色再批量生成。\n\n编号由角色和精确文字生成，调整顺序不会改变编号；文字变化会产生新编号，不用旧语音冒充新台词。相同句子只录一份，清单列出所有触发条件。默认剧情、主动H和特殊操作回应已区分。当前未接入语音播放；接入时需停止过期语音、匹配字幕时长、压低音乐并另设人声音量。\n\n## 主线开场\n\n"%entries.size())
	for item in Lines.opening():md.store_string("- **%s**：%s（`%s.wav`）\n"%["衍月" if item.speaker=="yanyue" else "特斯拉",item.text,item.id])
	md.store_string("\n## 第一关复盘\n\n")
	for item in Lines.debrief():md.store_string("- **%s**：%s（`%s.wav`）\n"%["衍月" if item.speaker=="yanyue" else "特斯拉",item.text,item.id])
	md.close()
	print("VOICE_MANIFEST ",entries.size()," unique lines -> ",folder)
	quit()
