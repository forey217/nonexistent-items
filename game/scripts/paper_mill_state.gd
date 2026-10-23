extends RefCounted
## Deterministic mechanisms and continuous motion, shared by play and recording.
signal event(kind: String)
const HEIGHT:=4.8
const DROP:=Vector2(11,10)
const LIFT:=Vector2(18,7)
const TOOL:=Vector2(5,13)
const STAIRS:=Vector2(3.5,8.8)
const LOWER_STAIRS:=Vector2(3.5,2.8)
const UPPER_ANCHOR:=Vector2(20,14)
const LOWER_ANCHOR:=Vector2(15,13)
const EXIT:=Vector2(19,16.1)
const CATCH_PLATE:=Vector2(7,8)
const SLUICE:=Vector2(18,4)
const BRIDGE:=Vector2(18,11)
const WORLD_NAMES:=["冰晶","重力","倒悬","显影"]
const WATER_STOPS:={"cage":Vector2(5,12),"catch":CATCH_PLATE,"junction":Vector2(11,8),"sluice":SLUICE,"guide":LOWER_ANCHOR}
const MOUNTAIN_STOPS:={"catch":DROP,"junction":Vector2(15,10),"lift":LIFT,"dock":Vector2(18,8.5),"bridge":Vector2(18,12.5),"anchor":UPPER_ANCHOR}
var worlds:Array[int]=[0,0]
var weights:Array[Dictionary]=[]
var clip_owned:=false
var clip_target:=""
var cage_open:=false
var support_released:=false
var hatch_broken:=false
var catch_height:=0.0
var lift_height:=0.0
var lifted_once:=false
var lowpass_open:=false
var upper_anchored:=false
var lower_anchored:=false
var checkpoint:=0
var clock:=0.0

func _init() -> void:
	weights=[make_weight("mountain",0,DROP,"hatch"),make_weight("water",1,WATER_STOPS.cage,"cage")]

func make_weight(id: String,layer: int,at: Vector2,station: String) -> Dictionary:
	return {"id":id,"layer":layer,"pos":at,"station":station,"elevation":0.0,"speed_y":0.0,"mode":"rest","path":[],"target":""}

func bridge_solid() -> bool:
	return worlds[0]==3 or clip_target=="bridge" or upper_anchored

func pressure(station: String) -> bool:
	var w: Dictionary=weights[1]
	return w.layer==1 and w.station==station and w.mode=="rest" and float(w.elevation)<0.02 and worlds[1]==1

func is_busy() -> bool:
	for w in weights:
		if w.mode!="rest" or absf(float(w.speed_y))>0.01:return true
	if pressure("catch") and catch_height<0.99:return true
	if pressure("sluice") and weights[0].station=="lift" and lift_height<HEIGHT-0.01:return true
	return false

func switch_world(layer: int,next: int) -> bool:
	if layer<0 or layer>1 or next<0 or next>3 or next==worlds[layer]:return false
	if (layer==0 and upper_anchored) or (layer==1 and lower_anchored):return false
	worlds[layer]=next
	event.emit("world_set")
	return true

func acquire_clip() -> String:
	if clip_owned:return "留影夹已在工具袋中。"
	if worlds[0]!=3:return "工具间前的旧廊尚未显影。"
	clip_owned=true;checkpoint=maxi(checkpoint,1);event.emit("star")
	return "取得留影夹。靠近黄铜夹环可以保留机关的姿态。"

func set_clip(target: String) -> String:
	if not clip_owned:return "先去上层工具间寻找留影夹。"
	if target==clip_target:
		clip_target="";event.emit("fold");return "留影夹已收回，原机关恢复正常。"
	if target=="catch" and catch_height<0.98:return "接物台还没升起，先让重压踏板工作。"
	if target=="bridge" and not bridge_solid():return "先在上层显影世界找回木桥。"
	if target not in ["catch","bridge",""]:return "这里没有可固定的夹环。"
	clip_target=target
	if target=="catch":checkpoint=maxi(checkpoint,2)
	event.emit("star")
	return "已固定接物台。下层现在可以切回冰晶。" if target=="catch" else ("旧桥已留影，切回冰晶也能运送镇纸。" if target=="bridge" else "留影夹已召回。")

func release_support() -> String:
	if support_released:return "落料板检修撑已解除。"
	if clip_target!="catch" or catch_height<0.98:return "井下接物台尚未固定，联锁仍扣住检修撑。"
	support_released=true;event.emit("stop")
	return "检修撑已解除。上层镇纸的重量可以作用于落料板。"

func destinations(index: int) -> Array[String]:
	var result:Array[String]=[]
	var w: Dictionary=weights[index]
	if w.mode!="rest":return result
	if index==1:
		match w.station:
			"cage":
				if cage_open:result=["catch"]
			"catch":result=["junction","cage"]
			"junction":result=["sluice","guide","catch"]
			"sluice":result=["junction"]
			"guide":result=["junction"]
	else:
		match w.station:
			"catch":result=["junction"]
			"junction":result=["lift","catch"]
			"lift":
				if w.layer==0:result=["dock"]
				else:result=["junction"]
			"dock":result=["bridge"]
			"bridge":result=["anchor","dock"]
			"anchor":
				if not upper_anchored:result=["bridge"]
	return result

func push(index: int,destination: String) -> String:
	if index<0 or index>1:return "没有选中镇纸。"
	var w: Dictionary=weights[index]
	if w.mode!="rest":return "镇纸还在运动，请稍候。"
	if worlds[w.layer]!=0:return "先让镇纸回到冰晶世界的轨道上。"
	if float(w.elevation)>0.03:return "镇纸还没落回轨道。"
	if destination not in destinations(index):return "这个止挡不与当前轨道连接。"
	if index==1 and destination=="guide" and not lowpass_open:return "低位通道仍被吊台联锁挡住。先完成一次跨层提升，让吊台归底。"
	if index==0 and destination in ["bridge","anchor"] and not bridge_solid():return "跨渠桥尚未保留，轨道在水渠边中断。"
	var target:Vector2=WATER_STOPS[destination] if index==1 else MOUNTAIN_STOPS[destination]
	var path:Array=[]
	# Orthogonal transport segments, with real stops at each junction.
	if index==1:
		if w.station=="cage" or destination=="cage":
			path=[Vector2(7,12),target] if w.station=="cage" else [Vector2(7,12),target]
		elif destination=="sluice":path=[Vector2(18,8),target]
		elif w.station=="sluice":path=[Vector2(18,8),target]
		elif destination=="guide":path=[Vector2(12,8),Vector2(12,13),target]
		elif w.station=="guide":path=[Vector2(12,13),Vector2(12,8),target]
		else:path=[target]
	else:
		if w.layer==1 and destination=="lift":path=[Vector2(18,10),target]
		elif w.layer==1 and w.station=="lift":path=[Vector2(18,10),target]
		elif destination=="anchor":path=[Vector2(18,14),target]
		elif w.station=="anchor":path=[Vector2(18,14),target]
		else:path=[target]
	w.path=path;w.target=destination;w.mode="slide";event.emit("push")
	return "镇纸沿导轨滑向下一处止挡。"

func step(delta: float) -> void:
	var remaining:=minf(delta,0.5)
	while remaining>0.00001:
		var dt:=minf(remaining,1.0/120.0);remaining-=dt;_step(dt)

func _step(dt: float) -> void:
	clock+=dt
	var target_catch:=1.0 if pressure("catch") or clip_target=="catch" else 0.0
	catch_height=move_toward(catch_height,target_catch,dt*0.9)
	var m:Dictionary=weights[0]
	var water:Dictionary=weights[1]
	if not hatch_broken and support_released and worlds[0]==1 and m.station=="hatch":
		hatch_broken=true;m.mode="fall";m.elevation=HEIGHT;m.speed_y=0.0;event.emit("seal_begin")
	if m.mode=="fall":
		var law:int=worlds[0] if float(m.elevation)>HEIGHT*0.5 else worlds[1]
		m.speed_y=float(m.speed_y)+(-8.0 if law==2 else (22.0 if law==1 else 9.0))*dt
		m.elevation=float(m.elevation)-float(m.speed_y)*dt
		if float(m.elevation)<HEIGHT*0.5:m.layer=1
		if float(m.elevation)<=0.0:
			m.layer=1;m.elevation=0.0;m.speed_y=0.0;m.mode="rest";m.station="catch";m.pos=DROP
			checkpoint=maxi(checkpoint,3);event.emit("land")
	elif m.station=="lift":
		if pressure("sluice"):
			lift_height=move_toward(lift_height,HEIGHT,dt*1.15)
			m.elevation=0.0
			if lift_height>=HEIGHT-0.001 and m.layer==1:
				m.layer=0;lifted_once=true;event.emit("moon")
		elif m.layer==1:lift_height=move_toward(lift_height,0.0,dt)
	elif not pressure("sluice"):lift_height=move_toward(lift_height,0.0,dt*1.5)
	if lifted_once and lift_height<.02 and not lowpass_open:
		lowpass_open=true;event.emit("stop")
	for i in range(2):
		var w:Dictionary=weights[i]
		if w.mode=="slide":
			if worlds[w.layer]!=0:continue
			var next:Vector2=w.path[0]
			w.pos=(w.pos as Vector2).move_toward(next,dt*3.6)
			if (w.pos as Vector2).distance_to(next)<0.001:
				w.path.pop_front()
				if w.path.is_empty():
					w.station=w.target;w.mode="rest";event.emit("stop")
					if i==0 and w.station=="dock":checkpoint=maxi(checkpoint,4)
		elif w.mode=="rest" and w.station not in ["hatch","lift"] and not (i==0 and upper_anchored) and not (i==1 and lower_anchored):
			var limit:=2.3 if i==1 and w.station in ["cage","guide"] else 1.5
			var law:int=worlds[w.layer]
			w.speed_y=clampf(float(w.speed_y)+(5.5 if law==2 else -10.0)*dt,-6.0,3.3)
			w.elevation=clampf(float(w.elevation)+float(w.speed_y)*dt,0.0,limit)
			if float(w.elevation)<=0.0 or float(w.elevation)>=limit:w.speed_y=0.0
	if water.station=="cage" and float(water.elevation)>=2.29 and not cage_open:
		cage_open=true;event.emit("star")
	if m.station=="anchor" and m.mode=="rest" and worlds[0]==1 and float(m.elevation)<0.02 and not upper_anchored:
		upper_anchored=true;checkpoint=maxi(checkpoint,5);event.emit("star")
	if water.station=="guide" and float(water.elevation)>=2.29 and worlds[1]==2 and upper_anchored and not lower_anchored:
		water.elevation=2.3;water.speed_y=0.0
		lower_anchored=true;checkpoint=6;event.emit("success")

func weight_height(index: int) -> float:
	var w:Dictionary=weights[index]
	if index==0 and w.mode=="fall":return float(w.elevation)
	if index==0 and w.station=="lift":return lift_height+0.18
	return (HEIGHT if w.layer==0 else 0.0)+float(w.elevation)+0.18

func objective() -> String:
	if lower_anchored:return "双锚已定，走入上层归位门"
	if upper_anchored:return "将水纹镇纸送至下层导向井，稳定高处锚位"
	if lifted_once and int(weights[0].layer)==0:return "将山纹镇纸送至上层锚座"
	if hatch_broken:return "将山纹镇纸送回上层锚座"
	if clip_target=="catch" or support_released:return "让山纹镇纸安全落到下层接物区"
	if clip_owned:return "升起并固定下层接物台，准备安全落点"
	return "寻找上层工具间的留影夹"

func snapshot() -> Dictionary:
	var list:Array=[]
	for w in weights:
		list.append({"layer":w.layer,"pos":[w.pos.x,w.pos.y],"station":w.station,"elevation":w.elevation})
	return {"worlds":worlds.duplicate(),"weights":list,"clip_owned":clip_owned,"clip_target":clip_target,"cage_open":cage_open,"support_released":support_released,"hatch_broken":hatch_broken,"catch_height":catch_height,"lift_height":lift_height,"lifted_once":lifted_once,"lowpass_open":lowpass_open,"upper_anchored":upper_anchored,"lower_anchored":lower_anchored,"checkpoint":checkpoint}

func restore(data: Dictionary) -> void:
	worlds.assign(data.get("worlds",[0,0]))
	for key in ["clip_owned","clip_target","cage_open","support_released","hatch_broken","catch_height","lift_height","lifted_once","lowpass_open","upper_anchored","lower_anchored","checkpoint"]:
		if data.has(key):set(key,data[key])
	var list:Array=data.get("weights",[])
	for i in range(mini(2,list.size())):
		var saved:Dictionary=list[i]
		weights[i]=make_weight("mountain" if i==0 else "water",int(saved.layer),Vector2(saved.pos[0],saved.pos[1]),saved.station)
		weights[i].elevation=float(saved.elevation)
