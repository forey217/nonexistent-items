extends "res://scripts/movement_room.gd"
signal levels_requested
signal dialogue_requested
var cleared := false
var globe: Node2D
var npc: Node2D
var npc_art: Sprite2D
var arrival: Node
var return_age := -1.0
var hint: Panel
var hint_text: Label
var pointer := Vector2(-1000,-1000)
var globe_fx: Node2D
var architecture: Node2D
var movement_hint: Control
var hall_camera:=Camera2D.new()
var furnishings: Array[Node2D]=[]
var entry_effect: CanvasLayer
var arrival_title: Control
var desk_beacon: Node2D
var invite_tesla := false
var globe_guide_hint: Label
var globe_guidance_obscured:=false

func _add_prop(key: String,title: String,at: Vector2,size: Vector2,width: float) -> void:
	if key=="chest":return
	super._add_prop(key,"星系仪" if key=="globe" else title,at,size,width)
	if key in ["desk","globe"]:
		var prop: Node2D=props[-1]
		var texture: Texture2D=load("res://assets/interior_v30/reception_"+("desk_v2" if key=="desk" else "globe")+".png")
		var art_width:=225.0 if key=="desk" else 155.0
		prop.art.texture=texture
		prop.art.scale=Vector2.ONE*(art_width/texture.get_width())
		var front_y:=0.0
		for point in prop.footprint:front_y=maxf(front_y,point.y)
		prop.art.position=Vector2(0,front_y-texture.get_height()*prop.art.scale.y*0.5)
	if key=="globe":globe=props[-1]

func _ready() -> void:
	floor_polygon=PackedVector2Array([iso(0,0),iso(17,0),iso(17,17),iso(0,17)])
	super._ready()
	architecture=preload("res://scripts/reception_architecture.gd").new()
	architecture.hub=self
	add_child(architecture)
	floor_art.show_rug=false
	floor_art.indoor_mode=true
	floor_art.panoramic_mode=true
	floor_art.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_art.queue_redraw()
	globe_fx=preload("res://scripts/globe_atmosphere.gd").new()
	globe_fx.configure(globe)
	var core_local:=Vector2(0,-globe.art.texture.get_height()*0.12)
	globe_fx.core=globe.art.position+core_local*globe.art.scale
	globe_fx.ink.set_shader_parameter("core_center",core_local)
	globe_fx.ink.set_shader_parameter("core_radius",globe.art.texture.get_width()*0.33)
	globe.add_child(globe_fx)
	globe_fx.awakened.connect(func():get_parent().ambience.play_globe_awaken())
	hud.hide()
	_add_tesla()
	face_tesla()
	_add_furnishings()
	var obstacles: Array[PackedVector2Array]=[]
	for prop in props:obstacles.append(prop.global_footprint())
	for footprint in architecture.solid_footprints:obstacles.append(footprint)
	for furnishing in furnishings:obstacles.append(furnishing.global_footprint())
	obstacles.append(_npc_footprint())
	navigation=preload("res://scripts/hall_navigation.gd").new()
	navigation.configure(floor_polygon,obstacles,player.FOOT_RADIUS,Callable(self,"segment_is_clear"))
	desk_beacon=preload("res://scripts/hall_desk_beacon.gd").new()
	var desk: Node2D=props.filter(func(prop):return prop.name=="Desk")[0]
	for offset in [Vector2(-48,48),Vector2(-68,36),Vector2(-92,12)]:
		var candidate: Vector2=desk.position+offset
		if navigation.is_safe(candidate) and not navigation.find_path(spawn_point,candidate).is_empty():
			desk_beacon.position=candidate;break
	desk_beacon.hide()
	sort_layer.add_child(desk_beacon)
	hall_camera.position=Vector2(640,400)
	hall_camera.limit_left=-350;hall_camera.limit_right=1630
	hall_camera.limit_top=-240;hall_camera.limit_bottom=1220
	add_child(hall_camera);hall_camera.make_current();hall_camera.force_update_scroll()
	var ui=preload("res://scripts/tutorial_hud.gd").new()
	var layer:=CanvasLayer.new();add_child(layer)
	arrival_title=preload("res://scripts/map_arrival_title.gd").new()
	arrival_title.map_name="接待大厅";layer.add_child(arrival_title)
	movement_hint=preload("res://scripts/hall_movement_hint.gd").new()
	layer.add_child(movement_hint)
	hint=ui.panel(layer,Vector2.ZERO,Vector2(175,31))
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hint_text=ui.label(hint,"星系仪 · 点击观测",Vector2(10,5),14,Color("4d737d"))
	hint.hide()
	globe_guide_hint=Label.new();globe_guide_hint.text="前往星系仪，开启观测"
	globe_guide_hint.size=Vector2(320,32);globe_guide_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	globe_guide_hint.add_theme_font_override("font",preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf"))
	globe_guide_hint.add_theme_font_size_override("font_size",19)
	globe_guide_hint.add_theme_color_override("font_color",Color("294859"))
	globe_guide_hint.add_theme_color_override("font_outline_color",Color("f2dfaf"))
	globe_guide_hint.add_theme_constant_override("outline_size",3)
	globe_guide_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;globe_guide_hint.hide();layer.add_child(globe_guide_hint)
	ui.free()

func begin_globe_guidance(animated: bool=true) -> void:
	if not cleared:globe_fx.begin_guidance(animated)

func finish_globe_guidance() -> void:
	globe_guide_hint.hide();globe_fx.finish_guidance()

func obscure_globe_guidance(value: bool) -> void:
	globe_guidance_obscured=value
	if value:globe_guide_hint.hide()

func set_tesla_invitation(value: bool) -> void:
	invite_tesla=value
	if not value:desk_beacon.hide()

func _add_furnishings() -> void:
	var data: Array=[
		["waiting_sofa",iso(2.8,9.6),Vector2(3.1,1.6),235.0],
		["waiting_sofa",iso(12.6,3.1),Vector2(3.1,1.6),240.0],
		["waiting_sofa",iso(13.3,6.1),Vector2(3.1,1.6),245.0],
		["planter",iso(2.1,12.2),Vector2(0.85,0.85),105.0],
		["planter",iso(11.0,1.1),Vector2(0.85,0.85),110.0]
	]
	for item in data:
		var furnishing:=preload("res://scripts/hall_furnishing.gd").new()
		var texture: Texture2D=load("res://assets/hall_v34/"+item[0]+".png")
		furnishing.configure(texture,item[1],_footprint(item[2]),item[3],player)
		sort_layer.add_child(furnishing);furnishings.append(furnishing)

func screen_to_world(at: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse()*at

func world_to_screen(at: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform()*at

func reset_player() -> void:
	super.reset_player()
	face_tesla()
	hall_camera.position=Vector2(640,400)
	if hall_camera.is_inside_tree():hall_camera.force_update_scroll()

func face_tesla() -> void:
	if not is_instance_valid(npc):return
	player.cancel_navigation();player.walking=false
	player.face_toward(npc.global_position)

func _tick_camera(delta: float) -> void:
	var screen:=world_to_screen(player.display_position())
	var shift:=Vector2(clampf(screen.x,240,1040)-screen.x,clampf(screen.y,230,640)-screen.y)
	var desired:=hall_camera.position-shift
	desired.x=clampf(desired.x,290,990);desired.y=clampf(desired.y,160,820)
	hall_camera.position=hall_camera.position.lerp(desired,1.0-exp(-delta*8))

func _add_tesla() -> void:
	npc=Node2D.new();npc.name="Tesla";npc.position=iso(4.15,2.60)
	sort_layer.add_child(npc)
	npc_art=Sprite2D.new();npc_art.texture=preload("res://assets/npc/tesla_v01.png")
	var height: float=npc_art.texture.get_height()
	npc_art.scale=Vector2.ONE*(143.0/height)
	npc_art.offset=Vector2(0,-height*0.5)
	npc.add_child(npc_art)
	var body:=StaticBody2D.new();body.collision_layer=1;body.collision_mask=2
	var collision:=CollisionPolygon2D.new();collision.polygon=_footprint(Vector2(0.48,0.42))
	body.add_child(collision);npc.add_child(body)

func _npc_footprint() -> PackedVector2Array:
	var polygon:=PackedVector2Array()
	for point in _footprint(Vector2(0.48,0.42)):polygon.append(point+npc.position)
	return polygon

func arrival_busy() -> bool:
	return (is_instance_valid(entry_effect) and entry_effect.active) or (is_instance_valid(arrival) and arrival.busy())

func prepare_return_arrival(approach_scale := 1.0) -> void:
	arrival=preload("res://scripts/rift_arrival.gd").new()
	arrival.approach_scale=approach_scale
	add_child(arrival);arrival.prepare(self)

func start_return_arrival() -> void:
	if not is_instance_valid(arrival):prepare_return_arrival()
	arrival.play()

func _process(_delta: float) -> void:
	_tick_camera(_delta)
	desk_beacon.visible=invite_tesla and not arrival_busy()
	if not arrival_busy():
		movement_hint.offer()
		if Input.get_vector("walk_left","walk_right","walk_up","walk_down").length_squared()>0.01:movement_hint.dismiss()
	return_age=arrival.age if is_instance_valid(arrival) and arrival.active else -1.0
	var over_globe: bool=globe.art.get_rect().has_point(globe.art.to_local(screen_to_world(pointer)))
	var over_npc: bool=npc_art.get_rect().has_point(npc_art.to_local(screen_to_world(pointer)))
	hint.visible=over_globe and not arrival_busy()
	if over_globe:
		hint.position=world_to_screen(globe.position)+Vector2(-83,-208)
		hint_text.text="星系仪 · 点击观测"
	globe.art.modulate=Color(1.09,1.09,1.03) if over_globe else Color.WHITE
	globe_fx.hovered=over_globe and not arrival_busy()
	var guide_point:=world_to_screen(globe.to_global(globe_fx.core))+Vector2(-160,-112)
	globe_guide_hint.position=Vector2(clampf(guide_point.x,20,940),clampf(guide_point.y,55,700))
	globe_guide_hint.modulate.a=globe_fx.hint_opacity
	globe_guide_hint.visible=globe_fx.hint_opacity>0.001 and not globe_guidance_obscured and not arrival_busy()
	if globe_guide_hint.visible:hint.hide()
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if (over_globe or over_npc) and not arrival_busy() else Input.CURSOR_ARROW)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse: pointer=event.position
	if arrival_busy() or player.controls_locked:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT] or event.keycode in [KEY_W,KEY_A,KEY_S,KEY_D]:movement_hint.dismiss()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:movement_hint.dismiss()

func _unhandled_input(event: InputEvent) -> void:
	if arrival_busy():return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT and invite_tesla and desk_beacon.contains_point(screen_to_world(event.position)):
			queue_destination(desk_beacon.position);get_viewport().set_input_as_handled();return
		if event.button_index==MOUSE_BUTTON_LEFT and npc_art.get_rect().has_point(npc_art.to_local(screen_to_world(event.position))):
			player.cancel_navigation();dialogue_requested.emit();get_viewport().set_input_as_handled();return
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] and globe.art.get_rect().has_point(globe.art.to_local(screen_to_world(event.position))):
			player.cancel_navigation();levels_requested.emit();get_viewport().set_input_as_handled();return
		if event.button_index==MOUSE_BUTTON_LEFT:queue_destination(screen_to_world(event.position))
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				if player.position.distance_to(globe.position)<=115:
					player.cancel_navigation();levels_requested.emit()
				elif player.position.distance_to(npc.position)<=150:
					player.cancel_navigation();dialogue_requested.emit();get_viewport().set_input_as_handled()
			KEY_R:reset_player()
			KEY_ESCAPE:cancel_orders()
			KEY_F2:toggle_debug()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
