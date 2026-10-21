extends Node3D
var view: Node2D
var ticks: Array[MeshInstance3D]=[]
var lit: StandardMaterial3D
var dim: StandardMaterial3D
var cursor: MeshInstance3D
var stamp_ring: MeshInstance3D
var stamp_ink: StandardMaterial3D
var stamp_left := 0.0
var stamp_count := 0
var gauge_lit_count := 0
var energy: Array[MeshInstance3D]=[]
var path := PackedVector3Array()
var builder=preload("res://scripts/calibration_scene_builder.gd").new()

func _ready() -> void:
	builder.configure(0,self)
	dim=builder.material(Color("4b626b"))
	lit=builder.material(Color("9fe5cf"),true)
	lit.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var base: Vector3=view.to_world(view.room.rail_end)
	builder.box(base+Vector3(0.48,1.50,0.083),Vector3(0.045,2.40,0.018),dim)
	for i in range(12):
		ticks.append(builder.box(base+Vector3(0.48,0.32+i*2.35/11.0,0.10),Vector3(0.14,0.024,0.018),dim))
	cursor=builder.box(base+Vector3(0.48,0.32,0.12),Vector3(0.19,0.035,0.025),lit)
	stamp_ink=builder.material(Color("b2eed4"),true)
	stamp_ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	stamp_ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var torus:=TorusMesh.new()
	torus.inner_radius=0.30;torus.outer_radius=0.32
	torus.rings=48;torus.ring_segments=8
	stamp_ring=MeshInstance3D.new()
	stamp_ring.mesh=torus
	stamp_ring.material_override=stamp_ink
	stamp_ring.position=base+Vector3(0,2.73,0)
	stamp_ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stamp_ring)
	stamp_ring.hide()
	path=PackedVector3Array([base+Vector3(0,0.08,0),Vector3(9.9,0.08,4.8),Vector3(9.9,0.08,3.85),Vector3(9.9,0.08,2.0),view.to_world(view.room.portal_position,0.08)])
	for i in range(2):
		var a: Vector3=path[i]
		var b: Vector3=path[i+1]
		builder.box((a+b)*0.5,Vector3(absf(a.x-b.x)+0.04,0.018,absf(a.z-b.z)+0.04),dim)
	for i in range(4):
		var bead:=builder.cylinder(Vector3.ZERO,0.055,0.028,lit)
		bead.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bead.hide();energy.append(bead)
	view._assign_render_layer(self,1<<3)

func trigger_stamp() -> void:
	stamp_left=0.48
	stamp_count+=1

func reset_feedback() -> void:
	stamp_left=0.0
	stamp_count=0
	if stamp_ring!=null:stamp_ring.hide()

func sync(delta: float) -> void:
	var fraction: float=clampf(view.room.state.elevation/view.room.State.CEILING,0,1)
	gauge_lit_count=clampi(ceili(fraction*12),0,12)
	for i in range(12):ticks[i].material_override=lit if i<gauge_lit_count else dim
	cursor.position.y=0.32+fraction*2.35
	stamp_left=maxf(0.0,stamp_left-delta)
	stamp_ring.visible=stamp_left>0
	if stamp_left>0:
		var phase:=1.0-stamp_left/0.48
		stamp_ring.scale=Vector3.ONE*lerpf(1.22,0.94,smoothstep(0.0,0.25,phase))
		stamp_ink.albedo_color.a=1.0-smoothstep(0.25,1.0,phase)
		view.landmarks.inks[1].emission_energy_multiplier=0.3+1.7*(1.0-phase)
	var age: float=view.room.seal_age
	for i in range(3):
		var center: float=[0.18,0.38,0.90][i]
		var pulse:=maxf(0.0,1.0-absf(age-center)/0.18) if view.room.seal_active else 0.0
		view.landmarks.ring_inks[i].emission_energy_multiplier=0.65+1.1*pulse
		if pulse>0.02:
			view.landmarks.rings[i].visible=true
			view.landmarks.rings[i].scale=Vector3.ONE*(1.0+0.10*pulse)
	for i in range(energy.size()):
		var progress: float=(age-0.43)/0.48-float(i)*0.075
		energy[i].visible=view.room.seal_active and progress>=0 and progress<=1
		energy[i].position=path_point(clampf(progress,0,1))

func path_point(progress: float) -> Vector3:
	var total:=0.0
	for i in range(path.size()-1):total+=path[i].distance_to(path[i+1])
	var distance:=progress*total
	for i in range(path.size()-1):
		var length:=path[i].distance_to(path[i+1])
		if distance<=length:return path[i].lerp(path[i+1],distance/maxf(length,0.001))
		distance-=length
	return path[path.size()-1]
