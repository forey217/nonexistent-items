extends RefCounted
## Deterministic mechanisms and continuous motion, shared by play and recording.
signal event(kind: String)
const RailGeometry=preload("res://scripts/paper_rail_network.gd")
const HEIGHT:=4.8
const DROP:=Vector2(11,10)
const LIFT:=Vector2(18,7)
const LIFT_OPENING:=Rect2(16.8,5.8,2.4,2.4)
const LIFT_DOCK_EPSILON:=0.002
const TOOL:=Vector2(5,13)
const STAIRS:=Vector2(3.5,8.8)
const LOWER_STAIRS:=Vector2(3.5,2.8)
const UPPER_ANCHOR:=Vector2(20,14)
const LOWER_ANCHOR:=Vector2(15,13)
const EXIT:=Vector2(19,16.1)
const CATCH_PLATE:=Vector2(7,8)
const SLUICE:=Vector2(18,4)
const BRIDGE:=Vector2(18,11)
# This upper-floor cutout meets the existing tool-room side walls. The lower
# workshop's fixed crossing and the separate clampable rail bridge are unchanged.
const OLD_CORRIDOR_GAP:=Rect2(2.5,10.0,5.0,2.0)
const OLD_CORRIDOR_DECK:=Rect2(4.2,9.7,1.6,2.6)
const WORLD_NAMES:=["冰晶","重力","倒悬","显影"]
const WATER_STOPS:={"cage":Vector2(5,12),"cage_turn":Vector2(7,12),"catch":CATCH_PLATE,"junction":Vector2(11,8),"guide_turn":Vector2(12,8),"sluice_turn":Vector2(18,8),"sluice":SLUICE,"guide_bend":Vector2(12,13),"guide":LOWER_ANCHOR}
const MOUNTAIN_STOPS:={"catch":DROP,"junction":Vector2(15,10),"lift_turn":Vector2(18,10),"lift":LIFT,"dock":Vector2(18,8.5),"bridge":Vector2(18,12.5),"anchor_turn":Vector2(18,14),"anchor":UPPER_ANCHOR}
const WATER_EDGES:=[["cage","cage_turn"],["cage_turn","catch"],["catch","junction"],["junction","guide_turn"],["guide_turn","sluice_turn"],["sluice_turn","sluice"],["guide_turn","guide_bend"],["guide_bend","guide"]]
const LOWER_EDGES:=[["catch","junction"],["junction","lift_turn"],["lift_turn","lift"]]
const UPPER_EDGES:=[["lift","dock"],["dock","bridge"],["bridge","anchor_turn"],["anchor_turn","anchor"]]
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

func old_corridor_solid() -> bool:
	# Owning the clip never fixes this corridor; it has no clamp ring.
	return worlds[0]==3

func old_corridor_blocks(at:Vector2,clearance:=0.0) -> bool:
	if not OLD_CORRIDOR_GAP.grow(clearance).has_point(at):return false
	return not (old_corridor_solid() and at.x>=OLD_CORRIDOR_DECK.position.x+clearance and at.x<=OLD_CORRIDOR_DECK.end.x-clearance)

func pressure(station: String) -> bool:
	var w: Dictionary=weights[1]
	return w.layer==1 and w.station==station and w.mode=="rest" and float(w.elevation)<0.02 and worlds[1]==1

func has_sliding_weight() -> bool:
	return weights.any(func(w):return w.mode=="slide")

func waterwheel_running() -> bool:
	return pressure("sluice") or lower_anchored

func lift_target_height() -> float:
	return HEIGHT if waterwheel_running() else 0.0

func lift_in_transit() -> bool:
	return lift_height>LIFT_DOCK_EPSILON and lift_height<HEIGHT-LIFT_DOCK_EPSILON

func lift_docked(layer:int) -> bool:
	return absf(lift_height-(HEIGHT if layer==0 else 0.0))<=LIFT_DOCK_EPSILON

func lift_transport_error(index:int,destination:String) -> String:
	if index!=0:return ""
	var w:Dictionary=weights[0]
	if w.station=="lift" or destination=="lift":
		var floor_height:=HEIGHT if w.layer==0 else 0.0
		if not lift_docked(w.layer) or absf(lift_target_height()-floor_height)>LIFT_DOCK_EPSILON:return "吊台还未与这一层对齐，等它停稳再推。"
	return ""

func is_busy() -> bool:
	for w in weights:
		if w.mode!="rest" or absf(float(w.speed_y))>0.01:return true
	if pressure("catch") and catch_height<0.99:return true
	if absf(lift_height-lift_target_height())>LIFT_DOCK_EPSILON:return true
	return false

func switch_world(layer: int,next: int) -> bool:
	if layer<0 or layer>1 or next<0 or next>3 or next==worlds[layer]:return false
	if has_sliding_weight():return false
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
	if clip_target=="bridge" and weights[0].mode=="slide" and weights[0].layer==0:
		return "镇纸正在上层导轨运送，停稳后再调整木桥夹子。"
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

func stops(index:int) -> Dictionary:return WATER_STOPS if index==1 else MOUNTAIN_STOPS

func edges(index:int) -> Array:
	return WATER_EDGES if index==1 else LOWER_EDGES if weights[0].layer==1 else UPPER_EDGES

func destinations(index:int) -> Array[String]:
	var result:Array[String]=[]
	var w:Dictionary=weights[index]
	for pair in edges(index):
		if pair[0]==w.station:result.append(pair[1])
		elif pair[1]==w.station:result.append(pair[0])
	return result

static func snap_direction(direction:Vector2) -> Vector2:
	if direction.length_squared()<.01:return Vector2.ZERO
	# Equal diagonals consistently prefer X; no frame-dependent random choice.
	return Vector2(signf(direction.x),0) if absf(direction.x)>=absf(direction.y) else Vector2(0,signf(direction.y))

func push_choice(index:int,direction:Vector2) -> String:
	var dir:=snap_direction(direction)
	if dir==Vector2.ZERO:return ""
	var w:Dictionary=weights[index]
	for destination in destinations(index):
		var offset:Vector2=stops(index)[destination]-w.pos
		if offset.normalized().dot(dir)>.99:return destination
	return ""

func push_error(index:int,direction:Vector2) -> String:
	return push_route(index,direction).error

func _push_start_error(index:int) -> String:
	var w:Dictionary=weights[index]
	if w.mode!="rest":return "镇纸还在滑行，请稍候。"
	if index==0 and upper_anchored or index==1 and lower_anchored:return "这块镇纸已稳住锚位。"
	if worlds[w.layer]==1:return "镇纸太重了，先切回冰晶。"
	if worlds[w.layer]!=0:return "先切回冰晶，再沿地面轨道推动。"
	if float(w.elevation)>.003 or absf(float(w.speed_y))>.01:return "镇纸尚未落回导轨，请等它停稳。"
	if index==1 and w.station=="cage" and not cage_open:return "封存架仍锁着，先观察上方锁扣。"
	return ""

func neighbors(index:int,station:String) -> Array[String]:
	var result:Array[String]=[]
	for pair in edges(index):
		if pair[0]==station:result.append(pair[1])
		elif pair[1]==station:result.append(pair[0])
	return result

func rail_error(index:int,origin:String,destination:String) -> String:
	var lift_error:=lift_transport_error(index,destination)
	if not lift_error.is_empty():return lift_error
	if index==1 and ((origin=="guide_turn" and destination=="guide_bend") or (origin=="guide_bend" and destination=="guide_turn")) and not lowpass_open:return "导向井通道尚未打开，先让吊台完成运输并归底。"
	if index==0 and (origin=="dock" and destination=="bridge" or origin=="bridge" and destination=="dock") and not bridge_solid():return "前方桥面尚未保留，先固定显影木桥。"
	return ""

func stop_reason(index:int,station:String) -> String:
	if index==1:
		return {"cage":"封存架终点","catch":"接物踏板","sluice":"水闸踏板","guide":"上浮导向井","guide_turn":"导轨分岔"}.get(station,"")
	return {"catch":"落料接物区","lift":"运纸吊台","anchor":"山纹锚座"}.get(station,"")

func push_route(index:int,direction:Vector2) -> Dictionary:
	var plan:={"direction":snap_direction(direction),"stations":[],"points":[],"target":"","error":_push_start_error(index),"blocked_reason":"","reason":""}
	if not plan.error.is_empty():return plan
	var next:=push_choice(index,direction)
	if next.is_empty():plan.error="这个方向没有相连导轨。";return plan
	var previous:String=weights[index].station
	var seen:Dictionary={previous:true}
	while not next.is_empty():
		var blocked:=rail_error(index,previous,next)
		if not blocked.is_empty():
			if plan.stations.is_empty():plan.error=blocked
			else:plan.blocked_reason=blocked;plan.reason="通路边界"
			break
		if seen.has(next):plan.error="导轨连接异常，请重新选择。";return plan
		seen[next]=true;plan.stations.append(next);plan.points.append(stops(index)[next]);plan.target=next
		var reason:=stop_reason(index,next)
		var onward:=neighbors(index,next);onward.erase(previous)
		if not reason.is_empty() or onward.size()!=1:
			plan.reason=reason if not reason.is_empty() else ("导轨分岔" if onward.size()>1 else "轨道终点");break
		previous=next;next=onward[0]
	if plan.error.is_empty() and not plan.stations.is_empty():
		var sampled:=_sample_transport_curve(index,plan.stations)
		plan.points=sampled.points;plan["point_stations"]=sampled.labels
	return plan

func _sample_transport_curve(index:int,stations:Array) -> Dictionary:
	var points:Array[Vector2]=[];var labels:Array[String]=[];var previous:Vector2=weights[index].pos
	for i in range(stations.size()):
		var id:String=stations[i];var at:Vector2=stops(index)[id]
		if i+1<stations.size() and neighbors(index,id).size()==2:
			var after:Vector2=stops(index)[stations[i+1]]
			var incoming:Vector2=(at-previous).normalized();var outgoing:Vector2=(after-at).normalized()
			if absf(incoming.cross(outgoing))>.01:
				var radius:float=RailGeometry.TURN_RADIUS
				var center:=at-incoming*radius+outgoing*radius
				var start:Vector2=-outgoing;var finish:Vector2=incoming
				var span:=atan2(start.cross(finish),start.dot(finish))
				points.append(center+start*radius);labels.append("")
				for step in range(1,RailGeometry.ARC_STEPS+1):
					points.append(center+start.rotated(span*float(step)/RailGeometry.ARC_STEPS)*radius)
					labels.append(id if step==RailGeometry.ARC_STEPS else "")
				previous=at;continue
		points.append(at);labels.append(id);previous=at
	return {"points":points,"labels":labels}

func push_direction(index:int,direction:Vector2) -> String:
	var plan:=push_route(index,direction)
	if not plan.error.is_empty():return plan.error
	var w:Dictionary=weights[index]
	w.path=plan.points.duplicate();w.route_stations=plan.point_stations.duplicate();w.target=plan.target;w.mode="slide";w.slide_speed=0.0
	var length:=0.0;var at:Vector2=w.pos
	for point:Vector2 in w.path:length+=at.distance_to(point);at=point
	w.slide_remaining=length;event.emit("push")
	return "镇纸沿导轨运送，在机关、分岔或终点停下。"

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
	# The waterwheel powers the platform independently of cargo and quest stage.
	var previous_lift:=lift_height
	lift_height=move_toward(lift_height,lift_target_height(),dt*(1.15 if waterwheel_running() else 1.5))
	# Pressure is a contact event, not merely a world/station combination.
	if not hatch_broken and support_released and worlds[0]==1 and m.station=="hatch" and m.mode=="rest" and float(m.elevation)<=0.0001:
		hatch_broken=true;m.mode="fall";m.elevation=HEIGHT+.18;m.speed_y=0.0;event.emit("seal_begin")
	if m.mode=="fall":
		var law:int=worlds[0] if float(m.elevation)>HEIGHT*0.5 else worlds[1]
		if law==2:
			var upward:=minf(3.3,sqrt(16.0*maxf(0.0,HEIGHT+1.68-float(m.elevation))))
			m.speed_y=move_toward(float(m.speed_y),-upward,8.0*dt)
		else:m.speed_y=float(m.speed_y)+(22.0 if law==1 else 9.0)*dt
		m.elevation=float(m.elevation)-float(m.speed_y)*dt
		if float(m.elevation)>=HEIGHT+1.68:m.elevation=HEIGHT+1.68;m.speed_y=0.0
		m.layer=0 if float(m.elevation)>HEIGHT*.5 else 1
		if float(m.elevation)<=.18:
			m.layer=1;m.elevation=0.0;m.speed_y=0.0;m.mode="rest";m.station="catch";m.pos=DROP
			checkpoint=maxi(checkpoint,3);event.emit("land")
	elif m.station=="lift" and m.mode=="rest":
		# The open platform carries the rail footprint; cargo may rise locally.
		# Only platform docking changes transport membership, never local height.
		var cargo_height:float=previous_lift+float(m.elevation)
		if lift_docked(0) and m.layer==1 and cargo_height>=HEIGHT-.02:
			m.layer=0;lifted_once=true;event.emit("moon")
		elif lift_docked(1) and cargo_height<=.02:m.layer=1
		# A withdrawn platform must not drag airborne cargo down with it.
		# Keep world height; the open shaft remains its only horizontal footprint.
		m.elevation=maxf(0.0,float(m.elevation)+previous_lift-lift_height)
	if lifted_once and lift_height<.02 and not lowpass_open:
		lowpass_open=true;event.emit("stop")
	for i in range(2):
		var w:Dictionary=weights[i]
		if w.mode=="slide":
			if worlds[w.layer]!=0:continue
			var remaining_distance:float=w.get("slide_remaining",0.0)
			var target_speed:=minf(3.6,sqrt(16.0*maxf(.002,remaining_distance)))
			w.slide_speed=move_toward(float(w.get("slide_speed",0.0)),target_speed,dt*10.0)
			var travel:float=dt*w.slide_speed
			while travel>0 and not w.path.is_empty():
				var next:Vector2=w.path[0];var distance:float=w.pos.distance_to(next)
				var moved:=minf(travel,distance);w.pos=(w.pos as Vector2).move_toward(next,moved);travel-=moved
				w.slide_remaining=maxf(0,float(w.slide_remaining)-moved)
				if moved<distance:break
				w.pos=next;w.path.pop_front()
				if not w.get("route_stations",[]).is_empty():
					var passed:String=w.route_stations.pop_front()
					if not passed.is_empty():w.station=passed
				if i==0 and w.station=="dock":checkpoint=maxi(checkpoint,4)
			if w.path.is_empty():w.station=w.target;w.mode="rest";w.slide_speed=0.0;event.emit("stop")
		elif w.mode=="rest" and not (i==0 and upper_anchored) and not (i==1 and lower_anchored):
			_step_local_height(i,dt)
	if water.station=="cage" and float(water.elevation)>=2.29 and not cage_open:
		cage_open=true;event.emit("star")
	if m.station=="anchor" and m.mode=="rest" and worlds[0]==1 and float(m.elevation)<0.02 and not upper_anchored:
		upper_anchored=true;checkpoint=maxi(checkpoint,5);event.emit("star")
	if water.station=="guide" and float(water.elevation)>=2.29 and worlds[1]==2 and upper_anchored and not lower_anchored:
		water.elevation=2.3;water.speed_y=0.0
		lower_anchored=true;checkpoint=6;event.emit("success")

func float_limit(index:int) -> float:
	# Cage/guide have existing 2.3m switches. All open stations share the
	# existing 1.5m inverted equilibrium, including hatch and open lift deck.
	var w:Dictionary=weights[index]
	if index==0 and w.station=="lift":return maxf(0.0,(HEIGHT if w.layer==0 else 0.0)+1.5-lift_height)
	return 2.3 if index==1 and w.station in ["cage","guide"] else 1.5

func _step_local_height(index:int,dt:float) -> void:
	var w:Dictionary=weights[index];var limit:=float_limit(index)
	var law:int=worlds[w.layer]
	if law==2:
		# Brake using remaining distance rather than abruptly hitting the cap.
		var desired:=minf(2.4,sqrt(11.0*maxf(0.0,limit-float(w.elevation))))
		w.speed_y=move_toward(float(w.speed_y),desired,5.5*dt)
	else:w.speed_y=maxf(-6.0,float(w.speed_y)-(16.0 if law==1 else 10.0)*dt)
	w.elevation=clampf(float(w.elevation)+float(w.speed_y)*dt,0.0,limit)
	if float(w.elevation)<=0.0 or float(w.elevation)>=limit:w.speed_y=0.0

func weight_support_height(index:int) -> float:
	var w:Dictionary=weights[index]
	if index==0 and w.station=="lift" and w.mode=="rest":return lift_height
	return HEIGHT if w.layer==0 else 0.0

func weight_height(index: int) -> float:
	var w:Dictionary=weights[index]
	if index==0 and w.mode=="fall":return float(w.elevation)
	return weight_support_height(index)+float(w.elevation)+0.18

func objective() -> String:
	if lower_anchored:return "双锚已定，返回上层归档"
	if upper_anchored:return "将水纹镇纸送至下层导向井，稳定高处锚位"
	if lifted_once and int(weights[0].layer)==0:return "将山纹镇纸送至上层锚座"
	if hatch_broken and int(weights[0].layer)==1 and weights[0].mode=="rest":return "将山纹镇纸送回上层锚座"
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
	# Older saves can contain a fully raised platform with a lower-floor cargo ID.
	var m:Dictionary=weights[0]
	if m.station=="lift":
		if lift_docked(0):m.layer=0
		elif lift_docked(1) and float(m.elevation)<=.02:m.layer=1
