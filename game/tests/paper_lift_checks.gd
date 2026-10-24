extends Node
const State=preload("res://scripts/paper_mill_state.gd")
var app:Node
var room:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition:Callable,limit:=700) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func check(title:String,passed:bool) -> void:
	results.append({"test":title,"passed":passed});print("PAPER_LIFT ",title," ",passed)
	if not passed:failures+=1;push_error("PAPER_LIFT_FAILED "+title)
	var file:=FileAccess.open(directory.path_join("lift-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results,"native_render":DisplayServer.get_name()!="headless"},"\t"))

func simulate(s:RefCounted,seconds:float) -> void:
	for i in range(ceili(seconds*120)):s.step(1.0/120.0)

func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func key(code:int) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down
		get_viewport().push_input(event,true)

func state_checks() -> void:
	for index in range(2):
		var s=State.new();var w:Dictionary=s.weights[index]
		w.station="junction";w.pos=s.stops(index).junction;w.layer=1
		var target:Vector2=s.stops(index)["lift" if index==0 else "guide_turn"]
		s.push_direction(index,target-w.pos)
		check("weight_%d_slide_starts_on_real_edge"%index,w.mode=="slide")
		var unchanged:bool=true
		for layer in range(2):
			for world in [1,2,3]:unchanged=not s.switch_world(layer,world) and unchanged
		check("weight_%d_slide_blocks_every_world_on_both_floors"%index,unchanged and s.worlds==[0,0])
		simulate(s,3)
		check("weight_%d_reaches_stop_and_unlocks_worlds"%index,w.mode=="rest" and w.pos==target and s.switch_world(0,2))
	var s=State.new()
	s.weights[1]=s.make_weight("water",1,s.SLUICE,"sluice");s.worlds[1]=1
	simulate(s,5)
	check("empty_lift_rises_before_any_quest_stage",s.lift_docked(0) and s.checkpoint==0 and not s.lifted_once and s.weights[0].station=="hatch")
	s.switch_world(1,0);simulate(s,4)
	check("empty_lift_returns_when_waterwheel_stops",s.lift_docked(1) and not s.waterwheel_running())
	s.weights[0]=s.make_weight("mountain",1,s.LIFT,"lift");s.worlds[0]=2;s.switch_world(1,1)
	simulate(s,5)
	check("loaded_lift_arrival_assigns_upper_rail_even_if_upper_is_inverted",s.weights[0].layer==0 and s.lifted_once and s.destinations(0)==["dock"])
	s.switch_world(0,0);simulate(s,1.0) # Cargo must physically settle after inverted arrival.
	s.push_direction(0,Vector2.DOWN);s.step(.1)
	var height:float=s.weight_height(0)
	check("departing_cargo_uses_upper_height_and_locks_early_inverted",not s.switch_world(0,2) and s.weights[0].mode=="slide" and absf(height-State.HEIGHT-.18)<.001)
	simulate(s,1)
	check("upper_cargo_reaches_dock_before_world_can_change",s.weights[0].station=="dock" and s.weights[0].layer==0 and s.switch_world(0,2))
	var bad=State.new();bad.weights[0]=bad.make_weight("mountain",1,bad.MOUNTAIN_STOPS.lift_turn,"lift_turn");bad.lift_height=State.HEIGHT
	check("lower_rail_cannot_load_an_absent_platform",not bad.push_error(0,Vector2.UP).is_empty())
	var legacy:Dictionary=s.snapshot();legacy.weights[0]={"layer":1,"pos":[18,7],"station":"lift","elevation":0.0};legacy.lift_height=State.HEIGHT
	bad.restore(legacy)
	check("legacy_raised_lift_restores_upper_cargo_membership",bad.weights[0].layer==0 and bad.destinations(0)==["dock"])

func fixture(loaded:=false) -> void:
	var data:Dictionary=State.new().snapshot()
	data.weights[1]={"layer":1,"pos":[18,4],"station":"sluice","elevation":0.0};data.cage_open=true
	if loaded:
		data.weights[0]={"layer":1,"pos":[18,7],"station":"lift","elevation":0.0};data.hatch_broken=true;data.support_released=true;data.checkpoint=3
	room.restore({"state":data,"player_layer":1,"player":[18.85,8.8]});room.communications.enabled=false
	room.hud.message_time=0;room.hud.saved_time=0;room.view.return_to_actor()

func run(flow:Node) -> void:
	app=flow
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if directory.is_empty():directory=ProjectSettings.globalize_path("user://paper-lift-checks")
	DirAccess.make_dir_recursive_absolute(directory);state_checks()
	app.show_paper_mill();room=app.current;room.communications.enabled=false;await frames(3)
	fixture();await frames(3)
	check("lower_platform_can_be_boarded_while_upper_opening_stays_blocked",room.is_walkable(Vector2(18.85,7.5),1) and not room.is_walkable(Vector2(18.85,7.5),0))
	check("actual_navigation_boards_empty_platform",room.walk_to(Vector2(18.85,7.5)) and await until(func():return not room.player.is_navigating() and room.lift_riding))
	var plan:Vector2=room.player_plan();var stable:Dictionary=room.stable_snapshot()
	check("waterwheel_can_start_before_cargo_arrives",room.change_world(1,1));await frames(100)
	check("passenger_height_follows_moving_platform",room.lift_riding and room.player.controls_locked and absf(room.actor_height()-room.state.lift_height-.16)<.001 and room.state.lift_in_transit())
	await frames(2)
	check("lift_passenger_visible_through_upper_floor_cutaway",room.view.actor.visible and not room.view.roots[0].visible)
	Input.action_press("walk_right");await frames(8);Input.action_release("walk_right")
	check("passenger_cannot_walk_out_into_open_shaft_midflight",room.player_plan().distance_to(plan)<.001 and not room.walk_to(Vector2(20,7)))
	check("autosave_keeps_previous_safe_floor_during_lift",room.stable_snapshot().state.lift_height==stable.state.lift_height)
	await shot("01-empty-lift-passenger-midway")
	check("passenger_arrives_on_upper_floor_without_quest_progress",await until(func():return room.player_layer==0 and room.state.lift_docked(0)) and room.state.checkpoint==0 and not room.state.lifted_once and room.view_layer==0 and not room.player.controls_locked)
	await frames(30);await shot("02-empty-lift-upper-arrival")
	check("upper_arrival_navigation_can_disembark",room.walk_to(Vector2(19.8,8.8)) and await until(func():return not room.player.is_navigating() and not room.lift_riding))
	check("return_to_platform_uses_upper_floor",room.walk_to(Vector2(18.85,7.5)) and await until(func():return not room.player.is_navigating() and room.lift_riding))
	check("stopping_waterwheel_can_lower_passenger",room.change_world(0,1))
	check("passenger_returns_to_lower_floor_with_same_plan_position",await until(func():return room.player_layer==1 and room.state.lift_docked(1)) and room.view_layer==1 and not room.player.controls_locked)
	fixture(true);await frames(3)
	check("waterwheel_raises_loaded_platform",room.change_world(1,1) and await until(func():return room.state.weights[0].layer==0 and room.state.lift_docked(0)))
	room.observe(0);await frames(3)
	check("raised_mountain_has_only_upper_route",room.state.destinations(0)==["dock"] and room.state.weights[0].layer==0)
	room.state.push_direction(0,Vector2.DOWN);await frames(2)
	var worlds:Array=room.state.worlds.duplicate();var cooldown:float=room.world_cooldown
	key(KEY_3);await frames(2)
	check("keyboard_inverted_is_rejected_mid_slide_without_cooldown",room.state.worlds==worlds and room.world_cooldown==cooldown and room.hud.last_message.contains("停稳"))
	check("all_world_buttons_disabled_while_cargo_slides",room.hud.rule_buttons.all(func(b):return b.disabled))
	check("api_cannot_switch_remote_floor_during_slide",not room.change_world(2,1) and room.state.worlds==worlds)
	check("departing_mountain_reaches_upper_dock",await until(func():return room.state.weights[0].station=="dock" and room.state.weights[0].mode=="rest") and room.state.weights[0].layer==0)
	await frames(20);room.view.set_focus(State.MOUNTAIN_STOPS.dock);await frames(35);await shot("03-upper-dock-correct-rails")
	check("world_buttons_reenable_after_real_stop",room.change_world(2,0))
	fixture(true);room.state.worlds[1]=1;room.state.step(.1);room.player_layer=1
	var height_before:float=room.state.lift_height;room.hud.toggle_menu();await frames(15)
	check("menu_pauses_waterwheel_platform_and_passenger",room.state.lift_height==height_before)
	room.hud.toggle_menu();await frames(2)
	print("PAPER_LIFT_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
