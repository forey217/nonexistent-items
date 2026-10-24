extends Node
const Instruments=preload("res://scripts/instrument_theme.gd")
var app:Node
var directory:=""
var results:Array[Dictionary]=[]
var samples:Array[Dictionary]=[]
var failures:=0

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func check(label:String,value:bool) -> void:
	results.append({"test":label,"passed":value});print("GLASS_UI ",label," ",value)
	if not value:failures+=1;push_error("GLASS_UI_FAILED "+label)

func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func point(at:Vector2) -> void:
	var e:=InputEventMouseMotion.new();e.position=at;e.global_position=at;get_viewport().push_input(e,true)

func caption_checks(kind:String) -> void:
	var text:="楼梯连接上下两层，规则却各自独立。先观察镇纸、踏板和吊台，再选择当前操作层。\n打开观测记录可以逐级查阅线索；切换观察层不会传送人物，也不会停止另一层的机关。最后一页仍应完整显示。"
	var dialogue=app.dialogue;dialogue.enabled=true;dialogue.voice.enabled=false
	dialogue.phase=app.current.state.stage()
	dialogue.play("glass-long-caption",[dialogue.Lines.line("tesla",text,kind)],false)
	await frames(4)
	var v=dialogue.view;var pages:Array=v.caption_pages.duplicate()
	check(kind+"_all_text_survives_paging","".join(pages)==text and pages.size()>1)
	for i in range(pages.size()):
		v.set_caption_elapsed(i*(v.caption_duration/pages.size())+.05);await frames(2)
		if kind=="subtitle":
			check(kind+"_page_fits_"+str(i),v.subtitle.get_content_height()<=v.subtitle.size.y and v.subtitle.get_line_count()<=2)
		else:
			check(kind+"_page_fits_"+str(i),v.body.get_line_count()<=2 and v.body.get_line_height()*mini(2,v.body.get_line_count())<=v.body.size.y)
		await shot("lab-"+kind+"-page-"+str(i))
	dialogue.clear();dialogue.enabled=false
	await frames(2)
	check(kind+"_entire_caption_hides",not v.root.visible and not v.level_subtitle_plate.visible)

func run(flow:Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	await frames(280)
	var room=app.current;var ui=room.hud
	ui.entry_hint.dismiss();point(Vector2(850,500));await frames(45)
	check("lab_shared_group_has_backing",ui.skill_panel.get_theme_stylebox("panel").get_script()==Instruments.Glass)
	check("lab_task_area_reduced_without_shrinking_text",ui.task_tracker.size.y<88 and ui.task_tracker.current_label.get_theme_font_size("font_size")==22)
	ui.message("那里没有可达的道路。");await frames(5);var time:float=ui.message_time;ui.message("那里没有可达的道路。")
	check("lab_repeated_error_does_not_extend",ui.message_time==time and ui.footer.size.x==520)
	await shot("lab-small-toast");ui.message_time=0
	await caption_checks("subtitle");await caption_checks("light")
	for rule in [1,2]:
		room.change_world(rule);await frames(120);point(ui.worlds[0].get_global_rect().get_center());ui.worlds[0].grab_focus();await frames(3)
		check("lab_focus_kept_"+str(rule),ui.worlds[0].has_focus() and ui.worlds[rule].selected and ui.worlds[rule].disabled)
		await shot("lab-world-"+str(rule)+"-focus")
	point(Vector2(850,500));ui.menu.open(ui.menu_button);await frames(3)
	check("lab_menu_is_same_material",ui.menu.panel.get_theme_stylebox("panel").get_script()==Instruments.Glass)
	await shot("lab-pause");ui.menu.request_action("options");await frames(24)
	check("lab_in_level_settings_use_glass",ui.menu.options.instrument_mode and not ui.menu.options.mill_material)
	await shot("lab-settings");ui.menu.close();await frames(3)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(Vector2i(1920,1080));await frames(25);await shot("lab-1920x1080")
		check("lab_wide_buttons_stay_inside",get_viewport().get_visible_rect().has_point(ui.menu_button.get_global_rect().end-Vector2.ONE))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);await frames(25);await shot("lab-fullscreen")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,800));await frames(25)
	app.show_paper_mill();await frames(270);room=app.current;ui=room.hud
	room.communications.enabled=false;room.story_time=0;ui.message_time=0;ui.entry_hint.dismiss();await frames(45)
	check("mill_uses_variant_of_same_resource",ui.record.get_theme_stylebox("panel").get_script()==Instruments.Glass and ui.record.get_theme_stylebox("panel").mill)
	for dimensions in [Vector2i(1280,800),Vector2i(1920,1080)]:
		if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(dimensions)
		await frames(25)
		for floor in [0,1]:
			var data:Dictionary=room.snapshot();data.player_layer=floor;data.player=[6,4];room.restore(data);room.communications.enabled=false
			for zoom in [.55,1.0,1.6]:
				room.view.set_focus(Vector2(10,8));room.view.zoom=zoom;room.view.target_zoom=zoom;room.view.angle=0;room.view.frame_to_ui=false
				await frames(18)
				check("mill_layout_"+str(dimensions)+str(floor)+str(zoom),ui.worlds.get_global_rect().end.x<ui.menu_button.position.x and not ui.subtitle_panel.visible and not ui.record.visible)
				await shot("mill-%dx%d-floor%d-zoom%.2f"%[dimensions.x,dimensions.y,floor,zoom])
				var at:Vector2=room.view.screen(Vector2(8,6),floor,0)
				check("mill_ground_pick_"+str(dimensions)+str(floor)+str(zoom),room.view.ground(at,floor).distance_to(Vector2(8,6))<.005)
			for yaw in [-45.0,45.0]:
				room.view.angle=yaw;await frames(8);await shot("mill-%d-floor%d-yaw%d"%[dimensions.x,floor,int(yaw)])
		if DisplayServer.get_name()!="headless":
			var screen:=DisplayServer.window_get_size();samples.append({"window":[screen.x,screen.y],"dpi":DisplayServer.screen_get_dpi(),"logical":str(get_viewport().get_visible_rect().size),"world_pixels":str(room.view.viewport.size)})
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(Vector2i(1280,800))
	room.observe(0);room.view.angle=0;room.view.zoom=1;room.view.target_zoom=1;room.view.return_to_actor();await frames(40)
	ui.toggle_record();await frames(45);await shot("mill-observation-record");ui.toggle_record();await frames(30)
	room.focus_target("w0");await frames(35);ui.show_destinations(0);await frames(35);await shot("mill-direction-picker");ui.push_picker.close()
	var text:="上下两层规则独立。观察水闸与吊台，寻找镇纸的通路。长通讯应分页完整展示，结尾也要读得到。最后沿楼梯走回上层，继续寻找旧廊。"
	room.talk("tesla",text);await frames(4)
	check("mill_caption_preserves_every_character","".join(ui.subtitle_pages)==text)
	for i in range(ui.subtitle_pages.size()):
		ui.subtitle_started=ui.clock-i*(ui.subtitle_duration/ui.subtitle_pages.size())-.05;ui.refresh(0);await frames(2)
		check("mill_caption_two_lines_fit_"+str(i),ui.subtitle_body.get_line_count()<=2 and ui.subtitle_body.get_minimum_size().y<=ui.subtitle_body.size.y)
		await shot("mill-communication-page"+str(i))
	room.story_time=0;ui.message_time=0;await frames(3)
	check("mill_hidden_caption_leaves_no_plate",not ui.subtitle_panel.visible and not ui.footer.visible)
	ui.toggle_menu();await frames(3);await shot("mill-pause");ui.menu.request_action("options");await frames(25);await shot("mill-settings")
	check("mill_settings_preserve_four_audio_channels",ui.menu.options.mill_material and ui.channel_sliders.size()==4)
	ui.menu.close();await frames(3)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);await frames(30);await shot("mill-fullscreen")
		check("fullscreen_UI_rect_inside",get_viewport().get_visible_rect().encloses(ui.tools_shade.get_global_rect()))
	var f:=FileAccess.open(directory.path_join("glass-ui-report.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"native_render":DisplayServer.get_name()!="headless","checks":results.size(),"failures":failures,"results":results,"samples":samples},"\t"));f.close()
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
