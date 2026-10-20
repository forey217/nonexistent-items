extends Node2D

const PlayerScript = preload("res://scripts/yanyue_mover.gd")
const PlayerScene = preload("res://scenes/yanyue.tscn")
const NavigationScript = preload("res://scripts/bureau_navigation.gd")
const PropScript = preload("res://scripts/bureau_prop.gd")
const FloorScript = preload("res://scripts/bureau_floor.gd")
const HudScript = preload("res://scripts/movement_hud.gd")
const OverlayScript = preload("res://scripts/movement_overlay.gd")

var player = PlayerScene.instantiate()
var navigation = NavigationScript.new()
var hud = HudScript.new()
var overlay = OverlayScript.new()
var sort_layer := Node2D.new()
var props: Array = []
var floor_polygon := PackedVector2Array([Vector2(640,220),Vector2(1108,454),Vector2(640,688),Vector2(172,454)])
var spawn_point := Vector2.ZERO
var marker_position := Vector2.ZERO
var marker_visible := false
var marker_valid := true
var last_request_succeeded := false
var _pending_click := false
var _requested_point := Vector2.ZERO
var _marker_time := 0.0

func iso(u: float, v: float) -> Vector2:
	return Vector2(640,220) + Vector2(52,26)*u + Vector2(-52,26)*v

func _ready() -> void:
	process_physics_priority = -20
	_setup_inputs()
	var floor_art := FloorScript.new()
	add_child(floor_art)
	_create_walls()
	sort_layer.name = "DepthSortedWorld"
	sort_layer.y_sort_enabled = true
	add_child(sort_layer)
	_add_prop("bookcase","书架",iso(2.0,1.1),Vector2(1.8,0.6),145)
	_add_prop("desk","办公桌",iso(4.4,3.8),Vector2(2.6,1.4),225)
	_add_prop("chest","收纳箱",iso(6.7,6.1),Vector2(1.35,0.95),142)
	_add_prop("globe","观测台",iso(7.3,2.0),Vector2(1.15,1.15),132)
	spawn_point = iso(3.1,6.4)
	player.name = "Yanyue"
	player.position = spawn_point
	sort_layer.add_child(player)
	player.navigation_finished.connect(_on_arrived)
	player.movement_notice.connect(_on_player_notice)
	var obstacles: Array[PackedVector2Array] = []
	for prop in props:
		obstacles.append(prop.global_footprint())
	navigation.configure(floor_polygon,obstacles,player.FOOT_RADIUS,Callable(self,"segment_is_clear"))
	add_child(hud)
	hud.reset_requested.connect(reset_player)
	hud.debug_requested.connect(toggle_debug)
	overlay.room = self
	overlay.z_index = 5
	add_child(overlay)
	var args := OS.get_cmdline_user_args()
	if "--self-test" in args:
		_run_test_suite.call_deferred()
	elif "--capture" in args:
		_capture_preview.call_deferred()
	elif "--capture-gait" in args:
		_capture_gait.call_deferred()
	elif "--walk-demo" in args:
		_open_walk_demo.call_deferred()

func _setup_inputs() -> void:
	var controls := {
		"walk_left":[KEY_A,KEY_LEFT],"walk_right":[KEY_D,KEY_RIGHT],
		"walk_up":[KEY_W,KEY_UP],"walk_down":[KEY_S,KEY_DOWN]
	}
	for action in controls:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in controls[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func _create_walls() -> void:
	for index in range(floor_polygon.size()):
		var a := floor_polygon[index]
		var b := floor_polygon[(index+1)%floor_polygon.size()]
		var outward := (b-a).orthogonal().normalized()
		var room_center := Vector2(640,454)
		if outward.dot(room_center-(a+b)*0.5)>0:
			outward = -outward
		outward *= 24
		var wall := StaticBody2D.new()
		wall.name = "Wall%d"%index
		wall.collision_layer = 1
		wall.collision_mask = 2
		var collision := CollisionPolygon2D.new()
		collision.polygon = PackedVector2Array([a,b,b+outward,a+outward])
		wall.add_child(collision)
		add_child(wall)

func _footprint(size: Vector2) -> PackedVector2Array:
	var u := Vector2(52,26)*size.x*0.5
	var v := Vector2(-52,26)*size.y*0.5
	return PackedVector2Array([-u-v,u-v,u+v,-u+v])

func _add_prop(key: String, title: String, at: Vector2, size: Vector2, art_width: float) -> void:
	var prop = PropScript.new()
	prop.configure(key,title,at,_footprint(size),art_width)
	props.append(prop)
	sort_layer.add_child(prop)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			queue_destination(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			hud.set_status("右键道具入口已保留；本版先验证人物移动。")
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				reset_player()
			KEY_ESCAPE:
				cancel_orders()
			KEY_F2:
				toggle_debug()
			KEY_F3:
				_open_walk_demo()

func queue_destination(destination: Vector2) -> void:
	_pending_click = true
	_requested_point = destination

func _physics_process(delta: float) -> void:
	if _pending_click:
		_pending_click = false
		marker_position = _requested_point
		marker_visible = true
		_marker_time = 1.5
		var path: PackedVector2Array = navigation.find_path(player.position,_requested_point)
		last_request_succeeded = not path.is_empty()
		marker_valid = last_request_succeeded
		if last_request_succeeded:
			player.follow_path(path)
			hud.set_status("正在绕开障碍；按 WASD 可立即接管。")
		else:
			player.cancel_navigation()
			hud.set_status("这里不是可到达的空地，请选择房间内的通路。",true)
	if marker_visible and not player.is_navigating():
		_marker_time -= delta
		if _marker_time <= 0:
			marker_visible = false
	hud.show_mode(player.walking,player.is_navigating())

func _circle_query(at: Vector2, radius: float) -> PhysicsShapeQueryParameters2D:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0,at)
	query.collision_mask = 1
	query.collide_with_areas = false
	return query

func actor_position_is_clear(at: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(at,floor_polygon):
		return false
	var query := _circle_query(at,player.FOOT_RADIUS-0.25)
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func segment_is_clear(from: Vector2, to: Vector2) -> bool:
	if from.distance_squared_to(to)<0.01:
		return actor_position_is_clear(to)
	var query := _circle_query(from,player.FOOT_RADIUS+0.2)
	query.motion = to-from
	var hit := get_world_2d().direct_space_state.cast_motion(query)
	return hit.size()==2 and hit[0]>=0.9999

func reset_player() -> void:
	_pending_click = false
	player.teleport_for_reset(spawn_point)
	marker_visible = false
	hud.set_status("已回到起点。左键点击空地，或用 WASD 走动。")

func cancel_orders() -> void:
	_pending_click = false
	player.cancel_navigation()
	marker_visible = false
	hud.set_status("已取消移动路线。")

func toggle_debug() -> void:
	overlay.show_debug = not overlay.show_debug
	hud.debug_button.text = "隐藏碰撞  F2" if overlay.show_debug else "碰撞显示  F2"

func _open_walk_demo() -> void:
	cancel_orders()
	player.set_physics_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	hud.hide()
	var gallery = preload("res://scripts/walk_demo.gd").new()
	gallery.z_index = 50
	add_child(gallery)

func _on_arrived() -> void:
	marker_visible = false
	hud.set_status("已到达。试着从家具的另一侧经过，检查遮挡。")

func _on_player_notice(message: String) -> void:
	marker_visible = false
	hud.set_status(message)

func artifacts_directory() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifacts="):
			return argument.trim_prefix("--artifacts=")
	return ProjectSettings.globalize_path("user://movement-checks")

func _run_test_suite() -> void:
	var test_script: GDScript = load("res://tests/movement_tests.gd")
	if test_script == null or not test_script.can_instantiate():
		get_tree().quit(1)
		return
	var suite = test_script.new()
	add_child(suite)
	await suite.run(self)

func _capture_preview() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var directory := artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	var shots := [
		["movement-overview.png",spawn_point],
		["behind-desk.png",iso(4.4,3.8)+Vector2(0,-77)],
		["front-desk.png",iso(4.4,3.8)+Vector2(-65,94)],
		["facing-right-back.png",spawn_point,2],
		["facing-left-back.png",spawn_point,3],
		["facing-right-front.png",spawn_point,0],
		["facing-left-front.png",spawn_point,1]
	]
	for shot in shots:
		if shot.size()>2: player.facing_row = shot[2]
		player.teleport_for_reset(shot[1])
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(directory.path_join(shot[0]))
		if error != OK:
			push_error("Could not save gameplay preview")
			get_tree().quit(1)
			return
	print("MOVEMENT_PREVIEWS_SAVED")
	get_tree().quit(0)

func _capture_gait() -> void:
	player.set_physics_process(false)
	hud.hide()
	sort_layer.hide()
	var board := Node2D.new()
	board.z_index = 20
	add_child(board)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2.ZERO,Vector2(1280,0),Vector2(1280,800),Vector2(0,800)])
	backdrop.color = Color("eae5dc")
	board.add_child(backdrop)
	for row in range(4):
		for column in range(8):
			var rig = preload("res://scripts/yanyue_walk_rig.gd").new()
			board.add_child(rig)
			rig.position = Vector2(90+column*155,170+row*195)
			rig.pose(float(column)/8.0*rig.STRIDE_DISTANCE,true,row,Vector2(1,0.4),1.0)
	await RenderingServer.frame_post_draw
	var directory := artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	var error := get_viewport().get_texture().get_image().save_png(directory.path_join("gait-contact-sheet.png"))
	get_tree().quit(0 if error==OK else 1)
