extends Node
var room:Node
var app:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0

func check(label:String,passed:bool) -> void:
	results.append({"test":label,"passed":passed})
	if not passed:failures+=1;push_error("MEMORY_FAILED "+label)

func shot(label:String) -> void:
	if DisplayServer.get_name()=="headless":return
	room.view._sync(0.0)
	room.hud.refresh(0.0)
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func run(flow:Node) -> void:
	directory=ProjectSettings.globalize_path("res://../showcase/checks/reveal-memory-v01")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	app=flow
	room=app.current
	await get_tree().process_frame
	room.communications.enabled=false;room.communications.stop();room.story_time=0
	room.set_process(false);room.set_physics_process(false);room.view.set_process(false)
	room.hud.entry_hint.offer();room.hud.entry_hint.dismiss()
	room.view.frame_to_ui=false;room.view.safe_center=Vector2(640,400)
	room.view.zoom=1.6;room.view.target_zoom=1.6;room.view.set_focus(Vector2(9,15))
	var props:Node3D=room.view.memory_props
	check("twelve_sparse_clusters",props.entries.size()==12)
	check("seven_lived_in_prop_types",["chair","tea","frame","plant","laundry","papers","painting"].all(func(kind):return props.entries.any(func(entry):return entry.kind==kind)))
	check("ordinary_world_is_invisible",props.entries.all(func(entry):return not entry.root.visible))
	check("visual_nodes_have_no_colliders_or_labels",props.entries.all(func(entry):return entry.root.find_children("*","CollisionObject3D",true,false).is_empty() and entry.root.find_children("*","Label3D",true,false).is_empty()))
	await shot("01-ordinary-upper")
	room.state.switch_world(0,3)
	var baseline:Dictionary=room.snapshot()
	var targets:Array=room.targets()
	var route:PackedVector2Array=room.path_to(Vector2(6,9))
	props.sync(.4,room.state.worlds)
	check("reveal_is_staggered",props.entries[0].progress>0 and props.entries[6].progress==0)
	check("upper_rule_does_not_reveal_lower",props.entries.filter(func(entry):return entry.layer==1).all(func(entry):return not entry.root.visible))
	await shot("02-edges-emerging")
	props.sync(.55,room.state.worlds);await shot("03-mid-development")
	props.sync(1.1,room.state.worlds);await shot("04-developed-upper")
	check("all_upper_clusters_finish_developing",props.entries.filter(func(entry):return entry.layer==0).all(func(entry):return is_equal_approx(entry.progress,1)))
	check("partial_and_echo_variants_exist",props.entries.any(func(entry):return entry.partial<.7) and props.entries.filter(func(entry):return not entry.ghosts.is_empty()).size()==4)
	check("decoration_does_not_change_save_targets_or_route",room.snapshot()==baseline and room.targets()==targets and room.path_to(Vector2(6,9))==route)
	room.state.switch_world(0,0);props.sync(.2,room.state.worlds)
	check("switching_away_leaves_brief_residue",props.entries[0].residue>0)
	await shot("05-fading-residue")
	for step in range(15):props.sync(.1,room.state.worlds)
	check("residue_fully_clears",props.entries.all(func(entry):return not entry.root.visible and entry.residue==0))
	room.state.switch_world(1,3);props.sync(2,room.state.worlds)
	check("lower_rule_is_independent",props.entries.filter(func(entry):return entry.layer==1).all(func(entry):return entry.root.visible) and props.entries.filter(func(entry):return entry.layer==0).all(func(entry):return not entry.root.visible))
	room.view_layer=1;await shot("06-developed-lower")
	room.state.switch_world(0,3);props.sync(2,room.state.worlds);room.view_layer=0
	room.view.zoom=.65;room.view.target_zoom=.65;room.view.set_focus(Vector2(12,9))
	await shot("07-spacing-overview")
	for step in range(12):
		room.state.switch_world(0,0 if step%2==0 else 3);props.sync(.04,room.state.worlds)
	check("rapid_switch_keeps_values_bounded",props.entries.all(func(entry):return entry.progress>=0 and entry.progress<=1 and entry.residue>=0 and entry.residue<=1))
	var file:=FileAccess.open(directory.path_join("memory-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"native_render":DisplayServer.get_name()!="headless","checks":results,"failures":failures},"\t"));file.close()
	print("MEMORY_REPORT ",results.size()," checks, ",failures," failures")
	await app.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
