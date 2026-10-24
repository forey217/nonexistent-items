extends Node
## Visual-only environment leaves share the live world; no duplicate simulation.
const COMMON:=1
const FLOOR_BITS:=[1<<8,1<<9]
const OLD_BIT:=1<<10
const NEW_BIT:=1<<11
const DURATION:=.55
const ALIGN_TIME:=.22
var view:Node
var active:=false
var layer_index:=0
var from_world:=0
var to_world:=0
var age:=0.0
var progress:=0.0
var alignment:=0.0
var sources:Array[Array]=[[],[]]
var copies:Array[Array]=[[],[]]
var containers:Array[Node3D]=[]
var old_view:=SubViewport.new()
var new_view:=SubViewport.new()
var old_camera:=Camera3D.new()
var new_camera:=Camera3D.new()
var material:=ShaderMaterial.new()
var variants:Dictionary={}
var creations:=0

func _ready() -> void:
	for pair in [[old_view,old_camera],[new_view,new_camera]]:
		var target:SubViewport=pair[0];var cam:Camera3D=pair[1]
		target.world_3d=view.world_root.get_world_3d();target.msaa_3d=Viewport.MSAA_4X
		target.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(target);target.add_child(cam);cam.current=true
	for i in range(2):
		var holder:=Node3D.new();holder.name="EnvironmentFilm%d"%i;view.world_root.add_child(holder);holder.hide();containers.append(holder)
	material.shader=preload("res://shaders/paper_world_film.gdshader")
	material.set_shader_parameter("old_film",old_view.get_texture());material.set_shader_parameter("new_film",new_view.get_texture())
	material.set_shader_parameter("actor_mask",view.paper_viewport.get_texture())
	view.camera.cull_mask=COMMON|FLOOR_BITS[0]|FLOOR_BITS[1]

func register_environment(root:Node,layer:int) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			child.layers=FLOOR_BITS[layer];sources[layer].append(child)
		register_environment(child,layer)

func _prepare(layer:int) -> void:
	if not copies[layer].is_empty():return
	for source:MeshInstance3D in sources[layer]:
		var pair:Array=[]
		for bit in [OLD_BIT,NEW_BIT]:
			var mesh:=MeshInstance3D.new();mesh.mesh=source.mesh;mesh.layers=bit
			mesh.material_override=source.material_override;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			containers[layer].add_child(mesh);pair.append(mesh);creations+=1
		copies[layer].append({"source":source,"old":pair[0],"new":pair[1]})

func begin(layer:int,source_world:int,destination:int) -> void:
	cancel();layer_index=layer;from_world=source_world;to_world=destination;age=0;progress=0;alignment=0
	_prepare(layer);active=true;containers[layer].show()
	for item:Dictionary in copies[layer]:
		for entry in [[item.old,source_world],[item.new,destination]]:
			var source:Material=item.source.material_override
			if source==view.layer_stone[layer] or source==view.rails[layer]:
				var key:=str(source.get_instance_id())+":"+str(entry[1])
				if not variants.has(key):
					var copy:StandardMaterial3D=source.duplicate()
					copy.albedo_color=view.STONE_COLORS[entry[1]] if source==view.layer_stone[layer] else view.RAIL_COLORS[entry[1]]
					variants[key]=copy
				entry[0].material_override=variants[key]
			else:entry[0].material_override=source
	old_camera.cull_mask=COMMON|FLOOR_BITS[1-layer]|OLD_BIT
	new_camera.cull_mask=COMMON|FLOOR_BITS[1-layer]|NEW_BIT
	old_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;new_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.output.material=material
	sync(0)

func _visible(source:Node3D,world:int) -> bool:
	var node:Node=source
	while node!=view.world_root:
		if node==view.bridge:
			if not (world==3 or view.room.state.clip_target=="bridge" or view.room.state.upper_anchored):return false
		elif node==view.side_bridge:
			if world!=3:return false
		elif node is Node3D and not node.visible:return false
		node=node.get_parent()
	return true

func _screen_shift(pixels:Vector2) -> Vector3:
	var anchor:Vector3=view.camera.global_position-view.camera.global_basis.z*20
	var center:Vector2=view.camera.unproject_position(anchor)
	return view.camera.project_position(center+view.to_render(pixels),20)-anchor

func sync(delta:float) -> void:
	if not active:return
	if view.room.finished:cancel();return
	if view.room.hud.menu.visible:
		old_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;new_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	old_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;new_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	# A shader's first-use stall must not swallow the whole visible transition.
	age+=minf(.05,delta/maxf(Engine.time_scale,.01))
	progress=clampf(age/DURATION,0,1);alignment=clampf(age/ALIGN_TIME,0,1)
	if progress>=1:cancel();return
	for pair in [[old_view,old_camera],[new_view,new_camera]]:
		pair[0].size=view.viewport.size
		pair[1].projection=view.camera.projection;pair[1].keep_aspect=view.camera.keep_aspect
		pair[1].size=view.camera.size;pair[1].global_transform=view.camera.global_transform
	var old_shift:=_screen_shift(Vector2(-8,4)*sin(alignment*PI))
	var new_shift:=_screen_shift(Vector2(18,-9)*(1-smoothstep(0,1,alignment)))
	for item:Dictionary in copies[layer_index]:
		item.old.global_transform=item.source.global_transform;item.new.global_transform=item.source.global_transform
		item.old.global_position+=old_shift;item.new.global_position+=new_shift
		item.old.visible=_visible(item.source,from_world);item.new.visible=_visible(item.source,to_world)
	material.set_shader_parameter("phase",progress)
	# Fixed-Y billboard projects a vertical world-space quad, including transparent padding.
	var extent:Vector2=Vector2(view.paper_viewport.size)*view.actor.pixel_size
	var center:Vector3=view.actor.global_position+Vector3.UP*view.actor.offset.y*view.actor.pixel_size
	var right:Vector3=view.camera.global_basis.x*extent.x*.5;var up:=Vector3.UP*extent.y*.5
	var lo:=Vector2(INF,INF);var hi:=Vector2(-INF,-INF)
	for point in [center-right-up,center+right-up,center-right+up,center+right+up]:
		var at:Vector2=view.camera.unproject_position(point);lo=lo.min(at);hi=hi.max(at)
	var actor_rect:=Vector4(lo.x/view.viewport.size.x,lo.y/view.viewport.size.y,(hi.x-lo.x)/view.viewport.size.x,(hi.y-lo.y)/view.viewport.size.y)
	material.set_shader_parameter("actor_rect",actor_rect)
	if view.switch_fx.material!=null:view.switch_fx.material.set_shader_parameter("actor_rect",actor_rect)
	material.set_shader_parameter("actor_visible",view.actor.visible)

func cancel() -> void:
	active=false;age=0;progress=0;alignment=0
	view.switch_fx.cancel()
	if is_instance_valid(view.output):view.output.material=null
	old_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;new_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	for holder in containers:holder.hide()
