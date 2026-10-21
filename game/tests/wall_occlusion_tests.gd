extends Node
## Render regression: compare normal depth to a reference and the empty backdrop.
## References temporarily bypass depth for measurement only; gameplay never does.
var room: Node2D
var checks: Array[Dictionary]=[]
var failures:=0

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func record(title: String,passed: bool,details: Dictionary={}) -> void:
	checks.append({"test":title,"passed":passed,"details":details})
	if not passed:failures+=1;print("WALL_FAILED ",title," ",JSON.stringify(details))

func hold(direction: Vector2) -> void:
	var keys: Vector2=room.player.input_basis.affine_inverse().basis_xform(direction).normalized()
	if keys.x<0:Input.action_press("walk_left",-keys.x)
	else:Input.action_press("walk_right",keys.x)
	if keys.y<0:Input.action_press("walk_up",-keys.y)
	else:Input.action_press("walk_down",keys.y)

func release() -> void:
	for action in ["walk_left","walk_right","walk_up","walk_down"]:Input.action_release(action)

func image3d() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return room.orbit_view.viewport.get_texture().get_image()

func rendered_check(title: String,row: int,cast: float) -> void:
	var view=room.orbit_view
	view.set_process(false)
	view.paper.cast_amount=cast
	view.paper.pose(0,false,row,Vector2(1,0.3),1.0)
	await frames(2)
	view.actor.no_depth_test=false
	view.actor.visible=true
	var normal: Image=await image3d()
	view.actor.no_depth_test=true
	var reference: Image=await image3d()
	view.actor.visible=false
	var background: Image=await image3d()
	view.actor.visible=true
	view.actor.no_depth_test=false
	var bounds: Rect2i=view.paper_viewport.get_texture().get_image().get_used_rect()
	var foot: Vector2=view.logic_to_screen(room.player.position,view.actor.position.y)
	var screen:=Rect2(foot+(Vector2(bounds.position)-Vector2(256,540))*0.5,Vector2(bounds.size)*0.5).grow(3)
	var rect:=Rect2i(screen).intersection(Rect2i(0,0,1280,800))
	var lost:=0
	var total:=0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var reference_color:=reference.get_pixel(x,y)
			var background_color:=background.get_pixel(x,y)
			if distance(reference_color,background_color)<0.08:continue
			total+=1
			if distance(reference_color,normal.get_pixel(x,y))>0.08:lost+=1
	normal.save_png(room.artifacts_directory().path_join(title+".png"))
	view.paper_viewport.get_texture().get_image().save_png(room.artifacts_directory().path_join(title+"-paper.png"))
	var details: Dictionary={"occluded_pixels":lost,"visible_reference_pixels":total,"logic_position":room.player.position,"world_position":view.actor.position,"paper_bounds":bounds,"angle":view.angle}
	record(title,total>800 and lost<=8,details)
	view.set_process(true)

func distance(a: Color,b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))

func run(target: Node2D) -> void:
	room=target
	DirAccess.make_dir_recursive_absolute(room.artifacts_directory())
	await frames(4)
	var guard=room.orbit_view.head_guard
	var sphere: SphereShape3D=guard.body.get_child(0).shape
	record("head_has_real_sphere_collision",sphere!=null and sphere.radius>0.2 and guard.body.collision_mask==guard.WALL_LAYER)
	var from: Vector2=room.iso(0.9,3.5)
	var motion: Vector2=room.iso(-0.3,3.5)-from
	var accepted: Vector2=guard.guard_motion(from,motion)
	var head_end: Vector3=room.orbit_view.to_world(from+accepted)
	record("head_sweep_blocks_wall_independently",head_end.x>=0.60 and head_end.x<0.9 and guard.blocked_sweeps>0,{"stopped_x":head_end.x})
	var slide_from: Vector2=room.iso(0.67,3.5)
	var slide: Vector2=guard.guard_motion(slide_from,room.iso(0.1,4.1)-slide_from)
	var slide_end: Vector3=room.orbit_view.to_world(slide_from+slide)
	record("head_collision_preserves_wall_sliding",slide_end.x>=0.60 and slide_end.z>3.9,{"end":slide_end})
	var fast_from: Vector2=room.iso(2.0,3.5)
	var fast_end: Vector3=room.orbit_view.to_world(fast_from+guard.guard_motion(fast_from,room.iso(-20.0,3.5)-fast_from))
	record("head_sweep_cannot_tunnel_through_wall",fast_end.x>=0.60,{"stopped_x":fast_end.x})
	var corner_from: Vector2=room.iso(1.1,1.1)
	var corner: Vector3=room.orbit_view.to_world(corner_from+guard.guard_motion(corner_from,room.iso(-0.4,-0.4)-corner_from))
	record("head_sweep_handles_two_wall_corner",corner.x>=0.60 and corner.z>=0.60,{"end":corner})
	record("navigation_avoids_rendered_wall_volume",not room.navigation.is_safe(room.iso(0.55,3.5)))
	room.debug_visible=true;room.orbit_view._sync_state(0.0)
	record("head_collision_visualizes_with_f2",guard.outline.visible and not room.orbit_view.actor.no_depth_test)
	room.debug_visible=false
	var scenarios: Array[Dictionary]=[
		{"wall":"z","angle":-45.0,"u":3.6,"v":1.8},
		{"wall":"x","angle":45.0,"u":1.8,"v":3.5},
		{"wall":"z","angle":0.0,"u":3.6,"v":1.8},
		{"wall":"x","angle":0.0,"u":1.8,"v":3.5}
	]
	for scenario in scenarios:
		room.reset_tutorial()
		room.orbit_view.set_angle(scenario.angle)
		room.player.teleport_for_reset(room.iso(scenario.u,scenario.v))
		await frames(3)
		var inward: Vector2=Vector2(46,23) if scenario.wall=="x" else Vector2(-46,23)
		hold(-inward.normalized())
		var contact:=false
		for i in range(110):
			await frames(1)
			if room.player.get_slide_collision_count()>0:contact=true;break
		release();await frames(3)
		record("physical_wall_"+scenario.wall+str(scenario.angle),contact and room.actor_position_is_clear(room.player.position))
		if DisplayServer.get_name()!="headless":
			await rendered_check("wall-%s-%d-front"%[scenario.wall,int(scenario.angle)],0,0.0)
			await rendered_check("wall-%s-%d-cast"%[scenario.wall,int(scenario.angle)],1,1.0)
			await rendered_check("wall-%s-%d-back"%[scenario.wall,int(scenario.angle)],2,0.0)
		var destination: Vector2=room.iso(2.2,3.5) if scenario.wall=="x" else room.iso(3.6,2.4)
		room.queue_screen_destination(room.orbit_view.logic_to_screen(destination))
		var arrived:=false
		for i in range(350):
			await frames(1)
			if room.player.position.distance_to(destination)<4:arrived=true;break
		record("click_away_from_wall_"+scenario.wall+str(scenario.angle),arrived and room.actor_position_is_clear(room.player.position))
	room.reset_tutorial()
	var report: Dictionary={"checks":checks.size(),"failures":failures,"results":checks}
	var file:=FileAccess.open(room.artifacts_directory().path_join("wall-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WALL_TEST_REPORT ",JSON.stringify({"checks":checks.size(),"failures":failures}))
	await get_tree().current_scene.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
