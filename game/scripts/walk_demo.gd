extends Node2D
## Developer gallery rendered by the same rig used in the playable scene.
var actors: Array[Node2D] = []
var elapsed := 0.0
var distance := 0.0

func _ready() -> void:
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2.ZERO,Vector2(1280,0),Vector2(1280,800),Vector2(0,800)])
	backdrop.color = Color("eee9df")
	add_child(backdrop)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","Arial"])
	for text_and_position in [["衍月 · 连续步态预览 v0.3",Vector2(50,35)],["约 1.6 步/秒  /  小幅迈步  /  四向肩部与遮挡校准",Vector2(50,90)]]:
		var label := Label.new()
		label.text = text_and_position[0]
		label.position = text_and_position[1]
		label.add_theme_font_override("font",font)
		label.add_theme_font_size_override("font_size",24)
		label.add_theme_color_override("font_color",Color("334954"))
		add_child(label)
	for row in range(4):
		var holder := Node2D.new()
		holder.position = Vector2(210+row*285,540)
		holder.scale = Vector2.ONE*2.4
		add_child(holder)
		var actor = preload("res://scripts/yanyue_walk_rig.gd").new()
		holder.add_child(actor)
		actors.append(actor)
		var caption := Label.new()
		caption.text = ["右前","左前","右后","左后"][row]
		caption.position = Vector2(180+row*285,610)
		caption.add_theme_font_override("font",font)
		caption.add_theme_font_size_override("font_size",22)
		caption.add_theme_color_override("font_color",Color("334954"))
		add_child(caption)
	var help := Label.new()
	help.text = "循环展示：行走 4 秒 → 停步 1 秒       Esc 返回移动测试"
	help.position = Vector2(255,720)
	help.add_theme_font_override("font",font)
	help.add_theme_font_size_override("font_size",20)
	help.add_theme_color_override("font_color",Color("61737a"))
	add_child(help)

func _process(delta: float) -> void:
	elapsed += delta
	var walking := fposmod(elapsed,5.0)<4.0
	if walking: distance += 145.0*delta
	for row in range(4):
		actors[row].pose(distance,walking,row,Vector2(1,0.3),delta)
	if Input.is_physical_key_pressed(KEY_ESCAPE):
		get_tree().reload_current_scene()
