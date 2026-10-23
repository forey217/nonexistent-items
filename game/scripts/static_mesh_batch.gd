extends RefCounted
## Merge only opaque, single-surface static leaves. Movable roots and wall
## partitions stay separate, so world selection, occlusion and puzzle state agree.
static func compact(parent: Node3D,partitions: Array[StringName]=[]) -> void:
	var groups: Dictionary={}
	_collect(parent,Transform3D.IDENTITY,groups,partitions)
	for group: Dictionary in groups.values():
		if group.items.size()<2:continue
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for item: Dictionary in group.items:
			surface.append_from(item.node.mesh,0,item.transform)
		var merged:=MeshInstance3D.new()
		merged.name="StaticBatch"
		merged.mesh=surface.commit()
		merged.material_override=group.material
		merged.cast_shadow=group.shadow
		merged.layers=group.layers
		parent.add_child(merged)
		for item: Dictionary in group.items:item.node.free()
	for name: StringName in partitions:
		var section:=parent.get_node_or_null(NodePath(name)) as Node3D
		if section!=null:compact(section)

static func _collect(node: Node3D,pose: Transform3D,groups: Dictionary,partitions: Array[StringName]) -> void:
	for child in node.get_children():
		if not child is Node3D or child.name in partitions:continue
		var transform: Transform3D=pose*child.transform
		if child is MeshInstance3D and child.get_child_count()==0 and child.visible and child.mesh!=null and child.mesh.get_surface_count()==1:
			var mesh: Mesh=child.mesh
			var material: Material=child.material_override if child.material_override!=null else mesh.surface_get_material(0)
			if (mesh is BoxMesh or mesh is CylinderMesh or mesh is PlaneMesh or mesh is QuadMesh) and material is StandardMaterial3D and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:
				var key: String="%s:%s:%s"%[material.get_instance_id(),child.cast_shadow,child.layers]
				if not groups.has(key):groups[key]={"material":material,"shadow":child.cast_shadow,"layers":child.layers,"items":[]}
				groups[key].items.append({"node":child,"transform":transform})
				continue
		_collect(child,transform,groups,partitions)
