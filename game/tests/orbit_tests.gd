extends Node
var room: Node2D
var checks: Array[Dictionary]=[]
var failures:=0

func record(title: String,passed: bool,details: Dictionary={}) -> void:
	checks.append({"test":title,"passed":passed,"details":details})
	if not passed:failures+=1;print("ORBIT_FAILED ",title," ",details)

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition: Callable,limit:=900) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func alt(pressed: bool,right:=false) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=KEY_ALT
	event.keycode=KEY_ALT
	event.location=KEY_LOCATION_RIGHT if right else KEY_LOCATION_LEFT
	event.pressed=pressed
	get_viewport().push_input(event,true)

func click(at: Vector2,pressed: bool,button:=MOUSE_BUTTON_LEFT) -> void:
	var event:=InputEventMouseButton.new()
	event.position=at
	event.global_position=at
	event.pressed=pressed
	event.button_index=button
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed and button==MOUSE_BUTTON_LEFT else 0
	get_viewport().push_input(event,true)

func drag(dx: float,at:=Vector2(600,450)) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=at+Vector2(dx,0)
	motion.relative=Vector2(dx,0)
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion,true)

func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(room.artifacts_directory().path_join(name+".png"))

func push_visible() -> void:
	var center: Vector2=room.orbit_view.logic_to_screen(room.block_ground_position(),0.22+room.state.elevation/room.orbit_view.HEIGHT_PIXELS)
	click(center+Vector2(0,-12),true,MOUSE_BUTTON_RIGHT)
	click(center+Vector2(0,-12),false,MOUSE_BUTTON_RIGHT)

func run(target: Node2D) -> void:
	room=target
	DirAccess.make_dir_recursive_absolute(room.artifacts_directory())
	await frames(4)
	var view=room.orbit_view
	var initial: Vector2=room.player.position
	# Actual input dispatch must consume the gesture before GUI/movement handling.
	alt(true);click(Vector2(650,450),true);drag(1000)
	await frames(3)
	record("left_alt_drag_clamps_at_plus_45",view.angle==45 and view.dragging)
	record("orbit_does_not_move_player_or_trigger_skill",room.player.position==initial and not room._pending_click and not room.player.is_navigating() and room.world_cooldown==0 and room.state.world==0)
	await snapshot("orbit-plus-45")
	drag(-2000);await frames(2)
	record("drag_clamps_at_minus_45",view.angle==-45)
	await snapshot("orbit-minus-45")
	click(Vector2(600,450),false);alt(false)
	await frames(1)
	record("release_keeps_angle_and_ends_drag",not view.dragging and view.angle==-45,{"dragging":view.dragging,"left_alt":view.left_alt,"angle":view.angle})
	view.reset_view();await frames(1)
	record("camera_reset_keeps_puzzle_and_player",view.angle==0 and room.player.position==initial and room.state.rail_position==0)
	# Alt-left-click over an actual skill button must not activate it.
	alt(true);click(room.hud.skill_button.get_global_rect().get_center(),true)
	click(room.hud.skill_button.get_global_rect().get_center(),false);alt(false);await frames(2)
	record("alt_gesture_cannot_click_skill_ui",not room.casting and room.world_cooldown==0 and room.state.world==0)
	alt(true,true);click(Vector2(650,450),true);drag(80);click(Vector2(650,450),false);alt(false,true)
	record("right_alt_cannot_start_orbit",not view.dragging and view.angle==0)
	room.cancel_orders();await frames(2)
	alt(true);click(Vector2(650,450),true)
	room._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	drag(200)
	record("focus_loss_cancels_modifier_and_drag",not view.dragging and not view.left_alt and view.angle==0)
	click(Vector2(650,450),false);alt(false)
	var worst:=0.0
	for angle in [-45.0,-22.5,0.0,22.5,45.0]:
		view.set_angle(angle)
		for u in [0.5,3.2,6.0,11.5]:
			for v in [0.5,3.4,7.5]:
				var logic: Vector2=room.iso(u,v)
				worst=maxf(worst,view.screen_to_logic(view.logic_to_screen(logic)).distance_to(logic))
	record("click_projection_roundtrip_at_five_angles",worst<0.03,{"max_error_pixels":worst})
	for angle in [-45.0,45.0]:
		view.set_angle(angle)
		room.player.teleport_for_reset(room.spawn_point)
		await frames(2)
		var before: Vector2=view.logic_to_screen(room.player.position)
		Input.action_press("walk_right");await frames(8);Input.action_release("walk_right");await frames(2)
		var after: Vector2=view.logic_to_screen(room.player.position)
		record("screen_right_wasd_at_%d"%int(angle),after.x>before.x+8 and absf(after.y-before.y)<1.0 and room.actor_position_is_clear(room.player.position),{"screen_motion":after-before})
	# Walk to a displayed floor point, then solve using displayed item clicks.
	room.reset_tutorial();await frames(2);view.set_angle(32)
	var destination: Vector2=room.iso(3.2,6.5)
	click(view.logic_to_screen(destination),true);click(view.logic_to_screen(destination),false)
	var arrived: bool=await until(func():return room.player.position.distance_to(destination)<4,350)
	record("left_click_rotated_ground_arrives_safely",arrived and room.actor_position_is_clear(room.player.position),{"position":room.player.position,"target":destination,"pending":room._pending_click,"navigating":room.player.is_navigating(),"alt":view.left_alt,"dragging":view.dragging})
	push_visible()
	var first: bool=await until(func():return room.state.rail_position>=room.State.FIRST_STOP-0.01)
	record("right_click_rotated_weight_pushes_to_plate",first,{"rail":room.state.rail_position,"position":room.player.position,"pending_push":room._pending_push})
	room.change_world(1);await until(func():return not room.casting)
	record("world_switch_keeps_orbit_and_3_second_cd",view.angle==32 and room.state.first_latched and room.world_cooldown>2.0)
	await until(func():return room.world_cooldown==0)
	view.set_angle(-32);room.change_world(0);await until(func():return not room.casting);push_visible()
	var end: bool=await until(func():return room.state.rail_position>=room.State.RAIL_LENGTH-0.01)
	record("remote_item_click_works_after_opposite_rotation",end and room.actor_position_is_clear(room.player.position))
	await until(func():return room.world_cooldown==0)
	room.change_world(2);await until(func():return room.state.receiver_latched)
	view.set_angle(30);await frames(2);await snapshot("orbit-inverted-calibrated")
	record("upward_receiver_and_billboard_remain_aligned",room.state.receiver_latched and view.actor.position.distance_to(view.to_world(room.player.position,0.025))<0.01)
	await until(func():return room.world_cooldown==0)
	room.change_world(1);await until(func():return room.state.gate_open);await frames(4)
	view.set_angle(-30);await frames(2);await snapshot("orbit-heavy-gate-open")
	click(view.logic_to_screen(room.portal_position,0.85),true);click(view.logic_to_screen(room.portal_position,0.85),false)
	var success: bool=await until(func():return room.finished,1200)
	record("rotated_portal_click_completes_tutorial",success and room.get_parent().completed_runs==1)
	var report: Dictionary={"checks":checks.size(),"failures":failures,"results":checks}
	var file:=FileAccess.open(room.artifacts_directory().path_join("orbit-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ORBIT_TEST_REPORT ",JSON.stringify({"checks":checks.size(),"failures":failures}))
	get_tree().quit(0 if failures==0 else 1)
