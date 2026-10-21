extends Node
var room: Node2D
var directory: String
var checks: Array[Dictionary]=[]
var failures := 0

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func record(title: String,passed: bool,details: Dictionary={}) -> void:
	checks.append({"test":title,"passed":passed,"details":details})
	if not passed:
		failures+=1
		push_error("FILM_CHECK_FAILED "+title+" "+JSON.stringify(details))

func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func actor_comparison() -> Dictionary:
	var view=room.orbit_view
	var main: Image=view.viewport.get_texture().get_image()
	var final: Image=get_viewport().get_texture().get_image()
	var mask: Image=view.paper_viewport.get_texture().get_image()
	var uv: Vector4=view.film.material.get_shader_parameter("actor_rect")
	var samples := 0
	var mismatches := 0
	var worst := 0.0
	for y in range(int(uv.y*800),int((uv.y+uv.w)*800)):
		for x in range(int(uv.x*1280),int((uv.x+uv.z)*1280)):
			if x<0 or y<0 or x>=1280 or y>=800:continue
			var px:=clampi(int((float(x)+0.5-uv.x*1280)/(uv.z*1280)*512),0,511)
			var py:=clampi(int((float(y)+0.5-uv.y*800)/(uv.w*800)*640),0,639)
			if mask.get_pixel(px,py).a<0.99:continue
			var a:=main.get_pixel(x,y)
			var b:=final.get_pixel(x,y)
			var error:=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			samples+=1
			worst=maxf(worst,error)
			if error>0.04:mismatches+=1
	return {"samples":samples,"mismatches":mismatches,"max_channel_error":worst}

func run(app: Node2D) -> void:
	room=app.current
	room.sound.enabled=false
	directory=room.artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(280)
	var view=room.orbit_view
	var film=view.film
	record("idle_disables_extra_rendering",not film.active and film.old_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and film.new_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and view.output.material==null)
	var pairs := [Vector2i(0,1),Vector2i(1,2),Vector2i(2,0),Vector2i(0,2),Vector2i(2,1),Vector2i(1,0)]
	for index in range(pairs.size()):
		room.reset_tutorial()
		room.state.switch_world(pairs[index].x)
		view.set_angle([-45.0,0.0,45.0][index%3])
		await frames(3)
		view.display_fx.hide()
		await snapshot("pair-%d-before"%index)
		record("pair_%d_starts_film"%index,room.change_world(pairs[index].y) and film.active and film.from_world==pairs[index].x and film.to_world==pairs[index].y)
		for frame in range(1,36):
			await frames(1)
			if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
			if index==1 and frame<=33:
				if DisplayServer.get_name()!="headless":get_viewport().get_texture().get_image().save_png(directory.path_join("animation-%02d.png"%frame))
			elif frame in [6,12,14,23,35]:
				await snapshot("pair-%d-frame-%02d"%[index,frame])
			if frame==6:
				record("pair_%d_old_rule_until_alignment"%index,room.state.world==pairs[index].x and film.alignment<1 and film.active)
				record("pair_%d_ghosts_exclude_actor"%index,(film.old_camera.cull_mask&view.actor.layers)==0 and (film.new_camera.cull_mask&view.actor.layers)==0 and (view.camera.cull_mask&view.actor.layers)!=0)
				if DisplayServer.get_name()!="headless":
					var old_image: Image=film.old_view.get_texture().get_image()
					var new_image: Image=film.new_view.get_texture().get_image()
					var at: Vector2=view.logic_to_screen(room.iso(3,6),0.04)
					var old_floor:=old_image.get_pixel(int(at.x),int(at.y))
					var new_floor:=new_image.get_pixel(int(at.x),int(at.y))
					record("pair_%d_both_environment_films_render_and_stay_lit"%index,old_floor.a>0.95 and new_floor.a>0.95 and maxf(old_floor.r,maxf(old_floor.g,old_floor.b))>0.75 and maxf(new_floor.r,maxf(new_floor.g,new_floor.b))>0.75,{"old_pixel":old_floor.to_html(),"new_pixel":new_floor.to_html()})
					var sample:=actor_comparison()
					record("pair_%d_actor_pixels_remain_crisp"%index,sample.samples>500 and sample.mismatches<float(sample.samples)*0.01,sample)
			if frame==14:
				record("pair_%d_rule_changes_when_films_align"%index,room.state.world==pairs[index].y and film.alignment==1.0 and film.active)
		record("pair_%d_settles_and_releases_controls"%index,not film.active and not room.casting and not room.player.controls_locked and view.output.material==null and room.world_cooldown>0.5)
		view.display_fx.show()
	room.reset_tutorial();room.change_world(1);await frames(6)
	view.set_angle(31);await frames(2)
	record("orbit_during_transition_keeps_films_registered",film.old_camera.global_transform.is_equal_approx(view.camera.global_transform) and film.new_camera.global_transform.is_equal_approx(view.camera.global_transform))
	room.reset_tutorial()
	record("reset_cancels_all_film_resources_immediately",not film.active and view.output.material==null and film.old_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and room.state.world==0 and room.world_cooldown==0)
	await frames(3)
	var visible_count := 0
	for theme in view.themes:
		if theme.root.visible:visible_count+=1
	record("reset_leaves_exactly_one_world_visible",visible_count==1)
	var file:=FileAccess.open(directory.path_join("film-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks.size(),"failures":failures,"results":checks},"\t"));file.close()
	print("FILM_TEST_REPORT ",JSON.stringify({"checks":checks.size(),"failures":failures}))
	await get_tree().current_scene.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
