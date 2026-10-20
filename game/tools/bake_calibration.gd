extends SceneTree
## Offline sprite baking and the live orbit view use the same model builder.
const OUT:="res://assets/calibration_v03/"
const PIXELS:=65.05382387
var viewport: SubViewport
var scene: Node3D
var theme:=0
var builder=preload("res://scripts/calibration_scene_builder.gd").new()

func _initialize() -> void:
	call_deferred("run")

func setup(size: Vector2i, origin: Vector2) -> void:
	viewport=SubViewport.new()
	viewport.size=size*2
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene=Node3D.new()
	viewport.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(0,0,0,0)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("d6e1e8")
	env.environment.ambient_light_energy=0.42
	env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	scene.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-58,-38,0)
	light.light_color=Color("fff1d4")
	light.light_energy=0.72
	light.shadow_enabled=true
	light.directional_shadow_max_distance=45
	light.shadow_bias=0.035
	scene.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-20,140,0)
	fill.light_color=Color("c7d8ed")
	fill.light_energy=0.15
	scene.add_child(fill)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.size=float(size.y)/PIXELS
	camera.position=Vector3(16,16*sqrt(2.0/3.0),16)
	camera.look_at(Vector3.ZERO)
	# Shift the camera plane, preserving the exact gameplay isometric projection.
	var dx: float=(float(size.x)*0.5-origin.x)/PIXELS
	var dy: float=(origin.y-float(size.y)*0.5)/PIXELS
	camera.position+=camera.basis.x*dx+camera.basis.y*dy
	camera.current=true
	builder.configure(theme,scene)

func save(name: String) -> void:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	var result:=viewport.get_texture().get_image()
	# High-resolution source preserved: Sprite2D scales it by one half.
	var error:=result.save_png(OUT+name+".png")
	print(name," ",result.get_size()," ",error)
	viewport.queue_free()
	await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for i in range(3):
		theme=i
		setup(Vector2i(1280,800),Vector2(535,222))
		builder.room_base()
		await save("room-"+str(i))
		setup(Vector2i(256,256),Vector2(128,205))
		builder.model("gate",Vector3.ZERO,Vector3.ONE*0.42,PI*0.25)
		await save("gate-"+str(i))
		setup(Vector2i(256,300),Vector2(128,230))
		builder.receiver()
		await save("receiver-"+str(i))
		setup(Vector2i(128,128),Vector2(64,85))
		builder.weight()
		await save("weight-"+str(i))
		setup(Vector2i(256,256),Vector2(128,205))
		builder.cabinet()
		await save("cabinet-"+str(i))
		setup(Vector2i(256,256),Vector2(128,205))
		builder.console_desk()
		await save("console-"+str(i))
	quit(0)
