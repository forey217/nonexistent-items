extends Node3D
## Small, bounded visual responses. Never part of navigation or mechanism state.
var view:Node
var pieces:Array[Dictionary]=[]
var clock:=0.0

func build(v:Node) -> void:
	view=v
	for spec:Dictionary in v.yard.loose_sheets:
		_add_loose(spec.layer,spec.at,spec.size,spec.turn,false)
	for layer in range(2):
		for at in [Vector2(8.5,15.8),Vector2(12.8,16.5)]:
			_add_loose(layer,Vector3(at.x,.13,at.y),Vector2(.30,.23),.12*layer,false)
		for at in [Vector2(10.7,16.5),Vector2(1.1,13.8)]:
			_add_loose(layer,Vector3(at.x,.10,at.y),Vector2(.06,.38),-.18,true)
		for at in [Vector2(10,16.5),Vector2(15,16.5)]:
			_add_strip(layer,Vector3(at.x-.48,.08,at.y-.22))
	baseline(v.room.state.worlds)

func _holder(layer:int,at:Vector3) -> Node3D:
	var n:=Node3D.new();view.roots[layer].add_child(n);n.position=at
	n.name="RuleDetail%d"%pieces.size()
	return n

func _add_loose(layer:int,at:Vector3,size:Vector2,turn:float,bamboo:bool) -> void:
	var n:=_holder(layer,at)
	var sheet:MeshInstance3D=view.box(n,Vector3.ZERO,Vector3(size.x,.009,size.y),view.wood if bamboo else view.paper_mat)
	sheet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pieces.append({"node":n,"layer":layer,"base":at,"turn":turn,"h":0.0,"v":0.0,"bend":0.0,"strip":false,"bamboo":bamboo,"phase":pieces.size()*1.73,"limit":.38 if bamboo else .55+.07*(pieces.size()%3)})

func _add_strip(layer:int,at:Vector3) -> void:
	var n:=_holder(layer,at);var segments:Array[Node3D]=[];var parent:=n
	# A tiny actual peg fixes the first end to the drying mat.
	view.box(n,Vector3(0,.012,0),Vector3(.14,.025,.04),view.brass)
	for i in range(5):
		var joint:=Node3D.new();parent.add_child(joint)
		if i>0:joint.position.z=.10
		view.box(joint,Vector3(0,0,.05),Vector3(.11,.006,.104),view.paper_mat)
		segments.append(joint);parent=joint
	pieces.append({"node":n,"layer":layer,"base":at,"turn":0.0,"h":0.0,"v":0.0,"bend":0.0,"strip":true,"phase":pieces.size()*1.73,"segments":segments})

func baseline(worlds:Array) -> void:
	clock=0.0
	for p:Dictionary in pieces:
		p.h=p.get("limit",0.0) if worlds[p.layer]==2 else 0.0;p.v=0.0
		p.bend=.25 if worlds[p.layer]==2 else 0.0
		_pose(p,worlds[p.layer],false)

func sync(dt:float,worlds:Array,motion:bool) -> void:
	if dt<=0:return # Pause freezes both pose and phase.
	clock+=dt if motion else 0.0
	for p:Dictionary in pieces:
		var world:int=worlds[p.layer]
		var target:float=p.get("limit",0.0) if world==2 else 0.0
		p.v+=(18.0*(target-float(p.h))-8.5*float(p.v))*minf(dt,.05)
		p.h=clampf(float(p.h)+float(p.v)*minf(dt,.05),0.0,p.get("limit",0.0))
		p.bend=lerpf(p.bend,.25 if world==2 else 0.0,1.0-exp(-minf(dt,.05)*6.0))
		_pose(p,world,motion)

func _pose(p:Dictionary,world:int,motion:bool) -> void:
	var n:Node3D=p.node
	n.position=p.base
	var sway:=sin(clock*(1.1+fmod(p.phase,.7))+p.phase) if motion else 0.0
	if p.strip:
		for i in range(p.segments.size()):p.segments[i].rotation.x=-p.bend*(.6+i*.22)-sway*.012*p.bend
	else:
		n.position.y+=p.h
		var amount:float=p.h/maxf(.01,p.limit)
		n.rotation=Vector3(amount*(.14+sway*.08),p.turn+amount*sway*.07,amount*.13*sin(p.phase))
		# Ice shifts only these decorative sheets by a few millimetres.
		if world==0:n.position.x+=.008*sway
