extends Node
var app: Node2D
var room: Node2D
var tracker: Control
var directory: String
var results: Array[Dictionary] = []
var failures := 0

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func record(title: String,passed: bool) -> void:
	results.append({"test":title,"passed":passed})
	if not passed:
		failures+=1
		push_error("TASK_CHECK_FAILED "+title)

func move_mouse(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=at
	event.global_position=at
	get_viewport().push_input(event,true)

func click(at: Vector2) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=at
		event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		get_viewport().push_input(event,true)

func snapshot(title: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(title+".png"))

func run(flow: Node2D) -> void:
	app=flow;room=app.current;tracker=room.hud.task_tracker
	room.sound.enabled=false
	directory=room.artifacts_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	move_mouse(Vector2(950,680));await frames(280)
	record("only_current_subtask_visible_at_rest",not tracker.popup.visible and tracker.current_label.text==tracker.STEPS[0] and tracker.current_step==0)
	record("main_task_black_and_current_pale_yellow",tracker.main_label.get_theme_color("font_color")==tracker.MAIN_COLOR and tracker.current_label.get_theme_color("font_color")==tracker.CURRENT_COLOR)
	await snapshot("01-main-and-current-only")
	move_mouse(tracker.current_label.get_global_rect().get_center());await frames(18)
	record("current_task_hover_lights_star_without_opening_list",not tracker.popup.visible and tracker.hovered_anchor==0 and room.orbit_view.landmarks.strengths[0]>0.99)
	await snapshot("01b-current-star-highlight")
	move_mouse(Vector2(950,680));await frames(20)
	record("leaving_task_removes_landmark_highlight",room.orbit_view.landmarks.hovered_index==-1 and room.orbit_view.landmarks.strengths[0]==0)
	room.state.rail_position=room.State.FIRST_STOP
	await frames(3)
	record("intermediate_action_does_not_advance_goal_or_reveal_solution",tracker.current_step==0 and room._hint_level==0 and not room.hud.message_label.text.contains("加重") and not room.hud.message_label.text.contains("按 2"))
	room.show_hint();room.show_hint();room.show_hint()
	record("explicit_solution_available_only_when_requesting_hints",room._hint_level==3 and room.hud.message_label.text.contains("按 2"))
	room.reset_tutorial();await frames(3)
	var main_center: Vector2=tracker.main_area.get_global_rect().get_center()
	move_mouse(main_center);await frames(12)
	record("real_mouse_hover_opens_ordered_checklist_on_right",tracker.popup.visible and tracker.popup.modulate.a>0.99 and tracker.popup.get_global_rect().position.x>tracker.get_global_rect().end.x and tracker.step_labels.size()==3)
	record("first_step_yellow_and_future_steps_gray",tracker.step_labels[0].get_theme_color("font_color")==tracker.CURRENT_COLOR and tracker.step_labels[2].get_theme_color("font_color")==tracker.FUTURE_COLOR)
	await snapshot("02-hover-initial-checklist")
	var original_world: int=room.state.world
	var original_rail: float=room.state.rail_position
	for i in range(3):
		move_mouse(tracker.step_bands[i].get_global_rect().get_center());await frames(18)
		var only_target: bool = room.orbit_view.landmarks.hovered_index==i
		for j in range(3):only_target=only_target and (room.orbit_view.landmarks.strengths[j]>0.99 if i==j else room.orbit_view.landmarks.strengths[j]<0.01)
		record("hover_task_%d_lights_only_its_landmark"%i,only_target)
		await snapshot("02-highlight-"+["star","moon","rift"][i])
	record("hover_does_not_solve_or_switch_world",room.state.world==original_world and room.state.rail_position==original_rail and not room.state.first_latched and not room.state.receiver_latched and not room.state.gate_open)
	move_mouse(main_center);await frames(3)
	var before: Vector2=room.player.position
	click(main_center);await frames(3)
	record("main_task_click_does_not_move_player",not room._pending_click and not room.player.is_navigating() and room.player.position==before)
	var bridge_point := Vector2((tracker.main_area.get_global_rect().end.x+tracker.popup.get_global_rect().position.x)*0.5,main_center.y)
	move_mouse(bridge_point);await frames(30)
	record("slow_pointer_crossing_gap_keeps_checklist_open",tracker.popup.visible)
	move_mouse(tracker.popup.get_global_rect().get_center());await frames(20)
	record("checklist_stays_open_when_pointer_moves_onto_it",tracker.popup.visible)
	room.state.first_latched=true
	room.state.rail_position=room.State.RAIL_LENGTH
	await frames(3)
	record("task_tracks_actual_puzzle_progress",tracker.current_step==1 and tracker.current_label.text==tracker.STEPS[1])
	var colors_correct := true
	for i in range(3):
		var expected: Color=tracker.DONE_COLOR if i<1 else (tracker.CURRENT_COLOR if i==1 else tracker.FUTURE_COLOR)
		colors_correct=colors_correct and tracker.step_labels[i].get_theme_color("font_color")==expected
	record("completed_green_current_yellow_future_gray",colors_correct)
	await snapshot("03-completed-current-future")
	move_mouse(Vector2(950,680));await frames(20)
	record("clicked_task_remains_pinned_for_reading",tracker.popup.visible and tracker.pinned)
	tracker.collapse();await frames(2)
	record("dismissing_pinned_task_closes_list",not tracker.popup.visible)
	await snapshot("04-current-subtask-advanced")
	room.reset_tutorial();await frames(3)
	record("reset_clears_completed_steps",tracker.current_step==0 and tracker.step_labels[1].get_theme_color("font_color")==tracker.FUTURE_COLOR and not tracker.popup.visible)
	move_mouse(main_center);await frames(12)
	room.state.first_latched=true;room.state.rail_position=room.State.RAIL_LENGTH
	room.state.receiver_latched=true;room.state.switch_world(1)
	await frames(65)
	record("open_gate_shows_return_to_bureau_as_current",room.state.gate_open and tracker.current_step==3 and tracker.step_labels[2].get_theme_color("font_color")==tracker.DONE_COLOR)
	record("rift_sealed_graphic_matches_actual_gate_state",room.orbit_view.landmarks.seal.visible and not room.orbit_view.landmarks.crack.visible)
	await snapshot("05-return-step")
	room.state.switch_world(0);await frames(3)
	record("lost_final_pressure_becomes_current_again",tracker.current_step==2 and tracker.step_labels[2].get_theme_color("font_color")==tracker.CURRENT_COLOR)
	var file := FileAccess.open(directory.path_join("task-test-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"));file.close()
	print("TASK_TEST_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	await get_tree().current_scene.shutdown_audio()
	get_tree().quit(0 if failures==0 else 1)
