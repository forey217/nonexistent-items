extends Control
## An arrival caption, independent of puzzle resets and world changes.
const TITLE_FONT = preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf")
const DURATION := 4.4
var map_name := "新手校准室"
var age := 0.0
var caption: Label

func _ready() -> void:
	position = Vector2(360,24)
	size = Vector2(560,100)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bureau := Label.new()
	bureau.text = "世 界 观 察 局"
	bureau.position = Vector2(0,0)
	bureau.size = Vector2(560,22)
	bureau.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bureau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bureau.add_theme_font_override("font",TITLE_FONT)
	bureau.add_theme_font_size_override("font_size",18)
	bureau.add_theme_color_override("font_color",Color("8b7756"))
	add_child(bureau)
	caption = Label.new()
	caption.text = map_name
	caption.position = Vector2(0,24)
	caption.size = Vector2(560,57)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_override("font",TITLE_FONT)
	caption.add_theme_font_size_override("font_size",42)
	caption.add_theme_color_override("font_color",Color("344e5b"))
	caption.add_theme_color_override("font_outline_color",Color("faf6e9"))
	caption.add_theme_constant_override("outline_size",5)
	add_child(caption)
	_update_opacity()

func _process(delta: float) -> void:
	age += delta
	_update_opacity()
	if age >= DURATION:
		hide()
		set_process(false)

func _update_opacity() -> void:
	var fade_in := smoothstep(0.0,0.55,age)
	var fade_out := 1.0-smoothstep(2.0,DURATION,age)
	modulate.a = fade_in*fade_out
	position.y = 24.0-6.0*smoothstep(2.0,DURATION,age)

func _draw() -> void:
	var gold := Color("b19a70")
	for side in [-1,1]:
		var center: Vector2 = Vector2(280+side*101,13)
		draw_line(center+Vector2(side*12,0),center+Vector2(side*77,0),gold,1.0,true)
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-3),center+Vector2(3,0),center+Vector2(0,3),center+Vector2(-3,0)]),gold)
	draw_line(Vector2(235,91),Vector2(265,91),gold,1.0,true)
	draw_line(Vector2(295,91),Vector2(325,91),gold,1.0,true)
	draw_arc(Vector2(280,91),5,-PI*0.7,PI*0.7,24,gold,1.2,true)
