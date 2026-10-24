extends Control
signal action_requested(action:String)
signal opened_changed(opened:bool)
const Instruments=preload("res://scripts/instrument_theme.gd")
var audio:Node
var paper_level:=false
var shade:=ColorRect.new()
var panel:=Panel.new()
var menu_scroll:=ScrollContainer.new()
var menu_contents:=Control.new()
var content_height:=0.0
var buttons:Dictionary={}
var options:Control
var confirmation:=Panel.new()
var pending_action:=""
var confirmation_text:Label
var confirm_button:Button
var cancel_button:Button
var return_focus:Control

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade.color=Color(.015,.035,.05,.20);shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade)
	shade.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_LEFT and not options.visible and not confirmation.visible:close()
			accept_event())
	panel.add_theme_stylebox_override("panel",Instruments.style(false,.90,paper_level));panel.mouse_force_pass_scroll_events=false;add_child(panel)
	Instruments.label(panel,"观测仪表",Vector2(18,12),Vector2(240,30),24,Instruments.COPPER_TEXT).add_theme_font_override("font",Instruments.TITLE)
	var rows:Array=[["view","复位视角"],["hub","返回机构"],["reset","恢复稳定记录   R" if paper_level else "重置关卡   R"],["hint","请求提示   H"],["manual","操作说明"],["options","声音设置"],["title","返回主界面   F10"]]
	if paper_level:rows.insert(3,["restart","完整重开本关"])
	if paper_level:rows.append_array([["mute","声音开关   M"],["fullscreen","全屏   F11"],["quit","退出游戏"]])
	if paper_level:
		var at:=rows.find(["manual","操作说明"])
		rows.insert(at,["demo_heading","演示"]);rows.insert(at+1,["demo","第二关完整演示"])
	menu_scroll.position=Vector2(12,49);menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus=true;panel.add_child(menu_scroll);menu_scroll.add_child(menu_contents)
	for row in rows:
		var action:String=row[0]
		if action=="demo_heading":
			Instruments.label(menu_contents,"演示",Vector2(8,content_height+2),Vector2(240,25),17,Instruments.COPPER_TEXT);content_height+=30
			continue
		var b:=_button(menu_contents,row[1],Rect2(0,content_height,240,37));content_height+=43
		b.focus_entered.connect(func():menu_scroll.ensure_control_visible.call_deferred(b))
		buttons[action]=b;b.pressed.connect(func():request_action(action))
	menu_contents.custom_minimum_size=Vector2(240,content_height);menu_contents.size=menu_contents.custom_minimum_size
	panel.size=Vector2(280,56+content_height)
	options=preload("res://scripts/archive_options.gd").new();options.audio=audio
	options.instrument_mode=true;options.mill_material=paper_level
	if paper_level:
		options.manual_groups=[
			["移动",[["WASD / 方向键","移动"],["左键地面 / 楼梯","寻路 / 自动上下楼"]]],
			["互动",[["右键镇纸 / E","打开方向箭头"],["左键箭头","走位并推动"],["任务记录","查看镇纸 / 留影夹"]]],
			["世界切换",[["1 / 2 / 3 / 4","切当前观察层规则"],["Tab","切观察层，人物不传送"]]],
			["其他操作",[["滚轮 / 中键","缩放 / 平移"],["左Alt + 左键","旋转视角"],["F / H / R","回人物 / 提示 / 稳定记录"],["M / F11 / F10","静音 / 全屏 / 主界面"]]]]
	add_child(options)
	options.closed.connect(func():panel.show();buttons.options.grab_focus())
	confirmation.add_theme_stylebox_override("panel",Instruments.style(false,.92,paper_level));confirmation.size=Vector2(430,190);add_child(confirmation);confirmation.hide()
	confirmation_text=Instruments.label(confirmation,"",Vector2(24,22),Vector2(382,80),21)
	confirmation_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cancel_button=_button(confirmation,"返回",Rect2(24,126,180,42));cancel_button.pressed.connect(_cancel_confirmation)
	confirm_button=_button(confirmation,"确认重置",Rect2(226,126,180,42));confirm_button.pressed.connect(func():_dispatch(pending_action))
	get_viewport().size_changed.connect(_layout);_layout();hide()

func _button(parent:Node,text:String,rect:Rect2) -> Button:
	var b:=Button.new();b.text=text;b.position=rect.position;b.size=rect.size;Instruments.apply_button(b,20,paper_level,true);parent.add_child(b)
	b.pressed.connect(func():
		if is_instance_valid(audio):audio.play_ui())
	return b

func _layout() -> void:
	var dimensions:=get_viewport().get_visible_rect().size
	size=dimensions;shade.size=dimensions;panel.size.y=minf(56+content_height,maxf(180,dimensions.y-102));panel.position=Vector2(dimensions.x-panel.size.x-24,78)
	menu_scroll.size=Vector2(256,panel.size.y-56)
	confirmation.position=(dimensions-confirmation.size)*.5
	if is_instance_valid(options):
		options.size=dimensions;options.shade.size=dimensions;options.home=(dimensions-options.sheet.size)*.5
		if not options.visible:options.sheet.position=options.home
		elif not options.closing:
			if is_instance_valid(options.animation):options.animation.kill()
			options.modulate.a=1;options.sheet.position=options.home

func open(focus:Control=null) -> void:
	return_focus=focus;confirmation.hide();options.hide();panel.show();show();opened_changed.emit(true);buttons.view.grab_focus()

func close() -> void:
	if options.visible:audio.save_settings()
	options.hide();confirmation.hide();hide();opened_changed.emit(false)
	if is_instance_valid(return_focus):return_focus.grab_focus()

func request_action(action:String) -> void:
	if action in ["reset","restart"]:
		if not visible:open()
		pending_action=action;panel.hide();confirmation.show();cancel_button.grab_focus()
		confirmation_text.text="恢复最近稳定的观测记录？" if paper_level and action=="reset" else "重新开始本关？当前未归档的机关进度将被重置。"
		confirm_button.text="恢复记录" if paper_level and action=="reset" else "确认重置"
	elif action in ["manual","options"]:
		panel.hide();options.open()
		if action=="manual":options.open_manual()
	else:_dispatch(action)

func _cancel_confirmation() -> void:
	confirmation.hide();panel.show();buttons.reset.grab_focus()

func _dispatch(action:String) -> void:
	close();action_requested.emit(action)

func _input(event:InputEvent) -> void:
	if not visible:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			if options.visible:
				if options.manual_content.visible:options.close_manual()
				else:options.close()
			elif confirmation.visible:_cancel_confirmation()
			else:close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode not in [KEY_M,KEY_F10,KEY_F11,KEY_TAB,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_ENTER,KEY_SPACE]:
			get_viewport().set_input_as_handled()
