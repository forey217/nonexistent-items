extends "res://scripts/movement_room.gd"
signal tutorial_requested
var cleared := false

func _ready() -> void:
	super._ready()
	hud.hide()
	var ui = preload("res://scripts/tutorial_hud.gd").new()
	# Use the same typography/components without creating the tutorial's HUD.
	ui.font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	var layer := CanvasLayer.new()
	add_child(layer)
	var top: Panel=ui.panel(layer,Vector2(22,16),Vector2(1236,78))
	ui.label(top,"观察局 · 接待大厅",Vector2(20,12),26,Color("344c59"))
	ui.label(top,"校准完成，已返回机构。" if cleared else "可以自由走动，或进入校准室。",Vector2(20,47),14,Color("70817d"))
	ui.button(top,"重玩校准室" if cleared else "进入校准室",Vector2(1055,18),Vector2(160,42)).pressed.connect(func(): tutorial_requested.emit())
	var footer: Panel=ui.panel(layer,Vector2(22,716),Vector2(1236,65))
	ui.label(footer,"WASD / 左键移动    ·    点击右上角按钮进入校准室    ·    R 返回起点",Vector2(18,11),16,Color("4b6371"))
	ui.label(footer,"在大厅自由走动，或重新进入校准室。",Vector2(18,37),13,Color("8a8b80"))
	ui.free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		queue_destination(event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_R: reset_player()
		if event.physical_keycode==KEY_ESCAPE: cancel_orders()
