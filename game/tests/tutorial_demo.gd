extends Node
var app: Node2D
var room: Node2D
var directory := ""
var observations: Array[Dictionary] = []

func frames(count: int) -> void:
	for i in range(count): await get_tree().physics_frame

func until(condition: Callable,limit: int=900) -> bool:
	for i in range(limit):
		await frames(1)
		if bool(condition.call()): return true
	return false

func skill_ready() -> void:
	await until(func():return room.world_cooldown<=0.001 and not room.casting,400)

func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))
	if result!=OK: push_error("Demo image save failed")

func run(flow: Node2D) -> void:
	app=flow
	room=app.current
	directory=room.artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(3)
	await snapshot("01-start-ice")
	room.request_push()
	if not await until(func():return room.state.rail_position>=room.State.FIRST_STOP): get_tree().quit(1);return
	await snapshot("02-first-plate")
	room.change_world(1);await frames(16)
	await snapshot("02b-world-skill-casting")
	await frames(20)
	await snapshot("03-heavy-latched")
	await skill_ready()
	room.change_world(0);await until(func():return not room.casting);room.request_push()
	if not await until(func():return room.state.rail_position>=room.State.RAIL_LENGTH):get_tree().quit(1);return
	await snapshot("04-at-end")
	await skill_ready();room.change_world(2)
	await frames(35)
	await snapshot("05-floating")
	if not await until(func():return room.state.receiver_latched):get_tree().quit(1);return
	await snapshot("06-upper-calibrated")
	await skill_ready();room.change_world(1)
	if not await until(func():return room.gate_ready):get_tree().quit(1);return
	await frames(4)
	await snapshot("07-exit-open")
	room.queue_destination(room.portal_position)
	if not await until(func():return app.completed_runs==1):get_tree().quit(1);return
	if not await until(func():return not app.returning):get_tree().quit(1);return
	if not await until(func():return not app.current.arrival_busy()):get_tree().quit(1);return
	await frames(5)
	await snapshot("08-returned-to-bureau")
	var file:=FileAccess.open(directory.path_join("native-walkthrough.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"completed_runs":app.completed_runs,"returned_to_bureau":app.current.get_script().resource_path.ends_with("tutorial_hub.gd")},"\t"))
	file.close()
	print("TUTORIAL_NATIVE_WALKTHROUGH_COMPLETE")
	await get_tree().current_scene.shutdown_audio()
	get_tree().quit(0)
