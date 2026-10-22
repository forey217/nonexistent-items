extends Node
var room: Node2D
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
		push_error("INTERACTION_FAILED "+title+" "+JSON.stringify(details))

func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func run(app: Node2D) -> void:
	room=app.current
	directory=room.artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	room.sound.enabled=false
	await frames(280)
	var air=room.orbit_view.atmosphere
	room.request_push();await until(func():return room.interacting);await frames(7)
	var stand: Vector2=room.player.position
	record("reach_precedes_object_motion",room.interacting and room.player._art.push_amount>0.2 and room.state.rail_position==0 and room.player.controls_locked)
	Input.action_press("walk_right");await frames(3);Input.action_release("walk_right")
	record("feet_remain_stationary_during_reach",room.player.position.distance_to(stand)<0.01 and room.actor_position_is_clear(stand))
	record("world_switch_waits_for_interaction",not room.change_world(1) and room.world_cooldown==0 and room.state.world==0)
	room.request_push();await frames(5)
	record("paperweight_moves_at_hand_contact",room.state.rail_position>0 and room.player._art.push_amount>0.8 and room.sound.events.count("push")==1)
	await snapshot("push-contact")
	await frames(17)
	record("push_recovers_and_unlocks_controls",not room.interacting and room.player._art.push_amount==0 and not room.player.controls_locked)
	await until(func():return room.state.rail_position>=room.State.FIRST_STOP)
	record("first_stop_still_blocks_forward_travel",not room.state.first_latched and room.state.rail_speed==0 and room.state.rail_position==room.State.FIRST_STOP)
	room.player.teleport_for_reset(room.first_plate+Vector2(-20,65));await frames(2)
	room.request_push();await until(func():return room.interacting);await frames(15)
	record("second_interaction_sends_blocked_weight_back",room.state.rail_speed<0 and room.state.rail_position<room.State.FIRST_STOP and not room.state.first_latched)
	var sounds: int=room.sound.events.count("push")
	room.request_push();await frames(1)
	record("repeated_input_does_not_restart_active_push",room.sound.events.count("push")==sounds)
	await until(func():return room.state.rail_position==0 and room.state.rail_speed==0)
	record("return_stops_at_start_and_keeps_latch_locked",room.state.rail_position==0 and room.state.rail_speed==0 and not room.state.first_latched and "stop" in room.sound.events)
	room.request_push()
	record("return_route_can_be_pushed_forward_again",await until(func():return room.state.rail_position>=room.State.FIRST_STOP))
	room.change_world(1);await until(func():return not room.casting)
	record("forward_puzzle_can_still_release_latch",room.state.first_latched)
	await until(func():return room.world_cooldown==0)
	room.change_world(0);await until(func():return not room.casting)
	room.request_push();await until(func():return room.state.rail_position==room.State.RAIL_LENGTH)
	room.player.teleport_for_reset(room.rail_end+Vector2(70,0));await frames(2)
	var endpoint: Vector2=room.orbit_view.logic_to_screen(room.block_ground_position(),0.35)
	var click:=InputEventMouseButton.new();click.position=endpoint;click.global_position=endpoint
	click.button_index=MOUSE_BUTTON_RIGHT;click.pressed=true
	get_viewport().push_input(click,true)
	var release: InputEventMouseButton=click.duplicate();release.pressed=false
	get_viewport().push_input(release,true);await frames(7)
	record("end_right_click_reaches_before_reversing",room.interacting and room.state.rail_position==room.State.RAIL_LENGTH and room.player._art.push_amount>0.2)
	await frames(8)
	record("end_right_click_reverses_at_hand_contact",room.state.rail_speed<0 and room.state.rail_position<room.State.RAIL_LENGTH and room.state.first_latched)
	await snapshot("rail-end-return-contact")
	await until(func():return room.state.rail_position==0 and room.state.rail_speed==0)
	record("end_return_stops_at_origin_and_keeps_star",room.state.rail_position==0 and room.state.first_latched and room.actor_position_is_clear(room.player.position))
	room.request_push();await until(func():return room.state.rail_position==room.State.RAIL_LENGTH,1400)
	record("return_then_forward_keeps_upper_puzzle_reachable",room.state.rail_position==room.State.RAIL_LENGTH and not room.state.receiver_latched,{"rail":room.state.rail_position,"speed":room.state.rail_speed,"player":room.player.position,"pending":room._pending_push,"navigating":room.player.is_navigating(),"stand":room.push_stand})
	room.reset_tutorial();await frames(2)
	room.request_push();await until(func():return room.interacting);await frames(5);room.reset_tutorial();await frames(40)
	record("reset_before_contact_cancels_future_movement",room.state.rail_position==0 and not room.interacting and not room.player.controls_locked and room.player._art.push_amount==0)
	room.request_push();await until(func():return room.interacting);await frames(4);room._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);await frames(40)
	record("focus_loss_before_contact_cancels_push",room.state.rail_position==0 and not room.interacting and not room.player.controls_locked)
	var offsets: Array[Vector2]=[Vector2(-20,65),Vector2(20,-65),Vector2(-70,0),Vector2(70,0)]
	for i in range(4):
		room.reset_tutorial();await frames(3)
		room.player.teleport_for_reset(room.rail_start+offsets[i]);await frames(2)
		await snapshot("pose-%d-before"%i)
		var initial: Vector2=room.player.position
		room.request_push()
		record("nearby_side_%d_interacts_without_detour"%i,room.interacting and not room._pending_push and not room.player.is_navigating() and room.player.position==initial)
		await until(func():return room.interacting)
		for frame in range(1,32):
			await frames(1)
			if frame%2==0:await snapshot("pose-%d-%02d"%[i,frame])
			if frame==11:
				record("gesture_keeps_collision_clear_view_%d"%i,room.interacting and room.player._art.push_amount>0.9 and room.actor_position_is_clear(room.player.position))
				await snapshot("pose-%d-contact"%i)
	room.reset_tutorial();await frames(2)
	record("frost_starts_near_rail_origin",air.frost[0].visible and not air.frost[31].visible)
	for i in range(60):
		await frames(1)
		if i%2==0:await snapshot("frost-%02d"%i)
	record("frost_propagates_to_both_rail_ends",air.frost.size()==64 and air.frost.all(func(p):return p.visible and p.scale.x>0.99))
	room.change_world(1);await until(func():return room.state.world==1);await frames(3)
	record("heavy_cracks_grow_outward_from_furniture",air.crack_strokes[0].visible and air.crack_strokes[0].scale.x<0.99 and air.crack_strokes[2].scale.x<0.1)
	await snapshot("cracks-early")
	await frames(45)
	record("heavy_cracks_complete_without_extra_collisions",air.crack_strokes.size()==16 and air.crack_strokes.all(func(p):return p.visible and p.scale.x>0.99) and room.actor_position_is_clear(room.player.position) and not air.groups[0].visible)
	await snapshot("cracks-complete")
	await until(func():return room.world_cooldown==0)
	room.change_world(0);await until(func():return room.state.world==0);await frames(2)
	record("reentering_ice_replays_freeze_and_hides_cracks",air.frost_age<0.15 and not air.frost[31].visible and air.groups[0].visible)
	await until(func():return not room.casting and room.world_cooldown==0)
	room.change_world(2);await until(func():return not room.casting)
	var file_start: Vector3=air.floating_files[0].position
	await frames(30)
	record("inverted_desk_papers_gently_levitate",air.floating_files.size()==3 and air.floating_files[0].position.distance_to(file_start)>0.02 and air.groups[2].visible and not air.groups[1].visible)
	await snapshot("inverted-files")
	var file:=FileAccess.open(directory.path_join("interaction-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks.size(),"failures":failures,"results":checks},"\t"));file.close()
	print("INTERACTION_TEST_REPORT ",JSON.stringify({"checks":checks.size(),"failures":failures}))
	await app.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
