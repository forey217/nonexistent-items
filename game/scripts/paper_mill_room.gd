extends Node2D
signal completed
signal hub_requested
const State=preload("res://scripts/paper_mill_state.gd")
const SCALE:=55.0
const StairGuards=preload("res://scripts/paper_mill_stair_guards.gd")
var stair_bodies:Array[StaticBody2D]=[]
var level_id:="paper_mill"
var state=State.new()
var player=preload("res://scripts/yanyue_mover.gd").new()
var view:Node2D
var hud:CanvasLayer
var sound=preload("res://scripts/tutorial_audio.gd").new()
var story=preload("res://scripts/dialogue_view.gd").new()
var communications=preload("res://scripts/paper_mill_dialogue.gd").new()
var player_layer:=0
var view_layer:=0
var world_cooldown:=0.0
var finished:=false
var interacting:=false
var push_age:=0.0
var arrival_age:=0.0
var pending:Dictionary={}
var selected_weight:=-1
var navigation:=AStarGrid2D.new()
var nav_signature:=""
var last_stable:Dictionary={}
var hint_level:=0
var story_time:=0.0
var last_checkpoint:=-1
var elapsed:=0.0
var event_log:Array[Dictionary]=[]
var transition_age:=0.0
var transition_from:=0
var transition_to:=0
var transition_start:=Vector2.ZERO
var arrival_fx:Node2D
var arrival_gate:Node3D
var arrival_origin:=Vector2.ZERO
var arrival_destination:=Vector2.ZERO
var world_cast_time:=0.0
var footstep_age:=0.0
var water_audio:AudioStreamPlayer
var stairs_armed:=true
var stairs_notice:=false

func _ready() -> void:
	player.position=Vector2(6,4)*SCALE;add_child(player);player.hide()
	player.motion_guard=Callable(self,"guard_motion")
	player.movement_notice.connect(func(_text):pending.clear();interacting=false)
	view=preload("res://scripts/paper_mill_view.gd").new();view.room=self;add_child(view)
	_build_stair_collisions()
	hud=preload("res://scripts/paper_mill_hud.gd").new();hud.room=self;add_child(hud)
	add_child(sound);add_child(story)
	communications.room=self;add_child(communications)
	_setup_water_audio()
	state.event.connect(_state_event)
	_rebuild_navigation();last_stable=snapshot()

func player_plan() -> Vector2:return player.position/SCALE
func arrival_busy() -> bool:return arrival_age>0 or transition_age>0
func stairs_position(layer:int) -> Vector2:return State.STAIRS if layer==0 else State.LOWER_STAIRS
func actor_height() -> float:
	if transition_age>0:
		var t:=clampf((1.0-transition_age/2.0-.1)/.8,0.0,1.0)
		return lerpf(State.HEIGHT if transition_from==0 else 0.0,State.HEIGHT if transition_to==0 else 0.0,t)
	return State.HEIGHT if player_layer==0 else 0.0

func start_rift_arrival() -> void:
	if arrival_age>0:return
	arrival_age=2.15;player.controls_locked=true
	arrival_destination=player.position;arrival_origin=arrival_destination
	for offset in [Vector2(-32,0),Vector2(0,-32),Vector2(24,0)]:
		var candidate: Vector2=arrival_destination+offset
		if is_walkable(candidate/SCALE) and (candidate+guard_motion(candidate,arrival_destination-candidate)).distance_to(arrival_destination)<1:
			arrival_origin=candidate;break
	player.teleport_for_reset(arrival_origin)
	arrival_gate=preload("res://scripts/armillary_billboard.gd").new()
	arrival_gate.pixel_density=58.0;arrival_gate.height_compensation=1.0
	view.world_root.add_child(arrival_gate)
	var at: Vector3=view.point(arrival_origin/SCALE,actor_height()+0.04)
	arrival_fx=arrival_gate.begin(at,view.camera.position-at)
	view.actor.modulate.a=0.0
	view.actor.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED


func talk(speaker:String,text:String) -> void:
	story.clear();hud.communicate(speaker,text);story_time=hud.subtitle_duration

func _setup_water_audio() -> void:
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=22050
	var bytes:=PackedByteArray();bytes.resize(44100)
	var rng:=RandomNumberGenerator.new();rng.seed=20261022;var filtered:=0.0
	for i in range(22050):
		filtered=lerpf(filtered,rng.randf_range(-1,1),.16)
		bytes.encode_s16(i*2,int(filtered*9500.0))
	stream.data=bytes;water_audio=AudioStreamPlayer.new();water_audio.stream=stream;water_audio.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master";water_audio.volume_db=-35
	sound.add_child(water_audio);sound.voices.append(water_audio);water_audio.play()

func _state_event(kind:String) -> void:
	sound.play_event(kind)
	event_log.append({"event":kind,"time":elapsed,"checkpoint":state.checkpoint})
	if event_log.size()>160:event_log.pop_front()
	if kind=="seal_begin":view.link_time=3.0;view.focus=State.DROP;view.auto_follow=false

func observe(layer:int) -> void:
	view_layer=clampi(layer,0,1);view.cancel_drag();hud.destination_panel.hide()
	view.set_focus(player_plan() if player_layer==view_layer else Vector2(12,9),player_layer==view_layer)

func change_world(next:int,layer:int=-1) -> bool:
	if layer<0:layer=view_layer
	if finished or arrival_busy() or interacting or world_cooldown>0:return false
	if layer==0 and next!=3 and not state.bridge_solid() and on_bridge(player_plan()) and player_layer==0:return false
	if layer==0 and next!=3 and state.clip_target!="bridge" and not state.upper_anchored and on_bridge(player_plan()) and player_layer==0:
		hud.message("先夹住木桥，或站回桥头再切换世界。");return false
	if not state.switch_world(layer,next):return false
	world_cooldown=1.5;world_cast_time=.5;communications.notify_attempt();pending.clear();player.cancel_navigation()
	_rebuild_navigation();hud.message(("上层" if layer==0 else "下层")+"已切到"+state.WORLD_NAMES[next]+"世界。")
	return true

func on_bridge(at:Vector2) -> bool:return at.x>17.1 and at.x<18.9 and at.y>10.45 and at.y<12.0

func is_walkable(at:Vector2,layer:int=-1,ignore_weights:=false) -> bool:
	if layer<0:layer=player_layer
	if at.x<.65 or at.x>23.35 or at.y<.65 or at.y>17.35:return false
	if StairGuards.OPENING.has_point(at):return false
	if StairGuards.blocks(at,layer,player.FOOT_RADIUS/SCALE):return false
	if layer==1 and not state.lowpass_open and Rect2(11.2,11.3,1.6,2.0).has_point(at):return false
	for hole in [Rect2(9.8,8.8,2.4,2.4),Rect2(16.8,5.8,2.4,2.4)]:
		if hole.has_point(at):return false
	if at.x>12.8 and at.x<22.2 and at.y>10.8 and at.y<12.2:
		if not (at.x>17.4 and at.x<18.6 and (layer==1 or state.bridge_solid())):return false
	if at.x>2.8 and at.x<7.2 and at.y>9.8 and at.y<11.2:
		if not (at.x>4.4 and at.x<5.6 and (layer==1 or state.worlds[0]==3 or state.clip_owned)):return false
	# Rear and side walls match the rendered open-front paper workshops.
	for rect in [Rect2(2.25,12,0.5,4.3),Rect2(7.25,12,.5,4.3),Rect2(2.25,15.8,5.5,.5),Rect2(7.5,16.35,5,.5),Rect2(7.5,13.8,.4,2.7),Rect2(12.0,13.8,.5,2.7)]:
		if rect.grow(.18).has_point(at):return false
	for vat in [Vector2(8,15),Vector2(12,16),Vector2(2,9),Vector2(21,16)]:
		if Rect2(vat-Vector2(.83,.62),Vector2(1.66,1.24)).has_point(at):return false
	if not ignore_weights:
		for w in state.weights:
			if int(w.layer)==layer and w.mode!="fall" and at.distance_to(w.pos)<.63:return false
	return true

func guard_motion(from:Vector2,motion:Vector2) -> Vector2:
	var start:=from/SCALE;var step:=motion/SCALE
	var result:=start
	var samples:=maxi(1,ceili(step.length()/.12))
	for i in range(samples):
		var delta:=step/samples
		if is_walkable(result+delta) or (not is_walkable(result) and is_walkable(result+delta,player_layer,true)):result+=delta
		elif is_walkable(result+Vector2(delta.x,0)):result.x+=delta.x
		elif is_walkable(result+Vector2(0,delta.y)):result.y+=delta.y
	return (result-start)*SCALE

func segment_clear(a:Vector2,b:Vector2,avoid_stairs:=false) -> bool:
	var count:=maxi(1,ceili(a.distance_to(b)/.16))
	var clearance:=minf(.6,a.distance_to(stairs_position(player_layer)))-.001
	for i in range(count+1):
		var at:=a.lerp(b,float(i)/count)
		if not is_walkable(at):return false
		if avoid_stairs and at.distance_to(stairs_position(player_layer))<clearance:return false
	return true

func _rebuild_navigation() -> void:
	for layer in range(stair_bodies.size()):stair_bodies[layer].collision_layer=1 if player_layer==layer and transition_age<=0 else 0
	nav_signature=_navigation_signature()
	navigation=AStarGrid2D.new();navigation.region=Rect2i(0,0,49,37);navigation.cell_size=Vector2(.5,.5)
	navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;navigation.update()
	for y in range(37):
		for x in range(49):navigation.set_point_solid(Vector2i(x,y),not is_walkable(Vector2(x,y)*.5))

func _build_stair_collisions() -> void:
	for layer in range(2):
		var body:=StaticBody2D.new();body.name="StairGuardCollision%d"%layer;body.collision_mask=2
		body.collision_layer=1 if player_layer==layer else 0;add_child(body);stair_bodies.append(body)
		for rect in StairGuards.boundaries(layer):
			var shape:=RectangleShape2D.new();shape.size=rect.size*SCALE
			var collision:=CollisionShape2D.new();collision.shape=shape;collision.position=rect.get_center()*SCALE;body.add_child(collision)

func _navigation_signature() -> String:
	return JSON.stringify([state.bridge_solid(),state.lowpass_open,state.clip_owned,state.cage_open,state.weights[0].layer,state.weights[0].station,state.weights[1].layer,state.weights[1].station])

func path_to(at:Vector2) -> PackedVector2Array:
	if not is_walkable(at):return PackedVector2Array()
	var a:=_near_cell(player_plan());var b:=_near_cell(at)
	if not navigation.is_in_boundsv(a) or not navigation.is_in_boundsv(b):return PackedVector2Array()
	if navigation.is_point_solid(a) or navigation.is_point_solid(b):return PackedVector2Array()
	var avoid_stairs:=at.distance_to(stairs_position(player_layer))>.6
	var reserved:Array[Vector2i]=[]
	if avoid_stairs:
		var center:=Vector2i((stairs_position(player_layer)*2).round())
		for y in range(-2,3):
			for x in range(-2,3):
				var cell:=center+Vector2i(x,y)
				if cell==a or cell==b or not navigation.is_in_boundsv(cell) or navigation.is_point_solid(cell):continue
				if (Vector2(cell)*.5).distance_to(stairs_position(player_layer))<.6:
					reserved.append(cell);navigation.set_point_solid(cell,true)
	var raw:=navigation.get_point_path(a,b)
	for cell in reserved:navigation.set_point_solid(cell,false)
	var result:=PackedVector2Array();var origin:=player_plan();var index:=0
	while index<raw.size():
		var end:=index
		for j in range(raw.size()-1,index-1,-1):
			if segment_clear(origin,raw[j],avoid_stairs):end=j;break
		if not segment_clear(origin,raw[end],avoid_stairs):return PackedVector2Array()
		result.append(raw[end]*SCALE);origin=raw[end];index=end+1
	if not raw.is_empty() and segment_clear(origin,at,avoid_stairs):result.append(at*SCALE)
	return result

func _near_cell(at:Vector2) -> Vector2i:
	var center:=Vector2i((at*2.0).round());var best:=Vector2i(-1,-1);var distance:=INF
	for y in range(-2,3):
		for x in range(-2,3):
			var cell:=center+Vector2i(x,y)
			if not navigation.is_in_boundsv(cell) or navigation.is_point_solid(cell):continue
			var point:=Vector2(cell)*.5;var d:=at.distance_squared_to(point)
			if d<distance and segment_clear(at,point):best=cell;distance=d
	return best

func walk_to(at:Vector2) -> bool:
	var route:=path_to(at)
	if route.is_empty():return false
	communications.notify_attempt()
	view.resume_actor_follow();player.follow_path(route);return true

func targets() -> Array[Dictionary]:
	var list:Array[Dictionary]=[{"id":"stairs","pos":stairs_position(player_layer),"layer":player_layer,"name":"检修楼梯"},{"id":"tool","pos":State.TOOL,"layer":0,"name":"留影夹"},{"id":"support","pos":State.DROP+Vector2(-1.4,0),"layer":0,"name":"检修撑"},{"id":"catch","pos":State.DROP+Vector2(1.4,0),"layer":1,"name":"接物台夹环"},{"id":"bridge","pos":State.BRIDGE+Vector2(.9,-.5),"layer":0,"name":"木桥夹环"},{"id":"exit","pos":State.EXIT,"layer":0,"name":"归位门"}]
	for i in range(2):list.append({"id":"w%d"%i,"pos":state.weights[i].pos,"layer":state.weights[i].layer,"name":"山纹镇纸" if i==0 else "水纹镇纸"})
	return list

func target_by_id(id:String) -> Dictionary:
	for target in targets():
		if target.id==id:return target
	return {}

func request_interaction(id:String,destination:="") -> bool:
	if arrival_busy() or finished or interacting:return false
	communications.notify_attempt()
	if id=="stairs":
		hud.message("走入楼梯即可自动上下楼。");return false
	var target:=target_by_id(id)
	if target.is_empty() or target.layer!=player_layer:
		hud.message("人物还在另一层，请经检修楼梯前往。");return false
	if id.begins_with("w"):
		var index:=int(id.trim_prefix("w"));selected_weight=index
		if destination.is_empty():
			var choices:Array[String]=state.destinations(index)
			if choices.is_empty():hud.message("先观察镇纸上方的机关与当前规则。");return false
			hud.show_destinations(index);return true
	var best:=Vector2.ZERO;var distance:=INF
	if id in ["stairs","exit"]:
		best=target.pos;distance=0.0
	for i in range(16):
		if id in ["stairs","exit"]:break
		var at:Vector2=target.pos+Vector2.from_angle(i*TAU/16.0)*1.45
		if not is_walkable(at):continue
		var d:=player_plan().distance_squared_to(at)
		if d<distance and not path_to(at).is_empty():best=at;distance=d
	if distance==INF:hud.message("这里的操作侧暂时不可达，先检查通路和世界。");return false
	pending={"id":id,"destination":destination}
	if player_plan().distance_to(target.pos)<=(.18 if id in ["stairs","exit"] else 1.9):_begin_interaction()
	else:walk_to(best)
	return true

func _begin_interaction() -> void:
	player.cancel_navigation();player.face_toward(target_by_id(pending.id).pos*SCALE)
	interacting=true;push_age=0.0;player.controls_locked=true

func _commit_interaction() -> void:
	if pending.is_empty():return
	var id:String=pending.id;var result:=""
	communications.notify_attempt()
	match id:
		"tool":result=state.acquire_clip()
		"support":result=state.release_support()
		"catch","bridge":result=state.set_clip(id)
		"exit":
			if state.lower_anchored:finished=true;completed.emit()
			else:result="纸页仍不完整，先稳定上下两处锚点。"
		"w0","w1":result=state.push(int(id.trim_prefix("w")),pending.destination)
	result=result.replace("已固定接物台。下层现在可以切回冰晶。","接物台已固定在当前高度。").replace("旧桥已留影，切回冰晶也能运送镇纸。","木桥已留影，当前姿态已保留。")
	pending.clear();hud.message(result);_rebuild_navigation()

func recall_clip() -> void:
	if not state.clip_owned:return
	communications.notify_attempt()
	if state.clip_target=="bridge" and player_layer==0 and on_bridge(player_plan()):hud.message("先离开桥面，再召回夹子。");return
	hud.message(state.set_clip(""));_rebuild_navigation()

func goal_target() -> String:
	return ["tool","w1","support","w0","bridge","w1","exit"][clampi(state.checkpoint,0,6)]

func focus_target(id:String) -> void:
	var target:=target_by_id(id)
	if target.is_empty():return
	view_layer=target.layer;view.set_focus(target.pos);hud.hover_target=id
	view.focused_target=id

func show_hint() -> void:
	communications.request_hint()

func snapshot() -> Dictionary:
	return {"state":state.snapshot(),"player_layer":player_layer,"player":[player_plan().x,player_plan().y],"communications":communications.snapshot()}

func stable_snapshot() -> Dictionary:
	if state.is_busy() or interacting or arrival_busy():
		var stable:=last_stable.duplicate(true);stable["communications"]=communications.snapshot();return stable
	last_stable=snapshot();return last_stable.duplicate(true)

func restore(data:Dictionary) -> void:
	state.restore(data.get("state",{}));player_layer=int(data.get("player_layer",0));view_layer=player_layer
	var at:Array=data.get("player",[3,4]);var destination:=Vector2(at[0],at[1])
	player.teleport_for_reset(_safe_player_position(destination)*SCALE)
	player.controls_locked=false;interacting=false;pending.clear();world_cooldown=0;story.clear();story_time=0
	transition_age=0;stairs_armed=player_plan().distance_to(stairs_position(player_layer))>.9;stairs_notice=false
	communications.restore(data.get("communications",{}),not data.has("communications"))
	_rebuild_navigation();view.return_to_actor();last_stable=snapshot();last_checkpoint=state.checkpoint

func _safe_player_position(at:Vector2) -> Vector2:
	if is_walkable(at):return at
	# Older saves may stand on the newly protected edge. Relocate only to the
	# nearest legal spot on that same floor, away from the automatic stair trigger.
	var nearest:=stairs_position(player_layer)+Vector2(0,.7 if player_layer==0 else -.7)
	var distance:=INF
	for y in range(-6,7):
		for x in range(-6,7):
			var candidate:=at+Vector2(x,y)*.25
			if not is_walkable(candidate) or candidate.distance_to(stairs_position(player_layer))<.55:continue
			var d:=at.distance_squared_to(candidate)
			if d<distance:nearest=candidate;distance=d
	return nearest

func restore_checkpoint() -> void:
	if arrival_busy() or finished:return
	restore(last_stable.duplicate(true));hud.message("已恢复最近稳定的观测记录。");sound.play_event("fold")

func restart() -> void:
	if finished or arrival_busy():return
	state=State.new();state.event.connect(_state_event);player_layer=0;view_layer=0;finished=false
	player.teleport_for_reset(Vector2(6,4)*SCALE);pending.clear();interacting=false;player.controls_locked=false
	stairs_armed=true;stairs_notice=false;transition_age=0;hud.record.hide();hud.help_panel.hide()
	communications.restore({});last_stable=snapshot();last_checkpoint=-1;world_cooldown=0;_rebuild_navigation();view.return_to_actor();hud.message("本关已完整重新开始。")

func _physics_process(delta:float) -> void:
	communications.set_paused(hud.menu.visible)
	if hud.menu.visible:return
	elapsed+=delta;world_cooldown=maxf(0,world_cooldown-delta)
	world_cast_time=maxf(0,world_cast_time-delta)
	footstep_age+=delta
	if player.walking and footstep_age>.36:footstep_age=0;sound.play_event("land",1.6)
	if is_instance_valid(water_audio):water_audio.volume_db=-31 if state.pressure("sluice") or state.lower_anchored else -36
	if arrival_age>0:
		arrival_age=maxf(0,arrival_age-delta)
		var gate_age:=2.15-arrival_age
		arrival_fx.age=gate_age
		view.actor.modulate.a=smoothstep(0.66,1.08,gate_age)
		player.controls_locked=true
		var offset: Vector2=arrival_destination-player.position
		player.cinematic_motion=offset.normalized()*minf(78.0,offset.length()/maxf(delta,0.001)) if gate_age>0.72 and gate_age<1.43 else Vector2.ZERO
		if arrival_age==0:
			player.controls_locked=false;player.cinematic_motion=Vector2.ZERO
			view.actor.modulate.a=1.0;view.actor.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
			if is_instance_valid(arrival_gate):arrival_gate.stop();arrival_gate.queue_free()
	if transition_age>0:
		transition_age=maxf(0,transition_age-delta);player.controls_locked=true
		var t:=1.0-transition_age/2.0
		var start:=stairs_position(transition_from);var end:=stairs_position(transition_to)
		var exit_offset:=Vector2(0,.36 if transition_to==0 else -.36)
		if t<.1:player.position=transition_start.lerp(start,t/.1)*SCALE
		elif t<.9:player.position=start.lerp(end,(t-.1)/.8)*SCALE
		else:player.position=end.lerp(end+exit_offset,(t-.9)/.1)*SCALE
		if transition_age==0:
			player_layer=transition_to
			player.teleport_for_reset((stairs_position(player_layer)+exit_offset)*SCALE);player.controls_locked=false
			view_layer=player_layer;view.link_time=0;_rebuild_navigation();view.return_to_actor()
			stairs_armed=false
	_update_stairs()
	if interacting:
		push_age+=delta
		if push_age>=.45:
			interacting=false;player.controls_locked=false;_commit_interaction()
	elif not pending.is_empty() and not arrival_busy():
		var target:=target_by_id(pending.id)
		if not target.is_empty() and player_plan().distance_to(target.pos)<=(.18 if pending.id in ["stairs","exit"] else 1.95):_begin_interaction()
		elif not player.is_navigating():pending.clear()
	state.step(delta)
	if state.lower_anchored and player_layer==0 and not arrival_busy() and not finished and player_plan().distance_to(State.EXIT)<.35:
		finished=true;pending.clear();player.cancel_navigation();completed.emit()
	if nav_signature!=_navigation_signature():_rebuild_navigation()
	if state.checkpoint!=last_checkpoint:
		last_checkpoint=state.checkpoint;hint_level=0
	communications.tick(delta)
	if not state.is_busy() and not interacting and not arrival_busy():last_stable=snapshot()
	if not communications.enabled:story_time=maxf(0,story_time-delta)
	if story_time==0 and story.mode!="":story.clear()
	hud.refresh(delta)

func _update_stairs() -> void:
	if arrival_busy() or finished or interacting:return
	var distance:=player_plan().distance_to(stairs_position(player_layer))
	if distance>.95:stairs_armed=true;stairs_notice=false
	if distance<1.6 and not stairs_notice:
		stairs_notice=true;hud.message("走入楼梯，"+("下至水碓坊。" if player_layer==0 else "回到晒纸院。"))
	if not stairs_armed or distance>.42:return
	stairs_armed=false;pending.clear();hud.destination_panel.hide()
	player.cancel_navigation();player.controls_locked=true;view.cancel_drag()
	transition_age=2.0;transition_from=player_layer;transition_to=1-player_layer
	# During the locked 3D flight the actor passes below the upper rim. Its 2D
	# footprint must not collide with that rim at the wrong elevation.
	for body in stair_bodies:body.collision_layer=0
	# Scripted stair travel bypasses the mover's velocity-based facing update.
	# Keep the same world-space heading through the flight and onto its landing.
	player.face_toward(player.global_position+(stairs_position(transition_to)-stairs_position(transition_from))*SCALE)
	transition_start=player_plan();view.link_time=2.1;view.resume_actor_follow()
	sound.play_event("fold")

func hit_target(at:Vector2) -> String:
	var best:="";var distance:=48.0
	for target in targets():
		if target.layer!=view_layer:continue
		var h:=.5
		if target.id.begins_with("w"):
			var i:=int(target.id.trim_prefix("w"));h=state.weight_height(i)-(State.HEIGHT if target.layer==0 else 0.0)+.3
		var d:float=view.screen(target.pos,target.layer,h).distance_to(at)
		if d<distance:distance=d;best=target.id
	return best

func _unhandled_input(event:InputEvent) -> void:
	if finished or arrival_busy() or hud.menu.visible:return
	if event is InputEventKey and event.pressed and not event.echo:
		var key:int=event.physical_keycode
		if key in [KEY_1,KEY_2,KEY_3,KEY_4]:change_world(key-KEY_1);get_viewport().set_input_as_handled()
		elif key==KEY_TAB:observe(1-view_layer);get_viewport().set_input_as_handled()
		elif key==KEY_F:view.return_to_actor();get_viewport().set_input_as_handled()
		elif key==KEY_H:show_hint();get_viewport().set_input_as_handled()
		elif key==KEY_R:hud.menu.request_action("reset");get_viewport().set_input_as_handled()
		elif key==KEY_ESCAPE:pending.clear();player.cancel_navigation();hud.destination_panel.hide()
		elif key==KEY_E:
			var best:="";var distance:=2.6
			for target in targets():
				if target.layer!=player_layer:continue
				if target.id=="stairs":continue
				if target.id=="tool" and state.clip_owned:continue
				var d:float=player_plan().distance_to(target.pos)
				if d<distance:distance=d;best=target.id
			if not best.is_empty():request_interaction(best)
			get_viewport().set_input_as_handled()

func archive_texture() -> Texture2D:
	return ImageTexture.create_from_image(view.viewport.get_texture().get_image())

func _input(event:InputEvent) -> void:
	# Route map clicks explicitly after the HUD's input phase. Empty canvas space
	# remains playable even after a popup has held GUI focus; real HUD regions win.
	if finished or arrival_busy() or hud.menu.visible:return
	if not event is InputEventMouseButton or not event.pressed or event.alt_pressed or view.rotating:return
	if hud.blocks_map(event.position):return
	if event.button_index==MOUSE_BUTTON_RIGHT:
		var target:=hit_target(event.position)
		if not target.is_empty():request_interaction(target)
		get_viewport().set_input_as_handled()
	elif event.button_index==MOUSE_BUTTON_LEFT:
		pending.clear();hud.destination_panel.hide()
		if view_layer==player_layer:
			var destination:Vector2=stairs_position(player_layer) if view.over_stairs(event.position) else view.ground(event.position)
			if not walk_to(destination):hud.message("那里没有可达的道路。")
		else:hud.message("人物在另一层。按 F 回到人物，或经楼梯换层。")
		get_viewport().set_input_as_handled()
