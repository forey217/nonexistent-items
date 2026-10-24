extends Node2D
signal completed
signal hub_requested
signal dialogue_hint(text: String)
signal dialogue_reset
signal dialogue_notice(text: String)
const State = preload("res://scripts/tutorial_state.gd")
const Navigation = preload("res://scripts/bureau_navigation.gd")
const Prop = preload("res://scripts/calibration_prop.gd")
const MachineArt = preload("res://scripts/tutorial_machine_art.gd")
const EXIT_RADIUS := 58.0
const WORLD_COOLDOWN := 1.5
const CAST_DURATION := 0.55
const CAST_COMMIT := 0.22
const WALL_INSET:=0.42
var state := State.new()
var player = preload("res://scenes/yanyue.tscn").instantiate()
var hud = preload("res://scripts/tutorial_hud.gd").new()
var floor_art = preload("res://scripts/tutorial_map_art.gd").new()
var sound = preload("res://scripts/tutorial_audio.gd").new()
var sort_layer := Node2D.new()
var weight_art := MachineArt.new()
var portal_art := MachineArt.new()
var navigation := Navigation.new()
var props: Array[Node2D] = []
var floor_polygon := PackedVector2Array()
var rail_polygon := PackedVector2Array()
var gate_polygon := PackedVector2Array()
var wall_polygons: Array[PackedVector2Array]=[]
var gate_collision := CollisionPolygon2D.new()
var rail_start := Vector2.ZERO
var rail_end := Vector2.ZERO
var first_plate := Vector2.ZERO
var portal_position := Vector2.ZERO
var spawn_point := Vector2.ZERO
var debug_visible := false
var finished := false
var _pending_click := false
var _click := Vector2.ZERO
var _pending_push := false
var _gate_open := false
var _refresh_navigation := 0
var _hint_level := 0
var _hint_stage := -1
var _last_stage := -1
var _last_goal := -1
var _last_state := Vector2i(-1,-1)
var _marker := Vector2.ZERO
var _marker_time := 0.0
var _elapsed := 0.0
var _test_mode := false
var world_cooldown := 0.0
var casting := false
var cast_age := 0.0
var pending_world := -1
var switch_fx=preload("res://scripts/world_switch_fx.gd").new()
var orbit_view: Node2D
const SEAL_DURATION := 1.0
var gate_ready := false
var seal_active := false
var seal_completed := false
var seal_age := 0.0
const PUSH_DURATION := 0.46
const PUSH_CONTACT := 0.20
const INTERACT_RADIUS := 105.0
var interacting := false
var push_age := 0.0
var push_committed := false
var push_stand := Vector2.ZERO
var task_feedback=preload("res://scripts/task_resonance.gd").new()
var arrival: Node

func arrival_busy() -> bool:
	return is_instance_valid(arrival) and arrival.busy()

func start_rift_arrival() -> void:
	arrival=preload("res://scripts/rift_arrival.gd").new()
	add_child(arrival)
	arrival.prepare(self)
	arrival.play()

func iso(u: float,v: float) -> Vector2:
	return Vector2(535,222)+Vector2(46,23)*u+Vector2(-46,23)*v

func rect_shape(u: float,v: float,w: float,h: float) -> PackedVector2Array:
	return PackedVector2Array([iso(u,v),iso(u+w,v),iso(u+w,v+h),iso(u,v+h)])

func _ready() -> void:
	process_physics_priority = -20
	floor_polygon=rect_shape(0,0,12,8)
	rail_polygon=rect_shape(1.9,4.35,7.7,0.9)
	rail_start=iso(2.2,4.8)
	rail_end=iso(9.3,4.8)
	first_plate=rail_start.lerp(rail_end,State.FIRST_STOP/State.RAIL_LENGTH)
	portal_position=iso(10.7,2.0)
	gate_polygon=rect_shape(10.15,1.65,1.1,0.7)
	spawn_point=iso(1.4,5.95)
	floor_art.room=self
	floor_art.live_rendering=false
	add_child(floor_art)
	_create_walls()
	_add_solid(rail_polygon,"GuardedRail")
	sort_layer.y_sort_enabled=true
	add_child(sort_layer)
	_add_prop("bookcase",iso(2.1,0.9),Vector2(1.7,0.55),143)
	_add_prop("desk",iso(6.8,0.8),Vector2(2.25,1.1),174)
	var receiver := MachineArt.new()
	receiver.live_rendering=false
	receiver.room=self
	receiver.kind="receiver"
	receiver.position=rail_end+Vector2(0,0.5)
	sort_layer.add_child(receiver)
	weight_art.room=self
	weight_art.live_rendering=false
	weight_art.position=rail_start
	sort_layer.add_child(weight_art)
	portal_art.room=self
	portal_art.live_rendering=false
	portal_art.kind="portal"
	portal_art.position=portal_position
	sort_layer.add_child(portal_art)
	var gate_body := StaticBody2D.new()
	gate_body.collision_layer=1
	gate_body.collision_mask=2
	gate_collision.polygon=gate_polygon
	gate_body.add_child(gate_collision)
	add_child(gate_body)
	player.position=spawn_point
	sort_layer.add_child(player)
	player.movement_notice.connect(func(message: String):
		_pending_push=false
		hud.message(message)
	)
	add_child(hud)
	hud.world_requested.connect(change_world)
	hud.reset_requested.connect(reset_tutorial)
	hud.hint_requested.connect(show_hint)
	hud.hub_requested.connect(func(): hub_requested.emit())
	add_child(sound)
	switch_fx.z_index=30
	add_child(switch_fx)
	orbit_view=preload("res://scripts/tutorial_orbit_view.gd").new()
	orbit_view.room=self
	add_child(orbit_view)
	floor_art.hide()
	sort_layer.hide()
	switch_fx.hide()
	hud.view_reset_requested.connect(orbit_view.reset_view)
	hud.task_tracker.anchor_hovered.connect(orbit_view.set_anchor_highlight)
	task_feedback.room=self;add_child(task_feedback)
	_rebuild_navigation()
	hud.refresh(state)
	hud.update_skill(0.0,false)
	hud.message("观察机关的变化，尝试不同世界。需要帮助时按 H，提示会逐级展开。")
	var args := OS.get_cmdline_user_args()
	_test_mode="--tutorial-self-test" in args or "--orbit-self-test" in args
	if "--wall-self-test" in args:_run_wall_tests.call_deferred()
	elif "--orbit-self-test" in args:_run_orbit_tests.call_deferred()
	elif _test_mode: _run_tests.call_deferred()
	elif "--tutorial-capture" in args: _capture.call_deferred()
	elif "--skill-capture" in args: _capture_cast.call_deferred()

func _add_prop(key: String,at: Vector2,size: Vector2,width: float) -> void:
	var prop := Prop.new()
	prop.live_rendering=false
	prop.room=self
	var u := Vector2(46,23)*size.x*0.5
	var v := Vector2(-46,23)*size.y*0.5
	prop.configure(key,key,at,PackedVector2Array([-u-v,u-v,u+v,-u+v]),width)
	props.append(prop)
	sort_layer.add_child(prop)

func _add_solid(polygon: PackedVector2Array,title: String) -> void:
	var body := StaticBody2D.new()
	body.name=title
	body.collision_layer=1
	body.collision_mask=2
	var collision := CollisionPolygon2D.new()
	collision.polygon=polygon
	body.add_child(collision)
	add_child(body)

func _create_walls() -> void:
	var center := iso(6,4)
	for i in range(4):
		var a := floor_polygon[i]
		var b := floor_polygon[(i+1)%4]
		var normal := (b-a).orthogonal().normalized()
		if normal.dot(center-(a+b)*0.5)>0: normal=-normal
		_add_solid(PackedVector2Array([a,b,b+normal*24,a+normal*24]),"Boundary%d"%i)
	# The rendered wall panels/pipes occupy space inside the old floor boundary.
	wall_polygons=[rect_shape(0,0,12,WALL_INSET),rect_shape(0,0,WALL_INSET,8)]
	for i in range(wall_polygons.size()):_add_solid(wall_polygons[i],"WallInterior%d"%i)

func obstacle_polygons() -> Array[PackedVector2Array]:
	var obstacles: Array[PackedVector2Array] = [rail_polygon]
	obstacles.append_array(wall_polygons)
	for prop in props: obstacles.append(prop.global_footprint())
	if not gate_ready: obstacles.append(gate_polygon)
	return obstacles

func _rebuild_navigation() -> void:
	navigation=Navigation.new()
	navigation.configure(floor_polygon,obstacle_polygons(),player.FOOT_RADIUS,Callable(self,"segment_is_clear"))

func _query(at: Vector2,radius: float) -> PhysicsShapeQueryParameters2D:
	var shape := CircleShape2D.new()
	shape.radius=radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.transform=Transform2D(0,at)
	query.collision_mask=1
	return query

func actor_position_is_clear(at: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(at,floor_polygon) and get_world_2d().direct_space_state.intersect_shape(_query(at,12.75),1).is_empty()

func segment_is_clear(from: Vector2,to: Vector2) -> bool:
	if orbit_view!=null and not orbit_view.head_guard.segment_is_clear(from,to):return false
	if from.distance_squared_to(to)<0.01: return actor_position_is_clear(to)
	var query := _query(from,13.2)
	query.motion=to-from
	var cast := get_world_2d().direct_space_state.cast_motion(query)
	return cast.size()==2 and cast[0]>=0.9999

func block_ground_position() -> Vector2:
	return rail_start.lerp(rail_end,state.rail_position/State.RAIL_LENGTH)

func _hit_block(at: Vector2) -> bool:
	return Rect2(block_ground_position()+Vector2(-29,-state.elevation-30),Vector2(58,49)).has_point(at)

func _input(event: InputEvent) -> void:
	if hud.menu.visible:return
	if orbit_view!=null and event is InputEventMouse:orbit_view.pointer_position=event.position
	if event is InputEventMouse and hud.blocks_map(event.position):
		if event is InputEventMouseButton and not event.pressed and orbit_view!=null:orbit_view.handle_input(event)
		return
	if orbit_view!=null and (event is InputEventMouseMotion or event is InputEventMouseButton):orbit_view.pointer_position=event.position
	if orbit_view!=null and orbit_view.handle_input(event):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if finished or hud.menu.visible: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if orbit_view.left_alt or orbit_view.dragging:return
			queue_screen_destination(event.position)
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			if orbit_view.hit_weight(event.position): request_push()
			elif _inspect_screen_instrument(event.position): pass
			elif orbit_view.hit_portal(event.position):
				hud.message("界缝封好后，修复的归位门就能通往机构。")
				if not gate_ready:dialogue_notice.emit("出口还不稳定。先完成当前的校准，我会在这里等你。")
			else: hud.message("右键点击带铜色圆印的镇纸；E 可与附近镇纸交互。")
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: change_world(0)
			KEY_2: change_world(1)
			KEY_3: change_world(2)
			KEY_E: request_push()
			KEY_H: show_hint()
			KEY_R: hud.request_reset()
			KEY_F2: debug_visible=not debug_visible
			KEY_ESCAPE: cancel_orders()

func _inspect_instrument(at: Vector2) -> bool:
	for prop in props:
		if prop.contains_visual(at):
			hud.message(prop.inspection_text())
			return true
	return false

func _inspect_screen_instrument(at: Vector2) -> bool:
	var index: int=orbit_view.instrument_at(at)
	if index<0:return false
	hud.message(props[index].inspection_text())
	return true

func queue_screen_destination(at: Vector2) -> void:
	if orbit_view.hit_weight(at):
		queue_destination(block_ground_position()+Vector2(0,-state.elevation-12))
	elif orbit_view.hit_portal(at):
		queue_destination(portal_position+Vector2(0,-45))
	else:queue_destination(orbit_view.screen_to_logic(at))

func queue_destination(at: Vector2) -> void:
	if casting or seal_active or interacting or arrival_busy():return
	_pending_push=false
	_click=at
	if _hit_block(at): _click=_stand_point(block_ground_position())
	elif at.distance_to(portal_position+Vector2(0,-45))<64:
		_click=portal_position if gate_ready else portal_position+Vector2(0,48)
	_pending_click=true

func _stand_point(at: Vector2) -> Vector2:
	var best := Vector2(-100,-100)
	var distance := INF
	var candidates: Array[Vector2]=[]
	# Either side is valid; choose the shortest walk instead of a preferred pose.
	var screen: Vector2=orbit_view.logic_to_screen(at)
	for offset in [Vector2(-48,40),Vector2(48,40),Vector2(-48,-40),Vector2(48,-40)]:
		candidates.append(orbit_view.screen_to_logic(screen+offset))
	for offset in [Vector2(-20,65),Vector2(20,-65),Vector2(-70,0),Vector2(70,0)]:
		candidates.append(at+offset)
	for candidate in candidates:
		if not navigation.is_safe(candidate): continue
		var path := navigation.find_path(player.position,candidate)
		if path.is_empty(): continue
		var cost: float=0.0
		var previous: Vector2=player.position
		for point in path:
			cost+=previous.distance_to(point)
			previous=point
		if cost<distance:
			distance=cost
			best=candidate
	return best

func request_push() -> void:
	if finished: return
	if seal_active or interacting or arrival_busy():return
	if casting:
		hud.message("正在折叠世界，手势完成后即可推动镇纸。")
		return
	if absf(state.rail_speed)>0.1:
		hud.message("镇纸正在沿导轨滑行。")
		return
	if player.position.distance_to(block_ground_position())<=INTERACT_RADIUS:
		_pending_push=false
		_begin_push()
	else:
		push_stand=_stand_point(block_ground_position())
		var path := navigation.find_path(player.position,push_stand)
		if path.is_empty():
			hud.message("请先走到镇纸旁边的通道。")
			return
		player.follow_path(path)
		_pending_push=true
		hud.message("正在靠近镇纸；按 WASD 可以取消这次交互。")

func _begin_push() -> void:
	if absf(state.rail_speed)>0.1:
		hud.message("镇纸正在沿导轨滑行。")
		return
	player.cancel_navigation()
	player._last_direction=(block_ground_position()-player.position).normalized()
	player._update_facing(player._last_direction)
	interacting=true
	push_age=0.0
	push_committed=false
	player.controls_locked=true

func _clear_push() -> void:
	interacting=false
	push_age=0.0
	push_committed=false
	player._art.push_amount=0.0

func _tick_push(delta: float) -> void:
	if not interacting:return
	push_age+=delta
	player._art.push_amount=smoothstep(0.0,0.18,push_age)*(1.0-smoothstep(0.26,PUSH_DURATION,push_age))
	if not push_committed and push_age>=PUSH_CONTACT:
		push_committed=true
		hud.message(state.push())
		if state.world==State.World.HEAVY:dialogue_notice.emit("它现在太重，无法推动。看看现有的规则。")
		elif state.elevation>0.3:dialogue_notice.emit("先让它接触导轨，才能推动。")
		if absf(state.rail_speed)>0.1:sound.play_event("push")
	if push_age>=PUSH_DURATION:_clear_push()

func change_world(index: int) -> bool:
	if index<0 or index>2 or index==state.world or finished: return false
	# The arrival zone lies outside the gate collider: never close on an actor.
	if gate_ready and player.position.distance_to(portal_position)<EXIT_RADIUS:
		_finish()
		return false
	if seal_active or interacting or arrival_busy():return false
	if world_cooldown>0.001 or casting:
		hud.message("世界折叠冷却中，还需 %.1f 秒。"%world_cooldown)
		return false
	world_cooldown=WORLD_COOLDOWN
	cast_age=0.0
	casting=true
	pending_world=index
	_pending_click=false
	_pending_push=false
	player.cancel_navigation()
	player.controls_locked=true
	orbit_view.film.begin(state.world,index)
	switch_fx.play(player.position,index)
	sound.play_event("fold")
	hud.message("施放世界折叠…")
	hud.update_skill(world_cooldown,casting,pending_world)
	return true

func _apply_world(index: int) -> void:
	var was_first: bool=state.first_latched
	state.switch_world(index)
	sound.play_event("world_set",[1.08,0.88,1.18][index])
	if not was_first and state.first_latched:sound.play_event("star")
	hud.message(["冰晶：摩擦降低，位置和校准记录保留。","重力：向下受力增强，镇纸重量 ×4。","倒悬：重力方向向上，镇纸会浮起。"][index])
	hud.refresh(state)

func _tick_skill(delta: float) -> void:
	world_cooldown=maxf(0.0,world_cooldown-delta)
	if not casting:return
	cast_age+=delta
	var progress:=clampf(cast_age/CAST_DURATION,0.0,1.0)
	player._art.cast_amount=sin(progress*PI)
	switch_fx.update_progress(progress)
	if pending_world>=0 and cast_age>=CAST_COMMIT:
		var target:=pending_world
		pending_world=-1
		_apply_world(target)
	if cast_age>=CAST_DURATION:
		casting=false
		player.controls_locked=false
		player._art.cast_amount=0.0

func reset_tutorial() -> void:
	hud.task_tracker.collapse()
	if is_instance_valid(arrival):arrival.cancel()
	state.reset()
	_clear_push()
	gate_ready=false
	seal_active=false
	seal_completed=false
	seal_age=0.0
	sound.stop_effects()
	if orbit_view!=null:orbit_view.feedback.reset_feedback()
	if orbit_view!=null:orbit_view.atmosphere.reset_effects()
	if orbit_view!=null:orbit_view.film.cancel()
	if orbit_view!=null:orbit_view.reset_view()
	world_cooldown=0
	casting=false
	cast_age=0
	pending_world=-1
	player.controls_locked=false
	player._art.cast_amount=0
	switch_fx.cancel()
	finished=false
	_hint_level=0
	_last_stage=-1
	_last_goal=-1
	_pending_push=false
	_pending_click=false
	player.teleport_for_reset(spawn_point)
	hud.message("已重置镇纸、机关和人物。需要帮助时按 H 查看提示。")
	hud.refresh(state)
	hud.update_skill(0,false)
	hud.update_completion(false,false,0.0)
	_gate_open=not gate_ready
	task_feedback.baseline([],true)
	dialogue_reset.emit()

func cancel_orders() -> void:
	_pending_click=false
	_pending_push=false
	player.cancel_navigation()
	hud.message("已取消移动与待执行交互。")

func show_hint() -> void:
	if _hint_stage!=state.stage():_hint_level=0;_hint_stage=state.stage()
	_hint_level=mini(_hint_level+1,3)
	hud.message("提示 %d/3：%s"%[_hint_level,state.hint(_hint_level)])
	dialogue_hint.emit(state.hint(_hint_level))

func _physics_process(delta: float) -> void:
	for audio_voice in sound.voices:audio_voice.stream_paused=hud.menu.visible
	if hud.menu.visible:return
	_elapsed+=delta
	if finished: return
	_tick_skill(delta)
	_tick_push(delta)
	if Input.get_vector("walk_left","walk_right","walk_up","walk_down").length_squared()>0.01:
		_pending_push=false
		_pending_click=false
	if _pending_click:
		_pending_click=false
		var path := navigation.find_path(player.position,_click)
		if not path.is_empty():
			player.follow_path(path)
			_marker=_click
			_marker_time=1.4
		else:
			player.cancel_navigation()
			hud.message("那里不是可走通道；护栏内的导轨不能进入。")
	if _pending_push and player.position.distance_to(block_ground_position())<=INTERACT_RADIUS:
		_pending_push=false
		player.cancel_navigation()
		_begin_push()
	var old_receiver: bool = state.receiver_latched
	var old_first: bool = state.first_latched
	var old_speed: float=state.rail_speed
	var old_height: float=state.elevation
	state.step(delta)
	weight_art.position=block_ground_position()
	weight_art.hovered=orbit_view.hit_weight(get_global_mouse_position())
	if absf(old_speed)>0.1 and state.rail_speed==0:sound.play_event("stop")
	if old_height>0.3 and state.elevation==0:sound.play_event("land")
	if not old_first and state.first_latched:sound.play_event("star")
	if not old_receiver and state.receiver_latched:
		sound.play_event("moon")
		orbit_view.feedback.trigger_stamp()
	_tick_completion(delta)
	player.controls_locked=casting or seal_active or interacting or arrival_busy()
	if _gate_open!=gate_ready:
		_gate_open=gate_ready
		gate_collision.set_deferred("disabled",_gate_open)
		_refresh_navigation=2
		player.cancel_navigation()
	if _refresh_navigation>0:
		_refresh_navigation-=1
		if _refresh_navigation==0: _rebuild_navigation()
	if _last_stage!=state.stage():
		_last_stage=state.stage()
		_hint_level=0
	if _last_goal!=state.goal_stage():
		_last_goal=state.goal_stage()
		if _last_goal>0:hud.message("三处锚点已响应，等待界缝稳定…" if seal_active else state.objective())
	hud.refresh(state)
	hud.update_skill(world_cooldown,casting,pending_world)
	hud.update_completion(seal_active,seal_completed,seal_age)
	task_feedback.tick(delta)
	if gate_ready and player.position.distance_to(portal_position)<EXIT_RADIUS: _finish()
	_marker_time=maxf(0,_marker_time-delta)
	queue_redraw()

func _tick_completion(delta: float) -> void:
	if not state.gate_open:
		gate_ready=false
		seal_active=false
		seal_age=0.0
		return
	if seal_completed:
		gate_ready=true
		seal_age=minf(2.5,seal_age+delta)
		return
	if not seal_active:
		seal_active=true
		seal_age=0.0
		_pending_click=false
		_pending_push=false
		player.cancel_navigation()
		sound.play_event("seal_begin")
	var previous := seal_age
	seal_age+=delta
	if previous<0.12 and seal_age>=0.12:sound.play_event("star",1.12)
	if previous<0.34 and seal_age>=0.34:sound.play_event("moon",1.06)
	if seal_age>=SEAL_DURATION:
		seal_active=false
		seal_completed=true
		gate_ready=true
		sound.play_event("success")
		hud.message("界缝已封，世界关系恢复稳定。可以返回机构。")

func _draw() -> void:
	if orbit_view!=null:return
	if _marker_time>0:
		draw_set_transform(_marker,0,Vector2(1,0.5))
		draw_arc(Vector2.ZERO,12,0,TAU,32,Color("69a69f"),2,true)
		draw_set_transform(Vector2.ZERO)

func _finish() -> void:
	if finished: return
	task_feedback.clear();hud.task_tracker.get_meta("task_transition").cancel()
	_clear_push()
	orbit_view.film.cancel()
	finished=true
	casting=false
	player.controls_locked=false
	player._art.cast_amount=0
	switch_fx.cancel()
	player.cancel_navigation()
	_pending_push=false
	completed.emit()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		if orbit_view!=null:orbit_view.cancel_drag()
		_pending_click=false
		_pending_push=false
		if player!=null:
			_clear_push()
			player.controls_locked=casting or seal_active or arrival_busy()

func artifacts_directory() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="): return arg.trim_prefix("--artifacts=")
	return ProjectSettings.globalize_path("user://tutorial-checks")

func _run_tests() -> void:
	var script: GDScript=load("res://tests/tutorial_tests.gd")
	if script==null or not script.can_instantiate(): get_tree().quit(1); return
	var suite=script.new()
	add_child(suite)
	await suite.run(self)

func _run_orbit_tests() -> void:
	var suite=load("res://tests/orbit_tests.gd").new()
	add_child(suite)
	await suite.run(self)

func _run_wall_tests() -> void:
	var suite=load("res://tests/wall_occlusion_tests.gd").new()
	add_child(suite)
	await suite.run(self)

func _capture() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var directory := artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	for index in range(3):
		while world_cooldown>0.001 or casting: await get_tree().physics_frame
		change_world(index)
		while casting: await get_tree().physics_frame
		state.rail_position=State.RAIL_LENGTH if index==2 else State.FIRST_STOP
		state.first_latched=true
		state.elevation=92 if index==2 else 0
		state.vertical_speed=0
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(directory.path_join(["tutorial-ice.png","tutorial-heavy.png","tutorial-inverted.png"][index]))
		if error!=OK: get_tree().quit(1); return
	get_tree().quit(0)

func _capture_cast() -> void:
	await get_tree().physics_frame
	var camera:=Camera2D.new()
	camera.position=spawn_point+Vector2(0,-50)
	camera.zoom=Vector2.ONE*2.0
	add_child(camera)
	var directory:=artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	for row in range(4):
		reset_tutorial()
		player.facing_row=row
		player.teleport_for_reset(spawn_point)
		await get_tree().physics_frame
		change_world(2)
		for i in range(16):await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("cast-facing-%d.png"%row))
	sound.enabled=false
	for voice in sound.voices:
		voice.stop()
		voice.stream=null
	reset_tutorial()
	remove_child(camera)
	camera.queue_free()
	for i in range(20):await get_tree().physics_frame
	get_tree().quit(0)
