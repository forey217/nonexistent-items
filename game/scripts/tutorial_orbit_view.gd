extends Node2D
## Live orthographic presentation of the existing 2D puzzle.
## Camera orbit affects rendering/input projection, never collision or puzzle state.
const Builder=preload("res://scripts/calibration_scene_builder.gd")
const PIXELS:=65.05382387
const HEIGHT_PIXELS:=56.33826408
const LIMIT:=45.0
const DRAG_SPEED:=0.20
var room: Node2D
var angle:=0.0
var left_alt:=false
var dragging:=false
var viewport:=SubViewport.new()
var world_root:=Node3D.new()
var camera:=Camera3D.new()
var output:=Sprite2D.new()
var themes: Array[Dictionary]=[]
var paper_viewport:=SubViewport.new()
var paper=preload("res://scripts/yanyue_walk_rig.gd").new()
var actor:=Sprite3D.new()
var actor_shadow: MeshInstance3D
var display_fx=preload("res://scripts/world_switch_fx.gd").new()
var font:=SystemFont.new()
var clock:=0.0
var last_world:=-1
var screen_direction:=Vector2(-1,1)

func _ready() -> void:
	font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	viewport.size=Vector2i(1280,800)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(world_root)
	_setup_lighting()
	viewport.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.size=800.0/PIXELS
	camera.current=true
	for i in range(3):_build_theme(i)
	output.texture=viewport.get_texture()
	output.centered=false
	output.show_behind_parent=true
	add_child(output)
	_setup_actor()
	add_child(display_fx)
	set_angle(0)
	_sync_state(0.0)

func _setup_lighting() -> void:
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(0,0,0,0)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("d6e1e8")
	env.environment.ambient_light_energy=0.42
	world_root.add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-58,-38,0)
	light.light_color=Color("fff1d4")
	light.light_energy=0.72
	light.shadow_enabled=true
	light.directional_shadow_max_distance=45
	light.shadow_bias=0.035
	world_root.add_child(light)
	var fill:=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-20,140,0)
	fill.light_color=Color("c7d8ed")
	fill.light_energy=0.15
	world_root.add_child(fill)

func _group(parent: Node3D,at: Vector3) -> Node3D:
	var node:=Node3D.new()
	parent.add_child(node)
	node.position=at
	return node

func _build_theme(index: int) -> void:
	var root3:=_group(world_root,Vector3.ZERO)
	var b:=Builder.new()
	b.configure(index,root3)
	b.room_base()
	var cabinet:=_group(root3,to_world(room.props[0].position))
	b.scene=cabinet
	b.cabinet()
	var console:=_group(root3,to_world(room.props[1].position))
	b.scene=console
	b.console_desk()
	var receiver:=_group(root3,to_world(room.rail_end))
	b.scene=receiver
	b.receiver()
	var weight:=_group(root3,to_world(room.rail_start))
	b.scene=weight
	b.weight()
	var gate:=_group(root3,to_world(room.portal_position))
	b.scene=gate
	b.model("gate",Vector3.ZERO,Vector3.ONE*0.42,PI*0.25)
	var bars:=_group(gate,Vector3.ZERO)
	bars.rotation.y=PI*0.25
	for i in range(5):b.box(Vector3(-0.55+i*0.275,0.85,0),Vector3(0.018,1.7,0.018),b.brass,bars)
	var gate_light:=b.material(Color("7bddbc"),true)
	var open_plane:=b.box(Vector3(0,0.95,0),Vector3(1.25,1.85,0.014),gate_light,gate)
	open_plane.rotation.y=PI*0.25
	gate_light.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	gate_light.albedo_color.a=0.13
	b.scene=root3
	var plate_mats: Array[StandardMaterial3D]=[]
	for at in [room.first_plate,room.rail_end]:
		var point: Vector3=to_world(at)
		b.box(point+Vector3(0,0.19,0),Vector3(0.78,0.12,0.78),b.metal)
		var mat:=b.material(Color("c8b58c"))
		b.box(point+Vector3(0,0.26,0),Vector3(0.63,0.035,0.63),mat)
		plate_mats.append(mat)
		var number:=Label3D.new()
		number.text="01" if plate_mats.size()==1 else "02"
		number.font=font
		number.font_size=28
		number.pixel_size=0.007
		number.outline_size=0
		number.modulate=Color("40535b")
		number.position=point+Vector3(0,0.287,0)
		number.rotation.x=-PI*0.5
		root3.add_child(number)
		for x in [-0.34,0.34]:
			for z in [-0.34,0.34]:b.cylinder(point+Vector3(x,0.26,z),0.024,0.025,b.brass)
	var stop:=b.box(to_world(room.first_plate)+Vector3(0.25,0.4,0),Vector3(0.12,0.34,0.65),b.brass)
	for z in [-0.22,0.0,0.22]:b.box(Vector3(0.068,0,z),Vector3(0.015,0.29,0.095),b.dark,stop)
	b.box(to_world(room.first_plate)+Vector3(0.25,0.205,0),Vector3(0.20,0.045,0.75),b.metal)
	var rail_leds: Array[StandardMaterial3D]=[]
	for i in range(20):
		var mat:=b.material(Color("536c77"),true)
		b.cylinder(Vector3(2.12+i*0.38,0.29,5.21),0.025,0.018,mat)
		rail_leds.append(mat)
	var led_mats: Array[StandardMaterial3D]=[]
	for i in range(3):
		var mat:=b.material(Color("526675"),true)
		b.box(console.position+Vector3(-0.65+i*0.65,1.19,-0.15),Vector3(0.35,0.035,0.018),mat)
		led_mats.append(mat)
	var sample:=b.cylinder(cabinet.position+Vector3(-0.45,0.72,0.34),0.045,0.075,b.glow)
	for x in [-0.54,-0.36]:b.box(cabinet.position+Vector3(x,1.02,0.34),Vector3(0.025,0.75,0.025),b.brass)
	for y in [0.64,1.4]:b.box(cabinet.position+Vector3(-0.45,y,0.34),Vector3(0.20,0.025,0.025),b.brass)
	var upper_mat:=b.material(Color("a9d7cd"),true)
	b.box(receiver.position+Vector3(0,2.77,0.02),Vector3(0.45,0.028,0.30),upper_mat)
	# Connected service cables run on the floor and remain walkable.
	var cable_color:=b.material(Color("8b9b86"))
	for segment in [[Vector3(6.8,0.045,1.3),Vector3(6.8,0.045,3.85)],[Vector3(6.8,0.045,3.85),Vector3(9.9,0.045,3.85)],[Vector3(9.9,0.045,3.85),Vector3(9.9,0.045,2.0)],[Vector3(9.9,0.045,2),to_world(room.portal_position)+Vector3(0,0.045,0)]]:
		var a: Vector3=segment[0]
		var c: Vector3=segment[1]
		b.box((a+c)*0.5,Vector3(absf(c.x-a.x)+0.045,0.035,absf(c.z-a.z)+0.045),b.dark)
		b.box((a+c)*0.5+Vector3(0,0.025,0),Vector3(absf(c.x-a.x)+0.015,0.015,absf(c.z-a.z)+0.015),cable_color)
	themes.append({"root":root3,"weight":weight,"bars":bars,"open":open_plane,"stop":stop,"plates":plate_mats,"leds":led_mats,"rail_leds":rail_leds,"sample":sample,"upper":upper_mat,"cable":cable_color})
	root3.visible=index==0

func _setup_actor() -> void:
	paper_viewport.size=Vector2i(512,640)
	paper_viewport.transparent_bg=true
	paper_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(paper_viewport)
	var paper_container:=Node2D.new()
	paper_container.scale=Vector2.ONE*2
	paper_viewport.add_child(paper_container)
	paper_container.add_child(paper)
	paper.position=Vector2(128,270)
	actor.texture=paper_viewport.get_texture()
	actor.pixel_size=0.5/PIXELS
	actor.offset=Vector2(0,220)
	actor.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	actor.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	actor.alpha_scissor_threshold=0.04
	actor.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	actor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(actor)
	var b:=Builder.new()
	b.configure(0,world_root)
	var shadow_material:=b.material(Color(0.12,0.18,0.23,0.2))
	shadow_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	actor_shadow=b.cylinder(Vector3.ZERO,0.23,0.002,shadow_material)

func to_world(logic: Vector2,height: float=0.0) -> Vector3:
	var point:=logic-Vector2(535,222)
	return Vector3((point.x/46.0+point.y/23.0)*0.5,height,(point.y/23.0-point.x/46.0)*0.5)

func to_logic(world: Vector3) -> Vector2:
	return room.iso(world.x,world.z)

func logic_to_screen(logic: Vector2,height: float=0.0) -> Vector2:
	return camera.unproject_position(to_world(logic,height))

func screen_to_logic(screen: Vector2) -> Vector2:
	var origin:=camera.project_ray_origin(screen)
	var direction:=camera.project_ray_normal(screen)
	if absf(direction.y)<0.00001:return Vector2(-10000,-10000)
	return to_logic(origin+direction*(-origin.y/direction.y))

func set_angle(value: float) -> void:
	angle=clampf(value,-LIMIT,LIMIT)
	var target:=Vector3(6,0,4)
	var offset:=Vector3(16,16*sqrt(2.0/3.0),16).rotated(Vector3.UP,deg_to_rad(angle))
	camera.position=target+offset
	camera.look_at(target)
	camera.position+=camera.basis.x*((640.0-627.0)/PIXELS)+camera.basis.y*((452.0-400.0)/PIXELS)
	var origin:=screen_to_logic(Vector2(640,400))
	room.player.input_basis=Transform2D(screen_to_logic(Vector2(641,400))-origin,screen_to_logic(Vector2(640,401))-origin,Vector2.ZERO)
	if room.hud.view_angle_label!=null:room.hud.view_angle_label.text="视角 %+.0f°"%angle
	queue_redraw()

func reset_view() -> void:
	cancel_drag()
	set_angle(0)

func cancel_drag() -> void:
	dragging=false
	left_alt=false

func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.physical_keycode==KEY_ALT:
		if event.location!=KEY_LOCATION_RIGHT:
			left_alt=event.pressed
			if not left_alt:dragging=false
			return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			var was_dragging:=dragging
			dragging=false
			return was_dragging or left_alt
		if left_alt:
			dragging=true
			room._pending_click=false
			room._pending_push=false
			room.player.cancel_navigation()
			return true
	if event is InputEventMouseMotion and dragging:
		if not left_alt or not event.button_mask&MOUSE_BUTTON_MASK_LEFT:
			dragging=false
			return true
		set_angle(angle+event.relative.x*DRAG_SPEED)
		return true
	return false

func hit_weight(screen: Vector2) -> bool:
	var center:=logic_to_screen(room.block_ground_position(),0.22+room.state.elevation/HEIGHT_PIXELS)
	return Rect2(center+Vector2(-31,-34),Vector2(62,50)).has_point(screen)

func hit_portal(screen: Vector2) -> bool:
	return screen.distance_to(logic_to_screen(room.portal_position,0.85))<67

func instrument_at(screen: Vector2) -> int:
	var selected:=-1
	var depth:=INF
	for i in range(2):
		var points:=PackedVector2Array()
		var center:=to_world(room.props[i].position)
		var size:=Vector3(1.7,1.9,0.55) if i==0 else Vector3(2.25,1.5,1.1)
		for x in [-0.5,0.5]:
			for y in [0.0,1.0]:
				for z in [-0.5,0.5]:points.append(camera.unproject_position(center+Vector3(x,y,z)*size))
		if Geometry2D.is_point_in_polygon(screen,Geometry2D.convex_hull(points)):
			var distance:=camera.global_position.distance_squared_to(center)
			if distance<depth:selected=i;depth=distance
	return selected

func _process(delta: float) -> void:
	clock+=delta
	_sync_state(delta)
	queue_redraw()

func _sync_state(delta: float) -> void:
	if themes.is_empty():return
	var index: int=room.state.world
	if last_world!=index:
		for i in range(3):themes[i].root.visible=i==index
		last_world=index
	var group: Dictionary=themes[index]
	group.weight.position=to_world(room.block_ground_position(),0.22+room.state.elevation/HEIGHT_PIXELS)
	group.stop.visible=not room.state.first_latched
	group.bars.visible=not room.state.gate_open
	group.open.visible=room.state.gate_open
	var flags: Array[bool]=[room.state.first_latched,room.state.receiver_latched,room.state.final_pressed]
	for i in range(3):
		group.leds[i].albedo_color=Color("84caae") if flags[i] else Color("526675")
		group.leds[i].emission=group.leds[i].albedo_color
	group.plates[0].albedo_color=Color("8eaf9e") if flags[0] else Color("c8b58c")
	group.plates[1].albedo_color=Color("8eaf9e") if flags[2] else Color("c8b58c")
	for i in range(20):
		var passed: bool=room.state.rail_position/room.State.RAIL_LENGTH>=float(i)/19.0
		group.rail_leds[i].albedo_color=Color("83c8b1") if passed else Color("536c77")
		group.rail_leds[i].emission=group.rail_leds[i].albedo_color
	group.cable.albedo_color=Color("80c2b4") if room.state.gate_open else Color("9f916e")
	group.upper.albedo_color=Color("83d8b4") if flags[1] else Color("c5b690")
	group.sample.position.y=move_toward(group.sample.position.y,1.36 if index==2 else 0.72,delta*0.65)
	actor.position=to_world(room.player.position,0.025)
	actor_shadow.position=to_world(room.player.position,0.032)
	var direction: Vector2=logic_to_screen(room.player.position+room.player._last_direction)-logic_to_screen(room.player.position)
	if absf(direction.x)>0.05:screen_direction.x=signf(direction.x)
	if absf(direction.y)>0.05:screen_direction.y=signf(direction.y)
	var facing: int=(0 if screen_direction.x>=0 else 1) if screen_direction.y>=0 else (2 if screen_direction.x>=0 else 3)
	paper.cast_amount=room.player._art.cast_amount
	paper.pose(room.player._walk_time,room.player.walking,facing,direction.normalized(),delta)
	display_fx.position=logic_to_screen(room.switch_fx.position)
	display_fx.active=room.switch_fx.active
	display_fx.progress=room.switch_fx.progress
	display_fx.color=room.switch_fx.color
	display_fx.queue_redraw()

func _draw() -> void:
	if themes.is_empty():return
	# Existing contextual readouts track their machine in the rotating view.
	badge(logic_to_screen(room.rail_end,3.34)+Vector2(-41,-9),"上部校准"+(" ✓" if room.state.receiver_latched else ""))
	badge(logic_to_screen(room.portal_position)+Vector2(-43,23),"归位门 · "+("开启" if room.state.gate_open else "待校准"))
	badge(logic_to_screen(room.props[1].position)+Vector2(-32,24),"%d / 3 已校准"%int(int(room.state.first_latched)+int(room.state.receiver_latched)+int(room.state.final_pressed)))
	if room._marker_time>0:
		draw_set_transform(logic_to_screen(room._marker),0,Vector2(1,0.5))
		draw_arc(Vector2.ZERO,12,0,TAU,32,Color("69a69f"),2,true)
		draw_set_transform(Vector2.ZERO)
	if room.debug_visible:
		for polygon in room.obstacle_polygons():
			var points:=PackedVector2Array()
			for point in polygon:points.append(logic_to_screen(point,0.03))
			draw_colored_polygon(points,Color(0.9,0.2,0.1,0.2))
			draw_polyline(points+PackedVector2Array([points[0]]),Color("c96945"),1.5,true)
		var center:=logic_to_screen(room.player.position)
		draw_arc(center,13,0,TAU,32,Color("e55b35"),1.6,true)

func badge(at: Vector2,text: String) -> void:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("344a55")
	style.border_color=Color("a99a75")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	draw_style_box(style,Rect2(at,Vector2(88,20)))
	draw_string(font,at+Vector2(5,14),text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("e5e6dc"))
