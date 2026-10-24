extends SceneTree
## Hidden-window native GPU check runner. Never included in exported builds.
class DrawPump extends Node:
	func _process(_delta:float) -> void:
		RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
		RenderingServer.force_draw.call_deferred(true)

func _initialize() -> void:
	root.add_child.call_deferred(DrawPump.new())
	root.add_child.call_deferred(load("res://main.tscn").instantiate())
