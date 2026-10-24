extends Control
## Extends the existing town-hall paperweight exhibit language: a transparent
## real model, restrained brass arcs and live type. Only one viewport is needed.
const Model=preload("res://scripts/paper_mission_model.gd")
const Instruments=preload("res://scripts/instrument_theme.gd")
var viewport:=SubViewport.new()
var world:=Node3D.new()
var camera:=Camera3D.new()
var models:Dictionary={}
var active_model:Node3D
var active_kind:=""
var display:=TextureRect.new()
var plate:=Panel.new()
var title:Label
var description:Label
var location:Label
var close_button:=Button.new()
var next_button:=Button.new()
var locate_button:=Button.new()
signal dismissed
signal next_requested
signal locate_requested

func _ready() -> void:
	size=Vector2(264,271);mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport.size=Vector2i(528,336);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport);viewport.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0,0,0,0)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dce1cf");env.environment.ambient_light_energy=.85;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-42,-32,0);light.light_color=Color("fff0cf");light.light_energy=1.2;world.add_child(light)
	var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-28,140,0);rim.light_color=Color("b4c9bc");rim.light_energy=.45;world.add_child(rim)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.position=Vector3(2.6,2.2,3.1);world.add_child(camera);camera.look_at(Vector3(0,.2,0));camera.current=true
	display.texture=viewport.get_texture();display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.size=Vector2(264,168);display.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(display)
	plate.position=Vector2(0,161);plate.size=Vector2(264,110);plate.mouse_filter=Control.MOUSE_FILTER_STOP;plate.add_theme_stylebox_override("panel",Instruments.style(false,.88,true));add_child(plate)
	title=Instruments.label(plate,"",Vector2(12,4),Vector2(238,25),20,Instruments.COPPER_TEXT)
	description=Instruments.label(plate,"",Vector2(12,32),Vector2(240,43),16);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	location=Instruments.label(self,"",Vector2(6,0),Vector2(220,25),16,Instruments.TEXT);location.add_theme_color_override("font_outline_color",Instruments.DEEP);location.add_theme_constant_override("outline_size",3)
	for b in [close_button,next_button,locate_button]:Instruments.apply_button(b,16,true,true);add_child(b)
	close_button.text="×";close_button.position=Vector2(234,0);close_button.size=Vector2(30,28);close_button.pressed.connect(func():dismissed.emit())
	next_button.text="下一件 ›";next_button.position=Vector2(155,237);next_button.size=Vector2(96,29);next_button.pressed.connect(func():next_requested.emit())
	locate_button.text="定位实物";locate_button.position=Vector2(8,237);locate_button.size=Vector2(105,29);locate_button.pressed.connect(func():locate_requested.emit())
	hide()

func show_model(id:String,name_text:String,detail:String,where:String,manual:bool) -> void:
	if is_instance_valid(active_model):active_model.hide()
	if not models.has(id):
		var n=Model.new(id);world.add_child(n);models[id]=n
	active_model=models[id];active_model.show();active_kind=id
	var center:=Vector3(0,.25,0);camera.size=1.7
	if id=="clip":center=Vector3(0,.12,0);camera.size=.9
	elif id=="ring":center=Vector3(0,.28,0);camera.size=1.08
	elif id=="lift":center=Vector3(0,0,0);camera.size=3.55
	elif id.ends_with("pad") or id.ends_with("anchor"):center=Vector3(0,.16,0);camera.size=1.8
	camera.position=center+Vector3(2.6,2.2,3.1);camera.look_at(center)
	title.text=name_text;description.text=detail;location.text=where
	next_button.visible=manual;locate_button.visible=manual
	plate.size.y=110 if manual else 85;size.y=271 if manual else 246
	var scale_factor:=maxf(1.0,get_viewport().get_screen_transform().get_scale().x)
	viewport.size=Vector2i(264,168)*clampi(ceili(scale_factor*1.5),2,3)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	show();queue_redraw()

func refresh_frame() -> void:
	if visible:viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func suspend() -> void:
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

func _draw() -> void:
	# The model stays still; these short arcs echo the original paperweight exhibit.
	draw_set_transform(Vector2(132,147),0,Vector2(1,.24))
	for start in [.15,PI+.15]:draw_arc(Vector2.ZERO,83,start,start+2.4,44,Color(Instruments.GOLD,.60),1,true)
	draw_set_transform(Vector2.ZERO)
