extends Node
const State=preload("res://scripts/paper_mill_state.gd")
var room:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func check(title:String,ok:bool) -> void:
	results.append({"test":title,"passed":ok});print("INVERTED ",title," ",ok)
	if not ok:failures+=1;push_error("INVERTED_FAILED "+title)
	var f:=FileAccess.open(directory.path_join("inverted-report.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"native_render":DisplayServer.get_name()!="headless","results":results},"\t"))

func simulate(s:RefCounted,seconds:float) -> void:
	for i in range(ceili(seconds*120)):s.step(1.0/120.0)

func shot(id:String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(id+".png"))

func state_checks() -> void:
	var s=State.new();var m:Dictionary=s.weights[0]
	s.switch_world(0,2)
	var last:=0.0;var monotonic:=true;var smooth:=true
	for i in range(360):
		s.step(1.0/120.0);monotonic=monotonic and m.elevation>=last;smooth=smooth and absf(m.elevation-last)<.035;last=m.elevation
	check("hatch_real_rise_smooth_and_monotonic",monotonic and smooth and is_equal_approx(m.elevation,1.5) and m.speed_y==0.0)
	check("hatch_keeps_footprint_floor_and_puzzle",m.pos==State.DROP and m.layer==0 and not s.hatch_broken and not s.clip_owned)
	s.worlds[1]=1;simulate(s,.3)
	check("other_floor_cannot_drop_upper_weight",m.elevation==1.5)
	var saved:Dictionary=s.snapshot();var resumed=State.new();resumed.restore(saved);simulate(resumed,.1)
	check("floating_stable_save_preserves_height",resumed.weights[0].elevation==1.5 and resumed.weights[0].layer==0)
	s.switch_world(0,0);s.step(.008)
	check("switch_back_has_no_height_reset",m.elevation>1.49 and not s.push_route(0,Vector2.DOWN).error.is_empty())
	simulate(s,2)
	check("ice_returns_to_supported_rest",m.elevation==0.0 and m.speed_y==0.0 and not s.hatch_broken)
	s.switch_world(0,2);simulate(s,2);s.switch_world(0,1);simulate(s,2)
	check("support_prevents_break_after_real_heavy_landing",m.elevation==0.0 and not s.hatch_broken)
	s.switch_world(0,2);simulate(s,2);s.clip_owned=true;s.clip_target="catch";s.catch_height=1.0;s.release_support();s.switch_world(0,1)
	var before:float=s.weight_height(0);s.step(.008)
	check("released_hatch_never_breaks_below_airborne_weight",not s.hatch_broken and s.weight_height(0)>before-.01)
	var max_jump:=0.0;var previous:float=s.weight_height(0)
	for i in range(300):
		s.step(1.0/120.0);max_jump=maxf(max_jump,absf(s.weight_height(0)-previous));previous=s.weight_height(0)
	check("contact_break_converts_local_to_absolute_without_jump",s.hatch_broken and max_jump<.18)
	check("original_drop_lands_at_lower_catch",m.layer==1 and m.station=="catch" and m.mode=="rest" and m.elevation==0.0 and s.checkpoint==3)
	var reverse=State.new();reverse.support_released=true;reverse.worlds[0]=1;reverse.step(.02);reverse.worlds.assign([2,2])
	simulate(reverse,8)
	check("reversed_cross_floor_fall_stays_in_hatch_column",reverse.weights[0].pos==State.DROP and reverse.weights[0].layer==0 and reverse.weight_height(0)<=State.HEIGHT+1.681)
	reverse.worlds.assign([1,1]);simulate(reverse,4)
	check("reversed_drop_can_resume_original_landing",reverse.weights[0].station=="catch" and reverse.weights[0].layer==1)
	for station:String in ["cage","junction","guide"]:
		var t=State.new();t.weights[1]=t.make_weight("water",1,t.WATER_STOPS[station],station);t.worlds[1]=2;simulate(t,3)
		check("water_"+station+"_retains_correct_ceiling",is_equal_approx(t.weights[1].elevation,2.3 if station!="junction" else 1.5))
	var lift=State.new();lift.weights[0]=lift.make_weight("mountain",1,State.LIFT,"lift");lift.worlds[1]=2;simulate(lift,3)
	check("open_lift_cargo_responds_without_ownership_change",lift.weights[0].elevation==1.5 and lift.weights[0].layer==1 and lift.weight_height(0)>1.6)
	lift.worlds[1]=0;simulate(lift,2);lift.weights[1]=lift.make_weight("water",1,State.SLUICE,"sluice");lift.worlds[1]=1;lift.worlds[0]=2;simulate(lift,6)
	check("lift_docks_before_upper_membership_then_floats",lift.lifted_once and lift.weights[0].layer==0 and lift.weights[0].elevation>1.4 and lift.lift_docked(0))
	var airborne_height:float=lift.weight_height(0);lift.worlds[1]=0;simulate(lift,4)
	check("withdrawing_lift_does_not_drag_airborne_cargo",lift.lift_docked(1) and lift.weights[0].layer==0 and absf(lift.weight_height(0)-airborne_height)<.02)
	var lift_restore=State.new();lift_restore.restore(lift.snapshot())
	check("detached_cargo_save_restores_real_height_and_owner",absf(lift_restore.weight_height(0)-airborne_height)<.02 and lift_restore.weights[0].layer==0)
	var book=preload("res://scripts/save_book.gd").new()
	check("detached_cargo_payload_is_valid",book.valid_paper({"state":lift.snapshot(),"player_layer":0,"player":[12,12]}))
	lift.worlds[0]=0;simulate(lift,3)
	check("detached_cargo_falls_back_to_actual_lower_deck",lift.weights[0].layer==1 and lift.weights[0].elevation==0.0 and lift.weight_height(0)<.2)
	var anchor=State.new();anchor.upper_anchored=true;anchor.lower_anchored=true;anchor.weights[1].elevation=2.3;anchor.worlds.assign([2,2]);simulate(anchor,2)
	check("anchored_weights_do_not_restart_motion",anchor.weights[0].elevation==0.0 and anchor.weights[1].elevation==2.3)
	var guide=State.new();guide.upper_anchored=true;guide.weights[1]=guide.make_weight("water",1,State.LOWER_ANCHOR,"guide");guide.worlds[1]=2;simulate(guide,3)
	check("guide_still_completes_lower_anchor",guide.lower_anchored and guide.checkpoint==6)
	var rapid=State.new();rapid.worlds[0]=2;simulate(rapid,.5);var continuity:=true
	for i in range(18):
		var h:float=rapid.weights[0].elevation;rapid.worlds[0]=[0,2,3,2,1,2][i%6];rapid.step(.008)
		continuity=continuity and absf(rapid.weights[0].elevation-h)<.04
	check("rapid_switch_continues_current_height",continuity and rapid.weights[0].pos==State.DROP)

func fixture() -> void:
	room.restore({"state":State.new().snapshot(),"player_layer":0,"player":[12.8,11.5]})
	room.communications.enabled=false;room.hud.message_time=0;room.hud.saved_time=0
	room.view.begin_manual_observation();room.view.focus=Vector2(11.2,12.8);room.view.zoom=1.0;room.view.target_zoom=1.0;room.view._camera()

func presentation(before:=false) -> void:
	fixture();await frames(45);await shot("01-normal")
	room.change_world(2,0);await frames(145);await shot("02-inverted")
	if not before:
		check("native_hatch_model_has_actual_height",room.state.weights[0].elevation>1.49 and absf(room.view.weight_nodes[0].position.y-room.state.weight_height(0))<.001)
		check("native_shadow_remains_on_actual_wood_surface",absf(room.view.weight_shadows[0].position.y-State.HEIGHT-.17)<.001)
		room.hud.hover_target="w0";room.view._sync(0)
		check("hover_highlight_follows_elevated_model",absf(room.view.highlight.position.y-room.state.weight_height(0)-.08)<.001)
		room.hud.hover_target=""
		check("floating_payload_remains_valid_for_save",get_parent().save_book.valid_paper(room.snapshot()))
		check("floating_weight_still_blocks_original_footprint",not room.is_walkable(State.DROP,0))
		var upper:=0.0;var lower:=0.0
		for p:Dictionary in room.view.rule_details.pieces:
			if p.layer==0:upper=maxf(upper,p.h)
			else:lower=maxf(lower,p.h)
		check("local_papers_respond_only_on_owner_floor",upper>.5 and lower==0.0)
		var common:=true
		for p:Dictionary in room.view.rule_details.pieces:
			for child:Node in p.node.get_children():
				if child is MeshInstance3D:common=common and child.layers==1 and not room.view.film.sources[p.layer].has(child)
		check("moving_leaves_have_no_static_film_copy",common)
		var node:Node3D=room.view.rule_details.pieces[0].node
		var pose:Transform3D=node.transform;var height:float=room.state.weights[0].elevation
		room.hud.menu.show();await frames(18)
		check("pause_freezes_real_height_and_paper_pose",node.transform==pose and room.state.weights[0].elevation==height)
		room.hud.menu.hide()
		for scale_value in [.55,1.0,1.6]:
			for angle in [-45,45]:
				room.view.zoom=scale_value;room.view.target_zoom=scale_value;room.view.angle=angle;room.view._camera();await frames(2)
				var at:Vector2=room.view.screen(State.DROP,0,room.state.weight_height(0)-State.HEIGHT+.3)
				check("float_picking_%s_%s"%[scale_value,angle],room.hit_target(at)=="w0")
				await shot("detail-%s-%s"%[scale_value,angle])
		room.view.angle=0;room.view.zoom=1;room.view.target_zoom=1;room.view._camera()
	room.change_world(1,0);await frames(105);await shot("03-returned")
	if not before:
		check("native_heavy_returns_without_releasing_hatch",room.state.weights[0].elevation==0.0 and not room.state.hatch_broken)
		room.hud.audio.preferences.motion_enabled=false;room.change_world(2,0);await frames(110)
		check("low_motion_keeps_required_gameplay_float",room.state.weights[0].elevation>1.49)
		room.hud.audio.preferences.motion_enabled=true
		DisplayServer.window_set_size(Vector2i(1920,1080));await frames(6);await shot("1920-inverted")
		check("large_window_render_tracks_draw_area",room.view.viewport.size.x>=1920)
		var previous_mode:=DisplayServer.window_get_mode();DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);await frames(6);await shot("fullscreen-inverted")
		check("fullscreen_remains_renderable",room.view.viewport.size.x>0)
		DisplayServer.window_set_mode(previous_mode)

func movie() -> void:
	fixture();room.view.focus=Vector2(11,13.4);room.view.zoom=1.2;room.view.target_zoom=1.2;room.view._camera()
	await frames(120);await shot("movie-normal")
	room.change_world(2,0);await frames(190);await shot("movie-inverted")
	check("recorded_real_hatch_float",room.state.weights[0].elevation>1.49)
	room.change_world(1,0);await frames(150);await shot("movie-returned")
	check("recorded_real_contact_return",room.state.weights[0].elevation==0.0 and not room.state.hatch_broken)
	# Nearby drying mats: same live instances, no cut to a mock-up animation.
	room.view.set_focus(Vector2(10.5,16.1));room.view.target_zoom=1.6;await frames(90);await shot("papers-normal-close")
	room.change_world(2,0);await frames(160);await shot("papers-inverted-close")
	room.change_world(1,0);await frames(125);await shot("papers-returned-close")

func run(app:Node) -> void:
	var args:=OS.get_cmdline_user_args()
	for arg:String in args:
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	var before:bool="--inverted-before" in args
	if not before and not "--inverted-record" in args:state_checks()
	app.show_paper_mill();room=app.current;await frames(5)
	if "--inverted-inspect" in args:
		fixture();return
	if "--inverted-record" in args:await movie()
	else:await presentation(before)
	await app.shutdown_audio()
	get_tree().quit(1 if failures>0 else 0)

