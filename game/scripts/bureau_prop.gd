extends Node2D

var footprint := PackedVector2Array()
var prop_name := ""
var art := Sprite2D.new()

func configure(key: String, title: String, center: Vector2, shape: PackedVector2Array, visual_width: float) -> void:
	name = key.capitalize()
	prop_name = title
	position = center
	footprint = shape
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprite_layout.json"))
	var region: Array = metadata["props"][key]["region"]
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/bureau_props_v02.png")
	texture.region = Rect2(region[0], region[1], region[2], region[3])
	texture.filter_clip = true
	art.texture = texture
	var factor := visual_width / float(region[2])
	art.scale = Vector2.ONE * factor
	var front_y := 0.0
	for point in shape:
		front_y = maxf(front_y, point.y)
	art.position = Vector2(0.0, front_y - float(region[3]) * factor * 0.5)
	add_child(art)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionPolygon2D.new()
	collision.polygon = shape
	body.add_child(collision)
	add_child(body)
	queue_redraw()

func _draw() -> void:
	var shadow := PackedVector2Array()
	for point in footprint:
		shadow.append(point + Vector2(0, 5))
	if shadow.size() > 2:
		draw_colored_polygon(shadow, Color(0.12, 0.12, 0.15, 0.16))

func global_footprint() -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in footprint:
		result.append(point + position)
	return result
