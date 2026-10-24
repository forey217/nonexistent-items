extends SceneTree
class DrawPump extends Node:
	func _process(_delta:float) -> void:
		RenderingServer.force_draw.call_deferred(true)
var app:Node
var directory:="../showcase/checks/movement-flicker/after"
var checks:Array[Dictionary]=[]
var failures:=0
func check(label:String,passed:bool,details:Dictionary={}) -> void:
	checks.append({"test":label,"passed":passed,"details":details})
	if not passed:failures+=1
	print("FLICKER_CHECK ",label," ",passed," ",details)
func _initialize() -> void:
	root.add_child.call_deferred(DrawPump.new())
	run.call_deferred()
func frames(n:int) -> void:
	for i in range(n):await physics_frame
func shot(v:Node,label:String) -> void:
	await RenderingServer.frame_post_draw
	v.viewport.get_texture().get_image().save_png(directory.path_join(label+".png"))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	app.show_paper_mill();await frames(45)
	var room=app.current;var v=room.view
	room.communications.enabled=false;room.player.controls_locked=true
	room.state.hatch_broken=true
	v.set_focus(Vector2(15,8.5),false);v.zoom=1.6;v.target_zoom=1.6
	await frames(40);await shot(v,"shafts")
	for i in range(3):
		v.focus+=Vector2(.012,.012);await frames(2);await shot(v,"shift%d"%i)
	for layer in range(2):
		var linings=v.roots[layer].find_children("ShaftLining*","MeshInstance3D",true,false)
		check("both_shafts_have_lining_floor%d"%layer,linings.size()==2)
		for i in range(linings.size()):
			var arrays:Array=linings[i].mesh.surface_get_arrays(0)
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var directions:Array=Array(normals)
			var walls:bool=directions.any(func(n):return n.x>.5) and directions.any(func(n):return n.x<-.5) and directions.any(func(n):return n.z>.5) and directions.any(func(n):return n.z<-.5)
			check("shaft%d_floor%d_has_walls_without_coplanar_caps"%[i,layer],walls and directions.any(func(n):return n.y<-.5) and not directions.any(func(n):return n.y>.5))
	# Exercise the real guard materials under intermittent edge misses, then a
	# sustained clear view. This also checks that a paused frame cannot change alpha.
	var Fade=load("res://scripts/paper_guard_fade.gd")
	for pair in [["stairs",v.stair_guards],["waterbank",v.waterbank_guards.sections]]:
		var section:Dictionary=pair[1][0];var before:Dictionary=room.state.snapshot()
		section.fade=0;section.occlusion_hold=0
		for i in range(20):Fade.sync(section,true,1.0/60)
		var minimum:float=section.fade
		for i in range(30):
			Fade.sync(section,i%6==0,1.0/60);minimum=minf(minimum,section.fade)
		check(pair[0]+"_edge_misses_do_not_restore_guard",minimum>.68)
		var paused:float=section.fade;Fade.sync(section,false,0)
		check(pair[0]+"_pause_freezes_alpha",section.fade==paused)
		for i in range(70):Fade.sync(section,false,1.0/60)
		check(pair[0]+"_clear_view_restores_opaque",section.fade==0 and section.meshes.all(func(mesh):return mesh.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED))
		check(pair[0]+"_fade_preserves_puzzle_state",before==room.state.snapshot())
	for layer in range(2):
		room.player_layer=layer;room.observe(layer)
		for yaw in [-45,0,45]:
			v.angle=yaw;v.set_focus(Vector2(15,8.5),false);await frames(25)
			await shot(v,"floor%d-yaw%d"%[layer,yaw])
	check("lighting_and_depth_still_enabled",v.world_root.get_children().any(func(n):return n is DirectionalLight3D and n.shadow_enabled) and not v.actor.no_depth_test)
	var report:={"checks":checks,"failures":failures,"native_render":DisplayServer.get_name()!="headless"}
	FileAccess.open(directory.path_join("flicker-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FLICKER_PROBE_DONE checks=",checks.size()," failures=",failures)
	await app.shutdown_audio();quit(0 if failures==0 else 1)
