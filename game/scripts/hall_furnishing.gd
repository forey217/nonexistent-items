extends Node2D
var footprint:=PackedVector2Array()
var art:=Sprite2D.new()
var player: Node2D

func configure(texture: Texture2D,at: Vector2,shape: PackedVector2Array,width: float,actor: Node2D) -> void:
	position=at;footprint=shape;player=actor
	art.texture=texture;art.scale=Vector2.ONE*(width/texture.get_width())
	var front_y:=0.0
	for p in shape:front_y=maxf(front_y,p.y)
	art.position=Vector2(0,front_y-texture.get_height()*art.scale.y*0.5)
	add_child(art)
	var body:=StaticBody2D.new();body.collision_layer=1;body.collision_mask=2
	var collision:=CollisionPolygon2D.new();collision.polygon=shape
	body.add_child(collision);add_child(body)

func global_footprint() -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p in footprint:result.append(p+position)
	return result

func _process(delta: float) -> void:
	if not is_instance_valid(player):return
	var body:=Rect2(player.position-Vector2(21,130),Vector2(42,130))
	var picture:=Rect2(position+art.position-art.texture.get_size()*art.scale*0.5,art.texture.get_size()*art.scale)
	var obscuring:=player.position.y<position.y-8 and body.intersects(picture)
	art.modulate.a=move_toward(art.modulate.a,0.36 if obscuring else 1.0,delta*4.0)
