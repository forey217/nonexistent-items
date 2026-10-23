extends Node3D
## Two depth-tested portal passes; inactive viewports stop rendering completely.
var pixel_density := 65.05382387
var height_compensation := 1.154700538
var rear_viewport: SubViewport
var front_viewport: SubViewport
var rear_sprite: Sprite3D
var front_sprite: Sprite3D
var rear_ink: Node2D
var front_ink: Node2D
var active := false

func _ready() -> void:
	var rear:=_make_pass("rear")
	rear_viewport=rear.viewport;rear_sprite=rear.sprite;rear_ink=rear.ink
	var front:=_make_pass("front")
	front_viewport=front.viewport;front_sprite=front.sprite;front_ink=front.ink
	rear_ink.linked_pass=front_ink
	stop()

func _make_pass(kind: String) -> Dictionary:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(640,640)
	viewport.transparent_bg=true;viewport.disable_3d=true
	add_child(viewport)
	var ink:=preload("res://scripts/spatial_rift.gd").new()
	ink.render_pass=kind;ink.position=Vector2(320,536);ink.scale=Vector2.ONE*2
	viewport.add_child(ink)
	var sprite:=Sprite3D.new()
	sprite.texture=viewport.get_texture();sprite.pixel_size=0.5/pixel_density
	sprite.offset=Vector2(0,216)
	sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.scale.y=height_compensation
	# Alpha blending keeps the faint floor reflection soft instead of cutting it to black.
	sprite.shaded=false;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
	# Draw translucent gate passes before the translucent actor. Their feet are at
	# different heights on outdoor floors, so distance sorting alone is ambiguous.
	sprite.render_priority=-10 if kind=="rear" else -9
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.layers=1<<3
	add_child(sprite)
	return {"viewport":viewport,"sprite":sprite,"ink":ink}

func begin(at: Vector3,toward_camera: Vector3) -> Node2D:
	position=at
	var normal:=Vector3(toward_camera.x,0,toward_camera.z).normalized()
	rear_sprite.position=-normal*0.018
	front_sprite.position=normal*0.045
	rear_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	front_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	rear_sprite.show();front_sprite.show()
	rear_ink.age=0.0;active=true
	return rear_ink

func stop() -> void:
	active=false
	if is_instance_valid(rear_sprite):rear_sprite.hide()
	if is_instance_valid(front_sprite):front_sprite.hide()
	if is_instance_valid(rear_viewport):rear_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if is_instance_valid(front_viewport):front_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
