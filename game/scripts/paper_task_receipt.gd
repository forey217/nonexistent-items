extends Control
## Receipts observe settled facts; neither text changes nor checkpoint increments complete tasks.
const Palette=preload("res://scripts/instrument_theme.gd")
const TITLES:=["寻找上层工具间的留影夹","升起并固定下层接物台，准备安全落点","让山纹镇纸安全落到下层接物区","将山纹镇纸送回上层锚座","将山纹镇纸送至上层锚座","将水纹镇纸送至下层导向井，稳定高处锚位","双锚已定，返回上层归档"]
const STAMP_TIME:=.20
const HOLD_TIME:=1.20
const OUT_TIME:=.15
const IN_TIME:=.15
var hud:Node
var heading:Label
var body:Label
var stamp:Label
var next_tag:Label
var card:Control
var page:=Control.new()
var phase:="idle"
var age:=2.0
var pending:Array[Dictionary]=[]
var seen:Dictionary={}
var history:Array[int]=[]
var current:Dictionary={}
var live:Dictionary={}
var active:Dictionary={}
var stage:=0
var tag_age:=2.0
var body_height:=52.0
var resting_height:=92.0
var content_alpha:=1.0
var completed_alpha:=0.0
var border_alpha:=0.0
var motion:=true
var layout_key:=""
var border:=StyleBoxFlat.new()
var font=Palette.body()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;card=get_parent()
	card.set_meta("task_transition",self)
	page.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(page)
	heading=Palette.label(page,"",Vector2(14,7),Vector2(272,25),17,Palette.COPPER_TEXT)
	body=Palette.label(page,"",Vector2(14,32),Vector2(272,52),20)
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	stamp=Palette.label(page,"校准完成",Vector2.ZERO,Vector2(102,28),17,Color("e3c996"))
	stamp.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stamp.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	next_tag=Palette.label(page,"下一步",Vector2.ZERO,Vector2(60,23),15,Palette.COPPER_TEXT)
	next_tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	border.bg_color=Color.TRANSPARENT;border.set_border_width_all(1)
	baseline()

func facts() -> Array[bool]:
	var s=hud.room.state;var m:Dictionary=s.weights[0]
	return [s.clip_owned,s.clip_target=="catch" and s.catch_height>=.98,
		s.hatch_broken and int(m.layer)==1 and m.mode=="rest" and m.station=="catch",
		s.lifted_once and int(m.layer)==0 and m.mode=="rest" and s.lift_docked(0),
		s.upper_anchored,s.upper_anchored and s.lower_anchored,hud.room.finished]

func model(index:int) -> Dictionary:
	return {"stage":mini(index,6),"text":TITLES[mini(index,6)],"number":clampi(hud.room.state.checkpoint+1,1,7)}

func baseline() -> void:
	pending.clear();seen.clear();history.clear();active.clear();phase="idle";age=2;tag_age=2
	var s=hud.room.state;var f:=facts()
	# Stable save flags establish historical completion without adding save fields.
	stage=6 if s.lower_anchored else 5 if s.upper_anchored else 4 if s.lifted_once and int(s.weights[0].layer)==0 else 3 if s.hatch_broken and int(s.weights[0].layer)==1 and s.weights[0].mode=="rest" else 2 if s.checkpoint>=2 or s.support_released else 1 if s.clip_owned else 0
	for i in range(7):
		if i<stage or f[i]:seen[i]=true
	live=model(stage);_show(live);_pose()

func observe() -> void:
	var f:=facts()
	for i in range(7):
		if not f[i] or seen.has(i):continue
		seen[i]=true
		# A later fact never fabricates completion receipts for skipped objectives.
		if i<stage:continue
		var done:Dictionary=current.duplicate() if int(current.get("stage",-1))==i and phase=="idle" else model(i)
		done.number=clampi(i+1,1,7) if int(live.get("stage",-1))!=i else live.number
		stage=mini(i+1,6);live=model(stage)
		pending.append({"id":i,"done":done,"next":live.duplicate(),"final":i==6})
		assert(pending.size()<=7)
	if phase=="idle" and pending.is_empty():
		live=model(stage)
		if current!=live:_show(live)
	if phase=="idle" and not pending.is_empty():_start()

func _start() -> void:
	active=pending.pop_front();history.append(active.id);phase="stamp";age=0;tag_age=2
	_show(active.done)
	# Archive departure may disable this room immediately. Keep the last receipt
	# visible without adding a new delay to the established completion sequence.
	if active.final:phase="final";age=2;_pose()

func _show(value:Dictionary) -> void:
	current=value.duplicate();body.text=current.text
	heading.text="纸山叠影　%d / 7"%current.number
	_layout_text()

func _layout_text() -> void:
	var width:=card.size.x
	var reserve:=27.0 if phase in ["stamp","out","final"] else 0.0
	var key:="%s:%s:%s"%[width,reserve,body.text]
	if key==layout_key:return
	layout_key=key;heading.size.x=width-28
	body.position.x=14+reserve;body.size.x=width-28-reserve
	var paragraph:=TextParagraph.new();paragraph.width=body.size.x
	paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
	paragraph.add_string(body.text,font,20)
	body_height=maxf(48,paragraph.get_size().y+4);body.size.y=body_height
	resting_height=maxf(92,body_height+42)
	stamp.position=Vector2(width-118,body_height+38)
	stamp.pivot_offset=stamp.size*.5
	next_tag.position=Vector2(width-74,8)

func tick(delta:float) -> void:
	if hud.menu.visible:return
	if hud.room.presentation_mode:delta/=maxf(.01,Engine.time_scale)
	motion=hud.audio==null or hud.audio.preferences.motion_enabled
	tag_age+=delta
	var remaining:=maxf(0.0,delta)
	while remaining>0:
		if phase in ["idle","final"]:break
		var duration:=STAMP_TIME+HOLD_TIME if phase=="stamp" else OUT_TIME if phase=="out" else IN_TIME
		var used:=minf(remaining,maxf(0,duration-age));age+=used;remaining-=used
		if age<duration:break
		if phase=="stamp":
			if active.final:phase="final";age=2;break
			phase="out";age=0
		elif phase=="out":
			phase="in";age=0;tag_age=0;_show(active.next)
		else:
			phase="idle";age=2
			if not pending.is_empty():_start()
	_pose()

func _pose() -> void:
	_layout_text()
	var done:=phase in ["stamp","out","final"]
	completed_alpha=smoothstep(0,.18,age) if phase=="stamp" else 1.0 if done else 0.0
	border_alpha=(1.0-smoothstep(.10,.42,age)) if phase=="stamp" else 0.0
	content_alpha=1.0
	var shift:=0.0
	if phase=="out":
		content_alpha=1.0-smoothstep(0,OUT_TIME,age);shift=-6*smoothstep(0,OUT_TIME,age) if motion else 0.0
	elif phase=="in":
		content_alpha=smoothstep(0,IN_TIME,age);shift=6*(1.0-smoothstep(0,IN_TIME,age)) if motion else 0.0
	page.position.y=shift;page.modulate.a=content_alpha
	stamp.visible=done;stamp.modulate.a=completed_alpha
	stamp.scale=Vector2.ONE*(lerpf(1.12,1.0,smoothstep(0,.18,age)) if motion and phase=="stamp" else 1.0)
	body.add_theme_color_override("font_color",Palette.TEXT.lerp(Color("fff0cd"),.55) if done else Palette.TEXT)
	next_tag.visible=not done and tag_age<1.0;next_tag.modulate.a=1.0-smoothstep(.70,1.0,tag_age)
	var expansion:=smoothstep(0,.20,age) if phase=="stamp" else 1.0 if phase in ["out","final"] else 1.0-smoothstep(0,IN_TIME,age) if phase=="in" else 0.0
	card.size.y=resting_height+34*expansion
	size=card.size;page.size=size
	queue_redraw()

func confirm(_receipt:String="") -> void:pass # Compatibility: generic resonance receipts never complete objectives.
func cancel() -> void:baseline()

func _draw() -> void:
	if border_alpha>0:
		border.border_color=Color("e6ce9b",border_alpha*.9)
		draw_style_box(border,Rect2(Vector2.ZERO,card.size))
	if completed_alpha<=0:return
	var ink:=Color("e3c996",completed_alpha*content_alpha)
	var offset:=page.position
	draw_polyline(PackedVector2Array([Vector2(15,45)+offset,Vector2(21,51)+offset,Vector2(32,37)+offset]),ink,2.3,true)
	var rect:=Rect2(stamp.position+offset+(Vector2.ONE-stamp.scale)*stamp.size*.5,stamp.size*stamp.scale)
	# A compact cut-corner archive seal. All wording is rendered with the real font.
	var a:=rect.position;var b:=rect.end;var c:=5.0
	draw_polyline(PackedVector2Array([a+Vector2(c,0),Vector2(b.x, a.y),Vector2(b.x,b.y-c),b-Vector2(c,0),Vector2(a.x,b.y),a+Vector2(0,c),a+Vector2(c,0)]),ink,1,true)
	draw_rect(rect.grow(-3),Color(ink,.45*ink.a),false,1)
