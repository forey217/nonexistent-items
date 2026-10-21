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
	elif "--tutorial" in args or "--tutorial-self-test" in args or "--orbit-self-test" in args or "--tutorial-demo" in args: show_tutorial()
	else: show_menu()
	if "--menu-self-test" in args:
		var checks = load("res://tests/menu_tests.gd").new()
		add_child(checks)
		checks.run.call_deferred(self)
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

func show_menu() -> void:
	clear_scene()
	current = load("res://scenes/start_menu.tscn").instantiate()
	current.start_requested.connect(func(): show_tutorial.call_deferred())
	add_child(current)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		if not current.has_signal("start_requested"):
			show_menu.call_deferred()

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
