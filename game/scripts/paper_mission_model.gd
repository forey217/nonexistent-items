extends Node3D
## The same geometry is used in the workshop and in the transparent item exhibit.
const Batch=preload("res://scripts/static_mesh_batch.gd")
var kind:=""
var face:MeshInstance3D
var latch:Node3D
var accent:StandardMaterial3D
var copper:StandardMaterial3D
var stone:StandardMaterial3D
var timber:StandardMaterial3D
var recess:StandardMaterial3D
var paper:StandardMaterial3D
var response:=0.0
var fixed:=false
var phase_materials:Array[StandardMaterial3D]=[]

func _init(id:="clip") -> void:
	kind=id;name="Mission_"+kind
	copper=material("9e8e6b",.64,.35);accent=material("baa77d",.52,.38)
	stone=material("69796e",.92);timber=material("574a38",.9)
	recess=material("293d37",.95);paper=material("e3d7b5",.94)
	match kind:
		"clip":build_clip()
		"mountain","water":build_weight()
		"catch_pad","sluice_pad","upper_anchor","lower_anchor":build_pad()
		"ring":build_ring()
		"lift":build_lift()
	Batch.compact(self,[&"Face",&"Latch"])
	if is_instance_valid(face):Batch.compact(face)
	if is_instance_valid(latch):Batch.compact(latch)

func material(hex:String,roughness:float,metallic:=0.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=roughness;m.metallic=metallic
	return m

func box(parent:Node3D,at:Vector3,dimensions:Vector3,m:Material) -> MeshInstance3D:
	var n:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=dimensions;n.mesh=mesh;n.material_override=m;n.position=at;parent.add_child(n);return n

func cylinder(parent:Node3D,at:Vector3,radius:float,height:float,m:Material) -> MeshInstance3D:
	var n:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=24;n.mesh=mesh;n.material_override=m;n.position=at;parent.add_child(n);return n

func bar(parent:Node3D,a:Vector3,b:Vector3,width:float,m:Material) -> MeshInstance3D:
	var n:=box(parent,(a+b)*.5,Vector3(width,a.distance_to(b),width),m)
	if a.distance_to(b)>.0001:n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return n

func arc(parent:Node3D,at:Vector3,radius:float,start:float,end:float,width:float,m:Material,vertical:=false) -> void:
	var count:=maxi(6,ceili(absf(end-start)*10))
	for i in range(count):
		var a:=lerpf(start,end,float(i)/count);var b:=lerpf(start,end,float(i+1)/count)
		var p:=Vector3(cos(a)*radius,sin(a)*radius,0) if vertical else Vector3(cos(a)*radius,0,sin(a)*radius)
		var q:=Vector3(cos(b)*radius,sin(b)*radius,0) if vertical else Vector3(cos(b)*radius,0,sin(b)*radius)
		bar(parent,at+p,at+q,width,m)

func rivets(parent:Node3D,y:float,extent:float) -> void:
	for x in [-extent,extent]:
		for z in [-extent,extent]:
			cylinder(parent,Vector3(x,y,z),.028,.018,copper)
			box(parent,Vector3(x,y+.012,z),Vector3(.025,.006,.006),recess)

func build_clip() -> void:
	# Two opposed jaws with an actual dark slot, spindle and return spring.
	for side in [-1,1]:
		var jaw:=box(self,Vector3(side*.135,.13,-.015),Vector3(.10,.12,.43),copper)
		jaw.rotation.z=side*.09
		box(self,Vector3(side*.086,.13,-.19),Vector3(.025,.10,.10),recess)
		box(self,Vector3(side*.16,.075,.235),Vector3(.10,.045,.18),copper)
		box(self,Vector3(side*.135,.198,-.03),Vector3(.035,.013,.31),accent)
		for z in [-.13,-.04,.05]:box(self,Vector3(side*.083,.13,z),Vector3(.022,.045,.026),copper)
	var axle:=cylinder(self,Vector3(0,.14,.115),.066,.40,copper);axle.rotation.z=PI*.5
	for x in [-.205,.205]:
		var cap:=cylinder(self,Vector3(x,.14,.115),.047,.018,recess);cap.rotation.z=PI*.5
		var pin:=cylinder(self,Vector3(x*1.05,.14,.115),.025,.02,accent);pin.rotation.z=PI*.5
	for i in range(7):arc(self,Vector3(-.064+i*.021,.14,.115),.071,0,TAU,.009,recess,true)
	box(self,Vector3(0,.055,-.10),Vector3(.12,.012,.29),paper)
	for i in range(4):box(self,Vector3(.018,.063,-.185+i*.032),Vector3(.06,.005,.004),copper)
	bar(self,Vector3(-.03,.066,-.11),Vector3(.03,.066,-.05),.009,accent)

func build_weight() -> void:
	# Keep the existing gameplay envelope: .64 wide, .5 high, with a stable base.
	box(self,Vector3(0,.055,0),Vector3(.70,.11,.70),recess)
	box(self,Vector3(0,.285,0),Vector3(.61,.40,.61),stone)
	box(self,Vector3(0,.50,0),Vector3(.65,.035,.65),copper)
	box(self,Vector3(0,.523,0),Vector3(.53,.018,.53),recess)
	for x in [-.29,.29]:
		for z in [-.29,.29]:box(self,Vector3(x,.285,z),Vector3(.055,.43,.055),copper)
	for y in [.14,.43]:
		for z in [-.309,.309]:box(self,Vector3(0,y,z),Vector3(.46,.022,.012),copper)
	if kind=="mountain":
		for offset in [-.12,0.0,.12]:
			var top:=Vector3(offset,.59 if offset==0 else .565,-.025)
			bar(self,Vector3(offset-.085,.54,.14),top,.035,accent)
			bar(self,top,Vector3(offset+.085,.54,.14),.035,accent)
	else:
		for row in range(3):
			for i in range(12):
				var x:float=-.21+i*.035;var nx:=x+.035
				bar(self,Vector3(x,.55,-.14+row*.14+sin(x*15)*.035),Vector3(nx,.55,-.14+row*.14+sin(nx*15)*.035),.023,accent)
	rivets(self,.529,.28)

func build_pad() -> void:
	box(self,Vector3(0,.065,0),Vector3(1.22,.13,1.22),stone)
	box(self,Vector3(0,.138,0),Vector3(1.10,.024,1.10),recess)
	for x in [-.39,.39]:
		for z in [-.39,.39]:
			cylinder(self,Vector3(x,.18,z),.045,.17,copper)
			for i in range(4):arc(self,Vector3(x,.13+i*.025,z),.058,0,TAU,.009,recess)
	face=box(self,Vector3(0,.23,0),Vector3(1.02,.065,1.02),timber);face.name="Face"
	box(face,Vector3(0,.038,0),Vector3(.88,.012,.88),stone)
	for side in [-1,1]:
		box(face,Vector3(side*.466,.045,0),Vector3(.018,.016,.94),copper)
		box(face,Vector3(0,.045,side*.466),Vector3(.94,.016,.018),copper)
		for z in [-.29,.29]:box(face,Vector3(side*.49,.050,z),Vector3(.04,.012,.075),accent)
	rivets(face,.05,.40)
	if kind=="catch_pad":
		# A shallow tray/catch symbol with a downward point.
		for side in [-1,1]:bar(face,Vector3(side*.24,.06,-.02),Vector3(side*.24,.06,.20),.035,accent)
		bar(face,Vector3(-.24,.06,.20),Vector3(.24,.06,.20),.035,accent)
		bar(face,Vector3(0,.06,-.25),Vector3(0,.06,.05),.035,accent)
		for side in [-1,1]:bar(face,Vector3(0,.06,.05),Vector3(side*.10,.06,-.05),.03,accent)
	elif kind=="sluice_pad" or kind=="lower_anchor":
		for row in range(3):
			for i in range(10):
				var x:float=-.26+i*.052
				bar(face,Vector3(x,.06,-.20+row*.20+sin(x*13)*.04),Vector3(x+.052,.06,-.20+row*.20+sin((x+.052)*13)*.04),.027,accent)
	else:
		for x in [-.15,0.0,.15]:
			bar(face,Vector3(x-.1,.06,.20),Vector3(x,.06,-.20),.035,accent)
			bar(face,Vector3(x,.06,-.20),Vector3(x+.1,.06,.20),.035,accent)

func build_ring() -> void:
	box(self,Vector3(0,.055,0),Vector3(.56,.11,.30),timber)
	for x in [-.21,.21]:
		box(self,Vector3(x,.13,0),Vector3(.13,.10,.18),copper)
		cylinder(self,Vector3(x,.19,0),.027,.025,recess)
	arc(self,Vector3(0,.37,0),.24,deg_to_rad(-65),deg_to_rad(245),.055,copper,true)
	arc(self,Vector3(0,.37,.008),.20,deg_to_rad(-55),deg_to_rad(230),.012,accent,true)
	var hinge:=cylinder(self,Vector3(-.10,.16,0),.06,.22,copper);hinge.rotation.x=PI*.5
	latch=Node3D.new();latch.name="Latch";add_child(latch)
	box(latch,Vector3(.06,.17,0),Vector3(.22,.045,.10),recess)
	box(latch,Vector3(.06,.197,0),Vector3(.10,.012,.08),accent)

func build_lift() -> void:
	for i in range(3):phase_materials.append(accent.duplicate())
	box(self,Vector3(0,-.12,0),Vector3(2.2,.24,2.2),timber)
	for i in range(9):box(self,Vector3(-.98+i*.245,.035,0),Vector3(.225,.07,2.12),timber)
	for x in [-1.07,1.07]:
		box(self,Vector3(x,.08,0),Vector3(.07,.09,2.20),phase_materials[0])
		box(self,Vector3(x,-.23,0),Vector3(.12,.15,2.15),recess)
		for z in [-.96,.96]:
			box(self,Vector3(x,.19,z),Vector3(.13,.24,.15),copper)
			arc(self,Vector3(x,.38,z),.11,0,TAU,.028,phase_materials[1],true)
		for z in [-.65,0.0,.65]:cylinder(self,Vector3(x,.135,z),.032,.022,recess)
	for z in [-1.07,1.07]:
		box(self,Vector3(0,.08,z),Vector3(2.12,.09,.065),copper)
		for i in range(9):box(self,Vector3(-.8+i*.2,.135,z),Vector3(.055,.012,.045),phase_materials[2])
	for side in [-1,1]:bar(self,Vector3(-.9,-.30,side*.80),Vector3(.9,-.30,-side*.80),.10,recess)

func set_response(amount:float,age:=0.0) -> void:
	response=clampf(amount,0,1)
	accent.emission_enabled=true;accent.emission=Color("d6c18b");accent.emission_energy_multiplier=.05+response*.75
	copper.emission_enabled=response>.01;copper.emission=Color("b29a65");copper.emission_energy_multiplier=response*.20
	for i in range(phase_materials.size()):
		var part:=phase_materials[i];part.emission_enabled=true;part.emission=Color("d6c18b")
		part.emission_energy_multiplier=response*.85*smoothstep(i*.40,i*.40+.25,age)

func set_fixed(value:bool) -> void:
	fixed=value
	if is_instance_valid(latch):latch.rotation.z=-.16 if value else .20
