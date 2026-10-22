extends Node
signal completed
var room: Node2D
var player: CharacterBody2D
var visual: Node2D
var active := false
var prepared := false
var age := 0.0
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var approach_scale := 1.0

func _ready() -> void:
	process_physics_priority=-30
	set_physics_process(false)

func prepare(owner_room: Node2D) -> void:
	room=owner_room;player=room.player
	destination=room.spawn_point
	origin=destination
	for offset in [Vector2(-24,-12),Vector2(24,-12),Vector2(-20,12)]:
		var candidate: Vector2=destination+offset*approach_scale
		if room.navigation.is_safe(candidate) and room.actor_position_is_clear(candidate) and room.segment_is_clear(candidate,destination):
			origin=candidate;break
	player.teleport_for_reset(origin)
	player.controls_locked=true
	player.cinematic_motion=Vector2.ZERO
	prepared=true
	if room.get("orbit_view")!=null:
		visual=room.orbit_view.prepare_arrival_rift(origin)
	else:
		visual=preload("res://scripts/spatial_rift.gd").new()
		visual.position=origin+Vector2(0,-0.2)
		room.sort_layer.add_child(visual)
	_set_alpha(0.0)

func play() -> void:
	age=0.0;active=true
	set_physics_process(true)

func _set_alpha(value: float) -> void:
	player.modulate.a=value
	if room.get("orbit_view")!=null:
		room.orbit_view.actor.modulate.a=value
		room.orbit_view.actor.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED if value<0.999 else SpriteBase3D.ALPHA_CUT_DISCARD

func _physics_process(delta: float) -> void:
	if not active:return
	age+=delta
	visual.age=age;visual.queue_redraw()
	_set_alpha(smoothstep(0.22,0.60,age))
	player.controls_locked=true
	var offset:=destination-player.position
	player.cinematic_motion=offset.normalized()*minf(68.0,offset.length()/maxf(delta,0.001)) if age>0.25 and age<0.98 else Vector2.ZERO
	if age>=1.10:
		cancel()
		completed.emit()

func cancel() -> void:
	active=false;prepared=false
	set_physics_process(false)
	if is_instance_valid(player):
		player.cinematic_motion=Vector2.ZERO
		player.controls_locked=false
		_set_alpha(1.0)
	if is_instance_valid(visual):
		if room.get("orbit_view")!=null:room.orbit_view.finish_arrival_rift()
		else:visual.queue_free()

func busy() -> bool:
	return active or prepared
