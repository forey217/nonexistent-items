extends CanvasLayer
## Match the illustrated globe to the real hall globe, with only local starlight.
const DEPARTURE := 0.48
const ARRIVAL := 0.72
var stage := "departure"
var progress := 0.0
var motion_enabled := true
var source_menu: Node2D
var hub: Node2D
var focus_world := Vector2.ZERO
var camera_home := Vector2.ZERO
var camera_start := Vector2.ZERO
var zoom_home := Vector2.ONE
var zoom_start := Vector2.ONE
var shield := Control.new()
var painting := TextureRect.new()
var reveal_material := ShaderMaterial.new()
var ink := RouteInk.new()

func _ready() -> void:
	layer=45
	shield.size=Vector2(1280,800)
	shield.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(shield)
	painting.size=Vector2(1280,800)
	painting.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	painting.stretch_mode=TextureRect.STRETCH_SCALE
	painting.mouse_filter=Control.MOUSE_FILTER_IGNORE
	reveal_material.shader=preload("res://shaders/bureau_entry_reveal.gdshader")
	painting.material=reveal_material
	painting.hide()
	shield.add_child(painting)
	ink.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ink.size=Vector2(1280,800)
	shield.add_child(ink)

func _input(event: InputEvent) -> void:
	# Keep the shared mute and fullscreen shortcuts usable during the camera move.
	if event is InputEventKey and event.keycode not in [KEY_M,KEY_F11]:
		get_viewport().set_input_as_handled()
	elif event is InputEventMouse:
		get_viewport().set_input_as_handled()

func play(menu: Node2D,flow: Node) -> void:
	source_menu=menu
	motion_enabled=menu.motion_enabled
	ink.animated=motion_enabled
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var departure:=create_tween()
	departure.tween_method(_depart,0.0,1.0,DEPARTURE if motion_enabled else 0.18)
	await departure.finished
	# Hold the last illustrated frame while the hall is constructed and first drawn.
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		painting.texture=ImageTexture.create_from_image(get_viewport().get_texture().get_image())
		painting.show()
	var bridge_center: Vector2=source_menu._scene_point(Vector2(0.8897,0.503))
	flow.show_hub(false)
	source_menu=null
	hub=flow.current
	hub.process_mode=Node.PROCESS_MODE_DISABLED
	hub.prepare_return_arrival(1.7)
	hub.player.controls_locked=true
	hub.player.cancel_navigation()
	focus_world=hub.globe.to_global(hub.globe_fx.core)
	camera_home=hub.hall_camera.position
	zoom_home=hub.hall_camera.zoom
	zoom_start=zoom_home*1.18 if motion_enabled else zoom_home
	camera_start=focus_world-(bridge_center-Vector2(640,400))/zoom_start if motion_enabled else camera_home
	hub.hall_camera.zoom=zoom_start
	hub.hall_camera.position=camera_start
	hub.hall_camera.force_update_scroll()
	hub.movement_hint.hide()
	hub.arrival_title.hide();hub.arrival_title.set_process(false)
	flow.return_menu_button.hide()
	stage="arrival"
	_arrive(0.0)
	# New textures and shaders render underneath the held illustration.
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	var arrival:=create_tween()
	arrival.tween_method(_arrive,0.0,1.0,ARRIVAL if motion_enabled else 0.30)
	await arrival.finished
	hub.hall_camera.position=camera_home
	hub.hall_camera.zoom=zoom_home
	hub.hall_camera.force_update_scroll()
	hub.process_mode=Node.PROCESS_MODE_INHERIT
	# The existing hall-entry controller now takes over the actor's arrival.
	stage="finished"
	painting.hide()
	ink.hide()

func _depart(value: float) -> void:
	progress=value
	source_menu.set_entry_progress(value)
	ink.center=source_menu._scene_point(Vector2(0.8897,0.503))
	ink.radius=lerpf(64.0,78.0,smoothstep(0.0,1.0,value))
	ink.strength=smoothstep(0.0,0.55,value)*0.80
	ink.clock=value*DEPARTURE
	ink.queue_redraw()

func _arrive(value: float) -> void:
	progress=value
	var ease_out:=1.0-pow(1.0-value,3.0)
	hub.hall_camera.zoom=zoom_start.lerp(zoom_home,ease_out)
	hub.hall_camera.position=camera_start.lerp(camera_home,ease_out)
	hub.hall_camera.force_update_scroll()
	ink.center=hub.world_to_screen(focus_world)
	# A feathered opening grows out of the instrument; only its edge overlaps rooms.
	if motion_enabled:
		reveal_material.set_shader_parameter("reveal",value)
		reveal_material.set_shader_parameter("focus",ink.center/Vector2(1280,800))
	else:
		reveal_material.set_shader_parameter("reveal",0.0)
		reveal_material.set_shader_parameter("opacity",1.0-smoothstep(0.0,1.0,value))
	ink.radius=lerpf(78.0,62.0,ease_out) if motion_enabled else 62.0
	ink.strength=0.80*(1.0-smoothstep(0.15,1.0,value))
	ink.clock=DEPARTURE+value*ARRIVAL
	ink.queue_redraw()

class RouteInk extends Control:
	var center:=Vector2.ZERO
	var radius:=64.0
	var strength:=0.0
	var clock:=0.0
	var animated:=true
	const COLORS: Array[Color]=[Color("a3dce7"),Color("e4c58a"),Color("89b9e2")]

	func _draw() -> void:
		if strength<=0.001:return
		# The soft glints stay around the brass instrument, away from the room.
		for i in range(6,0,-1):
			draw_circle(center,radius*(0.57+i*0.07),Color(0.32,0.61,0.75,strength*0.009))
		for orbit in range(3):
			var tilt: float=[-0.42,0.65,-0.94][orbit]
			var phase: float=orbit*2.1+(clock*(2.0+orbit*0.4) if animated else 0.0)
			var points:=PackedVector2Array()
			for step in range(49):
				var angle:=step*TAU/48.0
				points.append(center+Vector2(cos(angle)*radius,sin(angle)*radius*0.40).rotated(tilt))
			draw_polyline(points,Color(COLORS[orbit],strength*0.40),1.0,true)
			if not animated:continue
			for trail in range(14):
				var angle:=phase-trail*0.035
				var at:=center+Vector2(cos(angle)*radius,sin(angle)*radius*0.40).rotated(tilt)
				draw_circle(at,1.8-trail*0.08,Color(COLORS[orbit],strength*(0.86-trail*0.05)),true,-1,true)
			var head:=center+Vector2(cos(phase)*radius,sin(phase)*radius*0.40).rotated(tilt)
			draw_line(head-Vector2(4,0),head+Vector2(4,0),Color("fff1d2")*Color(1,1,1,strength),1.0,true)
			draw_line(head-Vector2(0,5),head+Vector2(0,5),Color("fff1d2")*Color(1,1,1,strength),1.0,true)
