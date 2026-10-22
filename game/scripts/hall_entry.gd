extends CanvasLayer
## Reveal the room before handing movement and conversation to the player.
signal finished
var room: Node2D
var active := false
var age := 0.0
var duration := 3.4
var first_visit := true
var rift_started := false
var caption_started := false
var room_revealed := false
var veil := ColorRect.new()

func _ready() -> void:
	layer=45
	# Run after the rift controller, before the actor, to hold the settling beat.
	process_physics_priority=-25
	veil.size=Vector2(1280,800)
	veil.color=Color("102632")
	veil.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(veil)
	set_physics_process(false)

func begin(hub: Node2D,first: bool,revealed := false) -> void:
	room=hub;first_visit=first
	room_revealed=revealed
	duration=3.4 if first else 1.55
	if revealed:
		duration=1.65 if first else 1.2
		veil.modulate.a=0.0
	room.dialogue_footer.hide()
	room.arrival_title.hide();room.arrival_title.set_process(false)
	if not is_instance_valid(room.arrival):room.prepare_return_arrival(1.7)
	active=true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not active:return
	age+=delta
	veil.modulate.a=0.0 if room_revealed else 1.0-smoothstep(0.0,1.1 if first_visit else 0.5,age)
	if not caption_started and age>=(0.0 if room_revealed else (0.55 if first_visit else 0.15)):
		caption_started=true
		room.arrival_title.age=0.0 if first_visit else 2.8
		room.arrival_title.show();room.arrival_title.set_process(true)
	if not rift_started and age>=(0.0 if room_revealed else (0.7 if first_visit else 0.15)):
		rift_started=true
		room.start_return_arrival()
		get_parent().ambience.play_world_gate("fold")
	room.player.controls_locked=true
	if age>=duration and not room.arrival.busy():
		room.player.cinematic_motion=Vector2.ZERO
		room.player.controls_locked=false
		room.face_tesla()
		room.dialogue_footer.show()
		active=false
		veil.hide();set_physics_process(false)
		finished.emit()
