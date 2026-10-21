extends Node
## Two live environment films; the existing main render keeps the actor crisp.
const COMMON_LAYER := 1 << 3
const ACTOR_LAYER := 1 << 4
var view: Node2D
var active := false
var from_world := 0
var to_world := 0
var progress := 0.0
var alignment := 0.0
var old_view := SubViewport.new()
var new_view := SubViewport.new()
var old_camera := Camera3D.new()
var new_camera := Camera3D.new()
var material := ShaderMaterial.new()

func _ready() -> void:
	for pair in [[old_view,old_camera],[new_view,new_camera]]:
		var target: SubViewport=pair[0]
		var cam: Camera3D=pair[1]
		target.size=Vector2i(1280,800)
		target.transparent_bg=true
		target.world_3d=view.world_root.get_world_3d()
		target.msaa_3d=Viewport.MSAA_4X
		target.render_target_update_mode=SubViewport.UPDATE_DISABLED
		add_child(target)
		target.add_child(cam)
		cam.current=true
	material.shader=preload("res://shaders/world_film.gdshader")
	material.set_shader_parameter("old_film",old_view.get_texture())
	material.set_shader_parameter("new_film",new_view.get_texture())
	material.set_shader_parameter("actor_mask",view.paper_viewport.get_texture())

func begin(source: int,destination: int) -> void:
	from_world=source
	to_world=destination
	progress=0.0
	alignment=0.0
	active=true
	old_camera.cull_mask=(1<<from_world)|COMMON_LAYER
	new_camera.cull_mask=(1<<to_world)|COMMON_LAYER
	old_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	new_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.output.material=material
	sync()

func sync() -> void:
	if not active:return
	if not view.room.casting or view.room.finished:
		cancel()
		return
	progress=clampf(view.room.cast_age/view.room.CAST_DURATION,0.0,1.0)
	alignment=clampf(view.room.cast_age/view.room.CAST_COMMIT,0.0,1.0)
	for cam in [old_camera,new_camera]:
		cam.projection=view.camera.projection
		cam.keep_aspect=view.camera.keep_aspect
		cam.size=view.camera.size
		cam.global_transform=view.camera.global_transform
	material.set_shader_parameter("phase",progress)
	material.set_shader_parameter("alignment",alignment)
	# Fixed-Y billboard: a 512x640 texture maps to a 256x320 screen rectangle.
	# Its transparent padding is retained, so only the actual actor silhouette is kept.
	var texture_size := Vector2(view.paper_viewport.size)
	var dimensions: Vector2=texture_size*view.actor.pixel_size*view.PIXELS
	var foot: Vector2=view.logic_to_screen(view.room.player.position,view.ACTOR_GROUND_HEIGHT)
	var center: Vector2=foot-Vector2(view.actor.offset.x,view.actor.offset.y)*view.actor.pixel_size*view.PIXELS
	var rect := Rect2(center-dimensions*0.5,dimensions)
	material.set_shader_parameter("actor_rect",Vector4(rect.position.x/1280.0,rect.position.y/800.0,rect.size.x/1280.0,rect.size.y/800.0))

func cancel() -> void:
	active=false
	progress=0.0
	alignment=0.0
	view.output.material=null
	old_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	new_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	view.camera.cull_mask=(1<<view.room.state.world)|COMMON_LAYER|ACTOR_LAYER
