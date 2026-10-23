extends Control
signal closed
const SERIF=preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf")
const TITLE_FONT=preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf")
const INK=Color("203b4a")
const BRASS=Color("ac915c")
var audio: Node
var sheet: Control
var shade:=ColorRect.new()
var options_content:=Control.new()
var manual_content:=Control.new()
var heading: Label
var slider: HSlider
var percentage: Label
var channel_sliders: Dictionary={}
var channel_percentages: Dictionary={}
var manual_button: Button
var back_button: Button
var manual_back: Button
var body_font:=FontVariation.new()
var animation: Tween
var closing := false
var manual_lines: Array[String]=[]
var manual_groups: Array=[]
var home:=Vector2(350,80)
var instrument_mode:=false
var mill_material:=false
const Instruments=preload("res://scripts/instrument_theme.gd")

func _ready() -> void:
	size=Vector2(1280,800);mouse_filter=Control.MOUSE_FILTER_STOP
	body_font.base_font=SERIF;body_font.variation_embolden=0.16
	shade.size=size;shade.color=Color(0.025,0.04,0.055,0.56)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(shade)
	if instrument_mode:
		sheet=Panel.new()
		sheet.add_theme_stylebox_override("panel",Instruments.style(false,.90,mill_material))
	else:sheet=preload("res://scripts/archive_paper_sheet.gd").new()
	sheet.position=home;sheet.size=Vector2(580,640);add_child(sheet)
	heading=_label(sheet,"旅途选项",Rect2(55,49,470,56),40,true)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	sheet.add_child(options_content);sheet.add_child(manual_content)
	options_content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	manual_content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var rows: Array=[["master","总音量"],["music","背景音"],["sfx","音效"],["dialogue","对话语音"]]
	for i in range(rows.size()):
		var channel: String=rows[i][0]
		var y:=149.0+i*78
		_label(options_content,rows[i][1],Rect2(76,y,270,32),24)
		var value_label:=_label(options_content,"",Rect2(424,y+3,80,28),20)
		value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var control:=preload("res://scripts/archive_volume_slider.gd").new()
		control.position=Vector2(76,y+33);control.size=Vector2(428,36)
		options_content.add_child(control)
		channel_sliders[channel]=control;channel_percentages[channel]=value_label
		if channel=="master":
			slider=control;percentage=value_label
			control.value_changed.connect(audio.set_volume)
		else:control.value_changed.connect(func(value):audio.set_channel_volume(channel,value))
	manual_button=_button(options_content,"操作说明",Rect2(76,484,428,48))
	manual_button.pressed.connect(open_manual)
	back_button=_button(options_content,"返回",Rect2(76,562,428,48))
	_label(back_button,"Esc",Rect2(340,14,60,24),16).modulate=Color(1,1,1,0.65)
	back_button.pressed.connect(close)
	_build_manual()
	var focus_order: Array=[slider,channel_sliders.music,channel_sliders.sfx,channel_sliders.dialogue,manual_button,back_button]
	for i in range(focus_order.size()):
		var control: Control=focus_order[i]
		control.focus_neighbor_top=control.get_path_to(focus_order[(i+focus_order.size()-1)%focus_order.size()])
		control.focus_neighbor_bottom=control.get_path_to(focus_order[(i+1)%focus_order.size()])
		control.focus_previous=control.focus_neighbor_top;control.focus_next=control.focus_neighbor_bottom
	audio.volume_changed.connect(_sync_volume)
	audio.channel_volume_changed.connect(_sync_channel)
	_sync_volume(audio.preferences.volume)
	for channel in audio.preferences.channels:_sync_channel(channel,audio.preferences.channels[channel])
	manual_content.hide();hide()

func _label(parent: Node,text: String,rect: Rect2,points: int,title:=false) -> Label:
	var label:=Label.new()
	label.text=text;label.position=rect.position;label.size=rect.size
	label.add_theme_font_override("font",TITLE_FONT if title else body_font)
	label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",Color("e7e2d4") if instrument_mode else INK)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _style(background: Color,border: Color) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=background;style.border_color=border
	style.set_border_width_all(1);style.set_corner_radius_all(3)
	return style

func _button(parent: Node,text: String,rect: Rect2) -> Button:
	var button:=Button.new()
	button.text=text;button.position=rect.position;button.size=rect.size
	button.add_theme_font_override("font",body_font)
	button.add_theme_font_size_override("font_size",24)
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:button.add_theme_color_override(state,INK)
	button.add_theme_stylebox_override("normal",_style(Color(0.96,0.93,0.84,0.40),Color(BRASS,0.65)))
	button.add_theme_stylebox_override("hover",_style(Color(0.99,0.97,0.90,0.65),BRASS))
	button.add_theme_stylebox_override("pressed",_style(Color(0.84,0.79,0.66,0.35),BRASS))
	button.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,Color("846936")))
	if instrument_mode:
		Instruments.apply_button(button,24,mill_material,true)
	parent.add_child(button)
	button.mouse_entered.connect(audio.play_ui)
	return button

func _build_manual() -> void:
	var groups: Array=[
		["移动",[["WASD / 方向键","移动"],["鼠标左键","点击地面寻路"]]],
		["互动",[["右键镇纸 / E","互动镇纸"],["特斯拉 / 星系仪","交谈 / 选择关卡"]]],
		["世界切换",[["1 / 2 / 3","切换世界 · 冷却1.5秒"]]],
		["其他操作",[["H / R","逐步提示 / 重置校准室"],["左Alt + 左键拖动","旋转视角"],["M / F11 / F10","静音 / 全屏 / 返回主界面"]]]
	]
	var y:=139.0
	if not manual_groups.is_empty():groups=manual_groups
	for group in groups:
		_label(manual_content,group[0],Rect2(56,y,468,25),19).add_theme_color_override("font_color",Instruments.COPPER_TEXT if instrument_mode else Color("8b6c3e"))
		manual_lines.append(group[0]);y+=25
		for row in group[1]:
			_label(manual_content,row[0],Rect2(56,y,200,26),18)
			_label(manual_content,row[1],Rect2(268,y,260,26),18)
			manual_lines.append(row[0]+" "+row[1]);y+=25
		y+=3
	manual_back=_button(manual_content,"返回选项",Rect2(76,562,428,48))
	manual_back.add_theme_font_size_override("font_size",20)
	_label(manual_back,"Esc",Rect2(340,7,60,24),15).modulate=Color(1,1,1,0.65)
	manual_back.pressed.connect(close_manual)

func _sync_volume(percent: float) -> void:
	_sync_channel("master",percent)

func _sync_channel(channel: String,percent: float) -> void:
	channel_sliders[channel].set_value_no_signal(percent)
	channel_sliders[channel].queue_redraw()
	channel_percentages[channel].text="%d%%"%roundi(percent)

func open() -> void:
	if closing:return
	if is_instance_valid(animation):animation.kill()
	options_content.show();manual_content.hide();heading.text="旅途选项"
	show();modulate.a=0.0;sheet.position=home+Vector2(0,12)
	animation=create_tween().set_parallel(true)
	animation.tween_property(self,"modulate:a",1.0,0.25)
	animation.tween_property(sheet,"position",home,0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slider.grab_focus()

func close() -> void:
	if closing:return
	closing=true;audio.save_settings()
	if is_instance_valid(animation):animation.kill()
	animation=create_tween()
	animation.tween_property(self,"modulate:a",0.0,0.20)
	await animation.finished
	hide();manual_content.hide();options_content.show()
	closing=false;closed.emit()

func open_manual() -> void:
	if closing:return
	options_content.hide();manual_content.show();heading.text="操作说明"
	manual_back.grab_focus()

func close_manual() -> void:
	manual_content.hide();options_content.show();heading.text="旅途选项"
	manual_button.grab_focus()
