extends Node
var room: Node2D
var directory: String
var checks: Array[Dictionary] = []
var failures := 0

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func record(title: String,passed: bool) -> void:
	checks.append({"test":title,"passed":passed})
	if not passed:
		failures+=1
		push_error("PAD_GUIDE_FAILED "+title)

func point(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=at;event.global_position=at
	get_viewport().push_input(event,true)

func run(app: Node2D) -> void:
	room=app.current
	room.sound.enabled=false
	directory=room.artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(280)
	var view=room.orbit_view
	var tracker=room.hud.task_tracker
	record("star_guides_to_actual_first_pressure_surface",view.landmarks.anchor_position(0).distance_to(view.to_world(room.first_plate,0.29))<0.001)
	record("moon_guides_to_actual_upper_contact_surface",view.landmarks.anchor_position(1).distance_to(view.to_world(room.rail_end,2.75))<0.001)
	record("rift_task_guides_to_end_pressure_surface_not_gate",view.landmarks.anchor_position(2).distance_to(view.to_world(room.rail_end,0.29))<0.001 and view.landmarks.anchor_position(2).distance_to(view.to_world(room.portal_position))>1.0)
	for phase in range(3):
		room.reset_tutorial()
		if phase==0:
			room.state.rail_position=room.State.FIRST_STOP
		else:
			room.state.first_latched=true
			room.state.rail_position=room.State.RAIL_LENGTH
			if phase==1:
				room.state.world=2
				room.state.elevation=room.State.CEILING
			else:
				room.state.receiver_latched=true
				room.state.world=1
		await frames(3)
		for angle in [-45.0,0.0,45.0]:
			point(tracker.main_area.get_global_rect().get_center());await frames(12)
			point(tracker.step_bands[phase].get_global_rect().get_center());await frames(18)
			view.set_angle(angle);await frames(3)
			if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
			var clear := true
			for rect in view.tag_rects:clear=clear and not rect.intersects(view.weight_screen_rect().grow(5))
			record("tags_avoid_weight_phase_%d_angle_%d"%[phase,int(angle)],clear)
			record("pressure_surface_highlight_phase_%d_angle_%d"%[phase,int(angle)],view.landmarks.rings[phase].global_position.distance_to(view.landmarks.anchor_position(phase))<0.001 and view.landmarks.strengths[phase]>0.99)
			if DisplayServer.get_name()!="headless":get_viewport().get_texture().get_image().save_png(directory.path_join("phase-%d-angle-%d.png"%[phase,int(angle)]))
	var file := FileAccess.open(directory.path_join("pad-guide-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks.size(),"failures":failures,"results":checks},"\t"));file.close()
	print("PAD_GUIDE_REPORT ",JSON.stringify({"checks":checks.size(),"failures":failures}))
	await get_tree().current_scene.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
