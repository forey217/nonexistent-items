extends Control
## Reuse the playable paperweight geometry, rather than a different illustration.
const Builder = preload("res://scripts/calibration_scene_builder.gd")
const FONT = preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf")
var viewport := SubViewport.new()
var model := Node3D.new()
var active_item := ""
var age := 0.0
var display := TextureRect.new()
var title := Label.new()
var description := Label.new()

func _ready() -> void:
	position=Vector2(410,95);size=Vector2(460,435)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport.size=Vector2i(460,330)
	viewport.transparent_bg=true;viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var world:=Node3D.new();viewport.add_child(world)
	world.add_child(model)
	var builder:=Builder.new();builder.configure(0,model);builder.weight()
	model.position.y=-0.19
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0,0,0,0)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("dbe9ef")
	environment.environment.ambient_light_energy=0.85
	world.add_child(environment)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-38,-28,0)
	key.light_color=Color("fff1d2");key.light_energy=1.5;world.add_child(key)
	var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-24,145,0)
	rim.light_color=Color("a5d7ee");rim.light_energy=0.75;world.add_child(rim)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.12;camera.position=Vector3(1.35,1.05,1.65)
	world.add_child(camera);camera.look_at(Vector3.ZERO,Vector3.UP);camera.current=true
	display.texture=viewport.get_texture();display.position=Vector2(0,25);display.size=Vector2(460,330)
	display.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(display)
	for label in [title,description]:
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color",Color("182c3a"))
		label.add_theme_constant_override("outline_size",5)
		add_child(label)
	title.text="镇纸";title.position=Vector2(30,337);title.size=Vector2(400,44)
	title.add_theme_font_override("font",FONT);title.add_theme_font_size_override("font_size",32)
	title.add_theme_color_override("font_color",Color("f7e8c3"))
	description.text="用于锚定重叠的平行世界"
	description.position=Vector2(20,389);description.size=Vector2(420,29)
	var body_font:=SystemFont.new();body_font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	description.add_theme_font_override("font",body_font);description.add_theme_font_size_override("font_size",18)
	description.add_theme_color_override("font_color",Color("f2f4ed"))
	hide_item()

func show_item(id: String) -> void:
	if id!="paperweight":hide_item();return
	if active_item==id:return
	active_item=id;age=0;modulate.a=0
	pivot_offset=size*0.5;scale=Vector2.ONE*0.94
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	show();set_process(true)

func hide_item() -> void:
	active_item="";age=0;hide();set_process(false)
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

func _process(delta: float) -> void:
	age+=delta
	var entrance:=1.0-pow(1.0-clampf(age/0.48,0.0,1.0),3.0)
	modulate.a=entrance;scale=Vector2.ONE*lerpf(0.94,1.0,entrance)
	position.y=95+(1.0-entrance)*20
	model.position.y=-0.19+sin(age*1.35)*0.011
	model.rotation.y=sin(age*0.42)*0.13
	queue_redraw()

func _draw() -> void:
	var center:=Vector2(230,190)
	for i in range(14,0,-1):
		draw_circle(center,36+i*9,Color(0.58,0.82,0.91,0.012))
	draw_set_transform(Vector2(230,283),0,Vector2(1,0.27))
	draw_arc(Vector2.ZERO,131,0,TAU,100,Color(0.77,0.68,0.47,0.65),1.5,true)
	draw_arc(Vector2.ZERO,148,0.3,2.55,50,Color(0.62,0.83,0.90,0.6),1,true)
	draw_arc(Vector2.ZERO,148,3.45,5.70,50,Color(0.62,0.83,0.90,0.6),1,true)
	draw_set_transform(Vector2.ZERO)
	for side in [-1,1]:
		draw_line(Vector2(230+side*64,361),Vector2(230+side*125,361),Color("baa16a"),1,true)
