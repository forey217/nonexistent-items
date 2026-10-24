extends CharacterBody2D

signal navigation_finished
signal movement_notice(message: String)

const FOOT_RADIUS := 13.0
const WalkRig = preload("res://scripts/yanyue_walk_rig.gd")
const DEFAULT_SPEED := 208.8
const ACCEL_SECONDS:=0.10
const BRAKE_SECONDS:=0.08
const ARRIVAL_RADIUS:=0.45
const Facing=preload("res://scripts/yanyue_facing.gd")
var speed := DEFAULT_SPEED
var route := PackedVector2Array()
var route_index := 0
var walking := false
var facing_row := 1
var selected_frame := 0
var manual_takeovers := 0
var blocked_frames := 0
var _walk_time := 0.0
var _last_horizontal := -1.0
var _last_vertical := 1.0
var _art := WalkRig.new()
var _last_direction := Vector2(-1,0)
var automation_owned:=false
var controls_locked:=false:
	set(value):
		if value and not controls_locked:
			cancel_navigation();walking=false
		controls_locked=value
var cinematic_motion := Vector2.ZERO
var input_basis:=Transform2D.IDENTITY
var motion_guard: Callable
var route_guard: Callable
var movement_ratio:=0.0
var _previous_position:=Vector2.ZERO
var _current_position:=Vector2.ZERO
var _previous_distance:=0.0
var _render_valid:=false
var _shadow_offset:=Vector2.ZERO

func _ready() -> void:
	_ensure_input_actions()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	safe_margin = 0.10
	max_slides = 6
	var shape := CircleShape2D.new()
	shape.radius = FOOT_RADIUS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	add_child(_art)
	_art.pose(0,false,facing_row,_last_direction,1.0)
	_reset_display()
	queue_redraw()

func _ensure_input_actions() -> void:
	var controls := {
		"walk_left":[KEY_A,KEY_LEFT],"walk_right":[KEY_D,KEY_RIGHT],
		"walk_up":[KEY_W,KEY_UP],"walk_down":[KEY_S,KEY_DOWN]
	}
	for action in controls:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if not InputMap.action_get_events(action).is_empty():
			continue
		for key in controls[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func _draw() -> void:
	draw_set_transform(_shadow_offset, 0.0, Vector2(1.0, 0.46))
	draw_circle(Vector2.ZERO, FOOT_RADIUS + 2.0, Color(0.12, 0.17, 0.22, 0.18))
	draw_set_transform(Vector2.ZERO)

func follow_path(points: PackedVector2Array) -> void:
	if points.is_empty():cancel_navigation();return
	route = points
	route_index = 0
	blocked_frames = 0

func cancel_navigation(stop_immediately: bool=true) -> void:
	route.clear()
	route_index = 0
	blocked_frames = 0
	if stop_immediately:
		velocity=Vector2.ZERO;walking=false;movement_ratio=0.0

func teleport_for_reset(destination: Vector2) -> void:
	cancel_navigation()
	position = destination
	walking = false
	_walk_time = 0.0
	selected_frame = -1
	_art.pose(0,false,facing_row,_last_direction,1.0)
	_reset_display()
	reset_physics_interpolation()

func is_navigating() -> bool:
	return route_index < route.size()

func face_toward(target: Vector2) -> void:
	var direction:=target-global_position
	if direction.length_squared()<0.01:return
	_last_direction=direction.normalized()
	_update_facing(_last_direction,true)
	_art.pose(_walk_time,walking,facing_row,_last_direction,1.0)

func _reset_display() -> void:
	_previous_position=position;_current_position=position;_previous_distance=_walk_time;_render_valid=true
	_art.position=Vector2.ZERO;_shadow_offset=Vector2.ZERO

func display_position() -> Vector2:
	if not _render_valid or position.distance_squared_to(_current_position)>0.01:return position
	return _previous_position.lerp(_current_position,Engine.get_physics_interpolation_fraction())

func display_distance() -> float:
	return lerpf(_previous_distance,_walk_time,Engine.get_physics_interpolation_fraction())

func _process(delta: float) -> void:
	_art.position=display_position()-position
	_shadow_offset=_art.position;queue_redraw()
	_art.pose(display_distance(),walking,facing_row,_last_direction,delta,movement_ratio)

func _safe_segment(a: Vector2,b: Vector2) -> bool:
	if route_guard.is_valid():return route_guard.call(a,b)
	if get_parent().has_method("segment_is_clear"):return get_parent().segment_is_clear(a,b)
	return false

func _route_aim() -> Vector2:
	var target:=route[route_index]
	if route_index+1>=route.size():return target
	var lookahead:=speed*0.10
	var next:=route[route_index+1]
	var outgoing:=(next-target).normalized()
	# Only leave the original segment when a full-width sweep validates the shortcut.
	if position.distance_to(target)<lookahead and (position-target).dot(outgoing)>0 and _safe_segment(position,next):
		route_index+=1;return next
	var lead:=clampf(lookahead-position.distance_to(target),0.0,lookahead)
	var candidate:=target.move_toward(next,lead)
	return candidate if lead>0 and _safe_segment(position,candidate) else target

func _physics_process(delta: float) -> void:
	if position.distance_squared_to(_current_position)>pow(speed*delta*3.0+1.0,2):_reset_display()
	_previous_position=_current_position;_previous_distance=_walk_time
	var keyboard := Vector2.ZERO if automation_owned else Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	keyboard=input_basis.basis_xform(keyboard)
	if controls_locked:
		keyboard=Vector2.ZERO
		cancel_navigation()
	var desired:=Vector2.ZERO
	var path_limit:=INF
	if keyboard.length_squared() > 0.01:
		if is_navigating():
			manual_takeovers += 1
			cancel_navigation(false)
			movement_notice.emit("已由 WASD 接管，原点击路线已取消")
		desired=keyboard.normalized()*speed
	elif is_navigating():
		while is_navigating() and position.distance_to(route[route_index]) <= (ARRIVAL_RADIUS if route_index==route.size()-1 else 1.2):
			route_index += 1
		if is_navigating():
			var offset:=_route_aim()-position
			var target_speed:=speed
			if route_index==route.size()-1:
				var remaining:=position.distance_to(route[-1])
				target_speed=minf(speed,sqrt(2.0*(speed/BRAKE_SECONDS)*maxf(0.0,remaining-ARRIVAL_RADIUS*0.5)))
			path_limit=offset.length()/maxf(delta,0.001)
			desired=offset.normalized()*target_speed
		else:
			cancel_navigation()
			navigation_finished.emit()
	var intended:=Vector2.ZERO
	if controls_locked:intended=cinematic_motion
	elif desired.length_squared()>0.01:
		var current_speed:=velocity.length()
		if current_speed>0.01 and velocity.normalized().dot(desired.normalized())< -0.25:
			current_speed=minf(current_speed,speed*0.35)
		var response:=speed/(ACCEL_SECONDS if desired.length()>current_speed else BRAKE_SECONDS)
		intended=desired.normalized()*minf(path_limit,move_toward(current_speed,desired.length(),response*delta))
	else:intended=velocity.move_toward(Vector2.ZERO,speed/BRAKE_SECONDS*delta)
	if motion_guard.is_valid() and delta>0.0:
		intended=motion_guard.call(position,intended*delta)/delta
	velocity = intended
	var old_position := position
	move_and_slide()
	var actual := position - old_position
	_current_position=position
	movement_ratio=clampf(actual.length()/maxf(delta*speed,0.001),0.0,1.0)
	walking=actual.length()/maxf(delta,0.001)>1.0
	if walking:
		var direction:=actual.normalized()
		if intended.length_squared()>0.01 and direction.dot(intended.normalized())>0.94:direction=intended.normalized()
		_last_direction=direction
		_update_facing(_last_direction)
		_walk_time += actual.length()
		selected_frame = int(fposmod(_walk_time/WalkRig.STRIDE_DISTANCE,1.0)*16.0)
	else:
		selected_frame = -1
	if is_navigating() and intended.length_squared() > 1.0 and not walking:
		blocked_frames += 1
		if blocked_frames > 12:
			cancel_navigation()
			movement_notice.emit("前方通路受阻，请重新选择地面")
	else:
		blocked_frames = 0

func _update_facing(direction: Vector2,force: bool=false) -> void:
	facing_row=Facing.row(direction,facing_row,force)
	_last_horizontal=1.0 if facing_row%2==0 else -1.0
	_last_vertical=1.0 if facing_row<2 else -1.0

func _notification(what: int) -> void:
	if get_meta("presentation_frozen",false) or automation_owned:return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree():
		cancel_navigation()
		for action in ["walk_left", "walk_right", "walk_up", "walk_down"]:
			Input.action_release(action)
