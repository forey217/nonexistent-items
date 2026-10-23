extends Node
var directory:=""
func frames(count:int) -> void:
	for i in range(count):await get_tree().process_frame
func shot(name:String) -> void:
	await frames(4);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))
func run(app:Node) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://mill-visual")
	DirAccess.make_dir_recursive_absolute(directory)
	var room=app.current
	await frames(15);await shot("00-entrance")
	room.view.set_focus(Vector2(12,9));room.view.zoom=.7;room.view.target_zoom=.7
	await shot("01-upper-wide")
	for i in range(4):
		room.state.switch_world(0,i);await shot("02-upper-world-%d"%i)
	room.observe(1);room.view.zoom=.8;room.view.target_zoom=.8
	for i in range(4):
		room.state.switch_world(1,i);await frames(25);await shot("03-lower-world-%d"%i)
	room.observe(0);room.view.set_focus(Vector2(11,10));room.view.zoom=1.4;room.view.target_zoom=1.4
	for angle in [-45.0,0.0,45.0]:
		room.view.angle=angle;await shot("04-near-angle-%d"%angle)
	print("MILL_VISUAL_FINISHED")
	await app.shutdown_audio();get_tree().quit()
