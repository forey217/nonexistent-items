extends Node
var app: Node
var results: Array[Dictionary]=[]
var failures:=0
var directory:=""

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func check(title: String,passed: bool) -> void:
	results.append({"test":title,"passed":passed})
	if not passed:failures+=1;push_error("GLOBE_GUIDE_FAILED "+title)

func key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
		get_viewport().push_input(event,true)

func click(at: Vector2) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;get_viewport().push_input(event,true)

func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func finish_opening() -> void:
	while app.dialogue.modal:app.dialogue.advance()

func run(flow: Node) -> void:
	app=flow
	var args:=OS.get_cmdline_user_args()
	if not Array(args).any(func(arg):return arg.begins_with("--save-dir=")):
		push_error("Guide tests require an isolated --save-dir");get_tree().quit(1);return
	for arg in args:
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=app.save_book.directory.path_join("reports")
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(5)
	var d=app.dialogue
	if "--globe-guide-reopen" in args:
		check("fresh_process_loads_completed_guide_record",app._activate_slot(1) and d.globe_guided and d.globe_awakened)
		app.show_hub(false);await frames(130)
		check("completed_guide_never_replays_after_restart",not app.current.globe_fx.guidance_active and app.current.globe_fx.guidance_strength==0 and not app.current.globe_guide_hint.visible)
		check("other_save_keeps_unfinished_guide_independent",app._activate_slot(2) and not d.globe_guided and d.globe_awakened)
		app.show_hub(false);await frames(6)
		check("unfinished_guide_resumes_steady_without_wake_or_caption",app.current.globe_fx.guidance_active and app.current.globe_fx.resumed and app.current.globe_fx.guidance_age>4.2 and not app.current.globe_guide_hint.visible)
		await snapshot("06-reopened-steady-light");await finish();return
	check("fresh_profile_starts_without_guide_flags",app._activate_slot(1) and not d.globe_awakened and not d.globe_guided)
	app.show_hub(false);await frames(10)
	var hub=app.current;var fx=hub.globe_fx
	check("hall_keeps_original_starlight_before_conversation",not fx.guidance_active and fx.guidance_strength==0 and not hub.globe_guide_hint.visible)
	hub.player.teleport_for_reset(hub.desk_beacon.position);hub.face_tesla()
	await snapshot("00-before-opening")
	d.talk_to_tesla();await frames(40)
	check("opening_dialogue_never_starts_guidance_early",d.modal and not fx.guidance_active and fx.guidance_strength==0)
	finish_opening()
	check("last_line_releases_actor_and_schedules_wakeup",not d.modal and not hub.player.controls_locked and fx.guidance_active and fx.guidance_age<0 and d.globe_awakened)
	var chimes:=[0];fx.awakened.connect(func():chimes[0]+=1)
	await frames(12)
	check("wakeup_waits_before_first_light",fx.guidance_age<0 and fx.guidance_strength==0 and chimes[0]==0)
	await frames(24)
	check("core_lights_before_base_and_full_orbit",fx.guidance_strength>0 and fx.base_strength==0 and fx.guidance_strength>fx.orbit_strength and chimes[0]==1)
	await snapshot("01-core-awakening")
	await frames(82)
	check("wakeup_reaches_local_core_orbits_and_base",fx.guidance_strength>0.85 and fx.orbit_strength>0.85 and fx.base_strength>0.85)
	check("caption_uses_matching_serif_and_ignores_mouse",hub.globe_guide_hint.visible and hub.globe_guide_hint.text=="前往星系仪，开启观测" and hub.globe_guide_hint.mouse_filter==Control.MOUSE_FILTER_IGNORE)
	await snapshot("02-awakened-invitation")
	var origin: Vector2=hub.player.position
	Input.action_press("walk_left");await frames(12);Input.action_release("walk_left")
	check("invitation_keeps_player_movement_available",hub.player.position.distance_to(origin)>1 and not hub.player.controls_locked)
	await frames(200)
	check("caption_fades_after_three_seconds_but_light_remains",not hub.globe_guide_hint.visible and fx.guidance_strength>0.75 and chimes[0]==1)
	var strength: float=fx.guidance_strength;await frames(45)
	check("steady_breath_is_subtle_and_three_second_period",absf(fx.guidance_strength-strength)>0.01 and fx.guidance_strength>=0.79 and fx.guidance_strength<=1.0)
	await snapshot("03-steady-guidance")
	d._set_modal(true);app.open_level_menu()
	check("blocked_menu_attempt_does_not_finish_guidance",app.level_menu==null and fx.guidance_active and not d.globe_guided)
	d._set_modal(false)
	click(hub.world_to_screen(hub.globe.art.to_global(Vector2.ZERO)));await frames(3)
	check("globe_click_opens_existing_world_selection",is_instance_valid(app.level_menu) and d.globe_guided and not fx.guidance_active)
	check("successful_opening_starts_smooth_local_fade",fx.finishing and fx.guidance_strength>0 and not hub.globe_guide_hint.visible)
	await frames(40)
	check("local_light_fades_even_while_hall_is_paused",not fx.finishing and fx.guidance_strength==0 and fx.base_strength==0 and hub.process_mode==Node.PROCESS_MODE_DISABLED)
	check("completion_is_written_to_selected_save",app.save_book.inspect(1).data.story.globe_guided and app.save_book.inspect(1).data.story.globe_awakened)
	app._close_level_menu();await frames(8)
	check("closing_selector_does_not_restart_guidance",not fx.guidance_active and fx.guidance_strength==0)
	app.show_hub(false);await frames(10)
	check("returning_to_hall_does_not_replay_completed_guide",not app.current.globe_fx.guidance_active and not app.current.globe_guide_hint.visible)
	# A separate profile skips the actual opening through the UI's Esc route.
	check("second_profile_starts_independently",app._activate_slot(2) and not d.globe_awakened and not d.globe_guided)
	app.show_hub(false);await frames(8);hub=app.current;fx=hub.globe_fx
	d.talk_to_tesla();await frames(20);key(KEY_ESCAPE);await frames(3)
	check("skipping_opening_schedules_same_wakeup",not d.modal and d.segment=="after-skip" and d.globe_awakened and fx.guidance_active and fx.guidance_age<0)
	await frames(100)
	check("skip_route_reaches_same_lit_guidance",fx.guidance_strength>0.85 and hub.globe_guide_hint.visible)
	await snapshot("04-skipped-opening-guidance")
	app._save_progress(true)
	check("unfinished_guidance_is_saved_without_marking_complete",app.save_book.inspect(2).data.story.globe_awakened and not app.save_book.inspect(2).data.story.globe_guided)
	d.clear();check("reloading_profile_restores_awakened_state",app._activate_slot(2) and d.globe_awakened and not d.globe_guided)
	app.show_hub(false);await frames(6)
	check("loading_unfinished_guide_resumes_without_replaying_animation",app.current.globe_fx.resumed and app.current.globe_fx.guidance_age>4.2 and not app.current.globe_guide_hint.visible)
	# Previous saves predate the optional guide fields and must remain readable.
	var legacy: Dictionary=app.save_book.create(3);legacy.story.intro_seen=true
	app.save_book.write(3,legacy)
	check("legacy_save_remains_valid",app.save_book.valid(legacy,3) and app._activate_slot(3) and d.globe_awakened and not d.globe_guided)
	app.show_hub(false);await frames(8)
	check("legacy_seen_intro_uses_steady_light_without_replaying",app.current.globe_fx.resumed and not app.current.globe_guide_hint.visible)
	await snapshot("05-legacy-save-steady")
	check("guide_flags_must_be_boolean_when_present",not app.save_book.valid(legacy.merged({"story":{"intro_seen":true,"debrief_seen":false,"tutorial_runs":0,"globe_guided":"bad"}},true),3))
	await finish()

func finish() -> void:
	var file:=FileAccess.open(directory.path_join("globe-guide-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"));file.close()
	print("GLOBE_GUIDE_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
