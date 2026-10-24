extends CanvasLayer
## Owns temporary scenes. The player's original live scene is retained verbatim.
const Instruments=preload("res://scripts/instrument_theme.gd")
const Route=preload("res://scripts/paper_demo_route.gd")
var flow:Node
var active:=false
var paused:=false
var mode:="running"
var original:Node2D
var room:Node2D
var hub:Node2D
var archive:CanvasLayer
var owned:Array[Node]=[]
var frozen:Array[Dictionary]=[]
var paused_nodes:Array[Dictionary]=[]
var backup:Dictionary={}
var steps:Array[Dictionary]=[]
var index:=0
var stage:Dictionary={}
var history:Array[Dictionary]=[]
var final_state:Dictionary={}
var spoken_lines:Array[Dictionary]=[]
var ambient_paused:Array=[]
var elapsed:=0.0
var finished_seconds:=0.0
var runs_finished:=0
var generation:=0
var target_rate:=2.0
var last_clock:=0
var wait_age:=0.0
var hold_age:=0.0
var attempts:=0
var pointer:=Vector2.ZERO
var pointer_age:=0.0
var root:=Control.new()
var panel:=Panel.new()
var title:Label
var status:Label
var pause_button:Button
var exit_button:Button
var repeat_button:Button
var pointer_canvas:=Control.new()

func _ready() -> void:
	layer=200;process_priority=-80
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);root.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(root)
	panel.add_theme_stylebox_override("panel",Instruments.style(false,.91,true));panel.size=Vector2(286,125);root.add_child(panel)
	title=Instruments.label(panel,"纸山叠影 · 完整演示",Vector2(14,8),Vector2(258,24),18,Instruments.COPPER_TEXT)
	status=Instruments.label(panel,"",Vector2(14,35),Vector2(258,40),17);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	pause_button=_button("暂停",Vector2(12,83),Vector2(118,32),toggle_pause)
	exit_button=_button("退出演示",Vector2(140,83),Vector2(134,32),stop)
	repeat_button=_button("再次演示",Vector2(12,83),Vector2(118,32),restart);repeat_button.hide()
	pointer_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(pointer_canvas);pointer_canvas.draw.connect(_draw_pointer)
	get_viewport().size_changed.connect(_layout);_layout()

func _button(text:String,at:Vector2,dimensions:Vector2,action:Callable) -> Button:
	var b:=Button.new();b.text=text;b.position=at;b.size=dimensions;Instruments.apply_button(b,17,true,true);panel.add_child(b);b.pressed.connect(action);return b

func _layout() -> void:
	root.size=get_viewport().get_visible_rect().size;panel.position=Vector2(root.size.x-panel.size.x-24,78)

func begin(source:Node2D) -> void:
	if active:return
	original=source;active=true
	backup={"scale":Engine.time_scale,"dialogue_mode":flow.dialogue.process_mode,"canvas":get_viewport().canvas_transform,
		"duck":flow.ambience.dialogue_active,"save_feedback":flow.save_feedback.visible,"nav":flow.return_menu_button.visible,"sound_button":flow.ambience.toggle_button.visible}
	_freeze(original,frozen,true);_freeze(flow.dialogue,frozen,false)
	original.player.set_meta("presentation_frozen",true)
	flow.save_feedback.hide();flow.return_menu_button.hide();flow.ambience.toggle_button.hide()
	restart()

func _freeze(node:Node,records:Array[Dictionary],collisions:bool) -> void:
	var record:Dictionary={"node":node,"process":node.process_mode,"visible":[],"audio":[],"viewports":[],"collisions":[]}
	for child in _tree(node):
		if child is CanvasLayer or child==node and child is CanvasItem:
			record.visible.append([child,child.visible]);child.hide()
		if child is AudioStreamPlayer:
			record.audio.append([child,child.stream_paused]);child.stream_paused=true
		if child is SubViewport:
			record.viewports.append([child,child.render_target_update_mode]);child.render_target_update_mode=SubViewport.UPDATE_DISABLED
		if collisions and child is CollisionObject2D:
			record.collisions.append([child,child.collision_layer,child.collision_mask]);child.collision_layer=0;child.collision_mask=0
	node.process_mode=Node.PROCESS_MODE_DISABLED;records.append(record)

func _tree(node:Node) -> Array[Node]:
	var nodes:Array[Node]=[node]
	for child in node.get_children():nodes.append_array(_tree(child))
	return nodes

func _restore(records:Array[Dictionary]) -> void:
	for record in records:
		if not is_instance_valid(record.node):continue
		for item in record.visible:
			if is_instance_valid(item[0]):item[0].visible=item[1]
		for item in record.audio:
			if is_instance_valid(item[0]):item[0].stream_paused=item[1]
		for item in record.viewports:
			if is_instance_valid(item[0]):item[0].render_target_update_mode=item[1]
		for item in record.collisions:
			if is_instance_valid(item[0]):item[0].collision_layer=item[1];item[0].collision_mask=item[2]
		record.node.process_mode=record.process
	records.clear()

func restart() -> void:
	if not active:return
	generation+=1;_dispose();paused=false;mode="running";elapsed=0;finished_seconds=0;index=0;stage.clear();history.clear();final_state.clear();spoken_lines.clear()
	get_viewport().canvas_transform=backup.canvas
	wait_age=0;hold_age=0;attempts=0;last_clock=Time.get_ticks_usec();target_rate=1.25;Engine.time_scale=1.25
	pause_button.show();pause_button.text="暂停";repeat_button.hide();exit_button.text="退出演示";title.text="纸山叠影 · 完整演示"
	room=load("res://scenes/paper_mill.tscn").instantiate();room.presentation_mode=true;room.player.automation_owned=true
	room.communications.presentation_mode=true;room.communications.voice.unscaled_clock=true
	flow.current=room;flow.add_child(room);owned.append(room);room.completed.connect(_completed)
	room.communications.enabled=true;room.communications.voice.enabled=true
	room.view.target_zoom=.92;room.start_rift_arrival()
	for node in _tree(room):
		node.set_process_input(false);node.set_process_unhandled_input(false)
		if node is BaseButton:node.focus_mode=Control.FOCUS_NONE
	steps=Route.steps();pause_button.grab_focus()

func _process(_delta:float) -> void:
	if not active:return
	var now:=Time.get_ticks_usec();var real_dt:=maxf(0,float(now-last_clock)/1000000.0);var dt:=minf(.1,real_dt);last_clock=now
	if paused or mode in ["done","error"]:return
	elapsed+=real_dt;Engine.time_scale=lerpf(Engine.time_scale,target_rate,1.0-exp(-dt*7.0))
	if pointer_age>0:pointer_age=maxf(0,pointer_age-dt);pointer_canvas.queue_redraw()
	if is_instance_valid(room):
		room.hud.message_time=0;room.hud.entry_hint.obscured=true;room.hud.entry_hint.hide()
		flow.ambience.dialogue_active=room.communications.speaking()
	if mode=="returning":
		if is_instance_valid(hub) and not hub.arrival_busy():_done()
		return
	if mode!="running" or not is_instance_valid(room):return
	if stage.is_empty():
		stage=steps[index].duplicate(true);stage["phase"]=0;stage["started"]=false;wait_age=0;hold_age=0;attempts=0
		status.text="演示中 · "+str(stage.title);target_rate=float(stage.rate)
	wait_age+=real_dt
	if wait_age>28:_fail("这一段暂时没有完成，请重新演示或返回原进度。");return
	if stage.get("finished",false):
		hold_age+=real_dt
		var voice_key:String=stage.get("voice","")
		var voice_wait:bool=not voice_key.is_empty() and hold_age<5.0 and (not room.communications.acknowledged.has(voice_key) or not room.communications.active.is_empty())
		if hold_age>=float(stage.get("hold",.16)) and not voice_wait:
			history.append({"op":stage.op,"title":stage.title,"seconds":elapsed,"worlds":room.state.worlds.duplicate(),"mountain_layer":room.state.weights[0].layer})
			index+=1;stage.clear()
		return
	_tick_step(dt)

func _idle() -> bool:
	return not room.arrival_busy() and not room.interacting and room.pending.is_empty() and not room.state.has_sliding_weight() and not room.view.film.active

func _tick_step(dt:float) -> void:
	var s=room.state
	match str(stage.op):
		"wait":
			if stage.condition=="mountain_landed":_scene_focus(s.DROP,1,dt,true)
			elif stage.condition=="lift_top":_scene_focus(s.LIFT,0,dt,true)
			elif stage.condition=="dual":
				_scene_focus(s.EXIT if s.lower_anchored else s.LOWER_ANCHOR,0 if s.lower_anchored else 1,dt,false)
				if s.lower_anchored:room.view.torso_offset=lerpf(room.view.torso_offset,1.35,1.0-exp(-dt*8.0))
			if _condition(stage.condition):stage.finished=true
		"world":
			if not stage.started:
				if not _idle() or room.world_cooldown>0:return
				room.observe(int(stage.layer))
				if s.worlds[stage.layer]!=stage.world and not room.change_world(stage.world,stage.layer):_retry("世界暂不可切换");return
				stage.started=true
				_point(room.hud.rule_buttons[int(stage.world)].get_global_rect().get_center())
			if room.world_cast_time<=0 and not room.view.film.active and s.worlds[stage.layer]==stage.world:stage.finished=true
		"interact":
			if not stage.started:
				if not _idle():return
				room.view_layer=room.player_layer;room.view.return_to_actor()
				if not room.request_interaction(stage.id):_retry("操作位置暂不可达");return
				stage.started=true
			if stage.started and _idle():
				var correct:bool=s.clip_owned if stage.id=="tool" else s.support_released if stage.id=="support" else s.clip_target==stage.id
				if correct:stage.finished=true
				else:_retry("机关尚未完成操作")
		"stairs":_stairs()
		"push":_push(dt)
		"recall":
			if not _idle():return
			if not stage.started:room.recall_clip();stage.started=true
			if s.clip_target.is_empty():stage.finished=true
		"exit":
			if not stage.started and _idle():
				room.view_layer=0;room.view.return_to_actor()
				if not room.walk_to(s.EXIT):_retry("归位门路线暂不可达");return
				stage.started=true

func _condition(id:String) -> bool:
	var s=room.state;var m:Dictionary=s.weights[0];var w:Dictionary=s.weights[1]
	match id:
		"arrival":return not room.arrival_busy()
		"cage":return s.cage_open
		"water_ground":return w.mode=="rest" and float(w.elevation)<.02
		"catch_up":return s.catch_height>=.99
		"mountain_landed":return m.layer==1 and m.mode=="rest" and m.station=="catch"
		"lift_top":return s.lifted_once and m.layer==0 and m.mode=="rest" and s.lift_docked(0)
		"upper":return s.upper_anchored
		"lowpass":return s.lowpass_open and s.lift_docked(1)
		"dual":return s.upper_anchored and s.lower_anchored and room.view.paper_unfold>=.999 and room.view.portal.ready_for_entry()
	return false

func _stairs() -> void:
	if int(stage.phase)==0:
		if not _idle():return
		stage["origin"]=room.player_layer;room.view_layer=room.player_layer;room.view.return_to_actor()
		# Both points stay outside the old-corridor cutout and stair-post clearance.
		stage["landing"]=Vector2(5.0,9.3) if room.player_layer==0 else Vector2(3.5,1.5)
		if not room.walk_to(stage.landing):_retry("楼梯入口暂不可达");return
		stage.phase=1
	if int(stage.phase)==1 and not room.player.is_navigating():
		if room.player_plan().distance_to(stage.landing)>.16:_retry("正在重新对齐楼梯入口");return
		if room.stairs_armed:stage.phase=2
	if int(stage.phase)==2:
		target_rate=1.25
		var mouth:=Vector2(3.5,9.4) if room.player_layer==0 else Vector2(3.5,1.7)
		if not room.walk_to(mouth):_retry("楼梯入口暂不可达");return
		stage.phase=3
	if int(stage.phase)==3 and not room.player.is_navigating():
		if not room.walk_to(room.stairs_position(room.player_layer)):_retry("楼梯暂不可达");return
		stage.phase=4
	if int(stage.phase)==4 and room.player_layer!=int(stage.origin) and not room.arrival_busy():stage.finished=true

func _push(dt:float) -> void:
	var id:int=stage.weight;var w:Dictionary=room.state.weights[id]
	if int(stage.phase)==0:
		if not _idle() or w.mode!="rest" or float(w.elevation)>.03:return
		if w.station==stage.destination:stage.finished=true;return
		room.view_layer=room.player_layer
		var direction:=Route.next_direction(room.state,id,stage.destination)
		if direction==Vector2.ZERO:_fail("没有找到可用的运输通路。");return
		var preview:Dictionary=room.push_preview(id,direction)
		if not preview.valid:_retry(preview.error);return
		stage["direction"]=direction;stage["stop"]=preview.target
		if not room.request_interaction("w%d"%id):_retry("方向选择暂不可用");return
		stage["choice_age"]=0.0;stage.phase=1
	if int(stage.phase)==1:
		stage.choice_age+=dt
		var picker=room.hud.push_picker;var arrow:int=picker.DIRECTIONS.find(room.state.snap_direction(stage.direction))
		if not picker.visible or arrow<0:_retry("方向选择已失效");return
		picker.hovered=arrow;picker.queue_redraw();_point(picker.arrows[arrow].get_global_rect().get_center())
		if float(stage.choice_age)<.22:return
		if not picker.choose(arrow):_retry("本次推动未启动");return
		stage.phase=2
	if int(stage.phase)==2:
		if w.mode=="slide":_scene_focus((room.player_plan()+w.pos)*.5,int(w.layer),dt,false)
		elif _idle() and not room.player.is_navigating():
			if w.station!=stage.stop:_retry("镇纸没有到达预计止挡");return
			if w.station==stage.destination:stage.finished=true
			else:stage.phase=0

func _scene_focus(at:Vector2,layer_index:int,dt:float,both:bool) -> void:
	var view=room.view;room.view_layer=layer_index;view.auto_follow=false;view.frame_to_ui=true
	view.focus=view.focus.lerp(at,1.0-exp(-dt*5.0));view.target_zoom=.85 if both else .92
	if both:view.link_time=maxf(view.link_time,.12)

func _point(at:Vector2) -> void:pointer=at;pointer_age=.24;pointer_canvas.queue_redraw()
func _draw_pointer() -> void:
	if pointer_age<=0 or not active:return
	var color:=Color(Instruments.COPPER_TEXT,minf(1,pointer_age/.10))
	pointer_canvas.draw_polyline(PackedVector2Array([pointer+Vector2(0,-10),pointer+Vector2(7,0),pointer+Vector2(0,10),pointer+Vector2(-7,0),pointer+Vector2(0,-10)]),color,1.8,true)

func _retry(reason:String) -> void:
	attempts+=1
	if attempts>2:_fail(reason);return
	room.cancel_push_command();room.player.cancel_navigation();stage.started=false;stage.phase=0
	room._rebuild_navigation();room.view.return_to_actor()

func _fail(reason:String) -> void:
	print("PAPER_DEMO_FAILURE ",reason," step=",index," stage=",stage," actor=",room.player_plan()," layer=",room.player_layer," locked=",room.player.controls_locked," route=",room.player.route," pending=",room.pending," riding=",room.lift_riding," transition=",room.transition_age)
	mode="error";_pause_scene();title.text="演示已暂停";status.text=reason;pause_button.hide();repeat_button.show();exit_button.text="返回原进度"

func toggle_pause() -> void:
	if not active or mode in ["done","error"]:return
	paused=not paused
	if paused:_pause_scene();pause_button.text="继续"
	else:_resume_scene();pause_button.text="暂停";last_clock=Time.get_ticks_usec()

func _pause_scene() -> void:
	if not paused_nodes.is_empty():return
	if mode!="done":
		for voice in [flow.ambience.ui_voice,flow.ambience.gate_voice]:
			ambient_paused.append([voice,voice.stream_paused]);voice.stream_paused=true
	for node in owned:
		if is_instance_valid(node):
			# Pause visible scenes without hiding their frozen picture.
			_freeze(node,paused_nodes,false)
			for item in paused_nodes[-1].visible:
				if is_instance_valid(item[0]):item[0].visible=item[1]

func _completed() -> void:
	if not active or mode!="running":return
	final_state=room.state.snapshot();spoken_lines=room.communications.history.duplicate(true);history.append({"op":"exit","title":"走入归位门","seconds":elapsed})
	mode="archiving";status.text="演示中 · 观测记录归档";target_rate=1.25
	_archive.call_deferred(generation)

func _archive(token:int) -> void:
	if not active or token!=generation:return
	while paused and active and token==generation:await get_tree().process_frame
	if not active or token!=generation:return
	room.communications.stop();room.sound.stop_effects();room.player.cancel_navigation();room.player.controls_locked=true;room.hud.hide()
	var photo:Texture2D
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		if not active or token!=generation or not is_instance_valid(room):return
		photo=room.archive_texture()
	while paused and active and token==generation:await get_tree().process_frame
	if not active or token!=generation:return
	room.process_mode=Node.PROCESS_MODE_DISABLED
	for child in _tree(room):
		if child is CollisionObject2D:child.collision_layer=0;child.collision_mask=0
	archive=preload("res://scripts/archive_return.gd").new();archive.external_controls=true;archive.anchor_count=2
	archive.record_title="纸山叠影 · 双锚观测归档";archive.record_scene="纸山叠影 · 温州泽雅"
	flow.add_child(archive);owned.append(archive);archive.sound_cue.connect(flow.ambience.play_archive)
	archive.reveal_hub.connect(func():if active and token==generation:_reveal_hub())
	archive.finished.connect(func():if active and token==generation:_return_arrival())
	archive.begin(photo,flow.paper_runs+1)

func _reveal_hub() -> void:
	hub=load("res://scripts/tutorial_hub.gd").new();hub.cleared=true;hub.player.automation_owned=true
	flow.current=hub;flow.add_child(hub);owned.append(hub)
	hub.prepare_return_arrival();hub.process_mode=Node.PROCESS_MODE_DISABLED
	for node in _tree(hub):node.set_process_input(false);node.set_process_unhandled_input(false)

func _return_arrival() -> void:
	if not active:return
	archive.queue_free();archive=null
	if is_instance_valid(room):room.queue_free();room=null
	hub.process_mode=Node.PROCESS_MODE_INHERIT;hub.start_return_arrival();flow.ambience.play_entry()
	mode="returning";status.text="演示中 · 返回世界观察局"

func _done() -> void:
	finished_seconds=elapsed;runs_finished+=1;mode="done";_pause_scene();Engine.time_scale=float(backup.scale)
	title.text="纸山叠影 · 演示完成";status.text="已归档返回，原进度已保留。"
	pause_button.hide();repeat_button.show();exit_button.text="返回原进度";exit_button.grab_focus()
	print("PAPER_DEMO_COMPLETE seconds=",snappedf(finished_seconds,.01)," steps=",history.size())

func _resume_scene() -> void:
	_restore(paused_nodes)
	for item in ambient_paused:
		if is_instance_valid(item[0]):item[0].stream_paused=item[1]
	ambient_paused.clear()

func _dispose() -> void:
	_resume_scene()
	flow.ambience.ui_voice.stop();flow.ambience.gate_voice.stop()
	for node in owned:
		if is_instance_valid(node):
			node.process_mode=Node.PROCESS_MODE_DISABLED
			for child in _tree(node):
				if child is AudioStreamPlayer:child.stop();child.stream=null
			if node.get_parent()!=null:node.get_parent().remove_child(node)
			node.queue_free()
	owned.clear();room=null;hub=null;archive=null

func stop() -> void:
	if not active:return
	active=false;generation+=1;_dispose();Engine.time_scale=float(backup.scale)
	flow.current=original;original.player.remove_meta("presentation_frozen");_restore(frozen)
	get_viewport().canvas_transform=backup.canvas;flow.ambience.dialogue_active=backup.duck
	flow.save_feedback.visible=backup.save_feedback;flow.return_menu_button.visible=backup.nav;flow.ambience.toggle_button.visible=backup.sound_button
	flow.paper_demo=null;queue_free()

func _input(event:InputEvent) -> void:
	if not active:return
	if event is InputEventKey:
		if event.physical_keycode in [KEY_M,KEY_F11]:return
		if event.pressed and not event.echo:
			if event.physical_keycode==KEY_ESCAPE:toggle_pause()
			elif event.physical_keycode==KEY_F10:stop();flow.request_title_return()
			elif event.physical_keycode in [KEY_TAB,KEY_ENTER,KEY_SPACE]:return
		get_viewport().set_input_as_handled()
