extends Node
## Non-modal communications. Read progress belongs to finished lines, never to a timer starting.
const Lines=preload("res://scripts/paper_mill_lines.gd")
var room:Node
var voice=preload("res://scripts/dialogue_voice.gd").new()
var enabled:=true
var presentation_mode:=false
var seen:Dictionary={}
var done:Dictionary={}
var pending:Array[Dictionary]=[]
var active:Dictionary={}
var remaining:=0.0
var total:=0.0
var previous:Dictionary={}
var first_target:=""
var first_world:=-1
var confirmed:=false
var idle:=0.0
var idle_notified:Dictionary={}
var context:=""
var gap_age:=0.0
var bridge_age:=0.0
var history:Array[Dictionary]=[]
const CONFIRMATIONS:=["P2-04-catch","P2-04-bridge","P2-05","P2-06","P2-07","P2-08"]
var acknowledged:Dictionary={}

func _ready() -> void:
	voice.library_root="res://assets/audio/paper_dialogue_v01/";add_child(voice)
	var args:=OS.get_cmdline_user_args()
	enabled="--paper-story-check" in args or "--paper-story-live" in args or not Array(args).any(func(arg):return not arg.contains("=") and arg.ends_with("-check"))
	previous=_physical();_schedule("P2-01",1.5,10)

func _physical() -> Dictionary:
	var s=room.state
	return {"clip":s.clip_owned,"target":s.clip_target,"mountain_layer":int(s.weights[0].layer),"mountain_mode":s.weights[0].mode,
		"lifted":s.lifted_once,"upper":s.upper_anchored,"lower":s.lower_anchored,"worlds":s.worlds.duplicate(),
		"motion":[s.weights[0].pos,s.weights[1].pos,s.weights[0].elevation,s.weights[1].elevation,s.catch_height,s.lift_height]}

func valid(key:String) -> bool:
	var s=room.state;var m:Dictionary=s.weights[0]
	match key:
		"P2-01":return not s.clip_owned
		"P2-02":return not s.clip_owned and room.player_layer==0 and int(s.worlds[0])!=3
		"P2-03":return s.clip_owned and not s.hatch_broken
		"P2-04-catch":return first_target=="catch" and s.clip_target=="catch" and s.catch_height>=.98 and not s.hatch_broken
		"P2-04-bridge":return first_target=="bridge" and s.clip_target=="bridge" and not s.upper_anchored
		"P2-04-confirm":return confirmed and s.clip_target==first_target and not s.upper_anchored
		"clip-limit":return s.clip_owned and not s.lower_anchored
		"P2-05":return s.hatch_broken and int(m.layer)==1 and m.mode=="rest" and m.station=="catch" and not s.lifted_once
		"P2-06":return s.lifted_once and int(m.layer)==0 and m.mode=="rest" and s.lift_docked(0) and not s.upper_anchored
		"P2-06-bridge":return s.lifted_once and not s.upper_anchored and not s.bridge_solid() and room.player_layer==0
		"P2-07":return s.upper_anchored and not s.lower_anchored
		"P2-08":return s.upper_anchored and s.lower_anchored
		"idle":return active.get("context",context)==context
	if key.begins_with("hint:"):return key.split(":")[1]==Lines.hint_key(s)
	return false

func _schedule(key:String,delay:float,priority:int) -> void:
	if presentation_mode and key not in ["P2-04-catch","P2-05","P2-06","P2-08"]:return
	if done.has(key) or active.get("key","")==key or acknowledged.has(key):return
	for item in pending:
		if item.key==key:return
	pending.append({"key":key,"delay":delay,"priority":priority,"expires":8.0})
	# Only current observations survive. Bound even malformed or repeated calls.
	pending=pending.filter(func(item):return valid(item.key))
	if pending.size()>4:pending.pop_front()

func notify_attempt() -> void:idle=0.0;gap_age=0.0;bridge_age=0.0

func _blocked() -> bool:
	return room.arrival_busy() or room.interacting or room.world_cast_time>0 or room.finished or (room.state.lower_anchored and room.view.paper_unfold<.999)

func set_paused(paused:bool) -> void:
	voice.player.stream_paused=paused

func tick(delta:float) -> void:
	if presentation_mode:delta/=maxf(Engine.time_scale,.01)
	if not enabled:return
	set_paused(room.hud.menu.visible)
	if room.hud.menu.visible:return
	var now:=_physical();var s=room.state
	var moving:bool=now.motion!=previous.get("motion",now.motion)
	if now.clip and not previous.get("clip",false):_schedule("P2-03",.8,60)
	if now.target!="" and now.target!=previous.get("target",""):
		if first_target.is_empty():
			first_target=now.target;first_world=int(s.worlds[1 if first_target=="catch" else 0])
			_schedule("P2-04-"+first_target,.6,65)
		elif now.target!=first_target:_schedule("clip-limit",.6,40)
	if not confirmed and not first_target.is_empty() and s.clip_target==first_target:
		if int(s.worlds[1 if first_target=="catch" else 0])!=first_world:
			confirmed=true;_schedule("P2-04-confirm",.6,45)
	if int(now.mountain_layer)==1 and now.mountain_mode=="rest" and (int(previous.get("mountain_layer",0))==0 or previous.get("mountain_mode","")=="fall"):
		_schedule("P2-05",.8,70)
	if now.lifted and not previous.get("lifted",false):_schedule("P2-06",1.0,70)
	if now.upper and not previous.get("upper",false):_schedule("P2-07",.8,80)
	if now.lower and not previous.get("lower",false):_schedule("P2-08",1.0,90)
	var next_context:=Lines.hint_key(s)
	if context!=next_context:
		context=next_context;room.hint_level=0;idle=0;room.hud.hint.text="需要一起分析时，按 H 联系特斯拉。"
		pending=pending.filter(func(item):return item.key!="idle")
	if moving or room.player.walking:notify_attempt()
	previous=now
	# Stage changes invalidate obsolete speech immediately, even during a cast or stairs.
	pending=pending.filter(func(item):return valid(item.key))
	if not active.is_empty() and not valid(active.key):_cancel()
	var blocked:=_blocked() or moving
	for item in pending:
		if CONFIRMATIONS.has(item.key):item.expires=float(item.get("expires",8))-delta
		if not blocked and not (item.key=="P2-08" and room.view.paper_unfold<.999):item.delay=maxf(0,item.delay-delta)
	if not active.is_empty():
		remaining=maxf(0,remaining-delta);room.story_time=remaining
		if remaining<=0:_finish_line()
	# A short observation must never become an old objective announcement.
	pending=pending.filter(func(item):return not CONFIRMATIONS.has(item.key) or float(item.get("expires",8))>0)
	var best:Dictionary={}
	if not blocked:
		for item in pending:
			if item.delay<=0 and (best.is_empty() or item.priority>best.priority):best=item
	if not best.is_empty() and (active.is_empty() or (not CONFIRMATIONS.has(best.key) and best.priority>=70 and best.priority>int(active.get("priority",0)))):
		if not active.is_empty():
			var resume:=active.key as String;var priority:=int(active.priority);_cancel();_schedule(resume,.4,priority)
		pending.erase(best);_begin(best)
	var observing:bool=not blocked and active.is_empty() and not room.player.walking and not room.player.controls_locked
	if observing:
		idle+=delta
		if idle>=35 and not idle_notified.has(context):
			idle_notified[context]=true;_schedule("idle",0,5)
		if valid("P2-02") and room.player_plan().distance_to(Vector2(6,10.4))<3.0:
			gap_age+=delta
			if gap_age>=5:_schedule("P2-02",0,20)
		else:gap_age=0
		if valid("P2-06-bridge") and room.player_plan().distance_to(s.BRIDGE)<3.0:
			bridge_age+=delta
			if bridge_age>=5:_schedule("P2-06-bridge",0,20)
		else:bridge_age=0
	room.story_time=remaining if not active.is_empty() else 0.0

func _begin(item:Dictionary) -> void:
	var lines:Array=item.get("lines",Lines.sequence(item.key))
	if presentation_mode:lines=lines.filter(func(line):return line.speaker=="yanyue")
	if not str(item.key).begins_with("hint:"):lines=lines.filter(func(line):return not seen.has(line.id))
	if lines.is_empty():done[item.key]=true;return
	active={"key":item.key,"priority":item.priority,"lines":lines,"context":context,"index":0}
	_start_line()

func _start_line() -> void:
	var line:Dictionary=active.lines[0]
	if CONFIRMATIONS.has(active.key) and line.speaker=="yanyue":
		acknowledged[active.key]=true;seen[line.id]=true
	var duration:=voice.start_line(line)
	total=duration+.25 if duration>0 else maxf(2.0,str(line.text).length()*.145+1)
	remaining=total;room.story_time=remaining
	room.hud.communicate(line.speaker,line.text,total)
	total=room.hud.subtitle_duration;remaining=total;room.story_time=remaining
	if is_instance_valid(room.mission_guide):room.mission_guide.begin_line(line,active.key,int(active.get("index",0)),context,total,voice.entries.get(line.id,{}))
	history.append({"node":active.key,"id":line.id,"text":line.text,"duration":total,"pitch_scale":voice.player.pitch_scale})
	if history.size()>160:history.pop_front()

func _finish_line() -> void:
	var key:String=active.key
	if not key.begins_with("hint:") and key!="idle":seen[active.lines[0].id]=true
	active.lines.pop_front();voice.stop()
	if is_instance_valid(room.mission_guide):room.mission_guide.cancel_line()
	active["index"]=int(active.get("index",0))+1
	if active.lines.is_empty():
		if key!="idle" and not key.begins_with("hint:"):done[key]=true
		active.clear();remaining=0;room.story_time=0
	else:_start_line()

func _cancel() -> void:
	voice.stop();active.clear();remaining=0;room.story_time=0
	if is_instance_valid(room.mission_guide):room.mission_guide.cancel_line()

func request_hint() -> void:
	notify_attempt()
	var key:=Lines.hint_key(room.state)
	if context!=key:context=key;room.hint_level=0
	room.hint_level=mini(3,room.hint_level+1)
	var text:String=Lines.hint_cases()[key][room.hint_level-1]
	room.hud.set_hint(text)
	if not enabled:return
	if not active.is_empty():
		var old:=str(active.key);var priority:=int(active.priority);_cancel()
		if not old.begins_with("hint:") and old!="idle":_schedule(old,.6,priority)
	pending=pending.filter(func(item):return not str(item.key).begins_with("hint:") and item.key!="idle")
	_begin({"key":"hint:"+key+":"+str(room.hint_level),"priority":100,"lines":[Lines.line("tesla",text)]})

func speaking() -> bool:return enabled and voice.speaking()
func stop() -> void:_cancel();pending.clear()

func snapshot() -> Dictionary:
	var keys:Array=[]
	for item in pending:
		if item.key!="idle" and not str(item.key).begins_with("hint:"):keys.append(item.key)
	if not active.is_empty() and active.key!="idle" and not str(active.key).begins_with("hint:"):keys.append(active.key)
	return {"version":2,"acknowledged":acknowledged.keys(),"seen":seen.keys(),"done":done.keys(),"pending":keys,"first_target":first_target,"first_world":first_world,"confirmed":confirmed,"idle_notified":idle_notified.keys()}

func restore(data:Dictionary,legacy:=false) -> void:
	var session_ack:=acknowledged.duplicate() if not data.is_empty() or legacy else {}
	stop();acknowledged=session_ack;seen.clear();done.clear();idle_notified.clear();first_target="";first_world=-1;confirmed=false;idle=0;context="";gap_age=0;bridge_age=0
	for id in data.get("acknowledged",[]):acknowledged[str(id)]=true
	# Restored mechanics are a baseline, not newly completed actions.
	var s=room.state
	if not data.is_empty() or legacy:
		if s.clip_target=="catch" or s.hatch_broken:acknowledged["P2-04-catch"]=true
		if s.clip_target=="bridge":acknowledged["P2-04-bridge"]=true
		if s.hatch_broken and (int(s.weights[0].layer)==1 or s.lifted_once):acknowledged["P2-05"]=true
		if s.lifted_once:acknowledged["P2-06"]=true
		if s.upper_anchored:acknowledged["P2-07"]=true
		if s.lower_anchored:acknowledged["P2-08"]=true
	for id in data.get("seen",[]):seen[str(id)]=true
	for id in data.get("done",[]):done[str(id)]=true
	for id in data.get("idle_notified",[]):idle_notified[str(id)]=true
	first_target=str(data.get("first_target",""));first_world=int(data.get("first_world",-1));confirmed=bool(data.get("confirmed",false))
	previous=_physical()
	if legacy:
		# Missing communications metadata is an older save, not permission to replay the opening.
		done["P2-01"]=true
		if s.clip_owned:
			done["P2-02"]=true;done["P2-03"]=true
		if not s.clip_target.is_empty() or s.hatch_broken:
			done["P2-04-catch"]=true;done["P2-04-bridge"]=true;done["P2-04-confirm"]=true
			first_target=s.clip_target;first_world=int(s.worlds[1 if first_target=="catch" else 0]);confirmed=true
		if s.hatch_broken and (int(s.weights[0].layer)==1 or s.lifted_once):done["P2-05"]=true
		if s.lifted_once:done["P2-06"]=true
		if s.upper_anchored:done["P2-07"]=true
		if s.lower_anchored:done["P2-08"]=true
		return
	for key in data.get("pending",[]):
		if Lines.NODES.has(key) and valid(key):_schedule(key,.8,80 if key=="P2-08" else 60)
	if data.is_empty():_schedule("P2-01",1.5,10)
