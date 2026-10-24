extends Node
var app: Node
var room: Node
var directory := ""
var results: Array[Dictionary]=[]
var samples: Array[Dictionary]=[]
var failures:=0

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func check(label:String,passed:bool) -> void:
	results.append({"test":label,"passed":passed})
	if not passed:failures+=1;push_error("MILL_V04_FAILED "+label)

func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func click(at:Vector2,index:=MOUSE_BUTTON_LEFT) -> void:
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=index;e.pressed=down
		get_viewport().push_input(e,true)

func until(condition:Callable) -> bool:
	for i in range(600):
		await frames(1)
		if condition.call():return true
	return false

func layout_checks() -> void:
	var ui=room.hud;var view=room.view
	check("rules_at_top_and_inventory_at_bottom",ui.worlds.position.y<100 and ui.bag.is_visible_in_tree() and ui.bag.get_global_rect().position.y>650)
	check("both_floor_rules_and_actor_location_stay_visible",ui.law.text.contains("上层A") and ui.law.text.contains("下层A") and ui.law.text.contains("人物在"))
	check("layer_dropdown_has_two_real_destinations",ui.layer_selector.get_popup().item_count==2 and ui.rule_buttons.size()==4)
	check("clip_recall_remains_directly_accessible",ui.bag_buttons[2].get_parent()==ui.bag and ui.bag_buttons[2].text.begins_with("夹"))
	check("no_default_record_or_bottom_prompt",not ui.record.visible and not ui.footer.visible and not ui.law_popup.visible)
	check("flow_does_not_draw_old_controls",not app.return_menu_button.visible and not app.ambience.toggle_button.visible and app.save_feedback.suppressed)
	for control in [ui.worlds,ui.bag,ui.tools]:
		var before:float=view.target_zoom;var at:Vector2=control.get_global_rect().get_center()
		click(at,MOUSE_BUTTON_WHEEL_UP);await frames(2)
		check("UI_blocks_wheel_"+control.name,view.target_zoom==before and ui.blocks_map(at))
	room.restore(room.snapshot());view.return_to_actor();await frames(45)
	var yaw:float=view.angle;var zoom:float=view.target_zoom
	ui.toggle_record();await frames(50)
	var torso:Vector2=view.to_ui(view.camera.unproject_position(view.actor.position+Vector3.UP*.9))
	check("record_reframes_actor_in_free_area",ui.safe_rect().has_point(torso) and not ui.record.get_global_rect().has_point(torso))
	check("panel_does_not_reset_zoom_or_rotation",view.angle==yaw and view.target_zoom==zoom)
	await shot("record-safe-framing");ui.toggle_record();await frames(30)
	room.focus_target("tool");await frames(35)
	check("task_focus_reveals_target_under_roof",view.focused_target=="tool" and not view.roofs[0].visible)
	await shot("task-target-revealed")
	room.focus_target("w0");await frames(30);ui.show_destinations(0);await frames(45)
	var weight:Dictionary=room.state.weights[0]
	var weight_at:Vector2=view.screen(weight.pos,weight.layer,.4)
	check("direction_picker_has_four_projected_choices",ui.push_picker.visible and ui.push_picker.arrows.size()==4 and ui.push_picker.arrows.all(func(b):return not b.get_global_rect().has_point(weight_at)))
	await shot("destinations-safe-framing");ui.push_picker.close()
	ui.message("那里没有可达的道路。");await frames(12);var remaining:float=ui.message_time
	ui.message("那里没有可达的道路。")
	check("repeated_error_does_not_restart_toast",is_equal_approx(ui.message_time,remaining))
	room.talk("tesla","上下两层的规则相互独立。先观察通路、镇纸和吊台，再选择当前操作层。打开观测记录可以逐级查阅线索，人物不会因切换观察层而移动。")
	await frames(5)
	# Font shaping can legitimately fit this sentence into one two-line page.
	check("subtitles_are_two_lines_and_exclude_toast",ui.subtitle_panel.visible and not ui.footer.visible and ui.subtitle_body.max_lines_visible==2 and ui.subtitle_body.get_line_count()<=2 and not ui.subtitle_pages.is_empty())
	var long_caption:String=ui.subtitle_pages[0].repeat(4)
	var pages:Array[String]=ui.Instruments.caption_pages(long_caption,620,19);var fits:=true
	for page in pages:
		ui.subtitle_body.text=page;fits=fits and ui.subtitle_body.get_line_count()<=2
	ui.subtitle_body.text=ui.subtitle_pages[0]
	check("long_captions_paginate_without_losing_text",pages.size()>1 and "".join(pages)==long_caption and fits)
	await shot("narrow-subtitle");room.story_time=0;ui.message_time=0;await frames(5)
	check("subtitle_disappears_without_communication",not ui.subtitle_panel.visible)
	ui.toggle_menu();var clock:float=room.state.clock;await frames(10)
	check("pause_contains_complete_tools",["reset","restart","hub","title","mute","fullscreen","quit","options"].all(func(id):return ui.menu.buttons.has(id)) and room.state.clock==clock)
	ui.menu.request_action("options");await frames(30)
	check("settings_use_ink_theme_and_four_real_sliders",ui.menu.options.instrument_mode and ui.channel_sliders.size()==4 and ui.menu.options.sheet is Panel)
	await shot("ink-settings");ui.menu.close();await frames(5)
	room.story_time=0;ui.message_time=0;view.return_to_actor();await frames(45)
	var goal:Vector2=room.player_plan()+Vector2(1.0,0)
	var at:Vector2=view.screen(goal,room.player_layer,0)
	check("transparent_world_area_does_not_intercept",not ui.blocks_map(at))
	click(at);check("real_ground_click_moves_player",await until(func():return room.player_plan().distance_to(goal)<.14))

func render_checks() -> void:
	var view=room.view
	view.focused_target=""
	for material in [view.stone,view.wood,view.wall_mat,view.roof_mat]:
		check("actual_mip_chain_"+material.albedo_texture.resource_path.get_file(),material.albedo_texture.get_image().has_mipmaps())
	for dimensions in [Vector2i(1280,800),Vector2i(1920,1080),Vector2i(2560,1440)]:
		if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(dimensions)
		await frames(25)
		var logical:Vector2=get_viewport().get_visible_rect().size
		var scale:Vector2=get_viewport().get_screen_transform().get_scale().abs()
		var expected:Vector2=logical*scale*view.render_scale;expected*=minf(1,3840/maxf(expected.x,expected.y))
		check("render_pixels_match_actual_area_"+str(dimensions),Vector2(view.viewport.size).distance_to(expected)<1)
		var resizes:int=view.resize_count;await frames(6)
		check("no_idle_render_target_realloc_"+str(dimensions),resizes==view.resize_count)
		for layer in [0,1]:
			var placement:Dictionary=room.snapshot();placement.player_layer=layer;placement.player=[6,4]
			room.restore(placement)
			for magnitude in [.55,1.0,1.6]:
				for yaw in [-45.0,0.0,45.0]:
					view.set_focus(Vector2(10,8));view.zoom=magnitude;view.target_zoom=magnitude;view.angle=yaw
					view.frame_to_ui=false;view.safe_center=Vector2(logical.x*.5,logical.y*.5125)
					await frames(8)
					var point:=Vector2(8,6);var at:Vector2=view.screen(point,layer,0)
					check("projection_%s_%d_%.2f_%d"%[dimensions,layer,magnitude,int(yaw)],view.ground(at,layer).distance_to(point)<.005)
					var w:Dictionary=room.state.weights[layer]
					var h:float=room.state.weight_height(layer)-(room.State.HEIGHT if w.layer==0 else 0)+.3
					check("weight_pick_%s_%d_%.2f_%d"%[dimensions,layer,magnitude,int(yaw)],room.hit_target(view.screen(w.pos,w.layer,h))=="w%d"%layer)
					if yaw==0 and layer==0:await shot("window-%dx%d-zoom-%.2f"%[dimensions.x,dimensions.y,magnitude])
					if yaw==0 and magnitude==1.6:
						check("actor_resolution_tracks_scale_"+str(dimensions)+str(layer),view.paper_density>=2 and view.paper_viewport.size==Vector2i(256,320)*view.paper_density)
						samples.append({"window_requested":[dimensions.x,dimensions.y],"window_actual":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"logical":[logical.x,logical.y],"draw_scale":[scale.x,scale.y],"render_pixels":[view.viewport.size.x,view.viewport.size.y],"actor_pixels":[view.paper_viewport.size.x,view.paper_viewport.size.y],"screen_dpi":DisplayServer.screen_get_dpi()})
		room.observe(0)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);await frames(30)
		check("fullscreen_round_trip",view.ground(view.screen(Vector2(8,6),0,0),0).distance_to(Vector2(8,6))<.005)
		await shot("fullscreen");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,800));await frames(20)
	view.set_focus(Vector2(10,8));view.zoom=.55;view.target_zoom=.55;view.angle=0
	var materials:Array=[view.stone,view.wood,view.wall_mat,view.roof_mat]
	for filter in [BaseMaterial3D.TEXTURE_FILTER_LINEAR,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC]:
		for material in materials:material.texture_filter=filter
		await frames(12);await shot("filter-%d-msaa4"%filter)
	view.viewport.msaa_3d=Viewport.MSAA_DISABLED;await frames(12);await shot("anisotropic-msaa-off")
	view.viewport.msaa_3d=Viewport.MSAA_4X

func stair_checks() -> void:
	var data:Dictionary=room.snapshot();data.player_layer=0;data.player=[4.6,9.4]
	room.restore(data)
	check("road_beside_stairs_is_walkable",room.walk_to(Vector2(3.1,9.4)))
	await until(func():return not room.player.is_navigating())
	check("passing_beside_entrance_does_not_trigger",room.player_layer==0 and room.transition_age==0)
	check("walk_into_real_entrance_is_accepted",room.walk_to(room.State.STAIRS))
	check("actual_entrance_starts_flight",await until(func():return room.transition_age>0))
	var clock:float=room.state.clock;var laws:Array=room.state.worlds.duplicate()
	await frames(40)
	check("both_floor_simulation_continues_on_stairs",room.state.clock>clock and room.state.worlds==laws and room.state.worlds.size()==2)
	check("flight_keeps_gait_without_push",room.view.paper.moving and is_zero_approx(room.view.paper.push_amount))
	check("mid_flight_save_uses_stable_floor",room.stable_snapshot().player_layer==0)
	await shot("feedback-stair-position")
	await until(func():return room.transition_age==0)
	await frames(90)
	check("exit_idle_never_bounces_back",room.player_layer==1 and not room.stairs_armed and not room.player.is_navigating())
	room.restore(room.snapshot());await frames(30)
	check("restoring_on_exit_does_not_retrigger",room.player_layer==1 and room.transition_age==0 and not room.stairs_armed)
	var position:Vector2=room.player_plan();room.observe(0);await frames(30)
	click(room.view.screen(room.State.STAIRS,0,0));await frames(5)
	check("distant_other_floor_click_is_not_teleport",room.player_layer==1 and room.player_plan().distance_to(position)<.01 and room.transition_age==0)
	room.observe(1);room.story_time=0;room.hud.message_time=0

func run(flow:Node) -> void:
	app=flow;room=app.current
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	await frames(20)
	room.story_time=0;room.hud.message_time=0;room.hud.entry_hint.offer();room.hud.entry_hint.dismiss();await frames(45)
	for magnitude in [.55,1.0,1.6]:
		room.view.set_focus(Vector2(10,8));room.view.zoom=magnitude;room.view.target_zoom=magnitude;room.view.angle=0
		# Match the baseline's exact camera center for the before/after pair.
		room.view.frame_to_ui=false;room.view.safe_center=Vector2(640,410)
		await frames(30);await shot("scene-%.2f"%magnitude)
	await layout_checks()
	await stair_checks()
	await render_checks()
	var report:=FileAccess.open(directory.path_join("delivery-report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results,"samples":samples},"\t"));report.close()
	print("MILL_V04_REPORT ",results.size()," checks, ",failures," failures")
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
