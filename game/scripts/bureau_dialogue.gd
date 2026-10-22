extends Node
## Session-scoped story and state-driven tutorial; never queues stale solutions.
const Lines = preload("res://scripts/dialogue_script.gd")
var flow: Node
var enabled := true
var view: CanvasLayer
var room: Node
var context := ""
var modal := false
var intro_seen := false
var debrief_seen := false
var tutorial_runs := 0
var pending: Array=[]
var active: Dictionary={}
var segment := ""
var seen: Dictionary={}
var history: Array[Dictionary]=[]
var phase := -1
var menu_phase := -1
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

func _ready() -> void:
	view=preload("res://scripts/dialogue_view.gd").new();add_child(view)
	view.advanced.connect(advance);view.skipped.connect(skip)

func bind(next_room: Node,kind: String) -> void:
	clear();room=next_room;context=kind;seen.clear();phase=-1;idle=0;elapsed=0
	first_push=false;first_float=false;hub_wait=kind=="hub"
	hub_near_age=0.0
	if kind=="hub":room.set_tesla_invitation(enabled and not intro_seen and not room.cleared)
	if kind=="tutorial":tutorial_runs+=1

func _footer(occupied: bool) -> void:
	if not is_instance_valid(room):return
	if context=="tutorial" and is_instance_valid(room.hud.footer):room.hud.footer.visible=not occupied
	elif context=="hub" and is_instance_valid(room.dialogue_footer):room.dialogue_footer.visible=not occupied

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
	if context=="tutorial" and is_instance_valid(room):room.orbit_view.teaching.stop()
	_set_modal(false);pending.clear();active.clear();segment="";timer=0
	if is_instance_valid(view):view.clear()
	_footer(false)

func play(id: String,lines: Array,once: bool=true) -> void:
	if not enabled or (once and seen.has(id)):return
	clear();seen[id]=true;segment=id;pending=lines.duplicate(true);_next()

func _next() -> void:
	if pending.is_empty():clear();return
	active=pending.pop_front()
	if context=="tutorial" and is_instance_valid(room) and room.state.world!=0 and active.text.begins_with("现在是冰晶世界"):
		active.text="先试试冰晶世界。那里的导轨摩擦很小，适合运送镇纸。"
	var style: String=active.get("style","subtitle")
	_set_modal(style=="story")
	var visual: String=active.get("visual","")
	view.set_subtitle_background(is_instance_valid(flow.level_menu) or flow.returning)
	if flow.returning:view.layer=110
	view.present(active.speaker,active.text,style,active.get("cue",""),active.get("exhibit",""),visual);_footer(true)
	if context=="tutorial" and is_instance_valid(room):room.orbit_view.teaching.start(visual)
	timer=clampf(1.0+active.text.length()*0.10,2.4,6.5)
	if style=="light":timer=maxf(timer,4.5)
	history.append({"segment":segment,"speaker":active.speaker,"text":active.text,"style":style,"phase":phase,"visual":visual})
	if history.size()>250:history.pop_front()

func advance() -> void:
	if modal:_next()

func skip() -> void:
	if not modal:return
	clear()
	if context=="hub":play("after-skip",[Lines.line("tesla","准备好了，就到星系仪旁边来。")],false)

func talk_to_tesla() -> void:
	if not enabled or modal or context!="hub" or not is_instance_valid(room):return
	if flow.menu_revealing or flow.returning or room.arrival_busy():return
	hub_wait=false
	room.set_tesla_invitation(false)
	if not intro_seen:
		intro_seen=true;play("opening",Lines.opening(),false)
	elif room.cleared:
		debrief_seen=true;play("debrief",Lines.debrief(),false)
	else:play("reminder",[Lines.line("tesla","先到星系仪旁边，找出那片区域。","story"),Lines.line("tesla","先定星位，再压月痕，最后封界缝。","story")],false)

func hint(text: String) -> void:
	play("hint",[Lines.line("tesla",text,"light","H  再看一层提示")],false)

func reset_tutorial() -> void:
	clear();seen.clear();phase=0;first_push=false;first_float=false;idle=0
	play("reset",[Lines.line("tesla","现场已复位。我们重新来，这次留意每次变化带来的结果。"),Lines.line("tesla","先试试冰晶世界。那里的导轨摩擦很小，适合运送镇纸。","light","1  冰晶 · E 推动")])

func notice(text: String) -> void:
	if elapsed-notice_time<6.0:return
	notice_time=elapsed
	play("notice",[Lines.line("tesla",text)],false)

func begin_selection() -> void:
	clear();hub_wait=false;menu_phase=-1

func archive() -> void:
	clear();play("archive",[Lines.line("tesla","现场校准完成。开始归档。")],false)

func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(room):return
	elapsed+=delta
	if is_instance_valid(flow.level_menu):
		var next_phase: int=flow.level_menu.phase
		if next_phase!=menu_phase:
			menu_phase=next_phase
			if next_phase==0:play("select-whole",Lines.selection(false),false)
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
				play("opening",Lines.opening().slice(8 if "--paperweight-preview" in args else 5))
			else:
				hub_near_age=hub_near_age+delta if room.player.position.distance_to(room.npc.position)<=145.0 else 0.0
				if hub_near_age>=0.3:talk_to_tesla()
		else:hub_wait=false
	elif context=="tutorial" and not flow.returning and not room.arrival_busy() and not room.finished:
		_tick_tutorial(delta)
	if not active.is_empty() and not modal:
		timer-=delta
		if timer<=0:_next()

func _tick_tutorial(delta: float) -> void:
	var state=room.state
	var step: int=state.stage()
	if step==5 and not room.gate_ready:step=4
	if step!=phase:
		var old:=phase;phase=step;idle=0
		clear()
		if old==5 and step==4:
			play("gate-lost",[Lines.line("yanyue","门又关了。"),Lines.line("tesla","封界踏板需要持续受压。切回重力世界，等镇纸落稳，再回来。","light","2  重力")],false)
		elif not seen.has("stage-%d"%step):play("stage-%d"%step,Lines.tutorial(step,state.world,tutorial_runs>1))
		elif step==5:play("gate-restored",[Lines.line("tesla","归位门已经稳定。保持重力世界，通过归位门回来。")],false)
	else:idle+=delta
	if not first_push and absf(state.rail_speed)>0.1:
		first_push=true
		play("first-push",[Lines.line("yanyue","真的只推了一下……它自己滑过去了。","subtitle","","","law-ice"),Lines.line("tesla","留意挡块。它会替你接住镇纸。")])
	if state.world==2 and state.elevation>3 and not first_float:
		first_float=true
		if phase==3:
			play("first-float",[Lines.line("yanyue","纸片也飘起来了……我怎么还站在地上？","subtitle","","","law-inverted"),Lines.line("tesla","检查员的靴子有固定装置。工作时，你得先站得稳。")])
		elif phase<3:
			play("early-float",[Lines.line("yanyue","升起来了，可这里没有印座。"),Lines.line("tesla","方向找对了，还需要找对位置。月痕在导轨尽头的上方。","light")])
	if idle>18 and active.is_empty() and not seen.has("idle-%d"%phase):
		seen["idle-%d"%phase]=true
		var message: String=state.hint(2)
		if phase==2:message="切回冰晶世界，再推一次。挡块已经打开，这次它能滑到尽头。"
		play("idle",[Lines.line("tesla",message,"light","H  逐步提示")],false)
