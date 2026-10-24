extends Node
var app:Node
var room:Node
var directory:=""
var checks:Array[Dictionary]=[]
var failures:=0
func frames(n:int) -> void:
	for i in range(n):await get_tree().physics_frame
func check(label:String,value:bool,details:Dictionary={}) -> void:
	checks.append({"test":label,"passed":value,"details":details});print("PAPER_FILM ",label," ",value)
	if not value:failures+=1;push_error("PAPER_FILM_FAILED "+label+" "+JSON.stringify(details))
func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))
func actor_pixels() -> Dictionary:
	var v=room.view;var film=v.film;var live:Image=v.viewport.get_texture().get_image();var result:Image=get_viewport().get_texture().get_image()
	var mask:Image=v.paper_viewport.get_texture().get_image();var rect:Vector4=film.material.get_shader_parameter("actor_rect")
	live.resize(result.get_width(),result.get_height(),Image.INTERPOLATE_BILINEAR)
	var samples:=0;var errors:=0
	for y in range(maxi(0,int(rect.y*result.get_height())),mini(result.get_height(),ceili((rect.y+rect.w)*result.get_height()))):
		for x in range(maxi(0,int(rect.x*result.get_width())),mini(result.get_width(),ceili((rect.x+rect.z)*result.get_width()))):
			var uv:=(Vector2(x+.5,y+.5)/Vector2(result.get_size())-Vector2(rect.x,rect.y))/Vector2(rect.z,rect.w)
			if mask.get_pixel(clampi(int(uv.x*mask.get_width()),0,mask.get_width()-1),clampi(int(uv.y*mask.get_height()),0,mask.get_height()-1)).a<.95:continue
			var a:=live.get_pixel(x,y);var b:=result.get_pixel(x,y);samples+=1
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.075:errors+=1
	return {"samples":samples,"errors":errors}
func stable_pixels() -> Dictionary:
	var v=room.view;var a:Image=v.viewport.get_texture().get_image();var b:Image=film_image()
	var errors:=0;var samples:=0
	for pos in [Vector2(8,4),Vector2(9,5),Vector2(10,4),Vector2(15,5),Vector2(6,6)]:
		var p:Vector2=v.camera.unproject_position(v.point(pos,(v.S.HEIGHT if v.film.layer_index==1 else 0.0)+.01))
		if not Rect2(Vector2.ZERO,Vector2(a.get_size())).has_point(p):continue
		var x:=int(p.x);var y:=int(p.y);var c:=a.get_pixel(x,y);var d:=b.get_pixel(x,y)
		samples+=1
		if maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),absf(c.b-d.b)))>.04:errors+=1
	return {"samples":samples,"errors":errors}
func film_image() -> Image:return room.view.film.new_view.get_texture().get_image()
func environment_difference() -> Dictionary:
	var a:Image=room.view.film.old_view.get_texture().get_image();var b:Image=film_image();var changed:=0;var samples:=0
	for y in range(140,a.get_height()-100,7):
		for x in range(40,a.get_width()-40,7):
			var c:=a.get_pixel(x,y);var d:=b.get_pixel(x,y);samples+=1
			if maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),absf(c.b-d.b)))>.03:changed+=1
	return {"samples":samples,"changed":changed}
func run(flow:Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory);app.show_paper_mill();room=app.current;await frames(45)
	room.communications.enabled=false;var v=room.view;var film=v.film
	check("idle_has_no_composite_or_extra_rendering",not film.active and v.output.material==null and film.old_view.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	for floor in [0,1]:
		for source in range(4):
			for destination in range(4):
				if source==destination:continue
				var fixture:Dictionary=room.snapshot();fixture.state.worlds=[0,0];fixture.state.worlds[floor]=source;fixture.player_layer=floor;fixture.player=[8,5]
				room.restore(fixture);room.observe(floor);v.return_to_actor();await frames(4)
				var other:int=room.state.worlds[1-floor];var tag:="%d_%d_%d"%[floor,source,destination]
				var okay:bool=room.change_world(destination,floor)
				check(tag+"_success_commits_once_at_original_time",okay and room.state.worlds[floor]==destination and film.active and room.world_cooldown==1.5)
				await frames(5)
				check(tag+"_only_target_environment_changes",room.state.worlds[1-floor]==other and (film.old_camera.cull_mask&film.FLOOR_BITS[1-floor])!=0 and film.old_camera.cull_mask&film.FLOOR_BITS[floor]==0)
				check(tag+"_mechanisms_are_live_common",v.weight_nodes.all(func(n):return n.get_child_count()>0) and v.actor.layers==film.COMMON and v.lift.get_child(0).layers==film.COMMON)
				if source==0:
					await shot("floor%d-to%d-overlap"%[floor,destination])
					if DisplayServer.get_name()!="headless":
						var pixels:=actor_pixels();check(tag+"_actor_pixels_match_main",pixels.samples>200 and pixels.errors<float(pixels.samples)*.02,pixels)
						var image_difference:=environment_difference();check(tag+"_two_real_environment_films_differ",image_difference.changed>100,image_difference)
				await frames(38)
				check(tag+"_ends_and_releases_resources",not film.active and v.output.material==null and film.old_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and film.new_view.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	var allocated:int=film.creations
	for floor in [0,1]:
		for yaw in [-45,0,45]:
			room.restart();room.player_layer=floor;room.observe(floor);room.player.teleport_for_reset(Vector2(8,5)*room.SCALE)
			v.angle=yaw;v.zoom=1.0;v.target_zoom=1.0;v.link_time=5;v.set_focus(Vector2(12,8),false);await frames(8)
			room.change_world(2,floor);await frames(4);await shot("both-floor%d-yaw%d"%[floor,yaw])
			if DisplayServer.get_name()!="headless":
				var actor_sample:=actor_pixels();check("actor_crisp_when_rotating_%d_%d"%[floor,yaw],actor_sample.samples>100 and actor_sample.errors<float(actor_sample.samples)*.02,actor_sample)
				# Isolate the other floor for pixel sampling; the changing upper court
				# otherwise legitimately occludes samples projected from the lower one.
				v.set_process(false)
				var mask:int=film.COMMON|film.FLOOR_BITS[1-floor]
				v.camera.cull_mask=mask;film.new_camera.cull_mask=mask;film.old_camera.cull_mask=mask
				await RenderingServer.frame_post_draw
				var sample:=stable_pixels();check("unaffected_floor_live_pixels_%d_%d"%[floor,yaw],sample.samples>0 and sample.errors==0,sample)
				v.camera.cull_mask=film.COMMON|film.FLOOR_BITS[0]|film.FLOOR_BITS[1]
				film.old_camera.cull_mask=film.COMMON|film.FLOOR_BITS[1-floor]|film.OLD_BIT;film.new_camera.cull_mask=film.COMMON|film.FLOOR_BITS[1-floor]|film.NEW_BIT
				v.set_process(true)
			await frames(40)
	for scale in [.55,1.6]:
		room.restart();v.angle=0;v.zoom=scale;v.target_zoom=scale;v.return_to_actor();await frames(10)
		room.change_world(1,0);await frames(4);await shot("actor-zoom%.2f"%scale)
		if DisplayServer.get_name()!="headless":
			var sample:=actor_pixels();check("actor_mask_matches_zoom_%.2f"%scale,sample.samples>100 and sample.errors<float(sample.samples)*.02,sample)
		await frames(40)
	if DisplayServer.get_name()!="headless":
		for dimensions in [Vector2i(960,540),Vector2i(1920,1080)]:
			DisplayServer.window_set_size(dimensions);await frames(10);room.restart();room.change_world(1,0);await frames(4)
			check("resized_films_follow_actual_pixels_%s"%str(dimensions),film.old_view.size==v.viewport.size and film.new_view.size==v.viewport.size)
			await shot("window-%dx%d"%[dimensions.x,dimensions.y]);await frames(40)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);await frames(10);room.restart();room.change_world(2,1);await frames(4)
		check("fullscreen_films_match_actual_view",film.old_view.size==v.viewport.size and film.new_camera.size==v.camera.size)
		await shot("fullscreen-transition");await frames(40)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,800));await frames(10)
	room.restart();room.change_world(1,0);await frames(5)
	var stamp:float=film.age;room.hud.menu.open();await frames(10)
	check("menu_pause_freezes_transition",is_equal_approx(stamp,film.age));room.hud.menu.close();await frames(40)
	check("resume_finishes_transition",not film.active)
	room.world_cooldown=0;room.change_world(2,0);await frames(5);v.angle=38;v.zoom=1.3;v.target_zoom=1.3;await frames(2)
	check("camera_and_render_dimensions_follow_main",film.old_camera.global_transform.is_equal_approx(v.camera.global_transform) and film.new_view.size==v.viewport.size)
	room.restore(room.snapshot());check("restore_clears_active_film",not film.active and v.output.material==null)
	room.change_world(1,0);await frames(4);room.restart();check("restart_clears_active_film",not film.active and v.output.material==null)
	check("reuses_environment_geometry",film.creations==allocated)
	room.state.cage_open=true;room.state.push_direction(1,Vector2.RIGHT)
	check("sliding_rejects_cast_and_visual",not room.change_world(2,0) and not film.active)
	room.restart();room.state.worlds[0]=3;room.state.clip_owned=true;room.state.clip_target="bridge";v._sync(0)
	room.change_world(0,0);await frames(4)
	check("fixed_bridge_remains_in_both_films",v.bridge.visible and film._visible(v.bridge,0) and film._visible(v.bridge,3))
	check("old_corridor_tracks_each_visual_world",not film._visible(v.side_bridge,0) and film._visible(v.side_bridge,3))
	room.restart();room.state.worlds[0]=3;v._sync(0);room.change_world(0,0);await frames(4)
	check("unfixed_bridge_disappears_only_in_new_film",film._visible(v.bridge,3) and not film._visible(v.bridge,0))
	room.restart();room.state.worlds[0]=1;room.state.worlds[1]=0;room.player_layer=1;room.view_layer=1;room.state.cage_open=true
	room.state.weights[1].pos=room.state.SLUICE;room.state.weights[1].station="sluice";room.state.weights[1].node="sluice";room.state.worlds[1]=1
	room.state.lift_height=1.0;room.world_cooldown=0;room.change_world(2,0);await frames(4)
	check("other_floor_lift_keeps_one_real_simulation",room.state.lift_height>1 and room.state.worlds==[2,1] and not film.copies[0].any(func(item):return item.source==v.lift))
	room.restart();Engine.time_scale=2.2;room.change_world(1,0);var started:=Time.get_ticks_usec();await frames(12)
	check("accelerated_demo_keeps_visible_real_time",film.active and film.age<.55)
	while film.active:await frames(1)
	var seconds:float=float(Time.get_ticks_usec()-started)/1000000;Engine.time_scale=1
	check("visual_duration_independent_of_demo_speed",seconds>=.47 and seconds<1,{"seconds":seconds})
	room.restart();room.change_world(1,0);await frames(4)
	var original_age:float=film.age;var original_state:String=JSON.stringify(room.snapshot())
	app.start_paper_demo();var demo:Node=app.paper_demo
	var deadline:=Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<deadline and not demo.room.view.film.active:await frames(1)
	check("demo_uses_same_formal_film_effect",demo.room.view.film.active and demo.room.view.film.to_world==3)
	demo.toggle_pause();var demo_film_age:float=demo.room.view.film.age;await frames(8)
	check("demo_pause_freezes_film_and_render_targets",is_equal_approx(demo_film_age,demo.room.view.film.age) and demo.room.view.film.old_view.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	demo.toggle_pause();demo.stop()
	check("demo_exit_restores_original_active_transition",app.current==room and film.active and is_equal_approx(film.age,original_age) and JSON.stringify(room.snapshot())==original_state)
	await frames(40);check("restored_original_transition_finishes_normally",not film.active and v.output.material==null)
	var report:=FileAccess.open(directory.path_join("paper-film-report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks.size(),"failures":failures,"results":checks,"native":DisplayServer.get_name()!="headless"},"  "))
	print("PAPER_FILM_REPORT checks=",checks.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
