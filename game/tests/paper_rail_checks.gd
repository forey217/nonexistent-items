extends Node
const S=preload("res://scripts/paper_mill_state.gd")
var app:Node
var room:Node
var directory:=""
var results:Array[Dictionary]=[]
var failures:=0

func frames(count:int) -> void:
	for i in range(count):await get_tree().physics_frame

func check(label:String,passed:bool) -> void:
	results.append({"test":label,"passed":passed});print("RAIL_CHECK ",label," ",passed)
	if not passed:failures+=1;push_error("RAIL_FAILED "+label)
	var file:=FileAccess.open(directory.path_join("rail-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results,"failures":failures,"native_render":DisplayServer.get_name()!="headless"},"\t"))

func shot(label:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func pose(at:Vector2,layer:int,yaw:=0.0,zoom:=1.6) -> void:
	room.player.cancel_navigation();room.player_layer=layer;room.view_layer=layer
	room.player.teleport_for_reset((at+Vector2(-1.1,1.2))*room.SCALE)
	var view=room.view
	view.set_focus(at);view.auto_follow=false;view.frame_to_ui=false;view.safe_center=Vector2(640,420)
	view.angle=yaw;view.zoom=zoom;view.target_zoom=zoom;room.story_time=0;room.hud.message_time=0
	room.hud.record.hide();room.hud.destination_panel.hide();room.hud.hover_target=""
	await frames(15)

func visual_checks() -> void:
	room.state.clip_target="bridge";room.state.cage_open=true;room.state.lowpass_open=true
	for spec in [["cage-turn",Vector2(7,12),1],["catch-turn",Vector2(7,8),1],["branch",Vector2(12,8),1],["guide-bend",Vector2(12,13),1],["lift-turn",Vector2(18,10),1],["upper-turn",Vector2(18,14),0]]:
		await pose(spec[1],spec[2]);await shot(spec[0])
	for layer in [0,1]:
		for yaw in [-45.0,0.0,45.0]:
			for zoom in [.55,1.0,1.6]:
				await pose(Vector2(18,13) if layer==0 else Vector2(8,11),layer,yaw,zoom)
				await shot("layer-%d-yaw-%d-zoom-%.2f"%[layer,yaw,zoom])

func geometry_checks() -> void:
	var view=room.view
	check("three_separate_real_networks",view.rail_networks.size()==3)
	for index in range(view.rail_networks.size()):
		var network=view.rail_networks[index]
		var expected:Array=[S.UPPER_EDGES,S.WATER_EDGES,S.LOWER_EDGES][index]
		check("only_actual_edges_%d"%index,network.segments.size()==expected.size() and network.segments.all(func(edge):return [edge.a,edge.b] in expected))
		for id:String in network.joints:
			var joint:Dictionary=network.joints[id]
			if joint.degree<2:continue
			var good:=true
			var connected:Array=joint.ends.duplicate()
			for curve:Dictionary in network.curves:
				if curve.joint==id:connected.append(curve.points[0]);connected.append(curve.points[-1])
			for end:Vector2 in connected:
				if connected.filter(func(other):return other.distance_to(end)<.0001).size()!=2:good=false
			check("both_rails_share_joint_%d_%s"%[index,id],good)
		for curve:Dictionary in network.curves:
			var vertices:PackedVector3Array=curve.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var circular:=vertices.size()>100
			for vertex:Vector3 in vertices:
				if absf(Vector2(vertex.x,vertex.z).distance_to(curve.center)-curve.radius)>.034:circular=false
			check("circular_mesh_%d_%s_%.2f"%[index,curve.joint,curve.radius],circular)
			if network.is_bend(curve.joint):
				var center_distance:float=network.stops[curve.joint].distance_to(curve.center)
				check("old_stop_within_double_rail_%d_%s_%.2f"%[index,curve.joint,curve.radius],absf(center_distance-.45)<.27)
		for edge:Dictionary in network.segments:
			if "lift" in [edge.a,edge.b]:
				var stop:int=0 if edge.a=="lift" else 1
				check("fixed_rail_ends_at_shaft_lip_%d"%index,edge.rails.all(func(rail):return absf(rail[stop].y-(S.LIFT.y+1.22))<.001))
	check("crossing_is_not_a_false_branch",not view.rail_networks[1].joints.has("lift_turn") and not view.rail_networks[2].joints.has("guide_turn"))
	var actual_top:=-1.0
	for mesh:MeshInstance3D in view.bridge.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override==view.rails[0]:actual_top=maxf(actual_top,mesh.get_aabb().end.y)
	check("rail_top_matches_weight_base",absf(actual_top-(room.state.weight_height(0)-S.HEIGHT))<.01)
	var before:Dictionary=room.state.snapshot()
	view._sync(0)
	check("visual_sync_does_not_change_simulation",before==room.state.snapshot())
	check("bridge_has_own_rail_meshes",view.bridge.find_children("*","MeshInstance3D",true,false).size()>2)
	room.state.clip_target="";room.state.worlds[0]=0;room.view_layer=0;view._sync(0)
	check("hidden_bridge_hides_its_track",not view.bridge.visible)
	await pose(Vector2(18,11.5),0);await shot("bridge-hidden")
	room.state.worlds[0]=3;view._sync(0)
	check("revealed_bridge_has_track",view.bridge.visible)
	await frames(10);await shot("bridge-revealed")
	room.state.worlds[0]=0;room.state.clip_target="bridge";view._sync(0)
	check("clamped_bridge_retains_track",view.bridge.visible)
	for layer in [0,1]:
		room.state.lift_height=S.HEIGHT if layer==0 else 0.0
		room.state.weights[1].station="sluice" if layer==0 else "cage"
		room.state.weights[1].pos=S.SLUICE if layer==0 else S.WATER_STOPS.cage
		room.state.worlds[1]=1
		view._sync(0)
		check("aligned_lift_track_%d"%layer,view.lift_rail_tongues.visible and is_equal_approx(view.lift.position.y,room.state.lift_height))
		await pose(S.LIFT+Vector2(0,.7),layer);await shot("lift-docked-%d"%layer)
	room.state.lift_height=S.HEIGHT*.5;view._sync(0)
	check("moving_lift_retracts_dock_tongues",not view.lift_rail_tongues.visible)
	await shot("lift-between-floors")

func run(flow:Node) -> void:
	app=flow
	app.show_paper_mill();await frames(30);room=app.current
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	DirAccess.make_dir_recursive_absolute(directory)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	room.communications.stop();room.communications.enabled=false;room.hud.entry_hint.offer();room.hud.entry_hint.dismiss()
	await frames(20);await visual_checks()
	if not "--rail-baseline" in OS.get_cmdline_user_args():await geometry_checks()
	print("RAIL_FINISHED checks=",results.size()," failures=",failures)
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
