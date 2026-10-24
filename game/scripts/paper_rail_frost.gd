extends Node
## A visual skin over the exact rail leaves. No colliders, navigation or save fields.
const DURATION:=0.90
const TAIL:=0.24
const SKIN_WIDTH:=0.13
const FrostShader=preload("res://shaders/paper_rail_frost.gdshader")
var view:Node
var ages:Array[float]=[0.0,0.0]
var strengths:Array[float]=[1.0,1.0]
var worlds:Array[int]=[0,0]
var materials:Array[Array]=[[],[],[]]
var old_materials:Array[Array]=[[],[]]
var batches:Array[Dictionary]=[]
var starts:Array[int]=[1,1]
var lift_layer:=-1

func _materials() -> void:
	for layer in range(3):
		for kind in range(3):
			var material:=ShaderMaterial.new();material.shader=FrostShader
			material.set_shader_parameter("kind",float(kind));materials[layer].append(material)

func build(v:Node) -> void:
	view=v;_materials();worlds.assign(view.room.state.worlds)
	for layer in range(2):strengths[layer]=1.0 if worlds[layer]==0 else 0.0
	for index in range(view.rail_networks.size()):
		var network=view.rail_networks[index]
		var paths:Array[Dictionary]=[]
		for edge:Dictionary in network.segments:
			for rail:Array in edge.rails:paths.append({"a":rail[0],"b":rail[1]})
		for curve:Dictionary in network.curves:
			for i in range(curve.points.size()-1):paths.append({"a":curve.points[i],"b":curve.points[i+1]})
		_arrival_distances(paths,network.segments[0].rails)
		_build_skin(network.surfaces,paths,0 if index==0 else 1,.0015 if index==2 else 0.0)
	_publish()

func build_lift() -> void:
	var surfaces:Array[Dictionary]=[]
	_collect_lift(view.lift,surfaces)
	var paths:Array[Dictionary]=[]
	for x in [-.27,.27]:paths.append({"a":Vector2(x,0),"b":Vector2(x,1.22),"da":0.0,"db":1.22,"max":1.22})
	_build_skin(surfaces,paths,2)
	_sync_lift()

func _collect_lift(node:Node,surfaces:Array[Dictionary]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.material_override==view.lift_rail_material:
			surfaces.append({"mesh":child,"origin":Vector2.ZERO})
		_collect_lift(child,surfaces)

func _key(p:Vector2) -> Vector2i:return Vector2i(roundi(p.x*10000),roundi(p.y*10000))

func _arrival_distances(paths:Array[Dictionary],seeds:Array) -> void:
	# Geodesic distances on the actual two rails, including all circular samples.
	# Independent crossing networks are intentionally never joined here.
	var graph:Dictionary={};var distance:Dictionary={};var pending:Array=[]
	for path:Dictionary in paths:
		var a:=_key(path.a);var b:=_key(path.b);var length:float=path.a.distance_to(path.b)
		for pair in [[a,b],[b,a]]:
			if not graph.has(pair[0]):graph[pair[0]]=[]
			graph[pair[0]].append({"to":pair[1],"length":length})
	for rail:Array in seeds:
		var key:=_key(rail[0]);distance[key]=0.0;pending.append(key)
	while not pending.is_empty():
		var best:=0
		for i in range(1,pending.size()):
			if distance[pending[i]]<distance[pending[best]]:best=i
		var at:Vector2i=pending.pop_at(best)
		for edge:Dictionary in graph[at]:
			var next:float=distance[at]+edge.length
			if next<float(distance.get(edge.to,INF)):
				distance[edge.to]=next
				if not edge.to in pending:pending.append(edge.to)
	var longest:=0.01
	for value:float in distance.values():longest=maxf(longest,value)
	for path:Dictionary in paths:
		path.da=distance.get(_key(path.a),0.0);path.db=distance.get(_key(path.b),longest);path.max=longest

func _nearest(at:Vector2,paths:Array[Dictionary]) -> Dictionary:
	var best:=INF;var result:Dictionary={}
	for path:Dictionary in paths:
		var vector:Vector2=path.b-path.a
		var t:=clampf((at-path.a).dot(vector)/maxf(.00001,vector.length_squared()),0.0,1.0)
		var point:Vector2=path.a+vector*t;var gap:=at.distance_squared_to(point)
		if gap<best:
			best=gap;result={"at":point,"tangent":vector.normalized(),"arrival":lerpf(path.da,path.db,t)/path.max*(DURATION-.075)}
	return result

func _surface_tool() -> SurfaceTool:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);return tool

func _vertex(tool:SurfaceTool,at:Vector3,uv:Vector2,arrival:float,seed:=0.0) -> void:
	tool.set_color(Color(arrival,0.0,seed,1.0));tool.set_uv(uv);tool.set_normal(Vector3.UP);tool.add_vertex(at)

func _build_skin(surfaces:Array[Dictionary],paths:Array[Dictionary],layer:int,depth_offset:=0.0) -> void:
	var hosts:Dictionary={}
	for surface:Dictionary in surfaces:
		var source:MeshInstance3D=surface.mesh;var host:Node3D=source.get_parent()
		if not hosts.has(host):hosts[host]={"tools":[_surface_tool(),_surface_tool(),_surface_tool()],"samples":{},"origin":surface.origin,"triangles":[]}
		var batch:Dictionary=hosts[host];var origin:Vector2=surface.origin
		var arrays:Array=source.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		# Select complete top triangles geometrically: the inherited rail meshes
		# are double-sided and some of their winding normals point downward.
		for triangle in range(0,vertices.size(),3):
			if not [0,1,2].all(func(j):return vertices[triangle+j].y>.18):continue
			var top:=PackedVector2Array()
			for j in range(3):top.append(Vector2(vertices[triangle+j].x,vertices[triangle+j].z)+origin)
			batch.triangles.append(top)
			for j in range(3):
				var original:Vector3=vertices[triangle+j];var p:=Vector2(original.x,original.z)+origin
				var nearest:=_nearest(p,paths);var normal:=Vector2(-nearest.tangent.y,nearest.tangent.x)
				var side:float=(p-nearest.at).dot(normal)
				var expanded:Vector2=p+normal*signf(side)*(SKIN_WIDTH-.065)*.5
				_vertex(batch.tools[0],Vector3(expanded.x-origin.x,original.y+.006+depth_offset,expanded.y-origin.y),Vector2(0,clampf(side/.065+.5,0,1)),nearest.arrival)
				# Sparse, pooled details are grouped per true visibility parent.
				var cell:=Vector2i(roundi(nearest.at.x/.55),roundi(nearest.at.y/.55))
				if not batch.samples.has(cell):batch.samples[cell]=nearest
	# Fill straight runs as well as bends. Test against the actual top triangles
	# so bridge gaps and the retracted docking lip never acquire floating mist.
	for path:Dictionary in paths:
		var steps:=maxi(1,ceili(path.a.distance_to(path.b)/.48))
		for i in range(steps+1):
			var at:Vector2=path.a.lerp(path.b,float(i)/steps)
			for host:Node3D in hosts:
				var batch:Dictionary=hosts[host]
				if not batch.triangles.any(func(triangle):return Geometry2D.is_point_in_polygon(at,triangle)):continue
				var cell:=Vector2i(roundi(at.x/.55),roundi(at.y/.55))
				if not batch.samples.has(cell):batch.samples[cell]=_nearest(at,paths)
	for host:Node3D in hosts:
		var batch:Dictionary=hosts[host];var origin:Vector2=batch.origin;var index:=0
		for sample:Dictionary in batch.samples.values():
			var n:=Vector2(-sample.tangent.y,sample.tangent.x)
			var at:Vector2=sample.at+n*(.073 if index%2==0 else -.073)-origin
			var base:=Vector3(at.x,.190,at.y);var seed:=fmod(index*.618,1.0)
			# Small low triangular shards sit beside the rail, never on its centre.
			if index%2==0:
				var along:=Vector3(sample.tangent.x,0,sample.tangent.y)*.035
				for vertex in [base-along,base+along,base+Vector3(n.x*.017,.048,n.y*.017)]:
					_vertex(batch.tools[1],vertex,Vector2(.5,.5),sample.arrival,seed)
			if index%3==0:
				var centre:=Vector3(sample.at.x-origin.x,.265,sample.at.y-origin.y)
				for uv in [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]:
					_vertex(batch.tools[2],centre,uv,sample.arrival,seed)
			index+=1
		for kind in range(3):
			var mesh:Mesh=batch.tools[kind].commit()
			if mesh==null or mesh.get_surface_count()==0:continue
			var instance:=MeshInstance3D.new();instance.name="RailFrost%d_%d"%[layer,kind]
			instance.mesh=mesh;instance.material_override=materials[layer][kind]
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.extra_cull_margin=.4;instance.set_meta("rail_frost",true);instance.set_meta("frost_layer",layer);instance.set_meta("frost_kind",kind)
			host.add_child(instance);batches.append({"node":instance,"layer":layer,"kind":kind})

func transition(layer:int,previous:int,next:int) -> void:
	if previous==next:return
	old_materials[layer].clear()
	for material:ShaderMaterial in materials[layer]:old_materials[layer].append(material.duplicate())
	worlds[layer]=next
	if next==0:ages[layer]=0.0;strengths[layer]=1.0;starts[layer]+=1
	_publish()

func film_material(source:MeshInstance3D,world:int,old:bool) -> Material:
	var layer:int=source.get_meta("frost_layer");var kind:int=source.get_meta("frost_kind")
	if old and world==0 and not old_materials[layer].is_empty():return old_materials[layer][kind]
	return materials[layer][kind]

func baseline(current:Array,replay:=false) -> void:
	worlds.assign(current)
	for layer in range(2):
		ages[layer]=0.0 if replay else DURATION+TAIL
		strengths[layer]=1.0 if worlds[layer]==0 else 0.0
		if replay and worlds[layer]==0:starts[layer]+=1
	_publish();_sync_lift()

func sync(delta:float,current:Array,motion:bool) -> void:
	var dt:=minf(.05,delta/maxf(Engine.time_scale,.01))
	for layer in range(2):
		if worlds[layer]!=current[layer]:transition(layer,worlds[layer],current[layer])
		if worlds[layer]==0:
			ages[layer]=minf(DURATION+TAIL,ages[layer]+dt) if motion else DURATION+TAIL
			strengths[layer]=1.0
		else:strengths[layer]=move_toward(strengths[layer],0.0,dt/.24)
	_publish();_sync_lift()

func _publish() -> void:
	for layer in range(2):
		for material:ShaderMaterial in materials[layer]:
			material.set_shader_parameter("age",ages[layer]);material.set_shader_parameter("strength",strengths[layer])

func _sync_lift() -> void:
	if not is_instance_valid(view.lift):return
	var state=view.room.state
	# Between floors the platform is neutral; no halfway rule flip or ghost tongue.
	lift_layer=0 if state.lift_docked(0) else (1 if state.lift_docked(1) else -1)
	for material:ShaderMaterial in materials[2]:
		material.set_shader_parameter("age",ages[lift_layer] if lift_layer>=0 else DURATION+TAIL)
		material.set_shader_parameter("strength",strengths[lift_layer] if lift_layer>=0 else 0.0)
