extends Node
## Session-scoped story and state-driven tutorial; never queues stale solutions.
const Lines = preload("res://scripts/dialogue_script.gd")
var flow: Node
var enabled := true
var view: CanvasLayer
var voice: Node
var room: Node
var context := ""
var modal := false
var intro_seen := false
var globe_awakened:=false
var globe_guided:=false
var debrief_seen := false
var tutorial_runs := 0
var pending: Array=[]
var active: Dictionary={}
var segment := ""
var seen: Dictionary={}
var history: Array[Dictionary]=[]
var phase := -1
var menu_phase := -1
var selection_prompt_seen := false
var timer := 0.0
var idle := 0.0
var elapsed := 0.0
var hub_wait := false
var first_push := false
var first_float := false
var locked_room: Node
var saved_mode := Node.PROCESS_MODE_INHERIT
var saved_lock := false
var notice_time := -10.0
var hub_near_age := 0.0
const IDLE_SECONDS:=35.0
var observed_position:=Vector2.ZERO
var observed_world:=-1
var observed_rail:=-1.0
var observed_height:=-1.0
var caption_duration:=0.0
var deferred_stage:Dictionary={}

func _ready() -> void:
	voice=preload("res://scripts/dialogue_voice.gd").new()
	var args:=OS.get_cmdline_user_args()
	# Existing accelerated mechanics/UI suites retain their original timing.
	voice.enabled="--voice-check" in args or not Array(args).any(func(arg):return arg.ends_with("-check") or arg.ends_with("-self-test") or arg.ends_with("-demo") or arg.contains("capture"))
	add_child(voice)
	view=preload("res://scripts/dialogue_view.gd").new();add_child(view)
	view.voice=voice
	view.advanced.connect(advance);view.skipped.connect(skip)

func bind(next_room: Node,kind: String) -> void:
	clear();deferred_stage.clear();room=next_room;context=kind;seen.clear();phase=-1;idle=0;elapsed=0
	first_push=false;first_float=false;hub_wait=kind=="hub"
	hub_near_age=0.0
	observed_position=room.player.position;observed_world=-1;observed_rail=-1;observed_height=-1
	if kind=="hub":
		room.set_tesla_invitation(enabled and not intro_seen and not room.cleared)
		if enabled and intro_seen and not globe_guided and not room.cleared:room.begin_globe_guidance(false)
	if kind=="tutorial":tutorial_runs+=1

func _footer(occupied: bool) -> void:
	if not is_instance_valid(room):return
	if context=="tutorial" and is_instance_valid(room.hud.footer):room.hud.set_dialogue_occupied(occupied,modal)
	elif context=="hub" and is_instance_valid(room.movement_hint):
		room.movement_hint.obscure(occupied);room.obscure_globe_guidance(occupied and modal)

func _set_modal(value: bool) -> void:
	if modal==value:return
	modal=value
	if value and is_instance_valid(room):
		locked_room=room;saved_mode=room.process_mode;saved_lock=room.player.controls_locked
		if context=="hub":room.face_tesla()
		room.player.cancel_navigation();room.player.controls_locked=true;room.process_mode=Node.PROCESS_MODE_DISABLED
	elif is_instance_valid(locked_room):
		locked_room.process_mode=saved_mode;locked_room.player.controls_locked=saved_lock
		locked_room=null

func clear() -> void:
	if is_instance_valid(voice):voice.stop()
	if is_instance_valid(flow.ambience):flow.ambience.dialogue_active=false
	if context=="tutorial" and is_instance_valid(room):room.orbit_view.teaching.stop()
	_set_modal(false);pending.clear();active.clear();segment="";timer=0
	if is_instance_valid(view):view.clear()
	_footer(false)

func play(id: String,lines: Array,once: bool=true) -> void:
	if not enabled or (once and seen.has(id)):return
	clear();seen[id]=true;segment=id;pending=lines.duplicate(true);_next()

func _next() -> void:
	if pending.is_empty():
		var opening_done:=segment=="opening" and context=="hub"
		clear()
		if opening_done:_complete_opening()
		return
	active=pending.pop_front()
	if context=="tutorial" and is_instance_valid(room) and room.state.world!=0 and active.text.begins_with("现在是冰晶世界"):
		active.text="先试试冰晶世界。那里的导轨摩擦很小，适合运送镇纸。"
	active.id=Lines.voice_id(active.speaker,active.text)
	var voice_duration: float=voice.start_line(active)
	var style: String=active.get("style","subtitle")
	_set_modal(style=="story")
	var visual: String=active.get("visual","")
	view.set_subtitle_background(is_instance_valid(flow.level_menu) or flow.returning)
	view.level_hud_layout=context=="tutorial" and not flow.returning
	if flow.returning:view.layer=110
	view.present(active.speaker,active.text,style,active.get("cue",""),active.get("exhibit",""),visual);_footer(true)
	if context=="tutorial" and is_instance_valid(room):view.keep_subtitle_clear_of(room.hud.skill_panel)
	if context=="tutorial" and is_instance_valid(room):room.orbit_view.teaching.start(visual)
	timer=clampf(1.0+active.text.length()*0.10,2.4,6.5)
	if style=="light":timer=maxf(timer,4.5)
	if visual=="anchors":timer=maxf(timer,4.5)
	if voice_duration>0:timer=maxf(timer,voice_duration+0.25)
	if view.level_hud_layout and not modal:
		timer=maxf(timer,view.caption_pages.size()*2.4)
		caption_duration=timer;view.caption_duration=timer
	if context=="tutorial" and visual=="anchors" and voice_duration>0:
		var cues: Dictionary=voice.current.get("cue_seconds",{})
		room.orbit_view.teaching.sync_speech(voice,cues,voice_duration+0.20)
	history.append({"id":active.id,"segment":segment,"speaker":active.speaker,"text":active.text,"style":style,"phase":phase,"visual":visual})
	if history.size()>250:history.pop_front()

func advance() -> void:
	if modal:_next()

func skip() -> void:
	if not modal:return
	var opening_done:=segment=="opening" and context=="hub"
	clear()
	if context=="hub":play("after-skip",Lines.event("after-skip"),false)
	if opening_done:_complete_opening()

func _complete_opening() -> void:
	if not is_instance_valid(room) or globe_guided or globe_awakened:return
	globe_awakened=true;room.begin_globe_guidance()

func talk_to_tesla() -> void:
	if not enabled or modal or context!="hub" or not is_instance_valid(room):return
	if flow.menu_revealing or flow.returning or room.arrival_busy():return
	hub_wait=false
	room.set_tesla_invitation(false)
	if not intro_seen:
		intro_seen=true;play("opening",Lines.opening(),false)
	elif room.cleared:
		debrief_seen=true;play("debrief",Lines.debrief(),false)
	else:play("reminder",Lines.event("reminder"),false)

func hint(text: String) -> void:
	idle=0
	var visual:=""
	if context=="tutorial" and is_instance_valid(room) and room._hint_level>=2:
		if text.contains("倒悬"):visual="law-inverted"
		elif text.contains("重力"):visual="law-heavy"
		elif text.contains("冰晶"):visual="law-ice"
	play("hint",[Lines.line("tesla",text,"light","H  再看一层提示","",visual)],false)

func reset_tutorial() -> void:
	clear();deferred_stage.clear();seen.clear();phase=0;first_push=false;first_float=false;idle=0
	play("reset",Lines.event("reset"))

func suppress_restored_confirmations() -> void:
	deferred_stage.clear()
	phase=room.state.stage()
	if phase==5 and not room.gate_ready:phase=4
	for step in range(phase+1):seen["stage-%d"%step]=true
	for id in room.task_feedback.seen:
		var step:int={"star":2,"moon":4,"seal":5}.get(id,-1)
		if step>=0:seen["stage-%d"%step]=true

func notice(text: String) -> void:
	if elapsed-notice_time<6.0:return
	notice_time=elapsed
	play("notice",[Lines.line("tesla",text)],false)

func begin_selection() -> void:
	clear();hub_wait=false;menu_phase=-1

func archive() -> void:
	deferred_stage.clear();clear();play("archive",Lines.event("archive"),false)

func _process(delta: float) -> void:
	if is_instance_valid(room) and room.get("hud")!=null and room.hud.get("menu")!=null and room.hud.menu.visible:return
	if is_instance_valid(voice) and is_instance_valid(flow.ambience):flow.ambience.dialogue_active=voice.speaking() or (is_instance_valid(flow.current) and flow.current.get("communications")!=null and flow.current.communications.speaking())
	if not enabled or not is_instance_valid(room):return
	elapsed+=delta
	if is_instance_valid(flow.level_menu):
		var next_phase: int=flow.level_menu.phase
		if next_phase!=menu_phase:
			menu_phase=next_phase
			if next_phase==0:
				if not selection_prompt_seen:
					selection_prompt_seen=true
					play("select-whole",Lines.selection(false),false)
			elif next_phase==2:play("select-fragments",Lines.selection(true),false)
			else:clear()
	elif context=="hub" and hub_wait and not flow.menu_revealing and not flow.returning and not room.arrival_busy() and elapsed>0.5:
		if room.cleared and not debrief_seen:
			hub_wait=false
			debrief_seen=true;play("debrief",Lines.debrief())
		elif not room.cleared and not intro_seen:
			var args:=OS.get_cmdline_user_args()
			if "--paperweight-preview" in args or "--teaching-preview" in args:
				hub_wait=false;intro_seen=true;room.set_tesla_invitation(false)
				play("opening",Lines.opening().slice(4 if "--paperweight-preview" in args else 2))
			else:
				hub_near_age=hub_near_age+delta if room.player.position.distance_to(room.npc.position)<=145.0 else 0.0
				if hub_near_age>=0.3:talk_to_tesla()
		else:hub_wait=false
	elif context=="tutorial" and not flow.returning and not room.arrival_busy() and not room.finished:
		_tick_tutorial(delta)
	if not active.is_empty() and not modal:
		timer-=delta
		if view.level_hud_layout:view.set_caption_elapsed(caption_duration-timer)
		if timer<=0 and not voice.speaking():_next()

func _tick_tutorial(delta: float) -> void:
	var state=room.state
	var step: int=state.stage()
	if step==5 and not room.gate_ready:step=4
	if step!=phase:
		var old:=phase;phase=step;idle=0
		deferred_stage.clear()
		if old==5 and step==4:
			play("gate-lost",Lines.event("gate-lost"),false)
		elif not seen.has("stage-%d"%step):
			if step in [2,4,5]:
				# Let the latch sound speak first. H and story speech keep priority.
				deferred_stage={"step":step,"delay":.45,"expires":4.0}
				if segment!="hint":clear()
			else:play("stage-%d"%step,Lines.tutorial(step,state.world,tutorial_runs>1))
		elif step==5:play("gate-restored",Lines.event("gate-restored"),false)
	if not deferred_stage.is_empty():
		deferred_stage.delay-=delta;deferred_stage.expires-=delta
		var scheduled:int=deferred_stage.step
		if scheduled!=step or deferred_stage.expires<=0:
			seen["stage-%d"%scheduled]=true;deferred_stage.clear()
		elif deferred_stage.delay<=0 and active.is_empty():
			deferred_stage.clear();play("stage-%d"%scheduled,Lines.tutorial(scheduled,state.world,tutorial_runs>1))
	if not first_push and absf(state.rail_speed)>0.1:
		first_push=true
		play("first-push",Lines.event("first-push"))
	if state.world==2 and state.elevation>3 and not first_float:
		first_float=true
		if phase==3:
			play("first-float",Lines.event("first-float"))
		elif phase<3:
			play("early-float",Lines.event("early-float"))
	_tick_idle(delta)

func _input(event: InputEvent) -> void:
	if context!="tutorial" or not enabled:return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):idle=0

func _tick_idle(delta: float) -> void:
	var state=room.state
	var changed: bool=observed_position.distance_squared_to(room.player.position)>0.01 or observed_world!=state.world or absf(observed_rail-state.rail_position)>0.01 or absf(observed_height-state.elevation)>0.01
	observed_position=room.player.position;observed_world=state.world;observed_rail=state.rail_position;observed_height=state.elevation
	var blocked: bool=modal or not active.is_empty() or flow.menu_revealing or flow.returning or room.arrival_busy() or room.casting or room.interacting or room.seal_active or room.finished or room.player.controls_locked or room.orbit_view.dragging or room.player.is_navigating() or room.player.walking or absf(state.rail_speed)>0.1 or absf(state.vertical_speed)>0.1
	if changed:idle=0
	elif not blocked:idle+=delta
	if not blocked and idle>=IDLE_SECONDS and not seen.has("idle-%d"%phase):
		seen["idle-%d"%phase]=true
		play("idle",Lines.event("idle"),false)
