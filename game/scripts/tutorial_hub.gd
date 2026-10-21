extends "res://scripts/movement_room.gd"
signal levels_requested
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

func _add_prop(key: String,title: String,at: Vector2,size: Vector2,width: float) -> void:
	if key=="chest":return
	super._add_prop(key,"星系仪" if key=="globe" else title,at,size,width)
	if key=="globe":globe=props[-1]

func _ready() -> void:
	super._ready()
	floor_art.show_rug=false
	floor_art.queue_redraw()
	globe_fx=preload("res://scripts/globe_atmosphere.gd").new()
	globe_fx.configure(globe)
	globe.add_child(globe_fx)
	hud.hide()
	_add_tesla()
	var obstacles: Array[PackedVector2Array]=[]
	for prop in props:obstacles.append(prop.global_footprint())
	obstacles.append(_npc_footprint())
	navigation=NavigationScript.new()
	navigation.configure(floor_polygon,obstacles,player.FOOT_RADIUS,Callable(self,"segment_is_clear"))
	var ui=preload("res://scripts/tutorial_hud.gd").new()
	ui.font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	var layer:=CanvasLayer.new();add_child(layer)
	var title=preload("res://scripts/map_arrival_title.gd").new()
	title.map_name="接待大厅";layer.add_child(title)
	var footer: Panel=ui.panel(layer,Vector2(22,716),Vector2(1236,65))
	ui.label(footer,"WASD / 左键移动    ·    点击星系仪：选择关卡    ·    靠近后也可按 E 观测",Vector2(18,11),16,Color("4b6371"))
	ui.label(footer,"星系仪连接着不同的平行世界。",Vector2(18,37),13,Color("8a8b80"))
	hint=ui.panel(layer,Vector2.ZERO,Vector2(175,31))
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hint_text=ui.label(hint,"星系仪 · 点击观测",Vector2(10,5),14,Color("4d737d"))
	hint.hide()
	ui.free()

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
	return is_instance_valid(arrival) and arrival.busy()

func prepare_return_arrival() -> void:
	arrival=preload("res://scripts/rift_arrival.gd").new()
	add_child(arrival);arrival.prepare(self)

func start_return_arrival() -> void:
	if not is_instance_valid(arrival):prepare_return_arrival()
	arrival.play()

func _process(_delta: float) -> void:
	return_age=arrival.age if is_instance_valid(arrival) and arrival.active else -1.0
	var over_globe: bool=globe.art.get_rect().has_point(globe.art.to_local(pointer))
	var over_npc: bool=npc_art.get_rect().has_point(npc_art.to_local(pointer))
	hint.visible=(over_globe or over_npc) and not arrival_busy()
	if over_globe:
		hint.position=globe.position+Vector2(-83,-176)
		hint_text.text="星系仪 · 点击观测"
	elif over_npc:
		hint.position=npc.position+Vector2(-75,-171)
		hint_text.text="特斯拉 · 资深观测员"
	globe.art.modulate=Color(1.09,1.09,1.03) if over_globe else Color.WHITE
	globe_fx.hovered=over_globe and not arrival_busy()
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over_globe else Input.CURSOR_ARROW)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse: pointer=event.position

func _unhandled_input(event: InputEvent) -> void:
	if arrival_busy():return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] and globe.art.get_rect().has_point(globe.art.to_local(event.position)):
			player.cancel_navigation();levels_requested.emit();get_viewport().set_input_as_handled();return
		if event.button_index==MOUSE_BUTTON_LEFT:queue_destination(event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				if player.position.distance_to(globe.position)<=115:
					player.cancel_navigation();levels_requested.emit()
			KEY_R:reset_player()
			KEY_ESCAPE:cancel_orders()
			KEY_F2:toggle_debug()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
