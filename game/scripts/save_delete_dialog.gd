extends Control
signal cancelled
signal confirmed
var slot:=0
var record: Dictionary={}
var book: RefCounted
var cancel_button: Button
var confirm_button: Button
var error_label: Label
var deleting:=false

func _ready() -> void:
	size=Vector2(1280,800);mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.size=size;shade.color=Color(0.035,0.06,0.08,0.54)
	shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade)
	var sheet=preload("res://scripts/archive_paper_sheet.gd").new()
	sheet.position=Vector2(330,185);sheet.size=Vector2(620,430);add_child(sheet)
	var font=preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf")
	_label(sheet,"删除存档 %02d？"%slot,Rect2(44,40,532,42),30,Color("253e50"),font)
	_label(sheet,"观 测 记 录 管 理",Rect2(44,86,532,25),15,Color("8c7651"),font)
	_label(sheet,"删除后，该存档的剧情与关卡进度将被清除，无法恢复。",Rect2(44,145,532,62),21,Color("704b40"),font)
	var summary:="记录无法读取"
	if record.get("status")=="ready":
		var data: Dictionary=record.data
		var stamp:=Time.get_datetime_dict_from_unix_time(int(data.saved_at)+int(Time.get_time_zone_from_system().bias)*60)
		summary="%s  ·  %s\n最近保存：%04d-%02d-%02d  %02d:%02d"%[book.location(data),book.progress(data),stamp.year,stamp.month,stamp.day,stamp.hour,stamp.minute]
	_label(sheet,summary,Rect2(44,225,532,66),18,Color("435663"),font)
	error_label=_label(sheet,"",Rect2(44,307,532,32),16,Color("8d433e"),font)
	cancel_button=_button(sheet,"保留记录",Vector2(44,354),false,font)
	confirm_button=_button(sheet,"确认删除",Vector2(330,354),true,font)
	cancel_button.pressed.connect(_cancel);confirm_button.pressed.connect(_confirm)
	cancel_button.focus_neighbor_left=confirm_button.get_path();cancel_button.focus_neighbor_right=confirm_button.get_path()
	confirm_button.focus_neighbor_left=cancel_button.get_path();confirm_button.focus_neighbor_right=cancel_button.get_path()
	cancel_button.focus_next=confirm_button.get_path();cancel_button.focus_previous=confirm_button.get_path()
	confirm_button.focus_next=cancel_button.get_path();confirm_button.focus_previous=cancel_button.get_path()
	cancel_button.grab_focus()

func _label(parent: Control,text: String,rect: Rect2,points: int,color: Color,font: Font) -> Label:
	var label:=Label.new();label.text=text;label.position=rect.position;label.size=rect.size
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",color);parent.add_child(label);return label

func _button(parent: Control,text: String,at: Vector2,danger: bool,font: Font) -> Button:
	var button:=Button.new();button.text=text;button.position=at;button.size=Vector2(246,44)
	button.add_theme_font_override("font",font);button.add_theme_font_size_override("font_size",21)
	for state in ["normal","hover","pressed","focus"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("81473f") if danger else Color("243d4a")
		if state=="hover":style.bg_color=style.bg_color.lightened(0.13)
		style.border_color=Color("e2c78e") if state=="focus" else Color("ad9366")
		style.set_border_width_all(2 if state=="focus" else 1);style.set_corner_radius_all(3)
		button.add_theme_stylebox_override(state,style)
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:button.add_theme_color_override(state,Color("fff4dc"))
	parent.add_child(button);return button

func _cancel() -> void:
	if not deleting:cancelled.emit()

func _confirm() -> void:
	if deleting:return
	deleting=true;cancel_button.disabled=true;confirm_button.disabled=true
	confirmed.emit()

func show_failure(message: String) -> void:
	deleting=false;cancel_button.disabled=false;confirm_button.disabled=false
	error_label.text=message;cancel_button.grab_focus()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	var key: int=event.physical_keycode if event.physical_keycode else event.keycode
	match key:
		KEY_ESCAPE:_cancel()
		KEY_LEFT,KEY_RIGHT:
			if not deleting:
				if cancel_button.has_focus():confirm_button.grab_focus()
				else:cancel_button.grab_focus()
		KEY_ENTER,KEY_SPACE:
			if confirm_button.has_focus():_confirm()
			else:_cancel()
		_:return
	get_viewport().set_input_as_handled()
