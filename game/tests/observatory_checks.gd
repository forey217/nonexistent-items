extends Node
var app:Node
var root:Window
var results:Array[Dictionary]=[]
var failures:=0
var directory:=""
var stats:Array[Dictionary]=[]

func frames(count:int) -> void:
	for i in range(count):await get_tree().process_frame
func until(condition:Callable,limit:=400) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false
func check(label:String,passed:bool) -> void:
	results.append({"test":label,"passed":passed})
	if not passed:failures+=1;push_error("OBSERVATORY_FAILED "+label)
func capture(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func nodes(node:Node) -> int:
	var count:=1
	for child in node.get_children():count+=nodes(child)
	return count
func measure(index:int) -> void:
	stats.append({"round":index,"nodes":nodes(root),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"static_memory":OS.get_static_memory_usage(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"texture_memory":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)})
func area(polygon:PackedVector2Array) -> float:
	var sum:=0.0
	for i in range(polygon.size()):sum+=polygon[i].cross(polygon[(i+1)%polygon.size()])
	return absf(sum)*0.5
func click(at:Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=down
		root.push_input(event,true)
func move(at:Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=at;event.global_position=at;root.push_input(event,true)

func run(flow:Node) -> void:
	app=flow;root=get_tree().root
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():push_error("Explicit artifacts directory required");get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	app.saving_enabled=false;app.dialogue.enabled=false
	app.show_hub(false);await frames(5)
	app.open_level_menu();await frames(40)
	var menu=app.level_menu
	check("new_background_bound_to_real_menu",menu.clock_material.get_shader_parameter("panorama").resource_path.ends_with("sealed_observatory.png"))
	var spoken:Dictionary=app.dialogue.Lines.selection(false)[0]
	check("selection_prompt_keeps_existing_recorded_voice",app.dialogue.voice.entries.has(spoken.id) and app.dialogue.voice.entries[spoken.id].display_text==spoken.text)
	check("single_viewport_for_six_real_meshes",menu.glass_renderer.get_children().filter(func(n):return n is SubViewport).size()==1 and menu.shards.all(func(s):return s.mesh.mesh is ArrayMesh and s.mesh.mesh.get_aabb().size.z>40))
	check("six_exact_petals_reconstruct_outline",menu.shards.size()==6 and menu.whole.size()==12 and menu.shards.all(func(s):return s.polygon.size()==6))
	var petal_area:=0.0
	for shard in menu.shards:petal_area+=area(shard.polygon)
	check("petals_cover_source_crystal_without_gaps_or_extra_area",absf(petal_area-area(menu.whole))<0.1)
	check("hover_not_active_at_rest",menu.hover_amount==0 and menu.shards.all(func(s):return s.hovered==0 and s.fracture==0))
	check("actual_projected_core_is_clickable",menu.core_hit(menu.CENTER) and not menu.core_hit(Vector2(210,690)))
	await capture("01-complete-core")
	move(menu.CENTER);await frames(20)
	check("hairline_cracks_react_to_hover",menu.hover_amount>0.95 and menu.shards.all(func(s):return s.fracture>0.9))
	await capture("02-hover-cracks")
	move(Vector2(60,680));await frames(20)
	check("hover_relaxes_without_permanent_enlargement",menu.hover_amount<0.01 and menu.core_transform().get_scale().distance_to(Vector2(1.06,1.12))<0.001)
	click(menu.CENTER);await frames(6)
	check("click_begins_opening_only",menu.phase==menu.Phase.OPENING and menu.selection_age<0)
	click(menu.CENTER);await frames(2)
	check("double_click_does_not_skip_selection",menu.selected==-1)
	await until(func():return menu.phase==menu.Phase.EXPANDED)
	await frames(8);move(menu.shards[0].position);await frames(15)
	check("fresh_game_preserves_one_unlocked_level",menu.shards[0].available and menu.shards.slice(1).all(func(s):return not s.available))
	check("static_miniatures_not_running_levels",menu.shards[0].ink.get_shader_parameter("vignette") is Texture2D and menu.glass_renderer.viewport.get_child_count()==1)
	check("shard_centers_match_rendered_picking",range(6).all(func(i):return menu.shard_at(menu.shards[i].position)==i))
	await capture("03-expanded-shards")
	click(menu.shards[3].position);await frames(3)
	check("locked_shard_feedback_without_entering",menu.selected==-1 and menu.phase==menu.Phase.EXPANDED and menu.shards[3].lock_pulse>0)
	click(menu.shards[0].position);await frames(30)
	check("playable_shard_spiral_starts_once",menu.selected==0 and menu.phase==menu.Phase.ENTERING and menu.close_button.disabled and menu.rift_starts.size()==6)
	click(menu.CENTER);menu.close()
	check("transition_cannot_repeat_or_cancel",app.level_menu==menu and menu.selected==0)
	await capture("04-selected-convergence")
	await until(func():return app.level_menu==null)
	check("first_level_route_and_rift_preserved",app.current.get_script().resource_path.ends_with("tutorial_room.gd") and app.current.arrival_busy())
	await until(func():return not app.current.arrival_busy())
	check("original_puzzle_rules_and_cd_preserved",app.current.State.FIRST_STOP>0 and is_equal_approx(app.current.WORLD_COOLDOWN,1.5))
	app.show_hub(true);app.completed_runs=1;await frames(5)
	app.open_level_menu();await frames(6);menu=app.level_menu
	menu.expand_crystal();await until(func():return menu.phase==menu.Phase.EXPANDED)
	check("existing_second_level_unlock_preserved",menu.paper_unlocked and menu.shards[1].available and menu.shards.slice(2).all(func(s):return not s.available))
	move(menu.shards[1].position);await frames(15)
	await capture("05-second-level-unlocked")
	menu.choose_shard(1);await until(func():return app.level_menu==null)
	check("second_level_route_preserved",app.current.get_script().resource_path.ends_with("paper_mill_room.gd"))
	app.show_hub(false);await frames(8)
	var hub=app.current;var baseline:=nodes(root)
	for i in range(10):
		app.open_level_menu();await frames(8)
		menu=app.level_menu
		if i%2==0:menu.expand_crystal();await until(func():return menu.phase==menu.Phase.EXPANDED)
		measure(i)
		var old_menu:WeakRef=weakref(menu);var old_view:WeakRef=weakref(menu.glass_renderer.viewport)
		menu.close();await frames(8)
		check("menu_and_shared_viewport_released_%02d"%i,old_menu.get_ref()==null and old_view.get_ref()==null)
		check("return_preserves_hub_and_node_count_%02d"%i,app.current==hub and nodes(root)==baseline and hub.process_mode==Node.PROCESS_MODE_INHERIT)
	check("render_resources_bounded_after_repeated_open",stats[-1].texture_memory<=stats[2].texture_memory+4194304 and stats[-1].static_memory<=stats[2].static_memory+8388608)
	check("all_selection_render_nodes_freed",app.level_menu==null and nodes(root)==baseline)
	var file:=FileAccess.open(directory.path_join("observatory-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results,"resources":stats},"\t"));file.close()
	print("OBSERVATORY_REPORT ",results.size()," checks, ",failures," failures")
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
