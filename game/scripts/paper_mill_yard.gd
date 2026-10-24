extends RefCounted
## Decorative composition and the visible, low tool-court boundary share one definition.
const TOOL_EDGES:=[Rect2(2.28,12.25,.34,4.15),Rect2(7.38,12.25,.34,4.15),Rect2(2.28,16.22,5.44,.32),Rect2(2.28,12.25,2.12,.28),Rect2(5.6,12.25,2.12,.28)]
var buildings:Array[Dictionary]=[]
var low_details:Array[Dictionary]=[]
var tool_station:Node3D

static func blocks_tool_edge(at:Vector2,layer:int,clearance:float) -> bool:
	if layer!=0:return false
	for edge in TOOL_EDGES:
		var closest:=at.clamp(edge.position,edge.end)
		if at.distance_squared_to(closest)<clearance*clearance:return true
	return false

func exterior(v:Node) -> void:
	var settlement=v.group(v.world_root);settlement.name="HillsidePaperVillage"
	# Rear quadrants remain behind both floors throughout the permitted camera yaw.
	for spec in [[Vector2(-10,3),Vector2(5,4),3.4],[Vector2(6,-7),Vector2(5.6,3.8),4.2],[Vector2(17,-6.5),Vector2(4.6,3.4),5.0],[Vector2(-9,13),Vector2(4.2,3.3),1.0]]:
		var at:Vector2=spec[0];var size:Vector2=spec[1];var height:float=spec[2]
		var n=v.group(settlement,Vector3(at.x,height,at.y));n.name="PeripheralWorkshop%d"%buildings.size()
		var foundation:float=height+2.3
		v.box(n,Vector3(0,-foundation*.72,0),Vector3(size.x+2.6,foundation*.56,size.y+2.6),v.stone)
		v.box(n,Vector3(0,-foundation*.22,0),Vector3(size.x+1.4,foundation*.44,size.y+1.4),v.stone)
		var roofs=v.group(n);v.building(n,roofs,Vector2.ZERO,size,false)
		v.paper_rack(n,Vector2(size.x*.5+.9,0),1.5,PI*.5)
		v.vat(n,Vector2(-size.x*.5-.6,-.4))
		preload("res://scripts/static_mesh_batch.gd").compact(n)
		# Peripheral buildings cannot throw a dark silhouette across puzzle objects.
		for child in n.get_children():
			if child is GeometryInstance3D:child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		buildings.append({"root":n,"footprint":Rect2(at-size*.5-Vector2(1.6,1),size+Vector2(3.2,2))})
	# Staggered hillside landings connect the buildings without forming a foreground wall.
	for i in range(7):
		v.box(settlement,Vector3(-6.7+i*.36,2.0+i*.13,-1.6-i*.5),Vector3(1.1,.28,.55),v.stone)
	for at in [Vector2(-5,-1.8),Vector2(2,-3),Vector2(12,-2.8),Vector2(23,-3.2)]:
		v.paper_rack(settlement,at,1.9)
		v.box(settlement,v.point(at,-1.15),Vector3(2.6,2.3,1.8),v.stone)
	preload("res://scripts/static_mesh_batch.gd").compact(settlement,[&"PeripheralWorkshop0",&"PeripheralWorkshop1",&"PeripheralWorkshop2",&"PeripheralWorkshop3"])

func workyard(v:Node,parent:Node3D,layer:int) -> void:
	var details=v.group(parent);details.name="LowPapermakingDetails"
	var reed=v.mat("a99b73");var pulp=v.mat("d0c6a6");var moss=v.mat("66725b");var damp=v.mat("8c998d")
	# Flat drying mats sit at the edges, with thin reeds and no upright frames.
	for spec in [[Vector2(1.1,13.5),Vector2(.65,2.0)],[Vector2(10,16.5),Vector2(2.4,.65)],[Vector2(15,16.5),Vector2(2.0,.65)],[Vector2(20,.95),Vector2(2.6,.7)]]:
		var at:Vector2=spec[0];var size:Vector2=spec[1];var n=v.group(details,v.point(at,.025))
		v.box(n,Vector3.ZERO,Vector3(size.x,.035,size.y),reed)
		for i in range(int(size.x/.09)):
			v.box(n,Vector3(-size.x*.5+i*.09,.025,0),Vector3(.018,.014,size.y),v.wood)
		for z in [-size.y*.46,size.y*.46]:v.box(n,Vector3(0,.033,z),Vector3(size.x,.018,.018),v.wood)
		for i in range(3):
			var sheet=v.box(n,Vector3(-size.x*.24+i*size.x*.23,.048,0),Vector3(size.x*.2,.008,size.y*.62),v.paper_mat)
			sheet.rotation.y=(i-1)*.035
		low_details.append({"at":at,"height":.09,"layer":layer,"kind":"drying_mat"})
	for at in [Vector2(8.5,15.8),Vector2(12.8,16.5),Vector2(1.05,8.9),Vector2(20.8,16.5)]:
		var n=v.group(details,v.point(at));_tray(v,n,Vector2(.9,.6),pulp)
		low_details.append({"at":at,"height":.18,"layer":layer,"kind":"pulp_tray"})
	# The former second workshop becomes a low sorting bed instead of empty paving.
	var sorting=v.group(details,v.point(Vector2(10,15.1)))
	v.box(sorting,Vector3(0,.025,0),Vector3(2.0,.05,1.15),reed)
	for i in range(4):
		var at:=Vector3(-.72+i*.48,.05,.08*sin(i+layer))
		for j in range(3+i%2):
			var sheet=v.box(sorting,at+Vector3(0,j*.018,0),Vector3(.38,.014,.72),v.paper_mat)
			sheet.rotation.y=.04*sin(i*3+j)
		for z in [-.48,.48]:v.box(sorting,Vector3(at.x,.13,z),Vector3(.39,.035,.035),v.wood)
	low_details.append({"at":Vector2(10,15.1),"height":.15,"layer":layer,"kind":"sorting_bed"})
	# Recessed wet stone, scattered fibers and moss communicate production at ground level.
	for i in range(14):
		var at:=Vector2(.9+fmod(i*5.37,21.8),.85 if i%2==0 else 17.05)
		var n=v.group(details,v.point(at,.012))
		v.box(n,Vector3.ZERO,Vector3(.55+.11*(i%3),.012,.13),damp)
		for j in range(4):
			var fiber=v.box(n,Vector3(-.21+j*.14,.009,.07*sin(i+j)),Vector3(.11,.008,.019),pulp)
			fiber.rotation.y=.3*sin(i*2+j)
		v.box(n,Vector3(.34,.006,.09),Vector3(.19,.01,.11),moss)
	if layer==0:
		# A low water curb replaces the old enclosing walls. Its actual solid edge
		# preserves the old-corridor route without leaving invisible house collisions.
		for edge in TOOL_EDGES:
			var center:Vector2=edge.get_center()
			v.box(details,v.point(center,.09),Vector3(edge.size.x,.18,edge.size.y),v.stone)
			v.box(details,v.point(center,.185),Vector3(maxf(.06,edge.size.x-.12),.015,maxf(.06,edge.size.y-.12)),damp)
		tool_station=v.group(details,v.point(v.S.TOOL));tool_station.name="OpenToolStation"
		v.box(tool_station,Vector3(0,.36,.36),Vector3(.95,.1,.46),v.wood)
		for x in [-.34,.34]:v.box(tool_station,Vector3(x,.16,.36),Vector3(.07,.32,.3),v.wood)
		# A recessed dark tool tray frames the real, removable clip model.
		v.box(tool_station,Vector3(0,.423,.36),Vector3(.70,.016,.40),v.dark)
		for x in [-.37,.37]:v.box(tool_station,Vector3(x,.44,.36),Vector3(.025,.035,.44),v.brass)
		for x in [-.19,.19]:v.box(tool_station,Vector3(x,.06,-.18),Vector3(.12,.05,.4),v.wood)
		# Flat tool outlines and a few folded sheets, never a roof over the pickup.
		for i in range(2):v.box(tool_station,Vector3(-.45+i*.90,.425,.36),Vector3(.10,.015,.24),v.paper_mat)
		preload("res://scripts/static_mesh_batch.gd").compact(tool_station)
	preload("res://scripts/static_mesh_batch.gd").compact(details,[&"OpenToolStation"])

func _tray(v:Node,n:Node3D,size:Vector2,pulp:Material) -> void:
	v.box(n,Vector3(0,.035,0),Vector3(size.x,.05,size.y),v.wood)
	for x in [-size.x*.5,size.x*.5]:v.box(n,Vector3(x,.105,0),Vector3(.035,.14,size.y),v.wood)
	for z in [-size.y*.5,size.y*.5]:v.box(n,Vector3(0,.105,z),Vector3(size.x,.14,.035),v.wood)
	v.box(n,Vector3(0,.085,0),Vector3(size.x-.08,.015,size.y-.08),pulp)
	for i in range(4):v.box(n,Vector3(-.3+i*.19,.10,0),Vector3(.08,.008,.32),v.paper_mat)
