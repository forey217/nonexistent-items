extends Node

var room: Node2D
var results: Array[Dictionary] = []
var skipped: Array[String] = []
var failures := 0
var sampled_positions := 0
var actual_contacts := 0
const ACTIONS := ["walk_left","walk_right","walk_up","walk_down"]

func _record(title: String, passed: bool, details: Dictionary = {}) -> void:
	results.append({"test":title,"passed":passed,"details":details})
	if not passed:
		failures += 1
		print("MOVEMENT_TEST_FAILED: ",title," ",JSON.stringify(details))

func _release() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

func _place(at: Vector2) -> void:
	_release()
	room.cancel_orders()
	room.player.teleport_for_reset(at)
	await _settle()

func _hold(direction: Vector2, frames: int, expected_prop: Node = null) -> Dictionary:
	_release()
	if direction.x<0: Input.action_press("walk_left",absf(direction.x))
	if direction.x>0: Input.action_press("walk_right",absf(direction.x))
	if direction.y<0: Input.action_press("walk_up",absf(direction.y))
	if direction.y>0: Input.action_press("walk_down",absf(direction.y))
	var clear := true
	var touched := false
	var animation_frames: Array[int] = []
	for index in range(frames):
		await get_tree().physics_frame
		sampled_positions += 1
		if not room.actor_position_is_clear(room.player.position):
			clear = false
		if not animation_frames.has(room.player.selected_frame):
			animation_frames.append(room.player.selected_frame)
		for collision_index in range(room.player.get_slide_collision_count()):
			var collider: Object = room.player.get_slide_collision(collision_index).get_collider()
			actual_contacts += 1
			if expected_prop == null or (collider is Node and collider.get_parent()==expected_prop):
				touched = true
	var moving_at_end: bool = room.player.walking
	_release()
	# Ordinary release now brakes in 80ms, then settles the feet over 140ms.
	for i in range(15):await get_tree().physics_frame
	return {"clear":clear,"contact":touched,"frames":animation_frames,"moving_at_end":moving_at_end}

func _wait_for_arrival(limit: int = 900) -> Dictionary:
	var clear := true
	var frames := 0
	for index in range(limit):
		await get_tree().physics_frame
		sampled_positions += 1
		frames += 1
		if not room.actor_position_is_clear(room.player.position):
			clear = false
		if not room.player.is_navigating():
			break
	return {"clear":clear,"frames":frames,"navigating":room.player.is_navigating()}

func run(test_room: Node2D) -> void:
	room = test_room
	await _settle()
	_record("spawn_clear",room.actor_position_is_clear(room.player.position))
	_record("front_back_cutout_views",room.player._art._views.size()==2)
	# Inspect the actual limb transforms, not just a changing frame counter.
	for row in range(4):
		var rig = room.player._art
		rig.pose(0,true,row,Vector2(1,0.4),1.0)
		var start_separation: float = rig.near_foot.x-rig.far_foot.x
		var near_start_x: float = rig.near_foot.x
		var far_start_x: float = rig.far_foot.x
		var arm_start: float = rig.near_arm.rotation
		rig.pose(rig.STRIDE_DISTANCE*0.5,true,row,Vector2(1,0.4),1.0)
		var opposite_separation: float = rig.near_foot.x-rig.far_foot.x
		var arm_opposite: float = rig.near_arm.rotation
		rig.pose(rig.STRIDE_DISTANCE*0.25,true,row,Vector2(1,0.4),1.0)
		var foot_lift: float = -4.0-rig.far_foot.y
		_record("opposite_steps_and_knee_lift_%d"%row,start_separation-opposite_separation>65 and absf(arm_start-arm_opposite)>0.2 and foot_lift>2.8 and foot_lift<3.6,{"first_step":start_separation,"opposite_step":opposite_separation,"lift":foot_lift})
		rig.pose(0,true,row,Vector2(1,0.4),1.0)
		var first_arm: float = rig.near_arm.rotation
		var first_far_arm: float = rig.far_arm.rotation
		rig.pose(rig.STRIDE_DISTANCE*0.5,true,row,Vector2(1,0.4),1.0)
		_record("opposing_arm_swing_%d"%row,first_arm-rig.near_arm.rotation>0.2 and rig.far_arm.rotation-first_far_arm>0.2 and near_start_x-rig.near_foot.x>30 and rig.far_foot.x-far_start_x>30)
		var proper_shoulder_side: bool = rig.near_arm.position.x<0 and rig.far_arm.position.x>0 if row<2 else rig.near_arm.position.x>0 and rig.far_arm.position.x<0
		_record("shoulder_side_and_occlusion_%d"%row,proper_shoulder_side and rig.near_arm.get_index()>rig.body.get_index() and rig.far_arm.get_index()<rig.body.get_index())
		rig.pose(0,false,row,Vector2.ZERO,1.0)
		_record("idle_legs_do_not_cross_%d"%row,(rig.near_foot.x<rig.far_foot.x) if row<2 else (rig.near_foot.x>rig.far_foot.x))
	var all_leg_quads_renderable := true
	var back_hands_stay_on_sides := true
	var checked_leg_quads := 0
	for row in range(4):
		for phase in range(32):
			var rig = room.player._art
			rig.pose(rig.STRIDE_DISTANCE*float(phase)/32.0,true,row,Vector2(1,0.4),1.0)
			if row>=2:
				var near_region: Rect2 = rig.near_arm.texture.region
				var far_region: Rect2 = rig.far_arm.texture.region
				var near_hand: Vector2 = rig.near_arm.transform*(rig.near_arm.offset+Vector2(40,near_region.size.y*0.92))
				var far_hand: Vector2 = rig.far_arm.transform*(rig.far_arm.offset+Vector2(35,far_region.size.y*0.92))
				if near_hand.x<=4.0 or far_hand.x>=-4.0:
					back_hands_stay_on_sides = false
			for leg in [rig.near_leg,rig.far_leg]:
				for indices in leg.polygons:
					var quad := PackedVector2Array()
					for index in indices: quad.append(leg.polygon[index])
					if Geometry2D.triangulate_polygon(quad).size()!=6:
						all_leg_quads_renderable = false
					checked_leg_quads += 1
	_record("no_folded_mesh_gaps_during_knee_bends",all_leg_quads_renderable,{"quads":checked_leg_quads,"phases_per_direction":32})
	_record("back_hands_do_not_swing_through_spine",back_hands_stay_on_sides)
	var steps_per_second: float = room.player.DEFAULT_SPEED/room.player._art.STRIDE_DISTANCE*2.0
	_record("walking_cadence_after_speed_increase",steps_per_second>=2.2 and steps_per_second<=2.4,{"steps_per_second":steps_per_second,"speed":room.player.DEFAULT_SPEED})
	_record("shared_depth_sort",room.sort_layer.y_sort_enabled and room.player.get_parent()==room.props[0].get_parent())
	for action in ACTIONS:
		_record("input_binding_"+action,InputMap.action_get_events(action).size()==2)

	var free_start: Vector2 = room.iso(1.7,4.9)
	await _place(free_start)
	var walk := await _hold(Vector2.RIGHT,10)
	var straight_distance: float = room.player.position.distance_to(free_start)
	_record("manual_move_and_walk_frames",straight_distance>room.player.DEFAULT_SPEED*.12 and straight_distance<room.player.DEFAULT_SPEED*.18 and walk["clear"] and walk["frames"].size()>=2,{"distance":straight_distance,"animation_frames":walk["frames"]})
	await _place(free_start)
	var diagonal := await _hold(Vector2(1,1),10)
	var diagonal_distance: float = room.player.position.distance_to(free_start)
	_record("diagonal_not_faster",absf(diagonal_distance-straight_distance)<1.0 and diagonal["clear"],{"straight":straight_distance,"diagonal":diagonal_distance})

	var sustained_cases := [
		[Vector2(390,500),Vector2(1,0.2),0],
		[Vector2(580,500),Vector2(-1,0.2),1],
		[Vector2(390,538),Vector2(1,-0.2),2],
		[Vector2(580,538),Vector2(-1,-0.2),3]
	]
	for trial in sustained_cases:
		await _place(trial[0])
		# Keep the full-gait sample inside its 200px obstacle-free corridor at any speed.
		var sustained := await _hold(trial[1],ceili(200.0/room.player.speed*60.0))
		_record("sustained_full_gait_%d"%trial[2],sustained["clear"] and sustained["frames"].size()>=16 and room.player.facing_row==trial[2],{"phases":sustained["frames"],"facing":room.player.facing_row})
		_record("stop_returns_to_idle_%d"%trial[2],not room.player.walking and room.player.selected_frame == -1 and not room.player._art.moving)

	# Equal travel must produce equal poses at different speeds.
	await _place(Vector2(400,450))
	room.player.set_physics_process(false)
	Input.action_press("walk_right")
	room.player.speed = 120
	for i in range(16): room.player._physics_process(1.0/60.0)
	var slow_phase: float = room.player._walk_time
	var slow_distance:float=room.player.position.distance_to(Vector2(400,450))
	_release()
	await _place(Vector2(400,450))
	Input.action_press("walk_right")
	room.player.speed = 240
	for i in range(8): room.player._physics_process(1.0/60.0)
	var fast_phase: float = room.player._walk_time
	var fast_distance:float=room.player.position.distance_to(Vector2(400,450))
	_release()
	room.player.speed = room.player.DEFAULT_SPEED
	room.player.set_physics_process(true)
	await _settle()
	_record("gait_tracks_distance_not_clock",absf(slow_phase-slow_distance)<0.1 and absf(fast_phase-fast_distance)<0.1,{"slow_distance":slow_distance,"fast_distance":fast_distance,"slow_gait":slow_phase,"fast_gait":fast_phase})

	for edge in range(room.floor_polygon.size()):
		var a: Vector2 = room.floor_polygon[edge]
		var b: Vector2 = room.floor_polygon[(edge+1)%room.floor_polygon.size()]
		var midpoint := (a+b)*0.5
		var inward := (b-a).orthogonal().normalized()
		if inward.dot(Vector2(640,454)-midpoint)<0: inward=-inward
		await _place(midpoint+inward*70)
		var boundary := await _hold(-inward,50)
		_record("boundary_collision_%d"%edge,boundary["clear"] and boundary["contact"],{"position":[room.player.position.x,room.player.position.y]})
		_record("blocked_wall_halts_steps_%d"%edge,not boundary["moving_at_end"])

	for prop in room.props:
		var polygon: PackedVector2Array = prop.global_footprint()
		for side in range(polygon.size()):
			var a := polygon[side]
			var b := polygon[(side+1)%polygon.size()]
			var midpoint := (a+b)*0.5
			var outward := (b-a).orthogonal().normalized()
			if outward.dot(midpoint-prop.position)<0: outward=-outward
			var start: Vector2 = midpoint+outward*(room.player.FOOT_RADIUS+23)
			if not room.actor_position_is_clear(start):
				skipped.append("%s side %d: adjacent scenery blocks the starting position"%[prop.name,side])
				continue
			await _place(start)
			var contact := await _hold(-outward,23,prop)
			_record("solid_%s_side_%d"%[prop.name,side],contact["clear"] and contact["contact"])

	var desk = room.props[1]
	var left_of_desk: Vector2 = desk.position+Vector2(-180,0)
	var right_of_desk: Vector2 = desk.position+Vector2(180,0)
	await _place(left_of_desk)
	_record("desk_blocks_direct_line",not room.segment_is_clear(left_of_desk,right_of_desk))
	room.queue_destination(right_of_desk)
	await _settle()
	var route_accepted: bool = room.last_request_succeeded
	var route_result := await _wait_for_arrival()
	_record("mouse_route_around_desk",route_accepted and route_result["clear"] and not route_result["navigating"] and room.player.position.distance_to(right_of_desk)<2.0,route_result)

	await _place(left_of_desk)
	room.queue_destination(right_of_desk)
	await _settle()
	var takeovers: int = room.player.manual_takeovers
	await _hold(Vector2.DOWN,4)
	var released_position: Vector2 = room.player.position
	await _settle()
	_record("wasd_cancels_old_click_route",room.player.manual_takeovers==takeovers+1 and not room.player.is_navigating() and room.player.position.distance_to(released_position)<0.01)

	await _place(room.spawn_point)
	room.queue_destination(desk.position)
	await _settle()
	_record("reject_inside_furniture",not room.last_request_succeeded and not room.player.is_navigating())
	room.queue_destination(Vector2(40,200))
	await _settle()
	_record("reject_outside_room",not room.last_request_succeeded and not room.player.is_navigating())

	await _place(left_of_desk)
	room.queue_destination(right_of_desk)
	await _settle()
	room.queue_destination(room.spawn_point)
	await _settle()
	var replacement := await _wait_for_arrival()
	_record("latest_click_replaces_route",replacement["clear"] and room.player.position.distance_to(room.spawn_point)<2.0)
	room.queue_destination(right_of_desk)
	await _settle()
	room.cancel_orders()
	var cancelled_at: Vector2 = room.player.position
	await _settle()
	_record("cancel_stops_immediately",not room.player.is_navigating() and room.player.position.distance_to(cancelled_at)<0.01)

	var desk_polygon: PackedVector2Array = desk.global_footprint()
	var fast_midpoint := (desk_polygon[2]+desk_polygon[3])*0.5
	var fast_outward := (desk_polygon[3]-desk_polygon[2]).orthogonal().normalized()
	if fast_outward.dot(fast_midpoint-desk.position)<0: fast_outward=-fast_outward
	await _place(fast_midpoint+fast_outward*(room.player.FOOT_RADIUS+30))
	room.player.speed=4000
	var fast := await _hold(-fast_outward,8,desk)
	room.player.speed=room.player.DEFAULT_SPEED
	var distance_from_face: float = (room.player.position-fast_midpoint).dot(fast_outward)
	_record("high_speed_sweep_no_tunnelling",fast["clear"] and fast["contact"] and distance_from_face>=room.player.FOOT_RADIUS-0.5,{"outside_distance":distance_from_face,"contact":fast["contact"],"clear":fast["clear"]})

	for corner_index in range(room.floor_polygon.size()):
		var corner: Vector2 = room.floor_polygon[corner_index]
		var inward: Vector2 = (Vector2(640,454)-corner).normalized()
		await _place(corner+inward*100)
		var corner_result := await _hold(-inward,50)
		_record("corner_seal_%d"%corner_index,corner_result["clear"] and corner_result["contact"])

	room.reset_player()
	await _settle()
	_record("reset_restores_safe_start",room.player.position.distance_to(room.spawn_point)<0.01 and room.actor_position_is_clear(room.player.position))
	var directory: String = room.artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	var report := {"checks":results.size(),"failures":failures,"sampled_positions":sampled_positions,"contact_samples":actual_contacts,"skipped_approaches":skipped,"results":results}
	var file := FileAccess.open(directory.path_join("movement-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("MOVEMENT_TEST_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures,"sampled_positions":sampled_positions,"contact_samples":actual_contacts,"skipped":skipped.size()}))
	get_tree().quit(0 if failures==0 else 1)
