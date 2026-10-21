extends Node
var results: Array[Dictionary] = []

func check(title: String, passed: bool) -> void:
	results.append({"test": title, "passed": passed})
	print("MENU_CHECK ", title, " ", "PASS" if passed else "FAIL")

func run(flow: Node) -> void:
	await get_tree().process_frame
	var menu = flow.current
	check("default_boot_opens_menu", menu.has_signal("start_requested"))
	check("keyboard_focus_on_start", menu.start_button.has_focus())
	for i in range(3):
		menu.selectors[i].pressed.emit()
		check("world_preview_%d" % i, menu.world == i and menu.world_label.text.contains(menu.WORLD_NAMES[i]))
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_1
	menu._unhandled_input(event)
	check("number_key_changes_preview", menu.world == 0)
	menu.help_panel.show()
	event.keycode = KEY_ESCAPE
	menu._unhandled_input(event)
	check("escape_closes_help", not menu.help_panel.visible and menu.start_button.has_focus())
	menu.begin()
	menu.begin()
	check("start_blocks_repeat_clicks", menu.starting and menu.start_button.disabled)
	await get_tree().create_timer(0.7).timeout
	check("start_enters_tutorial", flow.current.has_signal("completed") and flow.current.state.world == 0)
	event.keycode = KEY_F10
	flow._unhandled_input(event)
	await get_tree().process_frame
	await get_tree().process_frame
	check("return_to_menu", flow.current.has_signal("start_requested"))
	flow.show_hub(false)
	check("hub_still_available", flow.current.has_signal("tutorial_requested"))
	flow.show_menu()
	check("menu_can_reopen_after_hub", flow.current.has_signal("start_requested") and not flow.current.starting)
	var failures := 0
	for result in results:
		if not result.passed: failures += 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):
			var directory := arg.trim_prefix("--artifacts=")
			DirAccess.make_dir_recursive_absolute(directory)
			var file := FileAccess.open(directory.path_join("menu-checks.json"), FileAccess.WRITE)
			file.store_string(JSON.stringify({"failures": failures, "checks": results}, "\t"))
	print("MENU_RESULT ", results.size(), " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
