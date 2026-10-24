extends Node
## Observe settled facts only. This layer never writes puzzle state or navigation.
const Paper=preload("res://scripts/paper_mill_state.gd")
var room:Node
var paper:=false
var previous:Dictionary={}
var seen:Dictionary={}
var history:Array[Dictionary]=[]
var effects:Array[Dictionary]=[]
var clock:=0.0
var last_sound:Dictionary={}

func _ready() -> void:baseline()

func facts() -> Dictionary:
	var s=room.state
	if not paper:
		return {"star":s.first_latched,"moon":s.receiver_latched,"seal":room.gate_ready,
			"motion":absf(s.rail_speed)>.1,"land":s.elevation<=.01,"stop":s.rail_position}
	var m:Dictionary=s.weights[0]
	return {"tool":s.clip_owned,"cage":s.cage_open,"clamp":s.clip_target=="catch" and s.catch_height>=.98,
		"bridge":s.clip_target=="bridge" and s.bridge_solid(),"support":s.support_released,
		"land":s.hatch_broken and int(m.layer)==1 and m.mode=="rest" and m.station=="catch",
		"lift":s.lifted_once and int(m.layer)==0 and m.mode=="rest" and m.station=="lift" and s.lift_docked(0),
		"dock":s.lifted_once and int(m.layer)==0 and m.mode=="rest" and m.station=="dock",
		"upper":s.upper_anchored,"dual":s.upper_anchored and s.lower_anchored,
		"wheel":s.waterwheel_running(),"lift_top":s.lift_docked(0),"lift_bottom":s.lift_docked(1),
		"motion0":m.mode,"motion1":s.weights[1].mode}

func baseline(saved:Array=[],restart:=false) -> void:
	clear()
	if restart:seen.clear();history.clear();clock=0;last_sound.clear()
	for id in saved:seen[str(id)]=true
	previous=facts()
	for id in milestone_ids():
		if previous.get(id,false):seen[id]=true
	var card:Control=room.hud.objective if paper else room.hud.task_tracker
	if card.has_meta("task_transition"):card.get_meta("task_transition").cancel()

func milestone_ids() -> Array:
	return ["tool","cage","clamp","bridge","support","land","lift","dock","upper","dual"] if paper else ["star","moon","seal"]

func tick(delta:float) -> void:
	clock+=delta
	var now:=facts()
	for id in milestone_ids():
		if now.get(id,false) and not previous.get(id,false):
			var first:=not seen.has(id);seen[id]=true
			respond(id,first and (not paper or id in ["tool","clamp","land","lift","dock","upper","dual"]))
	if paper:
		for id in ["wheel","lift_top","lift_bottom"]:
			if now.get(id,false) and not previous.get(id,false):respond(id,false)
		for i in range(2):
			if previous.get("motion%d"%i,"")=="slide" and now["motion%d"%i]=="rest":respond("stop%d"%i,false)
	previous=now
	for effect in effects.duplicate():
		effect.age+=delta
		if effect.age>=1.5:
			effect.root.queue_free();effects.erase(effect);continue
		effect.root.visible=effect.age>=0 and (not paper or room.view.link_time>0 or room.view_layer==int(effect.layer))
		var t:float=maxf(0,effect.age)
		var material:StandardMaterial3D=effect.material
		material.albedo_color.a=minf(t/.08,1.0)*(1.0-smoothstep(.85,1.5,t))*.95
		for i in range(effect.lines.size()):
			effect.lines[i].visible=t>=.18+float(i)/maxi(1,effect.lines.size())*.42
		if is_instance_valid(effect.latch):effect.latch.position.y=effect.latch_y+.055*(1.0-smoothstep(0,.22,t))
	var card:Control=room.hud.objective if paper else room.hud.task_tracker
	if card.has_meta("task_transition"):card.get_meta("task_transition").tick(delta)

func respond(id:String,completed:bool) -> void:
	if room.finished:return
	var spec:=location(id)
	if spec.is_empty():return
	var kind:String=spec.get("kind","stop")
	# Physical stop events already have their own contact sound. Do not double them.
	if id in ["tool","cage","wheel","lift","lift_top","lift_bottom","clamp","bridge","star","moon","upper","dual","seal"] and clock-float(last_sound.get(kind,-10.0))>.18:
		room.sound.play_resonance(kind);last_sound[kind]=clock
	var entry:Dictionary={"id":id,"completed":completed,"at":clock,"kind":kind}
	history.append(entry)
	if history.size()>100:history.pop_front()
	if effects.size()>=8:
		effects[0].root.queue_free();effects.pop_front()
	_draw_response(spec)
	if id=="dual":
		_draw_response({"at":Vector3(Paper.UPPER_ANCHOR.x,Paper.HEIGHT+.32,Paper.UPPER_ANCHOR.y),"kind":"anchor","delay":.25})
		_draw_response({"at":Vector3(Paper.EXIT.x,Paper.HEIGHT+.14,Paper.EXIT.y),"kind":"anchor","delay":.50})
	if completed:
		var card:Control=room.hud.objective if paper else room.hud.task_tracker
		if card.has_meta("task_transition"):
			var receipt:String={"clamp":"接物台已升起并固定","land":"山纹已安全落在接物区","lift":"山纹已回到上层","dock":"山纹已抵达中转止挡","seal":"封界踏板已锁定，界缝稳定"}.get(id,"")
			card.get_meta("task_transition").confirm(receipt)

func location(id:String) -> Dictionary:
	if not paper:
		var v=room.orbit_view
		match id:
			"star":return {"at":v.to_world(room.first_plate,.29),"kind":"plate","path":[v.to_world(room.first_plate,.17),v.to_world(room.first_plate.lerp(room.rail_end,.13),.17)]}
			"moon":return {"at":v.to_world(room.rail_end,2.73),"kind":"anchor"}
			"seal":return {"at":v.to_world(room.portal_position,.15),"kind":"anchor"}
		return {}
	var s=room.state
	match id:
		"tool":return {"at":Vector3(Paper.TOOL.x,Paper.HEIGHT+.5,Paper.TOOL.y),"kind":"clamp"}
		"cage":return {"at":Vector3(5,2.4,12),"kind":"clamp"}
		"clamp":return {"at":Vector3(Paper.DROP.x+1.4,s.catch_height*.15+.61,Paper.DROP.y),"kind":"clamp","path":[Vector3(11,.112,10),Vector3(9,.112,10),Vector3(9,.112,9.5)]}
		"bridge":return {"at":Vector3(Paper.BRIDGE.x+.9,Paper.HEIGHT+.18,Paper.BRIDGE.y-.5),"kind":"clamp"}
		"support":return {"at":Vector3(Paper.DROP.x-1.35,Paper.HEIGHT+.35,Paper.DROP.y),"kind":"clamp"}
		"land":return {"at":Vector3(Paper.DROP.x,s.catch_height*.15+.19,Paper.DROP.y),"kind":"stop"}
		"lift","lift_top","lift_bottom":return {"at":Vector3(Paper.LIFT.x,s.lift_height+.22,Paper.LIFT.y),"kind":"dock"}
		"dock":return {"at":Vector3(s.weights[0].pos.x,Paper.HEIGHT+.15,s.weights[0].pos.y),"kind":"stop"}
		"upper":return {"at":Vector3(Paper.UPPER_ANCHOR.x,Paper.HEIGHT+.32,Paper.UPPER_ANCHOR.y),"kind":"anchor"}
		"dual":return {"at":Vector3(Paper.LOWER_ANCHOR.x,2.65,Paper.LOWER_ANCHOR.y),"kind":"anchor"}
		"wheel":return {"at":Vector3(22,.98,4),"kind":"wheel","path":[Vector3(22,.99,4),Vector3(19,.99,4),Vector3(19,1.28,5)]}
		"stop0","stop1":
			var i:=int(id.right(1));var w:Dictionary=s.weights[i]
			return {"at":Vector3(w.pos.x,s.weight_height(i)+.05,w.pos.y),"kind":"stop"}
	return {}

func _draw_response(spec:Dictionary) -> void:
	var root:=Node3D.new()
	(room.view.world_root if paper else room.orbit_view.world_root).add_child(root)
	root.position=spec.at
	var material:=StandardMaterial3D.new();material.albedo_color=Color("e7c88a");material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.no_depth_test=false
	var lines:Array[MeshInstance3D]=[]
	var kind:String=spec.kind
	var extent:=.24 if kind=="clamp" else (.65 if kind=="dock" else .47)
	for side in [-1,1]:
		for i in range(4):
			var a:=Vector3(side*extent,.025,-.29+i*.18)
			lines.append(_bar(root,a,a+Vector3(side*.11,0,0),.023,material))
	var latch:MeshInstance3D
	if kind in ["clamp","dock"]:
		latch=_bar(root,Vector3(-extent,.03,-.35),Vector3(extent,.03,-.35),.05,material)
	elif kind=="anchor":
		for i in range(3):lines.append(_bar(root,Vector3(-.20,.04,-.18+i*.18),Vector3(.20,.04,-.18+i*.18),.024,material))
	elif kind=="plate":lines.append(_bar(root,Vector3(-.45,.035,-.4),Vector3(.45,.035,-.4),.032,material))
	elif kind=="stop":lines.append(_bar(root,Vector3(-.35,.02,-.36),Vector3(.35,.02,-.36),.035,material))
	var path:Array=spec.get("path",[])
	for i in range(1,path.size()):
		var a:Vector3=path[i-1]-root.position;var b:Vector3=path[i]-root.position
		var count:=maxi(1,ceili(a.distance_to(b)/.18))
		for n in range(count):lines.append(_bar(root,a.lerp(b,float(n)/count),a.lerp(b,float(n+1)/count),.018,material))
	for line in lines:line.hide()
	effects.append({"root":root,"material":material,"lines":lines,"latch":latch,"latch_y":latch.position.y if is_instance_valid(latch) else 0.0,"layer":0 if root.position.y>=Paper.HEIGHT-.1 else 1,"age":-float(spec.get("delay",0))})

func _bar(root:Node3D,a:Vector3,b:Vector3,width:float,material:Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(width,a.distance_to(b),width)
	node.mesh=mesh;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position=(a+b)*.5;node.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	if not paper:node.layers=1<<3
	root.add_child(node);return node

func clear() -> void:
	for effect in effects:
		if is_instance_valid(effect.root):effect.root.queue_free()
	effects.clear()

func snapshot() -> Array:return seen.keys()
