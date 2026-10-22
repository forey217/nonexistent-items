extends SceneTree
## Render coverage across all three worlds and the supported orbit extremes.
var app: Node
var room: Node
var directory: String
var results: Array[Dictionary]=[]
var failures:=0

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):await physics_frame

func record(title: String,passed: bool,details: Dictionary={}) -> void:
	results.append({"test":title,"passed":passed,"details":details})
	if not passed:failures+=1;push_error("INTERIOR_RENDER_FAILED "+title)

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://interior-render")
	DirAccess.make_dir_recursive_absolute(directory)
	app=load("res://main.tscn").instantiate();root.add_child(app);current_scene=app
	await frames(3);app.show_tutorial();await frames(8);room=app.current
	for world in range(3):
		while room.world_cooldown>0.001 or room.casting:await frames(1)
		room.change_world(world)
		while room.casting:await frames(1)
		await frames(25)
		for angle in [-45.0,0.0,45.0]:
			room.orbit_view.set_angle(angle);await frames(3)
			await RenderingServer.frame_post_draw
			var rendered: Image=room.orbit_view.viewport.get_texture().get_image()
			var clear_pixels:=0
			for y in range(8,800,24):
				for x in range(8,1280,24):
					if rendered.get_pixel(x,y).a<0.98:clear_pixels+=1
			record("world_%d_angle_%d_fills_viewport"%[world,int(angle)],clear_pixels==0,{"unfilled_samples":clear_pixels})
			get_root().get_texture().get_image().save_png(directory.path_join("world-%d-angle-%d.png"%[world,int(angle)]))
	var file:=FileAccess.open(directory.path_join("interior-render-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"));file.close()
	print("INTERIOR_RENDER_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	await app.shutdown_audio();quit(0 if failures==0 else 1)
