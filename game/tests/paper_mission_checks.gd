extends Node
const Cues=preload("res://scripts/paper_mission_cues.gd")
const Lines=preload("res://scripts/paper_mill_lines.gd")
var app:Node
var room:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0
var frames_recorded:=0
var movie_active:=false

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func check(title:String,value:bool) -> void:
	results.append({"test":title,"passed":value});print("MISSION_CHECK ",title," ",value)
	if not value:failures+=1;push_error("MISSION_FAILED "+title)
	var f:=FileAccess.open(directory.path_join("mission-report.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"native_render":DisplayServer.get_name()!="headless","failures":failures,"checks":results},"\t"))

func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func wait_movie(count:int) -> void:
	if not movie_active:await frames(count);return
	for i in range(0,count,4):
		await frames(mini(4,count-i));await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("frames/frame-%04d.png"%frames_recorded));frames_recorded+=1

func pose(at:Vector2,layer:int,zoom:=1.6) -> void:
	room.player.cancel_navigation();room.player_layer=layer;room.view_layer=layer;room.player.teleport_for_reset(at*room.SCALE)
	room.view.angle=0;room.view.zoom=zoom;room.view.target_zoom=zoom;room.view.set_focus(at);room.view.auto_follow=false
	room.view.frame_to_ui=false;room.view.safe_center=Vector2(640,420);room.story_time=0;room.hud.message_time=0;room.hud.record.hide();room.hud.hover_target=""
	await frames(30)

func specimen_shots() -> void:
	for spec in [["clip",Vector2(5,13),0],["mountain",room.State.DROP,0],["water",Vector2(5,12),1],["pads",room.State.CATCH_PLATE,1],["ring",room.State.DROP+Vector2(1.4,0),1],["lift",room.State.LIFT,1]]:
		await pose(spec[1]+Vector2(1.4,-1.2),spec[2]);room.view.set_focus(spec[1]);await frames(30);await shot("specimen-"+spec[0])

func cue_checks() -> void:
	var records:Dictionary=room.communications.voice.entries
	var checked:=0;var exact:=0;var estimated:=0;var mapped:Array[String]=[]
	for node in Lines.NODES:
		var lines:Array=Lines.sequence(node)
		for i in range(lines.size()):
			var line:Dictionary=lines[i];var record:Dictionary=records.get(line.id,{})
			var plan:=Cues.plan(line,node,i,"","catch",record,float(record.get("duration_seconds",6)))
			for cue:Dictionary in plan:
				checked+=1
				if cue.timing_source=="recorded_word_boundary":exact+=1
				else:estimated+=1
				for id in cue.objects:
					if id not in mapped:mapped.append(id)
				check("recorded_cue_in_audio_"+node+str(i)+cue.anchor,cue.at>=0 and cue.at<float(record.get("duration_seconds",10)) and cue.timing_source=="recorded_word_boundary")
	for context in Lines.hint_cases():
		var texts:Array=Lines.hint_cases()[context]
		for i in range(texts.size()):
			var line:Dictionary=Lines.line("tesla",texts[i]);var record:Dictionary=records.get(line.id,{})
			for cue:Dictionary in Cues.plan(line,"hint:"+context,i,context,"",record,float(record.get("duration_seconds",6))):
				checked+=1
				if cue.timing_source=="recorded_word_boundary":exact+=1
				else:estimated+=1
				check("hint_has_named_target_"+context+str(i)+cue.anchor,cue.objects.all(func(id):return Cues.ITEMS.has(id)) and (cue.timing_source=="recorded_word_boundary" if not record.is_empty() else cue.timing_source=="reading_estimate"))
	check("story_targets_cover_key_objects",["tool","w0","w1","catch","bridge","upper_anchor","lower_anchor","corridor"].all(func(id):return id in mapped))
	var f:=FileAccess.open(directory.path_join("cue-coverage.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"scheduled":checked,"recorded_word_boundaries":exact,"estimates":estimated},"\t"))

func interaction_checks() -> void:
	var g=room.mission_guide;var s=room.state
	room.communications.stop();room.communications.enabled=false;s.clip_owned=false
	await pose(s.TOOL+Vector2(1.3,-1.5),0)
	g.inspect("tool");await frames(25)
	check("world_and_exhibit_use_same_model_script",g.exhibit.active_model.get_script()==room.view.tool_model.get_script() and g.exhibit.active_kind=="clip")
	check("exhibit_is_transparent_and_one_viewport",g.exhibit.viewport.transparent_bg and g.exhibit.viewport.own_world_3d and g.exhibit.models.size()==1)
	check("exhibit_does_not_cover_actor",not g.occupied_rect().has_point(room.view.to_ui(room.view.camera.unproject_position(room.view.actor.position+Vector3.UP*.9))))
	check("exhibit_transparent_area_does_not_block_map",not room.hud.blocks_map(g.exhibit.position+Vector2(125,90)))
	check("real_exhibit_buttons_block_map",room.hud.blocks_map(g.exhibit.locate_button.get_global_rect().get_center()))
	check("exhibit_text_plate_blocks_map",room.hud.blocks_map(g.exhibit.description.get_global_rect().get_center()))
	check("exhibit_description_does_not_overlap_controls",g.exhibit.description.get_global_rect().end.y<=g.exhibit.locate_button.get_global_rect().position.y)
	var previous_alpha:float=g.exhibit_alpha;g.inspect("tool")
	check("same_model_repeat_keeps_exhibit_fade",g.exhibit_alpha==previous_alpha and g.queued_object.is_empty())
	await shot("clip-exhibit-and-response")
	var line:Dictionary=Lines.sequence("P2-01")[2]
	g.manual=false;g.shown.clear();g.begin_line(line,"P2-01",2,"tool",9,room.communications.voice.entries[line.id])
	check("opening_mentions_clip_before_paired_weights",g.schedule.size()==2 and g.schedule[0].objects==["tool"] and g.schedule[1].objects==["w0","w1"] and g.schedule[0].at<g.schedule[1].at)
	g.line_age=float(g.schedule[0].at)+.01;g._process(.01);await frames(16)
	check("clip_accent_responds_to_mention",room.view.tool_model.response>.1 and g.active_object=="tool")
	var clip_strength:float=g.strengths.tool;g.emphasize(["tool"],false);check("repeat_mention_does_not_restart_fade",g.strengths.tool==clip_strength)
	var before:Dictionary=s.snapshot();g.emphasize(["catch_pad","sluice_pad"],false);await frames(12)
	check("highlights_never_press_unloaded_plates",s.snapshot()==before and room.view.pressure_faces.all(func(face):return is_equal_approx(face.position.y,.23)))
	room.hud.menu.open();var age:float=g.line_age;var hold:float=g.exhibit_hold;var strength:float=g.strengths.tool;await frames(25)
	check("pause_freezes_response_and_exhibit",g.line_age==age and g.exhibit_hold==hold and g.strengths.tool==strength and not g.root.visible and g.exhibit.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	room.hud.menu.close();await frames(3);g.cancel_line();await frames(45)
	check("cancel_fades_out_caption_objects",not g.line_live and not g.exhibit.visible and g.strengths.tool<.01)
	s.clip_owned=true;await frames(2);g.emphasize(["tool"],false);await frames(20)
	check("collected_clip_removed_from_actual_tray",not room.view.tool_model.visible and g.target("tool").stored and not g.rings.tool.visible)
	check("collected_clip_points_at_bag",g.pointers.any(func(p):return p.visible and p.text.contains("工具袋")))
	s.clip_target="catch";await frames(2)
	check("clip_target_tracks_current_fixed_object",g.target("tool").layer==1 and g.target("tool").pos==s.DROP+Vector2(1.4,0) and room.view.clamp.visible and room.view.catch_ring.fixed)
	s.clip_target="bridge";await frames(2)
	check("transfer_and_ring_latches_update",g.target("tool").layer==0 and room.view.bridge_ring.fixed and not room.view.catch_ring.fixed and room.view.clamp.global_position.distance_to(room.view.bridge_ring.global_position+Vector3(0,.36,0))<.001)
	s.clip_target="";await frames(2);check("recall_removes_real_fixed_clip",not room.view.clamp.visible and not room.view.bridge_ring.fixed)
	g.cancel_line();s.worlds[0]=0;room.view_layer=0;g.emphasize(["corridor"],false);await frames(12)
	check("hidden_corridor_marker_does_not_reveal_or_unlock",not room.view.side_bridge.visible and not room.is_walkable(Vector2(5,11)) and g.target("corridor").pos.y<10)
	var view_before:Array=[room.view.focus,room.view.angle,room.view.target_zoom,room.view_layer]
	g.emphasize(["w1"],false);await frames(12)
	check("other_floor_communication_does_not_move_camera",view_before==[room.view.focus,room.view.angle,room.view.target_zoom,room.view_layer])
	check("other_floor_label_is_explicit",g.pointers.any(func(p):return p.visible and p.text.contains("下层")))
	room.view.focus=Vector2(24,17);room.view.auto_follow=false;room.view.frame_to_ui=false;await frames(10)
	g.emphasize(["w0"],false);await frames(10)
	check("offscreen_object_has_direction_pointer",g.pointers.any(func(p):return p.visible and p.text.contains("山纹镇纸")))
	g.inspect("sluice_pad");await frames(15);await shot("sluice-exhibit-other-floor")
	g.cancel_line();g.manual=false;g.exhibit_hold=0;await frames(35)
	check("closed_exhibit_disables_rendering",not g.exhibit.visible and g.exhibit.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	# Drive a real pressure state; the visual moving face must follow simulation.
	s.weights[1].pos=s.CATCH_PLATE;s.weights[1].station="catch";s.worlds[1]=1;s.weights[1].elevation=0
	await frames(2);check("loaded_plate_actual_face_moves",is_equal_approx(room.view.pressure_faces[0].position.y,.12))

func visual_matrix() -> void:
	var g=room.mission_guide
	room.communications.stop();room.communications.enabled=false
	for spec in [["tool",room.State.TOOL,0],["w0",room.State.DROP,0],["w1",Vector2(5,12),1],["catch_pad",room.State.CATCH_PLATE,1],["catch",room.State.DROP+Vector2(1.4,0),1],["lift",room.State.LIFT,1]]:
		room.state.clip_owned=false;room.state.clip_target="";await pose(spec[1]+Vector2(1.2,-1),spec[2])
		g.inspect(spec[0]);await frames(22);await shot("refined-"+spec[0])
		g.manual=false;g.exhibit_hold=0;await frames(25)
	for zoom in [.55,1.0,1.6]:
		await pose(Vector2(7,10),0,zoom);g.inspect("w0");await frames(24)
		check("readable_exhibit_independent_of_map_zoom_"+str(zoom),g.exhibit.size.x==264 and g.exhibit.viewport.size.x>=528)
		await shot("zoom-%.2f"%zoom)
	room.hud.toggle_record();await frames(30)
	check("record_and_exhibit_do_not_overlap",not room.hud.record.get_global_rect().intersects(g.occupied_rect()))
	await shot("record-with-catalog");room.hud.toggle_record()
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(Vector2i(1920,1080));await frames(20);await shot("wide-exhibit")
		check("wide_exhibit_inside_logical_area",get_viewport().get_visible_rect().encloses(g.occupied_rect()))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);await frames(25);await shot("fullscreen-exhibit")
		check("fullscreen_exhibit_inside_logical_area",get_viewport().get_visible_rect().encloses(g.occupied_rect()))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,800));await frames(20)

func movie() -> void:
	if DisplayServer.get_name()=="headless" or not "--record-mission" in OS.get_cmdline_user_args():return
	DirAccess.make_dir_recursive_absolute(directory.path_join("frames"));movie_active=not "--native-movie" in OS.get_cmdline_user_args()
	var g=room.mission_guide;g.shown.clear();g.manual=false;g.exhibit_hold=0
	g.history.clear()
	room.restore({"state":room.State.new().snapshot(),"player_layer":0,"player":[6,11.7]});room.communications.enabled=false
	await pose(Vector2(6,11.7),0,1.0)
	room.communications.enabled=true;room.communications.voice.enabled=true
	# This approved line has an actual MP3 and word boundaries for each named prop.
	room.communications._begin({"key":"P2-01","priority":100,"lines":[Lines.sequence("P2-01")[2]]})
	await wait_movie(660)
	check("live_voice_drove_recorded_word_response",g.history.any(func(h):return h.source=="recorded_word_boundary" and h.objects==["tool"]))
	await shot("live-communication-end")
	room.communications.stop();room.communications.enabled=false
	room.state.clip_owned=true;room.state.cage_open=true
	await pose(room.State.CATCH_PLATE+Vector2(1,-1),1,1.1)
	var text:String=Lines.hint_cases()["water-to-catch"][1]
	room.hint_level=2;room.communications.previous=room.communications._physical();room.communications.pending.clear();room.communications.enabled=true
	room.communications._begin({"key":"hint:water-to-catch:2","priority":100,"lines":[Lines.line("tesla",text)]})
	await wait_movie(520);room.communications.stop();await wait_movie(45)
	check("live_voice_drove_paired_weights",g.history.any(func(h):return h.objects==["w0","w1"]))
	check("live_voice_drove_pressure_plate",g.history.any(func(h):return h.objects==["catch_pad"] and h.source=="recorded_word_boundary"))
	room.communications.enabled=false
	await pose(room.State.DROP+Vector2(2.4,-1.0),1,1.2)
	room.communications.enabled=true;room.communications.pending.clear();room.communications.seen.clear()
	room.communications._begin({"key":"P2-03","priority":100,"lines":[Lines.sequence("P2-03")[1]]})
	await wait_movie(660);room.communications.stop();await wait_movie(60)
	check("live_voice_drove_real_ring",g.history.any(func(h):return h.objects==["catch","bridge"] and h.source=="recorded_word_boundary"))
	check("recording_ends_without_residual_exhibit",not g.exhibit.visible)
	var f:=FileAccess.open(directory.path_join("movie.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"fps":60 if "--native-movie" in OS.get_cmdline_user_args() else 15,"frames":frames_recorded,"native_movie_writer":"--native-movie" in OS.get_cmdline_user_args(),"events":g.history},"\t"))

func run(flow:Node) -> void:
	app=flow;room=flow.current
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	await frames(30);room.communications.stop();room.communications.enabled=false;room.hud.entry_hint.offer();room.hud.entry_hint.dismiss();await frames(45)
	if "--native-movie" in OS.get_cmdline_user_args():
		await movie();print("MISSION_MOVIE_FINISHED checks=",results.size()," failures=",failures);await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1);return
	if "--mission-baseline" in OS.get_cmdline_user_args():await specimen_shots();await app.shutdown_audio();get_tree().quit();return
	await specimen_shots();await cue_checks();await interaction_checks();await visual_matrix();await movie()
	print("MISSION_FINISHED checks=",results.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
