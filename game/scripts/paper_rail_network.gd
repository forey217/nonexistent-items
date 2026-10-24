extends RefCounted
## Visual geometry only. Each network uses the simulation's own stops and edges.
const GAUGE:=.27
const WIDTH:=.065
const HEIGHT:=.15
const DOCK_LIP:=1.22
const TURN_RADIUS:=.45
const ARC_STEPS:=16
var view:Node
var joints:Dictionary={}
var segments:Array[Dictionary]=[]
var stops:Dictionary
var adjacency:Dictionary={}
var crossings:Array[Vector2]=[]
var curves:Array[Dictionary]=[]

func _init(owner_view:Node) -> void:view=owner_view

func normal(d:Vector2) -> Vector2:return Vector2(-d.y,d.x)

func endpoint(id:String,d:Vector2,offset:float) -> Vector2:
	var at:Vector2=stops[id]
	if id=="lift":return at+d*DOCK_LIP+normal(d)*offset
	var directions:Array=adjacency[id]
	if directions.size()==2:
		var other:Vector2=directions[1] if directions[0].dot(d)>.99 else directions[0]
		if absf(d.cross(other))>.01:
			return at+d*TURN_RADIUS+normal(d)*offset
	elif directions.size()==3:
		# A real T junction: open the main line's branch side, join both shoulders
		# to the branch rails. The opposite main rail stays continuous.
		var branch:=Vector2.ZERO
		for candidate:Vector2 in directions:
			if not directions.any(func(other):return candidate.dot(other)<-.99):branch=candidate
		if d.dot(branch)>.99:return at+normal(d)*offset+d*TURN_RADIUS
		if normal(d).dot(branch)*offset>0:return at+normal(d)*offset+d*TURN_RADIUS
	return at+normal(d)*offset

func build(parent:Node3D,positions:Dictionary,edges:Array,material:Material,bridge:Node3D=null) -> void:
	stops=positions
	for edge:Array in edges:
		for reverse in [false,true]:
			var a:String=edge[1] if reverse else edge[0]
			var b:String=edge[0] if reverse else edge[1]
			if not adjacency.has(a):adjacency[a]=[]
			adjacency[a].append((positions[b]-positions[a]).normalized())
	for id:String in adjacency:
		joints[id]={"pos":positions[id],"degree":adjacency[id].size(),"ends":[]}
	for edge:Array in edges:
		var a:String=edge[0];var b:String=edge[1]
		var d:Vector2=(positions[b]-positions[a]).normalized()
		var ends:Array=[]
		for side in [-1.0,1.0]:
			var start:=endpoint(a,d,side*GAUGE)
			var finish:=endpoint(b,-d,-side*GAUGE)
			joints[a].ends.append(start);joints[b].ends.append(finish);ends.append([start,finish])
			var polygon:Array[Vector2]=[endpoint(a,d,side*GAUGE-WIDTH*.5),endpoint(a,d,side*GAUGE+WIDTH*.5),endpoint(b,-d,-side*GAUGE-WIDTH*.5),endpoint(b,-d,-side*GAUGE+WIDTH*.5)]
			if bridge!=null and a=="dock" and b=="bridge":
				# Partition at the plank deck edges. The middle section inherits the
				# bridge's actual visibility; no static metal crosses an empty gap.
				var start_z:=10.75;var end_z:=12.25
				prism(parent,[polygon[0],polygon[1],Vector2(polygon[1].x,start_z),Vector2(polygon[0].x,start_z)],material)
				prism(bridge,[Vector2(polygon[0].x,start_z),Vector2(polygon[1].x,start_z),Vector2(polygon[2].x,end_z),Vector2(polygon[3].x,end_z)],material,Vector2(18,11.5))
				prism(parent,[Vector2(polygon[0].x,end_z),Vector2(polygon[1].x,end_z),polygon[2],polygon[3]],material)
			else:prism(parent,polygon,material)
		segments.append({"a":a,"b":b,"rails":ends})
		var length:float=positions[a].distance_to(positions[b])
		for i in range(1,ceili(length/.38)):
			var distance:float=i*.38
			if distance>length-.34 or distance<.34:continue
			if (is_bend(a) or adjacency[a].size()==3) and distance<TURN_RADIUS+.14:continue
			if (is_bend(b) or adjacency[b].size()==3) and length-distance<TURN_RADIUS+.14:continue
			var at:Vector2=positions[a]+d*distance
			if crossings.any(func(crossing):return crossing.distance_to(at)<.65):continue
			if (a=="lift" and distance<DOCK_LIP+.12) or (b=="lift" and length-distance<DOCK_LIP+.12):continue
			if bridge!=null and a=="dock" and b=="bridge" and at.y>10.58 and at.y<12.42:continue
			sleeper(parent,at,d)
	for id:String in adjacency:
		if id=="lift":continue
		var at:Vector2=positions[id];var directions:Array=adjacency[id]
		if is_bend(id):
			var a:Vector2=directions[0];var b:Vector2=directions[1]
			var center:=at+(a+b)*TURN_RADIUS
			for offset in [-GAUGE,GAUGE]:arc(parent,id,center,-b,-a,TURN_RADIUS+offset,material)
			for i in range(5):
				var radial:=(-b).rotated(atan2(b.cross(a),b.dot(a))*float(i)/4.0)
				view.beam(parent,view.point(center+radial*(TURN_RADIUS-.42),.065),view.point(center+radial*(TURN_RADIUS+.42),.065),.115,view.wood)
		else:sleeper(parent,at,directions[0])
		if directions.size()==3:
			var branch:=Vector2.ZERO
			for d:Vector2 in directions:
				if not directions.any(func(other):return d.dot(other)<-.99):branch=d
			for d:Vector2 in directions:
				if d.dot(branch)>.99:continue
				arc(parent,id,at+(d+branch)*TURN_RADIUS,-branch,-d,TURN_RADIUS-GAUGE,material)
				sleeper(parent,at+d*TURN_RADIUS,d)
			sleeper(parent,at+branch*TURN_RADIUS,branch)
		if directions.size()>2 or (directions.size()==2 and absf(directions[0].cross(directions[1]))>.01):
			for d:Vector2 in directions:
				for side in [-1.0,1.0]:
					var seat:=endpoint(id,d,side*GAUGE)+d*.19
					# Small fishplates beside the rail, rather than a cover over the joint.
					var outside:Vector2=seat+normal(d)*side*.045
					view.beam(parent,view.point(outside-d*.12,.143),view.point(outside+d*.12,.143),.035,view.brass)
					for step in [-.075,.075]:view.cylinder(parent,view.point(outside+d*step,.166),.021,.018,view.brass)

func sleeper(parent:Node3D,at:Vector2,d:Vector2) -> void:
	var across:=normal(d)*.42
	view.beam(parent,view.point(at-across,.065),view.point(at+across,.065),.115,view.wood)

func is_bend(id:String) -> bool:
	var directions:Array=adjacency[id]
	return directions.size()==2 and absf(directions[0].cross(directions[1]))>.01

func arc(parent:Node3D,id:String,center:Vector2,start:Vector2,finish:Vector2,radius:float,material:Material) -> void:
	var span:=atan2(start.cross(finish),start.dot(finish))
	var mesh:=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples:=PackedVector2Array()
	for i in range(ARC_STEPS+1):samples.append(center+start.rotated(span*float(i)/ARC_STEPS)*radius)
	for i in range(ARC_STEPS):
		var a:=start.rotated(span*float(i)/ARC_STEPS)
		var b:=start.rotated(span*float(i+1)/ARC_STEPS)
		var polygon:Array[Vector2]=[center+a*(radius-WIDTH*.5),center+a*(radius+WIDTH*.5),center+b*(radius+WIDTH*.5),center+b*(radius-WIDTH*.5)]
		extrude(mesh,polygon)
	mesh.generate_normals()
	var instance:=MeshInstance3D.new();instance.mesh=mesh.commit();instance.material_override=material;parent.add_child(instance)
	curves.append({"joint":id,"center":center,"radius":radius,"points":samples,"mesh":instance})

func extrude(mesh:SurfaceTool,polygon:Array[Vector2],origin:=Vector2.ZERO) -> void:
	var points:Array[Vector3]=[]
	for height in [HEIGHT-WIDTH*.5,HEIGHT+WIDTH*.5]:
		for p:Vector2 in polygon:points.append(Vector3(p.x-origin.x,height,p.y-origin.y))
	for face in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		for index in [0,1,2,0,2,3]:mesh.add_vertex(points[face[index]])

func prism(parent:Node3D,polygon:Array[Vector2],material:Material,origin:=Vector2.ZERO,cut_crossing:=true) -> void:
	# Two independent routes cross on the lower floor without a logical branch.
	# Slot the horizontal metal around the vertical metal's width to avoid
	# coplanar flashing, while leaving both real centerline routes unchanged.
	if cut_crossing and not crossings.is_empty() and absf(polygon[0].y-polygon[3].y)<.001:
		var left:=minf(polygon[0].x,polygon[3].x);var right:=maxf(polygon[0].x,polygon[3].x)
		var bottom:=minf(polygon[0].y,polygon[1].y);var top:=maxf(polygon[0].y,polygon[1].y)
		for crossing:Vector2 in crossings:
			if crossing.x<=left or crossing.x>=right or absf(crossing.y-(top+bottom)*.5)>GAUGE+WIDTH:continue
			var intervals:Array=[left,crossing.x-GAUGE-WIDTH*.5,crossing.x-GAUGE+WIDTH*.5,crossing.x+GAUGE-WIDTH*.5,crossing.x+GAUGE+WIDTH*.5,right]
			for i in [0,2,4]:
				prism(parent,[Vector2(intervals[i],bottom),Vector2(intervals[i],top),Vector2(intervals[i+1],top),Vector2(intervals[i+1],bottom)],material,origin,false)
			return
	# Straight rail ends meet the exact tangent cross-section of the circular bend.
	var mesh:=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	extrude(mesh,polygon,origin)
	mesh.generate_normals()
	var instance:=MeshInstance3D.new();instance.mesh=mesh.commit();instance.material_override=material;parent.add_child(instance)
