extends SceneTree
## Run with --script res://tests/performance_checks.gd -- --performance-check.
## Checks bounded scene ownership and batching boundaries, without player saves.
var results: Array[Dictionary]=[]
var failures:=0
var app: Node
func _initialize() -> void:run.call_deferred()
func check(label: String,passed: bool) -> void:
	results.append({"test":label,"passed":passed})
	if not passed:failures+=1;push_error("PERFORMANCE_FAILED "+label)
func frames(count: int) -> void:
	for i in range(count):await process_frame
func count_nodes(node: Node) -> int:
	var total:=1
	for child in node.get_children():total+=count_nodes(child)
	return total
func batching_boundaries() -> void:
	var group:=Node3D.new();root.add_child(group)
	var opaque:=StandardMaterial3D.new()
	var glass:=StandardMaterial3D.new();glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	for x in [0.0,4.0]:
		var block:=MeshInstance3D.new();block.mesh=BoxMesh.new();block.material_override=opaque;block.position.x=x;group.add_child(block)
	var transparent:=MeshInstance3D.new();transparent.mesh=BoxMesh.new();transparent.material_override=glass;group.add_child(transparent)
	var first: WeakRef=weakref(group.get_child(0));var second: WeakRef=weakref(group.get_child(1))
	load("res://scripts/static_mesh_batch.gd").compact(group)
	check("static_leaves_are_released_after_compaction",first.get_ref()==null and second.get_ref()==null)
	check("transparent_geometry_keeps_independent_sorting",is_instance_valid(transparent) and transparent.get_parent()==group)
	var merged:=group.get_node("StaticBatch") as MeshInstance3D
	check("baked_geometry_keeps_relative_positions",is_equal_approx(merged.mesh.get_aabb().size.x,5.0))
	check("baked_geometry_keeps_material_and_shadow",merged.material_override==opaque and merged.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	group.free()
func run() -> void:
	batching_boundaries()
	app=load("res://main.tscn").instantiate();root.add_child(app)
	app.saving_enabled=false;app.dialogue.enabled=false
	app.show_tutorial();await frames(8)
	var room=app.current
	check("legacy_floor_does_not_load_unused_room_images",room.floor_art.backgrounds.is_empty() and not room.floor_art.is_processing())
	check("legacy_mechanisms_do_not_load_unused_sprite_sets",room.weight_art.textures.is_empty() and room.portal_art.textures.is_empty() and not room.weight_art.is_processing())
	check("hidden_furniture_keeps_collision_without_art_updates",room.props.all(func(prop):return not prop.is_processing() and prop.art.texture==null and prop.get_child_count()>=2))
	check("side_walls_keep_independent_orbit_visibility",room.orbit_view.themes.all(func(theme):return theme.root.has_node("InteriorBackWall") and theme.root.has_node("InteriorSideWall")))
	check("batched_room_stays_below_1500_nodes",count_nodes(room)<1500)
	check("head_collision_remains_active",room.orbit_view.head_guard.body.get_child_count()==2)
	var reference_count:=count_nodes(room)
	for i in range(6):
		var old_room: WeakRef=weakref(app.current)
		var old_view: WeakRef=weakref(app.current.orbit_view.viewport)
		app.show_hub(false);await frames(6)
		check("scene_and_render_target_released_round_%d"%i,old_room.get_ref()==null and old_view.get_ref()==null)
		app.show_tutorial();await frames(8)
		check("scene_node_count_bounded_round_%d"%i,count_nodes(app.current)==reference_count)
	await app.shutdown_audio()
	app.queue_free();await frames(4)
	check("all_game_nodes_released_on_exit",count_nodes(root)==1)
	var summary={"checks":results.size(),"failures":failures,"results":results}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--performance-report="):
			var file:=FileAccess.open(arg.trim_prefix("--performance-report="),FileAccess.WRITE)
			file.store_string(JSON.stringify(summary,"\t"));file.close()
	print("PERFORMANCE_TEST_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	quit(0 if failures==0 else 1)
