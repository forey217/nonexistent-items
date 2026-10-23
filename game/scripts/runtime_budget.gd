extends Node
## Avoid burning laptop CPU/GPU on a 165 Hz menu or a background window.
const FOREGROUND_FPS:=60
const BACKGROUND_FPS:=30
func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		Engine.max_fps=0
		return
	Engine.max_fps=FOREGROUND_FPS if DisplayServer.window_is_focused() else BACKGROUND_FPS
func _notification(what: int) -> void:
	if DisplayServer.get_name()=="headless":return
	if what==NOTIFICATION_APPLICATION_FOCUS_IN:Engine.max_fps=FOREGROUND_FPS
	elif what==NOTIFICATION_APPLICATION_FOCUS_OUT:Engine.max_fps=BACKGROUND_FPS
