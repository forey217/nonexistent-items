extends Node
const State=preload("res://scripts/tutorial_state.gd")
var room: Node2D
var results: Array[Dictionary] = []
var failures := 0
var samples := 0
var collision_free := true

func record(title: String,passed: bool,details: Dictionary={}) -> void:
	results.append({"test":title,"passed":passed,"details":details})
	if not passed:
		failures+=1
		print("TUTORIAL_TEST_FAILED ",title," ",JSON.stringify(details))

func simulate(state: RefCounted,seconds: float,delta: float=1.0/60.0) -> void:
	for i in range(ceili(seconds/delta)): state.step(delta)

func fall_sample(index: int,delta: float) -> Dictionary:
	var s:=State.new()
	s.rail_position=State.RAIL_LENGTH
	s.first_latched=true
	s.receiver_latched=true
	s.elevation=State.CEILING
	s.switch_world(index)
	var elapsed:=0.0
	while s.elevation>0 and elapsed<3.0:
		s.step(delta)
		elapsed+=delta
	return {"seconds":elapsed,"landed":s.elevation==0 and s.vertical_speed==0,"gate_open":s.gate_open}

func unit_checks() -> void:
	var heavy_60:=fall_sample(State.World.HEAVY,1.0/60.0)
	var heavy_120:=fall_sample(State.World.HEAVY,1.0/120.0)
	record("heavy_fall_is_quicker_and_activates_end_plate",heavy_60.landed and heavy_60.gate_open and heavy_60.seconds>0.75 and heavy_60.seconds<0.90,heavy_60)
	record("quicker_fall_is_consistent_at_60_and_120_fps",absf(heavy_60.seconds-heavy_120.seconds)<0.018,heavy_120)
	var normal:=fall_sample(State.World.ICE,1.0/60.0)
	record("normal_world_fall_and_insufficient_pressure_unchanged",normal.landed and not normal.gate_open and normal.seconds>1.33 and normal.seconds<1.40,normal)
	var s:=State.new()
	record("initial_world_and_locked_exit",s.world==0 and not s.gate_open and s.rail_position==0)
	s.push(); simulate(s,0.25)
	var position := s.rail_position
	simulate(s,0.25)
	record("ice_inertia_without_repeated_input",s.rail_position>position+20 and s.rail_speed>0)
	simulate(s,3)
	record("first_stop_no_overshoot",absf(s.rail_position-State.FIRST_STOP)<0.01 and s.rail_speed==0)
	record("normal_weight_cannot_release_stop",not s.first_latched)
	s.push(); simulate(s,1)
	record("locked_stop_interaction_returns_towards_start",s.rail_position<State.FIRST_STOP and s.rail_speed<0 and not s.first_latched)
	simulate(s,1)
	record("return_stops_at_start_without_overshoot",s.rail_position==0 and s.rail_speed==0)
	s.push();simulate(s,2)
	s.switch_world(1)
	record("heavy_weight_releases_stop",s.first_latched)
	s.push(); simulate(s,1)
	record("heavy_cannot_be_pushed",s.rail_speed==0 and s.rail_position==State.FIRST_STOP)
	s.switch_world(0)
	record("mechanical_latch_persists_across_worlds",s.first_latched)
	s.push(); simulate(s,4)
	record("rail_end_no_overshoot",s.rail_position==State.RAIL_LENGTH and s.rail_speed==0)
	s.switch_world(1); simulate(s,0.2)
	record("bottom_plate_alone_does_not_open_exit",s.final_pressed and not s.gate_open)
	s.switch_world(2); simulate(s,0.4)
	var old_height := s.elevation
	var old_position := s.rail_position
	s.switch_world(1)
	record("switch_preserves_position_and_height",s.elevation==old_height and s.rail_position==old_position)
	simulate(s,2)
	record("heavy_gravity_brings_object_down",s.elevation==0)
	s.switch_world(2); simulate(s,3)
	record("upward_gravity_reaches_ceiling_receiver",s.elevation==State.CEILING and s.receiver_latched)
	record("ceiling_contact_alone_does_not_open_exit",not s.final_pressed and not s.gate_open)
	s.switch_world(0); simulate(s,3)
	record("ordinary_gravity_lands_but_insufficient_weight",s.elevation==0 and s.receiver_latched and not s.gate_open)
	s.switch_world(1); simulate(s,1)
	record("both_conditions_open_exit",s.receiver_latched and s.final_pressed and s.gate_open)
	s.switch_world(0)
	record("exit_requires_maintained_heavy_pressure",not s.gate_open and s.receiver_latched)
	s.reset(); s.switch_world(2); simulate(s,3)
	record("wrong_location_cannot_calibrate_receiver",s.elevation==State.CEILING and not s.receiver_latched)
	s.switch_world(1); simulate(s,3); s.switch_world(0); s.push(); simulate(s,3)
	record("wrong_world_order_is_recoverable",s.rail_position==State.FIRST_STOP)
	s.reset(); s.push(); simulate(s,0.3)
	var halfway:=s.rail_position
	s.switch_world(1); simulate(s,1)
	record("heavy_stops_mid_slide_without_teleport",s.rail_position==halfway)
	s.switch_world(0); s.push(); simulate(s,3)
	record("interrupted_slide_resumes",s.rail_position==State.FIRST_STOP)
	s.switch_world(2); simulate(s,1); s.reset()
	record("reset_recovers_midair_and_clears_all_latches",s.elevation==0 and s.rail_position==0 and not s.first_latched and not s.receiver_latched and s.world==0)
	var a:=State.new(); var b:=State.new()
	a.push(); b.push(); simulate(a,2,1.0/30.0); simulate(b,2,1.0/120.0)
	record("slide_contacts_are_frame_rate_independent",a.rail_position==b.rail_position)
	a.switch_world(1); a.switch_world(0); a.push(); a.step(0.5)
	record("long_frame_stays_on_rail",a.rail_position>=State.FIRST_STOP and a.rail_position<=State.RAIL_LENGTH)

func wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
		samples+=1
		if not room.actor_position_is_clear(room.player.position): collision_free=false

func until(condition: Callable,limit: int=700) -> bool:
	for i in range(limit):
		await wait_frames(1)
		if bool(condition.call()): return true
	return false

func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	room._unhandled_input(event)

func right_click_block() -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_RIGHT
	event.pressed=true
	event.position=room.block_ground_position()+Vector2(0,-room.state.elevation-12)
	room._unhandled_input(event)

func skill_ready() -> void:
	await until(func():return room.world_cooldown<=0.001 and not room.casting,400)

func run(test_room: Node2D) -> void:
	room=test_room
	unit_checks()
	await wait_frames(3)
	record("tutorial_spawn_clear",room.actor_position_is_clear(room.player.position))
	record("guarded_rail_is_solid",not room.actor_position_is_clear(room.first_plate))
	record("closed_portal_is_solid",not room.actor_position_is_clear(room.portal_position))
	record("skill_card_is_in_upper_left",room.hud.skill_panel.get_global_rect().position.x<100 and room.hud.skill_panel.get_global_rect().position.y<300)
	record("same_world_does_not_consume_cooldown",not room.change_world(0) and room.world_cooldown==0)
	record("invalid_world_does_not_consume_cooldown",not room.change_world(9) and room.world_cooldown==0)
	var before: Vector2=room.player.position
	room.hud.worlds[1].pressed.emit()
	record("world_tile_starts_shared_one_point_five_second_cooldown",room.casting and absf(room.world_cooldown-1.5)<0.001 and room.hud.worlds[2].disabled)
	key(KEY_3);room.hud.worlds[2].pressed.emit()
	record("keyboard_and_target_buttons_cannot_bypass_cooldown",room.pending_world==1 and absf(room.world_cooldown-1.5)<0.001)
	Input.action_press("walk_right")
	await wait_frames(20)
	Input.action_release("walk_right")
	record("world_tile_changes_world_without_moving_player",room.state.world==1 and room.player.position==before)
	record("cast_gesture_and_effect_active",room.player._art.cast_amount>0.3 and room.switch_fx.active and room.player.controls_locked)
	await wait_frames(20)
	var after_cast:Vector2=room.player.position
	Input.action_press("walk_right");await wait_frames(6);Input.action_release("walk_right");await wait_frames(2)
	record("movement_restored_before_cooldown_ends",not room.player.controls_locked and room.player.position.distance_to(after_cast)>8 and room.world_cooldown>0.5)
	await wait_frames(37)
	record("cannot_switch_before_one_point_five_seconds",room.world_cooldown>0.03 and not room.change_world(2))
	var cd_before:float=room.world_cooldown
	key(KEY_3)
	record("rejected_input_does_not_extend_cooldown",room.world_cooldown==cd_before)
	await wait_frames(8)
	record("skill_recovers_at_one_point_five_seconds",room.world_cooldown==0 and not room.casting and not room.hud.worlds[2].disabled and not room.player.controls_locked)
	key(KEY_3); await wait_frames(50)
	record("skill_works_again_after_recovery",room.state.world==2 and room.state.elevation>0)
	key(KEY_R); await wait_frames(3)
	record("r_restores_safe_start_midair",room.state.world==0 and room.state.elevation==0 and room.player.position==room.spawn_point)
	record("reset_clears_cast_and_cooldown",room.world_cooldown==0 and not room.casting and not room.switch_fx.active and room.player._art.cast_amount==0)
	key(KEY_H); key(KEY_H); key(KEY_H)
	record("h_reveals_progressive_hint",room._hint_level==3 and room.hud.message_label.text.contains("右键"))
	right_click_block()
	var first: bool=await until(func():return room.state.rail_position>=State.FIRST_STOP-0.01)
	record("right_click_moves_to_first_plate",first and not room.state.first_latched)
	room.hud.worlds[1].pressed.emit(); await until(func():return room.state.world==1)
	record("world_button_releases_latched_stop",room.state.first_latched and room.state.world==1)
	await skill_ready()
	key(KEY_1); await until(func():return not room.casting); right_click_block()
	var end: bool=await until(func():return room.state.rail_position>=State.RAIL_LENGTH-0.01)
	record("remote_right_click_walks_to_safe_stand_then_pushes",end and collision_free)
	await skill_ready(); key(KEY_3)
	var upper: bool=await until(func():return room.state.receiver_latched)
	record("live_upward_gravity_calibrates_receiver",upper and room.state.elevation>=State.CEILING-0.2)
	await skill_ready(); key(KEY_2)
	var open: bool=await until(func():return room.gate_ready)
	await wait_frames(4)
	record("live_heavy_landing_opens_portal",open and room.gate_collision.disabled)
	record("open_portal_is_walkable",room.navigation.is_safe(room.portal_position) and room.actor_position_is_clear(room.portal_position))
	room.queue_destination(room.portal_position)
	var success: bool=await until(func():return room.finished,1000)
	record("complete_by_walking_into_open_gate",success and room.get_parent().completed_runs==1)
	room.finished=false
	room.player.teleport_for_reset(room.portal_position+Vector2(50,0))
	room.change_world(0)
	record("world_change_cannot_close_gate_on_player",room.finished and room.state.gate_open and room.get_parent().completed_runs==2)
	room.reset_tutorial(); await wait_frames(4)
	record("reset_recloses_portal",not room.finished and not room.gate_collision.disabled and not room.state.gate_open)
	# Check collision and keyboard takeover with real navigation on the new map.
	room.player.teleport_for_reset(room.iso(9.0,6.2)); await wait_frames(2)
	room.request_push(); await wait_frames(3)
	Input.action_press("walk_left"); await wait_frames(5); Input.action_release("walk_left"); await wait_frames(3)
	record("manual_takeover_cancels_queued_interaction",not room._pending_push and not room.player.is_navigating())
	room.request_push()
	room._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	record("losing_focus_cancels_pending_push",not room._pending_push)
	room.reset_tutorial(); await wait_frames(3)
	for index in range(4):
		var a:Vector2=room.floor_polygon[index]
		var b:Vector2=room.floor_polygon[(index+1)%4]
		var inward:Vector2=(room.iso(6,4)-(a+b)*0.5).normalized()
		var start:=Vector2.ZERO
		for t in [0.3,0.5,0.7]:
			var candidate:Vector2=a.lerp(b,t)+inward*80
			if room.actor_position_is_clear(candidate): start=candidate; break
		room.player.teleport_for_reset(start)
		await wait_frames(2)
		var direction:Vector2=-inward
		if direction.x<0:Input.action_press("walk_left",absf(direction.x))
		else:Input.action_press("walk_right",absf(direction.x))
		if direction.y<0:Input.action_press("walk_up",absf(direction.y))
		else:Input.action_press("walk_down",absf(direction.y))
		await wait_frames(80)
		var contact:bool=room.player.get_slide_collision_count()>0
		for action in ["walk_left","walk_right","walk_up","walk_down"]:Input.action_release(action)
		await wait_frames(2)
		record("new_room_boundary_%d"%index,contact and room.actor_position_is_clear(room.player.position))
	record("all_sampled_positions_collision_free",collision_free,{"samples":samples})
	var report:Dictionary={"checks":results.size(),"failures":failures,"sampled_positions":samples,"results":results}
	DirAccess.make_dir_recursive_absolute(room.artifacts_directory())
	var file:=FileAccess.open(room.artifacts_directory().path_join("tutorial-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("TUTORIAL_TEST_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures,"samples":samples}))
	await get_tree().current_scene.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
