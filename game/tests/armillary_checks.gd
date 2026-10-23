extends Node
var app: Node
var directory := ""
var results: Array[Dictionary]=[]
var failures := 0

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition: Callable,limit:=400) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func check(title: String,passed: bool) -> void:
	results.append({"test":title,"passed":passed})
	if not passed:failures+=1;push_error("ARMILLARY_FAILED "+title)

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func record_clip() -> void:
	app.show_hub(false);await frames(3)
	var hub=app.current
	hub.arrival_title.hide();hub.arrival_title.set_process(false)
	hub.movement_hint.obscure(true)
	app.ambience.toggle_button.modulate.a=0.0
	app.return_menu_button.modulate.a=0.0
	hub.hall_camera.zoom=Vector2.ONE*1.6
	hub.hall_camera.position=hub.spawn_point+Vector2(-28,-82)
	hub.hall_camera.force_update_scroll()
	hub.prepare_return_arrival(1.7);hub.start_return_arrival()
	DirAccess.make_dir_recursive_absolute(directory.path_join("clip"))
	var index:=0
	while hub.arrival_busy() and index<60:
		await frames(3)
		await capture("clip/frame-%03d"%index)
		index+=1
	print("ARMILLARY_CLIP ",index," frames")

func run(flow: Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://armillary-checks")
	DirAccess.make_dir_recursive_absolute(directory)
	if "--armillary-clip" in OS.get_cmdline_user_args():
		await record_clip();await app.shutdown_audio();get_tree().quit();return
	app.show_hub(false);await frames(3)
	var hub=app.current
	hub.prepare_return_arrival(1.7);hub.start_return_arrival()
	var arrival=hub.arrival
	var front=arrival.foreground_visual
	check("hall_entry_locks_controls_before_gate_opens",hub.player.controls_locked and hub.arrival_busy() and hub.player.modulate.a==0)
	check("hall_front_and_rear_have_independent_depth",front.get_parent()==hub.sort_layer and arrival.visual.get_parent()==hub.sort_layer and front.position.y>arrival.visual.position.y)
	await until(func():return arrival.age>=0.25)
	check("hero_does_not_appear_during_localization",hub.player.modulate.a==0 and hub.player.position.distance_to(arrival.origin)<0.1)
	await capture("01-hall-localization")
	await until(func():return arrival.age>=0.65)
	check("gate_opens_before_hero",arrival.visual.opening()>0.9 and hub.player.modulate.a==0)
	await capture("02-hall-opening")
	await until(func():return arrival.age>=1.10)
	check("hero_walks_out_of_gate",hub.player.modulate.a>0.99 and hub.player.position.distance_to(arrival.origin)>12)
	check("front_and_rear_share_one_animation_clock",is_equal_approx(front.age,arrival.visual.age))
	check("return_to_title_cannot_interrupt_gate",not app.request_title_return())
	await capture("03-hall-emerging")
	await until(func():return arrival.age>=1.72)
	check("gate_waits_until_actor_has_crossed_before_closing",hub.player.position.distance_to(hub.spawn_point)<2 and hub.player.modulate.a==1 and arrival.visual.opening()<0.8)
	await capture("04-hall-closing")
	await until(func():return not hub.arrival_busy());await frames(2)
	check("hall_gate_finishes_in_two_seconds",arrival.age>=2.15 and arrival.age<2.19 and not hub.player.controls_locked)
	check("hall_gate_frees_both_layers",not is_instance_valid(arrival.visual) and not is_instance_valid(front))
	check("hall_actor_stands_on_safe_spawn",hub.actor_position_is_clear(hub.player.position) and hub.player.position.distance_to(hub.spawn_point)<2 and hub.player.modulate.a==1)
	await capture("05-hall-finished")
	app.show_tutorial();await frames(3)
	var room=app.current
	room.start_rift_arrival()
	var gate=room.orbit_view.arrival_gate
	check("level_gate_has_two_depth_tested_layers",gate.active and gate.rear_sprite.layers==(1<<3) and gate.front_sprite.layers==(1<<3) and gate.rear_sprite.position!=gate.front_sprite.position)
	await until(func():return room.arrival.age>=1.12)
	check("level_gate_anchors_in_world_space",gate.position.distance_to(room.orbit_view.to_world(room.arrival.origin,0.035))<0.001)
	check("level_actor_reappears_without_changing_appearance",room.orbit_view.actor.modulate.a==1 and room.player.modulate.a==1)
	await capture("06-level-emerging")
	await until(func():return not room.arrival_busy())
	check("level_gate_disables_both_viewports",not gate.active and not gate.rear_sprite.visible and not gate.front_sprite.visible and gate.rear_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and gate.front_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	check("level_restores_controls_and_safe_spawn",not room.player.controls_locked and room.actor_position_is_clear(room.player.position) and room.player.position.distance_to(room.spawn_point)<2)
	for angle in [-45,45]:
		room.orbit_view.set_angle(angle);room.start_rift_arrival()
		await until(func():return room.arrival.age>=1.12)
		await capture("07-level-angle-%d"%angle)
		check("gate_follows_camera_at_%d_degrees"%angle,gate.position.distance_to(room.orbit_view.to_world(room.arrival.origin,0.035))<0.001 and gate.active)
		await until(func():return not room.arrival_busy())
	room.start_rift_arrival();await until(func():return room.arrival.age>=0.95)
	room.reset_tutorial();await frames(2)
	check("reset_mid_arrival_cleans_both_layers",not room.arrival_busy() and not gate.active and not gate.rear_sprite.visible and not gate.front_sprite.visible and gate.rear_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and gate.front_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and room.orbit_view.actor.modulate.a==1)
	app.show_paper_mill();await frames(4)
	var mill=app.current
	mill.start_rift_arrival()
	var mill_gate=mill.arrival_gate
	check("paper_mill_uses_shared_world_space_gate",mill_gate.active and mill.arrival_fx==mill_gate.rear_ink and mill.view.actor.modulate.a==0 and mill.player.controls_locked)
	await until(func():return mill.arrival_age<=1.02)
	check("paper_mill_actor_steps_out",mill.player.position.distance_to(mill.arrival_origin)>10 and mill.view.actor.modulate.a>0.99)
	await capture("08-paper-mill-emerging")
	await until(func():return not mill.arrival_busy());await frames(2)
	check("paper_mill_releases_gate_and_restores_controls",not is_instance_valid(mill_gate) and not mill.player.controls_locked and mill.player.position.distance_to(mill.arrival_destination)<2 and mill.view.actor.modulate.a==1)
	var file:=FileAccess.open(directory.path_join("armillary-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"));file.close()
	print("ARMILLARY_RESULT ",results.size()," checks, ",failures," failures")
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
