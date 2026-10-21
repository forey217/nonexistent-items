extends CharacterBody2D

signal navigation_finished
signal movement_notice(message: String)

const FOOT_RADIUS := 13.0
const WalkRig = preload("res://scripts/yanyue_walk_rig.gd")
const DEFAULT_SPEED := 145.0
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
var controls_locked := false
var cinematic_motion := Vector2.ZERO
var input_basis:=Transform2D.IDENTITY
var motion_guard: Callable

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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.46))
	draw_circle(Vector2.ZERO, FOOT_RADIUS + 2.0, Color(0.12, 0.17, 0.22, 0.18))
	draw_set_transform(Vector2.ZERO)

func follow_path(points: PackedVector2Array) -> void:
	route = points
	route_index = 0
	blocked_frames = 0

func cancel_navigation() -> void:
	route.clear()
	route_index = 0
	blocked_frames = 0
	velocity = Vector2.ZERO

func teleport_for_reset(destination: Vector2) -> void:
	cancel_navigation()
	position = destination
	walking = false
	_walk_time = 0.0
	selected_frame = -1
	_art.pose(0,false,facing_row,_last_direction,1.0)
	reset_physics_interpolation()

func is_navigating() -> bool:
	return route_index < route.size()

func _physics_process(delta: float) -> void:
	var keyboard := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	keyboard=input_basis.basis_xform(keyboard)
	if controls_locked:
		keyboard=Vector2.ZERO
		cancel_navigation()
	var intended := Vector2.ZERO
	if keyboard.length_squared() > 0.01:
		if is_navigating():
			manual_takeovers += 1
			cancel_navigation()
			movement_notice.emit("已由 WASD 接管，原点击路线已取消")
		intended = keyboard.normalized() * speed
	elif is_navigating():
		while is_navigating() and position.distance_to(route[route_index]) <= 1.2:
			route_index += 1
		if is_navigating():
			var offset := route[route_index] - position
			intended = offset.normalized() * minf(speed, offset.length() / delta)
		else:
			cancel_navigation()
			navigation_finished.emit()
	if controls_locked:intended=cinematic_motion
	if motion_guard.is_valid() and delta>0.0:
		intended=motion_guard.call(position,intended*delta)/delta
	velocity = intended
	var old_position := position
	move_and_slide()
	var actual := position - old_position
	walking = actual.length_squared() > 0.01
	if walking:
		_last_direction = actual.normalized()
		_update_facing(_last_direction)
		_walk_time += actual.length()
		selected_frame = int(fposmod(_walk_time/WalkRig.STRIDE_DISTANCE,1.0)*16.0)
	else:
		if intended.length_squared()>0.1:
			_update_facing(intended.normalized())
		_walk_time = 0.0
		selected_frame = -1
	_art.pose(_walk_time,walking,facing_row,_last_direction,delta)
	if is_navigating() and intended.length_squared() > 1.0 and not walking:
		blocked_frames += 1
		if blocked_frames > 12:
			cancel_navigation()
			movement_notice.emit("前方通路受阻，请重新选择地面")
	else:
		blocked_frames = 0

func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > 0.12:
		_last_horizontal = signf(direction.x)
	if absf(direction.y) > 0.12:
		_last_vertical = signf(direction.y)
	if _last_vertical >= 0.0:
		facing_row = 0 if _last_horizontal >= 0.0 else 1
	else:
		facing_row = 2 if _last_horizontal >= 0.0 else 3

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree():
		cancel_navigation()
		for action in ["walk_left", "walk_right", "walk_up", "walk_down"]:
			Input.action_release(action)
