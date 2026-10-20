extends Node2D
var current: Node2D
var completed_runs := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for legacy in ["--self-test","--capture","--capture-gait","--walk-demo"]:
		if legacy in args:
			current=load("res://scenes/movement_test.tscn").instantiate()
			add_child(current)
			return
	if "--hub" in args: show_hub(false)
	else: show_tutorial()
	if "--tutorial-demo" in args:
		var demo=load("res://tests/tutorial_demo.gd").new()
		add_child(demo)
		demo.run.call_deferred(self)

func clear_scene() -> void:
	if is_instance_valid(current):
		remove_child(current)
		current.queue_free()

func show_tutorial() -> void:
	clear_scene()
	current=load("res://scenes/tutorial.tscn").instantiate()
	current.completed.connect(_on_completed)
	current.hub_requested.connect(func(): show_hub.call_deferred(false))
	add_child(current)

func _on_completed() -> void:
	completed_runs+=1
	if "--tutorial-self-test" in OS.get_cmdline_user_args() or "--orbit-self-test" in OS.get_cmdline_user_args(): return
	show_hub.call_deferred(true)

func show_hub(cleared: bool) -> void:
	clear_scene()
	current=load("res://scripts/tutorial_hub.gd").new()
	current.cleared=cleared
	current.tutorial_requested.connect(func(): show_tutorial.call_deferred())
	add_child(current)
