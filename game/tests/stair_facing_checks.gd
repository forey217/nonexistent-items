extends SceneTree
## Approach the real stairs sideways, then verify both flights at rotated views.
var app: Node
var room: Node
var directory := ""
var failures := 0
var results: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(label: String, passed: bool) -> void:
	results.append({"test":label,"passed":passed})
	if not passed:failures+=1;push_error("STAIR_FACING_FAILED "+label)

func frames(count: int) -> void:
	for i in range(count):await physics_frame

func until(condition: Callable) -> bool:
	for i in range(360):
		await physics_frame
		if condition.call():return true
	return false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():push_error("Use --artifacts");quit(1);return
	DirAccess.make_dir_recursive_absolute(directory)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await frames(4);room=app.current
	for angle in [-45.0,0.0,45.0]:
		for layer in [0,1]:
			var name:="%s_%d"%["down" if layer==0 else "up",int(angle)]
			var data: Dictionary=room.snapshot()
			var approach: Vector2=room.stairs_position(layer)+Vector2(1.1,0)
			data.player_layer=layer;data.player=[approach.x,approach.y]
			room.restore(data);room.view.angle=angle
			await frames(3)
			check(name+"_sideways_approach",room.walk_to(room.stairs_position(layer)))
			if not await until(func():return room.transition_age>0):
				check(name+"_enters_stairs",false);continue
			check(name+"_enters_stairs",true)
			var expected:=Vector2.UP if layer==0 else Vector2.DOWN
			var heading_ok:=true
			var pose_ok:=true
			var captured:=false
			while room.transition_age>0:
				await physics_frame
				room.view._sync(0.0)
				heading_ok=heading_ok and room.player._last_direction.dot(expected)>0.999
				var actor: Vector3=room.view.actor.position
				var camera: Camera3D=room.view.camera
				var projected: Vector2=camera.unproject_position(actor+Vector3(0,0,expected.y))-camera.unproject_position(actor)
				var expected_row: int=(0 if projected.x>=0 else 1) if projected.y>=0 else (2 if projected.x>=0 else 3)
				pose_ok=pose_ok and room.view.paper.facing_row==expected_row
				if angle==0.0 and not captured and room.transition_age<1.05 and room.transition_age>0:
					captured=true
					if DisplayServer.get_name()!="headless":
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(directory.path_join(name+".png"))
			check(name+"_faces_along_flight_every_frame",heading_ok)
			check(name+"_rendered_pose_matches_rotated_stairs",pose_ok)
			check(name+"_lands_without_turning_back",room.player_layer==1-layer and not room.player.controls_locked and room.player._last_direction.dot(expected)>0.999)
	var report:=FileAccess.open(directory.path_join("stair-facing-report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"));report.close()
	print("STAIR_FACING_REPORT ",results.size()," checks, ",failures," failures")
	await app.shutdown_audio();quit(0 if failures==0 else 1)
