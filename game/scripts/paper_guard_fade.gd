extends RefCounted
## A missed ray at a post/rail edge must not immediately reverse the fade.
const RELEASE_DELAY:=.16
static func sync(section:Dictionary,covered:bool,delta:float) -> void:
	var remaining:float=section.get("occlusion_hold",0.0)
	remaining=RELEASE_DELAY if covered else maxf(0.0,remaining-delta)
	section.occlusion_hold=remaining
	var target:=.70 if covered or remaining>0.0 else 0.0
	section.fade=lerpf(section.fade,target,1.0-exp(-delta*12.0))
	if absf(section.fade-target)<.001:section.fade=target
	for mesh:GeometryInstance3D in section.meshes:
		var material:StandardMaterial3D=mesh.material_override
		# Keep opaque guards in the opaque pass; return only once fully restored.
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if section.fade>0 else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a=1.0-section.fade
