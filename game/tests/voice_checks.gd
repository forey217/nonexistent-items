extends Node
var app: Node
var results: Array[Dictionary]=[]
var failures:=0
var directory:=""

func check(name: String,passed: bool) -> void:
	results.append({"test":name,"passed":passed})
	if not passed:failures+=1;push_error("VOICE_FAILED "+name)

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition: Callable,limit:=800) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func run(flow: Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory="user://voice-checks"
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(3)
	var d=app.dialogue
	var voice=d.voice
	check("manifest_has_all_74_exact_lines",voice.enabled and voice.entries.size()==74)
	var all_load:=true;var identity:=true;var female:=0;var male:=0
	for record: Dictionary in voice.entries.values():
		var item: Dictionary=d.Lines.line(record.speaker,record.display_text)
		identity=identity and item.id==record.id
		var duration: float=voice.start_line(item)
		all_load=all_load and duration>0.8 and absf(duration-float(record.duration_seconds))<0.12 and voice.player.stream!=null
		if record.speaker=="yanyue":female+=1;identity=identity and record.voice=="zh-CN-XiaoyiNeural" and record.gender=="female"
		else:male+=1;identity=identity and record.voice=="zh-CN-YunyangNeural" and record.gender=="male" and record.rate=="-8%" and record.pitch=="-4Hz"
	voice.stop()
	check("all_74_mp3_resources_decode_and_match_duration",all_load)
	check("16_female_and_58_male_have_correct_voice_and_stable_ids",identity and female==16 and male==58)
	check("voice_routes_to_existing_dialogue_bus",voice.player.bus=="Dialogue" and AudioServer.get_bus_index("Dialogue")>=0)
	var swapped: Dictionary=d.Lines.opening()[0].duplicate(true);swapped.speaker="yanyue"
	check("speaker_mismatch_cannot_play_male_clip_as_female",voice.start_line(swapped)==0.0 and voice.current_id.is_empty())
	var rewritten: Dictionary=d.Lines.opening()[0].duplicate(true);rewritten.text+="修改"
	check("changed_text_cannot_reuse_old_clip",voice.start_line(rewritten)==0.0 and voice.current_id.is_empty())
	app.show_hub(false);d.hub_wait=false
	d.play("voice-opening",d.Lines.opening(),false);await frames(2)
	check("real_story_starts_exact_male_clip",voice.current_id==d.active.id and voice.current.speaker=="tesla" and voice.player.playing)
	var first_id: String=voice.current_id
	var played_count: int=voice.history.size()
	d.view.age=0.2;d.view.advance()
	check("revealing_text_never_restarts_voice",voice.current_id==first_id and voice.history.size()==played_count and d.view.body.visible_characters==-1)
	d.advance();await frames(2)
	check("advancing_replaces_male_with_exact_female_clip",voice.current_id==d.active.id and voice.current.speaker=="yanyue" and voice.current_id!=first_id)
	d.skip();await frames(2)
	check("skip_stops_story_and_only_plays_current_followup",not d.modal and voice.current_id==d.active.id and d.segment=="after-skip")
	d.clear();await frames(2)
	check("clear_releases_audio_and_music_duck",voice.current_id.is_empty() and not voice.player.playing and not app.ambience.dialogue_active)
	d.play("paperweight-spoken",[d.Lines.opening()[4]],false)
	d.view.body.visible_characters=-1
	await frames(2)
	check("paperweight_waits_for_audio_keyword_despite_full_text",not d.view.item_exhibit.visible and voice.cue_time("镇纸")>0.5)
	check("paperweight_appears_on_spoken_word",await until(func():return d.view.item_exhibit.visible) and voice.position_seconds()>=voice.cue_time("镇纸"))
	d.play("overlap-spoken",[d.Lines.opening()[2]],false)
	d.view.body.visible_characters=-1;await frames(2)
	check("world_overlap_waits_for_audio_keyword",not d.view.world_overlap.active and voice.cue_time("平行世界")>1.0)
	check("world_overlap_starts_with_spoken_parallel_worlds",await until(func():return d.view.world_overlap.active) and voice.position_seconds()>=voice.cue_time("平行世界"))
	d.clear();app.show_tutorial();d.enabled=false
	await frames(3);d.enabled=true
	var anchors: Dictionary=d.Lines.tutorial(0).filter(func(item):return item.visual=="anchors")[0]
	d.play("anchors-spoken",[anchors],false)
	d.enabled=false
	var guide=app.current.orbit_view.teaching
	await frames(2)
	check("subtitle_duration_covers_complete_audio",d.timer>=voice.duration-0.1)
	check("three_step_guide_uses_word_boundary_timestamps",guide.speech==voice and guide.speech_cues.has("星位") and guide.speech_cues.has("月痕") and guide.speech_cues.has("界缝"))
	check("star_highlights_when_its_name_is_spoken",await until(func():return guide.anchor_index==0))
	check("moon_highlights_when_its_name_is_spoken",await until(func():return guide.anchor_index==1) and voice.position_seconds()>=voice.cue_time("月痕"))
	check("seam_highlights_when_its_name_is_spoken",await until(func():return guide.anchor_index==2) and guide.anchor_history==[0,1,2] and voice.position_seconds()>=voice.cue_time("界缝"))
	d.clear();d.enabled=true
	var long_line: Dictionary=d.Lines.tutorial(0)[0]
	d.play("long-subtitle",[long_line],false);await frames(2)
	d.timer=0.0;await frames(2)
	check("automatic_caption_never_truncates_playing_voice",not d.active.is_empty() and voice.current_id==long_line.id)
	var voice_bus:=AudioServer.get_bus_index("Dialogue")
	app.ambience.set_channel_volume("dialogue",0.0)
	check("dialogue_volume_can_mute_voice_independently",AudioServer.is_bus_mute(voice_bus) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	app.ambience.set_channel_volume("dialogue",100.0);app.ambience.set_volume(0.0)
	check("master_mute_includes_voice",AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	app.ambience.set_volume(100.0)
	await frames(15)
	check("voice_ducks_background_music",app.ambience.dialogue_active and app.ambience.music.volume_db<app.ambience.target_db)
	d.clear();await frames(20)
	check("music_restores_after_voice_stops",not app.ambience.dialogue_active and absf(app.ambience.music.volume_db-app.ambience.target_db)<0.2)
	d.play("scene-cancel",[long_line],false);app.show_hub(false);d.hub_wait=false
	check("scene_change_stops_old_voice",voice.current_id.is_empty() and not voice.player.playing)
	d.play("missing-voice",[d.Lines.line("yanyue","这句没有录音，仅保留字幕。")],false)
	check("missing_audio_falls_back_to_complete_subtitle",d.view.shown_text=="这句没有录音，仅保留字幕。" and voice.current_id.is_empty())
	d.clear()
	var file:=FileAccess.open(directory.path_join("voice-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results,"runtime_history":voice.history},"\t"));file.close()
	print("VOICE_TEST_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
