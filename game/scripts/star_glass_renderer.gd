extends Node2D
## All six physical petals share exactly one transparent render target.
var viewport:=SubViewport.new()
var world:=Node3D.new()
var camera:=Camera3D.new()
var output:=Sprite2D.new()

func _ready() -> void:
	viewport.size=Vector2i(1280,800)
	viewport.transparent_bg=true;viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport);viewport.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0,0,0,0)
	world.add_child(environment)
	world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=800
	camera.position=Vector3(0,0,1800);camera.far=5000;camera.current=true
	output.texture=viewport.get_texture();output.position=Vector2(640,400)
	add_child(output)

func shutdown() -> void:
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	output.hide()
