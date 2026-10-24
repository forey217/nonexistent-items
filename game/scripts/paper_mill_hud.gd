extends CanvasLayer
## The paper mill keeps its four actual worlds and two observation floors.
const Instruments=preload("res://scripts/instrument_theme.gd")
const INK=Instruments.DEEP
const TEXT=Instruments.TEXT
const GOLD=Instruments.COPPER_TEXT
const MUTED=Instruments.MUTED
var room:Node
var root:=Control.new()
var font:=Instruments.body()
var objective:Panel
var objective_feedback=preload("res://scripts/paper_task_receipt.gd").new()
var objective_heading:Label
var objective_body:Label
var law:Label
var inventory:Label
var status:Label
var selection:Label
var rule_buttons:Array[Button]=[]
var layer_selector:=MenuButton.new()
var subtitle_pages:Array[String]=[]
var subtitle_display_pages:Array[String]=[]
var subtitle_started:=0.0
var subtitle_duration:=6.0
var deferred_notice:Dictionary={}
var destination_buttons:Array[Button]=[]
var menu_buttons:Array[Button]=[]
var hover_target:=""
var message_time:=0.0
var last_message:=""
var last_message_at:=-10.0
var clock:=0.0
var worlds:Panel
var badges:Panel
var bag:HBoxContainer
var bag_shade:Panel
var tools_shade:Panel
var bag_buttons:Array[Button]=[]
var tools:=HBoxContainer.new()
var menu_button:Button
var destination_panel:Panel
var footer:Panel
var record:Panel
var hint:Label
var record_task:Label
var subtitle_panel:Panel
var subtitle_name:Label
var subtitle_body:Label
var portrait:TextureRect
var menu_shade:ColorRect
var menu:Control
var help_panel:Control
var channel_sliders:Dictionary={}
var channel_values:Dictionary={}
var audio:Node
var saved_time:=0.0
var saved_label:Label
var last_checkpoint:=-1
var law_popup:Panel
var law_detail:Label
var law_hovered:=false
var law_time:=3.0
var last_world:=-1
var last_layer:=-1
var entry_hint:Control
var object_panel:Panel
var object_label:Label
var record_pinned:=false
var record_timer:=Timer.new()
var task_flash:=0.0
var styled_world:=-1
var push_picker=preload("res://scripts/paper_push_picker.gd").new()

func style(active:=false) -> StyleBox:
	return Instruments.style(active,.88,true)

func quiet_button(b:Button) -> void:
	for state in ["normal","disabled"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state in ["hover","pressed"]:b.add_theme_stylebox_override(state,Instruments.state_style(state=="pressed",true))

func panel(parent:Node) -> Panel:
	var p:=Panel.new();p.mouse_force_pass_scroll_events=false;p.add_theme_stylebox_override("panel",style());parent.add_child(p);return p

func label(parent:Node,text:String,at:Vector2,dimensions:Vector2,points:=18,color:=TEXT) -> Label:
	return Instruments.label(parent,text,at,dimensions,points,color)

func button(parent:Node,text:String,at:Vector2,dimensions:Vector2,action:Callable) -> Button:
	var b:=Button.new();b.text=text;b.position=at;b.size=dimensions;b.custom_minimum_size=dimensions
	Instruments.apply_button(b,19,true,true);parent.add_child(b);menu_buttons.append(b)
	quiet_button(b)
	if action.is_valid():b.pressed.connect(action)
	b.pressed.connect(func():
		if audio!=null:audio.play_ui())
	return b

func _ready() -> void:
	layer=5
	if room.get_parent().get("ambience")!=null:audio=room.get_parent().ambience
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	objective=panel(root);objective.position=Vector2(24,20);objective.size=Vector2(300,92)
	objective.mouse_filter=Control.MOUSE_FILTER_IGNORE
	objective_feedback.hud=self;objective.add_child(objective_feedback)
	objective_heading=objective_feedback.heading;objective_body=objective_feedback.body
	worlds=panel(root);worlds.size=Vector2(572,46)
	var row:=HBoxContainer.new();row.position=Vector2(6,3);row.size=worlds.size-Vector2(12,6);row.add_theme_constant_override("separation",4);worlds.add_child(row)
	layer_selector.custom_minimum_size=Vector2(164,40);Instruments.apply_button(layer_selector,18,true,true);quiet_button(layer_selector);row.add_child(layer_selector)
	layer_selector.get_popup().add_item("上层 · 晒纸院",0);layer_selector.get_popup().add_item("下层 · 水碓坊",1)
	layer_selector.get_popup().id_pressed.connect(func(next):room.observe(next))
	layer_selector.get_popup().add_theme_stylebox_override("panel",style(true))
	layer_selector.get_popup().add_theme_font_override("font",font);layer_selector.get_popup().add_theme_font_size_override("font_size",20)
	layer_selector.tooltip_text="切换操作层；Tab 同样可切换，人物不传送"
	for i in range(4):
		var next:=i
		var item:=button(row,str(i+1)+" "+["冰晶","重力","倒悬","显影"][i],Vector2.ZERO,Vector2(94,40),func():room.change_world(next))
		item.add_theme_font_size_override("font_size",18)
		rule_buttons.append(item)
	badges=panel(root);badges.size=Vector2(572,32)
	law=label(badges,"",Vector2(10,4),Vector2(552,25),17)
	badges.mouse_entered.connect(func():law_hovered=true);badges.mouse_exited.connect(func():law_hovered=false)
	law_popup=panel(root);law_popup.size=Vector2(282,128);law_popup.mouse_filter=Control.MOUSE_FILTER_IGNORE
	law_detail=label(law_popup,"",Vector2(14,10),Vector2(254,108),17);law_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	menu_button=button(root,"≡",Vector2.ZERO,Vector2(44,44),toggle_menu);menu_button.tooltip_text="观测菜单 · Esc"
	menu_button.add_theme_stylebox_override("normal",style())
	saved_label=label(root,"",Vector2.ZERO,Vector2(240,24),16);saved_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	saved_label.add_theme_color_override("font_outline_color",INK);saved_label.add_theme_constant_override("outline_size",3)
	_build_record();_build_destinations();_build_subtitle();_build_menu()
	bag_shade=panel(root);bag_shade.size=Vector2(380,40)
	bag.reparent(bag_shade);bag.position=Vector2(6,1);bag.size=Vector2(368,38)
	bag_buttons[2].reparent(bag)
	for i in range(3):
		bag_buttons[i].custom_minimum_size=Vector2(100 if i<2 else 158,38)
		bag_buttons[i].add_theme_font_size_override("font_size",18)
	tools_shade=panel(root);tools_shade.size=Vector2(268,40)
	tools_shade.add_child(tools);tools.position=Vector2(6,1);tools.add_theme_constant_override("separation",6)
	button(tools,"回人物 F",Vector2.ZERO,Vector2(96,38),func():room.view.return_to_actor())
	button(tools,"提示 H",Vector2.ZERO,Vector2(82,38),func():room.show_hint())
	button(tools,"工具",Vector2.ZERO,Vector2(66,38),toggle_details)
	object_panel=panel(root);object_panel.size=Vector2(220,61);object_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;object_panel.hide()
	object_label=label(object_panel,"",Vector2(12,8),Vector2(196,50),17);object_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	root.move_child(menu,root.get_child_count()-1)
	footer=panel(root);footer.size=Vector2(520,46);footer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status=label(footer,"",Vector2(12,5),Vector2(496,38),18);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	entry_hint=preload("res://scripts/level_entry_hint.gd").new();entry_hint.text="右键镇纸 → 左键方向　·　WASD / 左键移动　·　走入楼梯换层";root.add_child(entry_hint)
	push_picker.room=room;root.add_child(push_picker)
	tools.mouse_filter=Control.MOUSE_FILTER_IGNORE
	record_timer.one_shot=true;record_timer.wait_time=.22;add_child(record_timer)
	record_timer.timeout.connect(func():
		if not record_pinned:record.hide())
	get_viewport().size_changed.connect(_layout);_layout();refresh(0)
	root.modulate.a=0;create_tween().tween_property(root,"modulate:a",1.0,.25)

func _build_record() -> void:
	record=panel(root);record.size=Vector2(350,490);record.hide()
	label(record,"观测记录",Vector2(16,10),Vector2(190,30),23,GOLD).add_theme_font_override("font",Instruments.TITLE)
	button(record,"物件图鉴",Vector2(205,9),Vector2(90,32),func():room.mission_guide.inspect("tool"))
	button(record,"×",Vector2(300,8),Vector2(36,34),func():record.hide();record_pinned=false)
	record_task=label(record,"",Vector2(16,54),Vector2(318,65),18);record_task.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	inventory=label(record,"",Vector2(16,125),Vector2(318,106),17,MUTED)
	bag=HBoxContainer.new();bag.position=Vector2(16,239);bag.add_theme_constant_override("separation",6);record.add_child(bag)
	for i in range(2):
		var index:=i
		bag_buttons.append(button(bag,"",Vector2.ZERO,Vector2(154,38),func():room.focus_target("w%d"%index)))
	bag_buttons.append(button(record,"",Vector2(16,283),Vector2(314,38),func():room.recall_clip()))
	inventory.size.y=206
	hint=label(record,"需要时再展开线索。",Vector2(16,337),Vector2(318,90),18);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(record,"下一条提示   H",Vector2(16,437),Vector2(314,39),func():room.show_hint())
	record.mouse_entered.connect(func():record_timer.stop())
	record.mouse_exited.connect(func():record_timer.start())

func _build_destinations() -> void:
	# Kept hidden for old UI callers; there are no choices, controls or map hit area.
	destination_panel=Panel.new();root.add_child(destination_panel);destination_panel.hide()

func _build_subtitle() -> void:
	subtitle_panel=panel(root);subtitle_panel.size=Vector2(720,90);subtitle_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;subtitle_panel.hide()
	portrait=TextureRect.new();portrait.position=Vector2(10,20);portrait.size=Vector2(44,48);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;subtitle_panel.add_child(portrait)
	subtitle_name=label(subtitle_panel,"",Vector2(82,9),Vector2(600,23),16,GOLD)
	subtitle_body=label(subtitle_panel,"",Vector2(82,34),Vector2(620,55),19);subtitle_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle_body.max_lines_visible=2

func _build_menu() -> void:
	menu=preload("res://scripts/level_hud_menu.gd").new();menu.audio=audio;menu.paper_level=true;root.add_child(menu)
	menu_shade=menu.shade;help_panel=menu.options;channel_sliders=menu.options.channel_sliders;channel_values=menu.options.channel_percentages
	menu.action_requested.connect(_menu_action)
	menu.opened_changed.connect(func(opened):
		room.player.controls_locked=opened or room.arrival_busy() or room.interacting
		room.player.cancel_navigation();room.view.cancel_drag()
		if opened:
			room.cancel_push_command()
			record.hide();record_pinned=false;destination_panel.hide();subtitle_panel.hide();footer.hide();entry_hint.hide();entry_hint.obscured=true
		refresh(0))

func _layout() -> void:
	var dimensions:=get_viewport().get_visible_rect().size
	worlds.position=Vector2(maxf(338,(dimensions.x-worlds.size.x)*.5),20)
	badges.position=worlds.position+Vector2(0,50);menu_button.position=Vector2(dimensions.x-68,22);law_popup.position=badges.position+Vector2(0,36)
	saved_label.position=Vector2(dimensions.x-264,100)
	bag_shade.position=Vector2(24,dimensions.y-58);tools_shade.position=Vector2(dimensions.x-292,dimensions.y-58)
	record.position=Vector2(24,118);destination_panel.position=Vector2(dimensions.x-304,170)
	subtitle_panel.position=Vector2((dimensions.x-720)*.5,dimensions.y-158)
	footer.position=Vector2((dimensions.x-footer.size.x)*.5,dimensions.y-116)
	entry_hint.position=Vector2((dimensions.x-entry_hint.size.x)*.5,dimensions.y-120)

func safe_rect() -> Rect2:
	var dimensions:=get_viewport().get_visible_rect().size
	var left:=398.0 if is_instance_valid(record) and record.visible else 35.0
	var right:=dimensions.x-35
	if is_instance_valid(room.mission_guide):
		var occupied:Rect2=room.mission_guide.occupied_rect()
		if occupied.has_area():
			if occupied.get_center().x>dimensions.x*.5:right=minf(right,occupied.position.x-18)
			else:left=maxf(left,occupied.end.x+18)
	var bottom:=dimensions.y-(174.0 if room.story_time>0 else 132.0 if message_time>0 else 78.0)
	return Rect2(Vector2(left,122),Vector2(maxf(300,right-left),maxf(260,bottom-122)))

func blocks_map(at:Vector2) -> bool:
	if menu.visible or layer_selector.get_popup().visible:return true
	if is_instance_valid(push_picker) and push_picker.blocks_map(at):return true
	if is_instance_valid(room.mission_guide) and room.mission_guide.blocks_map(at):return true
	for control in [worlds,badges,menu_button,record,bag,tools]:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(at):return true
	return false

func toggle_details() -> void:
	record_pinned=not record_pinned;record.visible=record_pinned
	room.view.frame_to_ui=true

func toggle_record() -> void:
	if record.visible and not record_pinned:
		record_pinned=true;room.show_hint();return
	record.visible=not record.visible;record_pinned=record.visible
	if record.visible:room.show_hint()
	room.view.frame_to_ui=true

func set_hint(text:String) -> void:
	record.show();record_pinned=true;hint.text="线索 %d / 3\n%s"%[room.hint_level,text];room.view.frame_to_ui=true

func toggle_menu() -> void:
	if menu.visible:menu.close()
	else:menu.open(menu_button)

func _menu_action(action:String) -> void:
	match action:
		"view":room.view.return_to_actor()
		"hub":room.hub_requested.emit()
		"reset":room.restore_checkpoint()
		"restart":room.restart()
		"hint":record_pinned=true;room.show_hint()
		"demo":room.get_parent().start_paper_demo()
		"title":room.get_parent().request_title_return()
		"mute":audio.toggle_mute()
		"fullscreen":DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		"quit":room.get_parent().quit_game()

func message(text:String) -> void:
	if text.is_empty():return
	if room.story_time>0:
		deferred_notice={"text":text,"goal":room.state.objective()};return
	if text==last_message and (message_time>0 or clock-last_message_at<3.5):return
	last_message=text;last_message_at=clock;status.text=text
	if text.contains("已切到") and text.ends_with("世界。"):law_time=3;return
	message_time=clampf(1+text.length()*.1,3.2,7.0)

func notify_saved() -> void:saved_time=1.4

func communicate(speaker:String,text:String,duration:=6.0) -> void:
	subtitle_name.text="衍月 · 现场记录" if speaker=="yanyue" else "特斯拉 · 观测通讯"
	subtitle_pages=Instruments.caption_pages(text,620,19);subtitle_started=clock
	subtitle_display_pages.clear()
	for page in subtitle_pages:subtitle_display_pages.append(Instruments.caption_display(page,620,19))
	subtitle_duration=maxf(duration,subtitle_pages.size()*2.4)
	subtitle_body.text=subtitle_display_pages[0] if not subtitle_display_pages.is_empty() else ""
	portrait.texture=load("res://assets/dialogue_chibi_v37/"+speaker+".png")

func show_destinations(index:int) -> void:
	destination_panel.hide();push_picker.open(index)

func station_name(station:String) -> String:
	return {"hatch":"落料板","start":"起始止挡","catch":"接物踏板","junction":"导轨连接段","cage":"封存架","sluice":"水闸踏板","guide":"上浮导向井","lift":"运纸吊台","dock":"上层中转台","bridge":"跨渠桥后","anchor":"山纹锚座","cage_turn":"封存架转角","guide_turn":"导轨分岔","sluice_turn":"水闸转角","guide_bend":"导向井转角","lift_turn":"吊台转角","anchor_turn":"锚座转角"}.get(station,station)

func refresh(delta:float) -> void:
	if room.presentation_mode:delta/=maxf(Engine.time_scale,.01)
	if room.story_time<=0 and not deferred_notice.is_empty():
		var notice:=deferred_notice;deferred_notice={}
		if notice.goal==room.state.objective():message(notice.text)
	clock+=delta;message_time=maxf(0,message_time-delta);saved_time=maxf(0,saved_time-delta);law_time=maxf(0,law_time-delta)
	var s=room.state;var world:int=s.worlds[room.view_layer]
	if world!=last_world or last_layer!=room.view_layer:law_time=3;last_world=world;last_layer=room.view_layer
	objective_feedback.observe();record_task.text=s.objective()
	var clip_name:String={"":"未固定","catch":"接物台","bridge":"木桥"}.get(s.clip_target,"未固定")
	for i in range(2):
		var w:Dictionary=s.weights[i];var moving:String=" · 运送" if w.mode!="rest" else " · 上浮" if w.elevation>.05 else ""
		bag_buttons[i].text=("山" if i==0 else "水")+"·"+("上层" if w.layer==0 else "下层")
		bag_buttons[i].tooltip_text=("山纹镇纸" if i==0 else "水纹镇纸")+" · "+station_name(w.station)+moving+"；点击定位"
	bag_buttons[2].text="夹·"+(clip_name if s.clip_owned else "未取得")+" ↶"
	bag_buttons[2].disabled=not s.clip_owned;bag_buttons[2].tooltip_text="留影夹一次只能固定一处。切换世界后保留姿态；取回后恢复原规则。\n点击召回；人物站在木桥上时保留支撑。"
	inventory.text="山纹镇纸：%s\n水纹镇纸：%s\n留影夹：%s\n人物在%s · 正在观察%s"%["上层" if s.weights[0].layer==0 else "下层","上层" if s.weights[1].layer==0 else "下层",clip_name if s.clip_owned else "未取得","上层" if room.player_layer==0 else "下层","上层" if room.view_layer==0 else "下层"]
	inventory.text="山·%s / %s\n水·%s / %s\n夹·%s\n人物在%s · 观察%s\n检修撑·%s　落料板·%s\n吊台·%s　木桥·%s"%["上层" if s.weights[0].layer==0 else "下层",station_name(s.weights[0].station),"上层" if s.weights[1].layer==0 else "下层",station_name(s.weights[1].station),clip_name if s.clip_owned else "未取得","上层" if room.player_layer==0 else "下层","上层" if room.view_layer==0 else "下层","已解除" if s.support_released else "支撑中","已打开" if s.hatch_broken else "完整","上层" if s.lift_height>room.State.HEIGHT-.1 else "运送中" if s.lift_height>.1 else "下层","固定" if s.clip_target=="bridge" else "显现" if s.bridge_solid() else "隐藏"]
	layer_selector.text=("上层·晒纸院" if room.view_layer==0 else "下层·水碓坊")+" ▾"
	law.text="上层%s / 下层%s　人物在%s · 操作%s"%[["A冰晶","B重力","C倒悬","D显影"][s.worlds[0]],["A冰晶","B重力","C倒悬","D显影"][s.worlds[1]],"上层" if room.player_layer==0 else "下层","上层" if room.view_layer==0 else "下层"]
	law_detail.text=["冰晶：镇纸可沿导轨运送。","重力：镇纸向下重压，可驱动踏板与水轮。","倒悬：未固定的镇纸向上浮起。","显影：旧廊、木桥与旧物显现。"][world]+"\n人物在"+("上层" if room.player_layer==0 else "下层")+" · 操作"+("上层" if room.view_layer==0 else "下层")
	law_popup.visible=law_hovered and not menu.visible and room.story_time<=0
	law_popup.modulate.a=1.0 if law_hovered else clampf(law_time/.4,0,1)
	for i in range(4):
		var locked:bool=s.upper_anchored if room.view_layer==0 else s.lower_anchored
		if styled_world!=world:
			for state_name in ["normal","disabled"]:rule_buttons[i].add_theme_stylebox_override(state_name,Instruments.state_style(true) if world==i else StyleBoxEmpty.new())
			rule_buttons[i].add_theme_color_override("font_disabled_color",TEXT if world==i else Color("8d9a90"))
		rule_buttons[i].disabled=locked or room.world_cooldown>0 or s.has_sliding_weight() or world==i
		rule_buttons[i].tooltip_text="镇纸滑行中，停稳后可切换" if s.has_sliding_weight() else ("本层锚点已固定" if locked else ("当前世界" if world==i else "切换到%s"%s.WORLD_NAMES[i]))
	styled_world=world
	footer.visible=message_time>0 and room.story_time<=0 and not menu.visible
	subtitle_panel.visible=room.story_time>0 and not menu.visible
	if not subtitle_pages.is_empty():
		var page_index:=mini(subtitle_pages.size()-1,int((clock-subtitle_started)/maxf(2.0,subtitle_duration/subtitle_pages.size())))
		var display:=subtitle_display_pages[page_index]
		if subtitle_body.text!=display:subtitle_body.text=display
	saved_label.text="✓ 观测已保存" if saved_time>0 and not menu.visible else ""
	entry_hint.obscured=menu.visible or room.story_time>0 or message_time>0 or room.arrival_busy()
	if not entry_hint.obscured and not entry_hint.offered:entry_hint.offer()
	if entry_hint.obscured:entry_hint.hide()
	elif entry_hint.offered and not entry_hint.dismissed:entry_hint.show()
	if room.player.walking:entry_hint.dismiss()
	if last_checkpoint!=s.checkpoint:
		last_checkpoint=s.checkpoint;hint.text="需要时再展开线索。"
	_update_object()

func _update_object() -> void:
	object_panel.hide()
	if menu.visible or record.visible or push_picker.visible or room.story_time>0 or room.arrival_busy():return
	var pointer:=get_viewport().get_mouse_position()
	if blocks_map(pointer):return
	var index:=-1;var closest:=2.1
	for i in range(2):
		var w:Dictionary=room.state.weights[i]
		if w.layer!=room.view_layer:continue
		var d:float=room.player_plan().distance_to(w.pos) if room.player_layer==w.layer else INF
		if d<closest:closest=d;index=i
	var hovered:String=room.hit_target(pointer)
	if hovered in ["w0","w1"]:index=int(hovered.trim_prefix("w"))
	if index<0:return
	var w:Dictionary=room.state.weights[index];var world:int=room.state.worlds[w.layer]
	object_label.text=("山纹镇纸" if index==0 else "水纹镇纸")+"\n"+("正在运送" if w.mode!="rest" else ["右键 / E · 选择方向","重压 · 当前不可推动","倒悬 · 向上浮起","显影 · 观察旧物"][world])
	var h:float=room.state.weight_height(index)-(room.State.HEIGHT if w.layer==0 else 0.0)+.5
	var target:Vector2=room.view.screen(w.pos,w.layer,h);var at:=target+Vector2(42,-35)
	var actor:Vector2=room.view.screen(room.player_plan(),room.player_layer,1.0)
	if Rect2(at,object_panel.size).has_point(actor):at=target+Vector2(-262,-35)
	var dimensions:=get_viewport().get_visible_rect().size
	at.x=clampf(at.x,24,dimensions.x-244);at.y=clampf(at.y,130,dimensions.y-230)
	object_panel.position=at;object_panel.show()

func _input(event:InputEvent) -> void:
	if menu.visible:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			if push_picker.visible or room.pending.has("direction"):room.cancel_push_command()
			elif destination_panel.visible:destination_panel.hide()
			elif record.visible:record.hide();record_pinned=false
			else:toggle_menu()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT] and not room.player.controls_locked:entry_hint.dismiss()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] and not blocks_map(event.position) and not room.player.controls_locked:entry_hint.dismiss()
