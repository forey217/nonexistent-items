extends Node
var app: Node2D
var directory: String
var checks: Array[Dictionary]=[]
var failures := 0

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition: Callable,limit:=700) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func record(title: String,passed: bool,details: Dictionary={}) -> void:
	checks.append({"test":title,"passed":passed,"details":details})
	if not passed:
		failures+=1
		push_error("HUB_FLOW_FAILED "+title+" "+JSON.stringify(details))

func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func click(at: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		get_viewport().push_input(event,true)

func key(code: int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=down
		get_viewport().push_input(event,true)

func move_pointer(at:Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=at;event.global_position=at
	get_viewport().push_input(event,true)

func open_globe(hub: Node2D) -> void:
	click(hub.globe.art.to_global(Vector2.ZERO))
	await frames(3)

func run(flow: Node2D) -> void:
	app=flow
	directory=app.current.artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(285)
	var hub=app.current
	var music_id: int=app.ambience.music.get_instance_id()
	record("normal_entry_is_reception_hub",hub.get_script().resource_path.ends_with("tutorial_hub.gd"))
	record("chest_removed_from_art_and_navigation",hub.props.size()==3 and hub.props.all(func(p):return p.name!="Chest") and hub.navigation.is_safe(hub.iso(6.7,6.1)) and hub.actor_position_is_clear(hub.iso(6.7,6.1)))
	var desk=hub.props.filter(func(p):return p.name=="Desk")[0]
	record("tesla_uses_generated_reference_sprite_behind_desk",hub.npc_art.texture.resource_path.ends_with("tesla_v01.png") and hub.npc.position.y<desk.position.y and not hub.navigation.is_safe(hub.npc.position))
	await snapshot("01-hub-tesla-no-chest")
	await open_globe(hub)
	record("clicking_globe_opens_one_level_map",app.level_menu!=null and app.current==hub and hub.process_mode==Node.PROCESS_MODE_DISABLED and app.level_menu.selection_age<0)
	var menu=app.level_menu
	var start: Vector2=menu.rift_position(0)
	await frames(35)
	record("bright_starfield_continues_animating",menu.age>0.4 and menu.rift_position(0).distance_to(start)>0.2 and menu.clock_material.get_shader_parameter("clock")>0.4)
	record("initial_view_is_one_whole_crystal_without_bottom_copy",menu.phase==menu.Phase.CLOSED and menu.shards.size()==6 and menu.shards.all(func(s):return s.revealed==0.0) and not menu.enter_button.visible)
	await snapshot("02-moving-star-map")
	move_pointer(menu.CENTER);await frames(20)
	record("hover_opens_hairline_fractures",menu.hover_amount>0.45 and menu.phase==menu.Phase.CLOSED and menu.shards.all(func(s):return s.fracture>0.45))
	await snapshot("02b-hover-fractures")
	move_pointer(Vector2(70,650));await frames(25)
	record("fractures_relax_when_pointer_leaves",menu.hover_amount<0.05)
	click(menu.CENTER+Vector2(100,0));await frames(2)
	record("empty_area_near_crystal_cannot_expand_it",menu.phase==menu.Phase.CLOSED)
	click(Vector2(75,660));await frames(3)
	record("background_click_does_not_enter_level",app.current==hub and menu.selection_age<0)
	key(KEY_M);await frames(2)
	record("mute_works_inside_level_map",app.ambience.muted)
	key(KEY_M);key(KEY_ESCAPE);await frames(4)
	record("escape_restores_hub_without_restarting_music",app.level_menu==null and app.current==hub and hub.process_mode==Node.PROCESS_MODE_INHERIT and app.ambience.music.get_instance_id()==music_id)
	hub.player.teleport_for_reset(hub.iso(7.3,3.4));await frames(3)
	key(KEY_E);await frames(4)
	record("nearby_E_also_opens_globe_map",app.level_menu!=null)
	menu=app.level_menu
	click(menu.CENTER);await frames(3)
	record("first_click_splits_crystal_without_entering_level",menu.phase==menu.Phase.OPENING and menu.selection_age<0 and app.current==hub)
	click(menu.CENTER);await frames(2)
	record("split_click_does_not_skip_level_selection",menu.selection_age<0)
	var split_frames:=0
	while menu.phase==menu.Phase.OPENING and split_frames<100:
		await frames(1);split_frames+=1
		if split_frames%3==0:await snapshot("split-%03d"%split_frames)
	record("fragments_expand_into_one_level_and_five_unknowns",menu.phase==menu.Phase.EXPANDED and menu.shards[0].available and menu.shards.slice(1).all(func(s):return not s.available and s.revealed>0.99))
	await snapshot("02c-expanded-level-fragments")
	click(menu.shards[1].global_position);await frames(3)
	record("question_mark_fragment_does_not_enter_or_select",menu.phase==menu.Phase.EXPANDED and menu.selection_age<0 and menu.selected==-1 and menu.shards[1].lock_pulse>0)
	click(menu.shards[0].global_position);await frames(3)
	record("available_fragment_begins_rotation_into_itself",menu.selection_age>0 and menu.selected==0 and menu.rift_starts.size()==6 and menu.enter_button.disabled and menu.close_button.disabled)
	click(menu.CENTER);key(KEY_ESCAPE);await frames(2)
	record("selection_cannot_duplicate_or_cancel_halfway",app.level_menu==menu and menu.selection_age>0 and app.current==hub)
	var count:=0
	var switched:=false
	while app.level_menu!=null and count<180:
		await frames(1);count+=1
		if count%2==0:await snapshot("select-%03d"%count)
		if is_instance_valid(menu) and menu.committed and not switched:
			switched=true
			record("level_swaps_at_white_crystal_peak",app.current!=hub and app.current.arrival_busy() and menu.sky.visible==false)
	var room=app.current
	record("selection_finishes_on_tutorial_without_extra_menu",app.level_menu==null and room.get_script().resource_path.ends_with("tutorial_room.gd"))
	record("level_entry_rift_has_real_world_depth",room.orbit_view.arrival_sprite.visible and room.orbit_view.arrival_sprite.layers==(1<<3) and room.arrival_busy())
	var entry_frames:=0
	var safe:=true
	while room.arrival_busy() and entry_frames<100:
		await frames(1);entry_frames+=1
		safe=safe and room.actor_position_is_clear(room.player.position)
		if entry_frames%2==0:await snapshot("entry-%03d"%entry_frames)
	record("hero_emerges_then_controls_restore",not room.arrival_busy() and not room.player.controls_locked and room.player.position.distance_to(room.spawn_point)<2 and safe)
	record("entry_rift_disables_its_extra_rendering",not room.orbit_view.arrival_sprite.visible and room.orbit_view.arrival_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	await snapshot("03-tutorial-arrived")
	var before: Vector2=room.player.position
	Input.action_press("walk_right");await frames(7);Input.action_release("walk_right");await frames(2)
	record("WASD_works_after_rift_arrival",room.player.position.distance_to(before)>6)
	room.reset_tutorial();await frames(3)
	# Complete the real puzzle, including the existing world switching rules.
	room.request_push();record("real_first_plate",await until(func():return room.state.rail_position>=room.State.FIRST_STOP))
	room.change_world(1);await until(func():return not room.casting and room.world_cooldown==0)
	room.change_world(0);await until(func():return not room.casting);room.request_push()
	record("real_rail_end",await until(func():return room.state.rail_position>=room.State.RAIL_LENGTH))
	await until(func():return room.world_cooldown==0);room.change_world(2)
	record("real_upper_receiver",await until(func():return room.state.receiver_latched))
	await until(func():return room.world_cooldown==0);room.change_world(1)
	record("real_gate_opens",await until(func():return room.gate_ready))
	await frames(3);room.queue_destination(room.portal_position)
	record("walking_out_starts_existing_archive",await until(func():return app.returning and app.completed_runs==1))
	await until(func():return not app.returning)
	hub=app.current
	record("archive_returns_to_hub_with_new_spatial_rift",hub.get_script().resource_path.ends_with("tutorial_hub.gd") and hub.cleared and hub.arrival_busy())
	var return_frames:=0
	while hub.arrival_busy() and return_frames<100:
		await frames(1);return_frames+=1
		if return_frames%2==0:await snapshot("return-%03d"%return_frames)
	record("return_rift_finishes_without_collision",not hub.arrival_busy() and not hub.player.controls_locked and hub.actor_position_is_clear(hub.player.position) and hub.player.modulate.a>0.99)
	record("hub_keeps_npc_and_chest_stays_removed_after_return",hub.props.size()==3 and is_instance_valid(hub.npc))
	record("music_continues_through_all_scenes",app.ambience.music.get_instance_id()==music_id and (DisplayServer.get_name()=="headless" or app.ambience.music.playing))
	await snapshot("04-returned-through-rift")
	await open_globe(hub)
	record("globe_reopens_whole_crystal_after_clear",app.level_menu!=null and app.level_menu.selection_age<0 and app.level_menu.phase==app.level_menu.Phase.CLOSED)
	key(KEY_ESCAPE);await frames(3)
	var file:=FileAccess.open(directory.path_join("hub-flow-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks.size(),"failures":failures,"results":checks},"\t"));file.close()
	print("HUB_FLOW_TEST_REPORT ",JSON.stringify({"checks":checks.size(),"failures":failures}))
	await app.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
