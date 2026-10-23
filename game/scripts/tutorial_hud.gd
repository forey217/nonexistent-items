extends CanvasLayer
signal world_requested(index:int)
signal reset_requested
signal hint_requested
signal hub_requested
signal view_reset_requested
const Instruments=preload("res://scripts/instrument_theme.gd")
var root:Control
var font:=Instruments.body()
var room:Node
var audio:Node
var view_angle_label:Label
var worlds:Array[Button]=[]
var task_tracker:Control
var law_label:Label
var object_label:Label
var message_label:Label
var world_heading:Label
var skill_panel:Panel
var menu_buttons:Array[Button]=[]
var arrival_title:Control
var current_world:=0
var completion_label:Label
var footer:Panel
var law_badge:Button
var law_popup:Panel
var object_panel:Panel
var menu_button:Button
var menu:Control
var entry_hint:Control
var law_time:=3.0
var law_hovered:=false
var message_time:=0.0
var dialogue_occupied:=false
var dialogue_modal:=false
var clock:=0.0
var rule_fade:=0.0
var last_message:=""
var last_message_at:=-10.0

func _ready() -> void:
	layer=5;room=get_parent()
	root=Control.new()
	if room.get_parent().get("ambience")!=null:audio=room.get_parent().ambience
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	task_tracker=preload("res://scripts/task_tracker.gd").new();root.add_child(task_tracker)
	skill_panel=panel(root,Vector2.ZERO,Vector2(300,64));skill_panel.mouse_filter=Control.MOUSE_FILTER_STOP
	for i in range(3):
		var index:=i
		var item=preload("res://scripts/world_skill_button.gd").new();item.world=i
		item.position=Vector2(i*102,0);item.size=Vector2(96,64);skill_panel.add_child(item)
		item.pressed.connect(func():world_requested.emit(index));worlds.append(item)
	law_badge=button(root,"",Vector2.ZERO,Vector2(234,44))
	law_badge.add_theme_font_size_override("font_size",20)
	law_badge.mouse_entered.connect(func():law_hovered=true)
	law_badge.mouse_exited.connect(func():law_hovered=false)
	law_badge.pressed.connect(func():law_time=3)
	world_heading=label(law_badge,"",Vector2(12,8),20,Instruments.TEXT)
	law_popup=panel(root,Vector2.ZERO,Vector2(282,92));law_popup.mouse_filter=Control.MOUSE_FILTER_IGNORE
	law_label=label(law_popup,"",Vector2(14,10),18,Instruments.TEXT);law_label.size=Vector2(254,74);law_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	object_panel=panel(root,Vector2.ZERO,Vector2(210,63));object_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;object_panel.hide()
	object_label=label(object_panel,"",Vector2(12,7),17,Instruments.TEXT);object_label.size=Vector2(188,52);object_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	menu_button=button(root,"≡",Vector2.ZERO,Vector2(44,44));menu_button.tooltip_text="观测菜单 · Esc"
	menu_button.pressed.connect(toggle_menu)
	arrival_title=preload("res://scripts/map_arrival_title.gd").new();root.add_child(arrival_title)
	footer=panel(root,Vector2.ZERO,Vector2(520,46));footer.mouse_filter=Control.MOUSE_FILTER_IGNORE;footer.hide()
	message_label=label(footer,"",Vector2(12,5),18,Instruments.TEXT);message_label.size=Vector2(496,38);message_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	entry_hint=preload("res://scripts/level_entry_hint.gd").new();root.add_child(entry_hint)
	completion_label=label(root,"◇ 世界关系已稳定",Vector2.ZERO,25,Instruments.TEXT)
	completion_label.size=Vector2(440,44);completion_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	completion_label.add_theme_font_override("font",Instruments.TITLE)
	completion_label.add_theme_color_override("font_outline_color",Instruments.DEEP);completion_label.add_theme_constant_override("outline_size",3);completion_label.hide()
	menu=preload("res://scripts/level_hud_menu.gd").new();menu.audio=audio;root.add_child(menu)
	menu.action_requested.connect(_menu_action);menu.opened_changed.connect(_menu_changed)
	for key in ["view","hub","reset","hint"]:menu_buttons.append(menu.buttons[key])
	view_angle_label=label(menu.panel,"视角 +0°",Vector2(167,20),14,Instruments.MUTED)
	get_viewport().size_changed.connect(_layout);_layout()
	root.modulate.a=0
	create_tween().tween_property(root,"modulate:a",1.0,.25)

func panel(parent:Node,at:Vector2,dimensions:Vector2) -> Panel:
	var p:=Panel.new();p.position=at;p.size=dimensions;p.mouse_filter=Control.MOUSE_FILTER_IGNORE;p.mouse_force_pass_scroll_events=false
	p.add_theme_stylebox_override("panel",Instruments.style());parent.add_child(p);return p

func label(parent:Node,text:String,at:Vector2,points:int,color:Color) -> Label:
	return Instruments.label(parent,text,at,Vector2.ZERO,points,color)

func button(parent:Node,text:String,at:Vector2,dimensions:Vector2) -> Button:
	var b:=Button.new();b.text=text;b.position=at;b.size=dimensions;Instruments.apply_button(b,20);parent.add_child(b);return b

func _layout() -> void:
	var dimensions:=get_viewport().get_visible_rect().size
	skill_panel.position=Vector2((dimensions.x-300)*.5,dimensions.y-88)
	law_badge.position=Vector2(dimensions.x-318,24);menu_button.position=Vector2(dimensions.x-68,24)
	law_popup.position=Vector2(dimensions.x-318,78)
	footer.position=Vector2((dimensions.x-footer.size.x)*.5,dimensions.y-158)
	entry_hint.position=Vector2((dimensions.x-entry_hint.size.x)*.5,dimensions.y-136)
	completion_label.position=Vector2((dimensions.x-440)*.5,126)

func refresh(state:RefCounted) -> void:
	if current_world!=state.world:law_time=3
	current_world=state.world;task_tracker.refresh(state)
	world_heading.text=["冰晶 · 低摩擦","重力 · 四倍重量","倒悬 · 向上受力"][state.world]
	law_label.text=["推动后持续滑行，碰到挡块才停。","重量增至四倍，可以压板，人物无法推动。","未固定物体向上浮起，可触碰高处装置。"][state.world]
	object_label.text=["镇纸 · 可推动\n重量 ×1","镇纸 · 当前无法推动\n重量 ×4，适合重压","镇纸 · 向上浮起\n磁力靴保持人物贴地"][state.world]

func message(text:String) -> void:
	if text.begins_with("冰晶：") or text.begins_with("重力：") or text.begins_with("倒悬：") or text in ["施放世界折叠…","观察机关的变化，尝试不同世界。需要帮助时按 H，提示会逐级展开。"]:return
	if text.is_empty() or (text==last_message and (message_time>0 or clock-last_message_at<3.5)):return
	last_message=text;last_message_at=clock;message_label.text=text
	# Keep two readable lines for unusually long non-dialogue feedback.
	footer.size.y=maxf(46,ceilf(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x/496)*26+12)
	message_label.size.y=footer.size.y-10
	message_time=clampf(1+text.length()*.1,3.2,8.0)

func update_completion(active:bool,complete:bool,age:float) -> void:
	if active:task_tracker.current_label.text="界缝正在合拢…"
	completion_label.visible=complete and age<2.4
	completion_label.modulate.a=smoothstep(1.0,1.12,age)*(1-smoothstep(1.6,2.4,age))

func update_skill(remaining:float,casting:bool,_pending:int=-1) -> void:
	for i in range(3):
		worlds[i].set("selected",i==current_world);worlds[i].set("cooldown_remaining",remaining)
		worlds[i].disabled=remaining>.001 or casting or i==current_world
		worlds[i].tooltip_text="当前世界" if i==current_world else ("世界折叠冷却中" if remaining>.001 else "切换到%s世界"%["冰晶","重力","倒悬"][i])

func set_dialogue_occupied(occupied:bool,modal:=false) -> void:
	dialogue_occupied=occupied;dialogue_modal=modal
	footer.visible=not occupied and message_time>0 and not menu.visible
	skill_panel.visible=not modal
	entry_hint.obscured=occupied or menu.visible
	if occupied:entry_hint.hide();object_panel.hide();law_popup.hide();task_tracker.collapse()

func _process(delta:float) -> void:
	clock+=delta
	var blocked:bool=menu.visible or dialogue_modal or room.arrival_busy()
	if not blocked:law_time=maxf(0,law_time-delta);message_time=maxf(0,message_time-delta)
	rule_fade=move_toward(rule_fade,1.0 if (law_hovered or law_time>0) and not blocked and not dialogue_occupied else 0.0,delta*5)
	law_popup.modulate.a=rule_fade;law_popup.visible=rule_fade>.001
	footer.visible=message_time>0 and not blocked and not dialogue_occupied
	entry_hint.obscured=blocked or dialogue_occupied or message_time>0
	if not entry_hint.obscured and not entry_hint.offered:entry_hint.offer()
	if entry_hint.obscured:entry_hint.hide()
	elif entry_hint.offered and not entry_hint.dismissed:entry_hint.show()
	if room.player.walking and not blocked:entry_hint.dismiss()
	_update_object(blocked or dialogue_occupied or task_tracker.popup.visible)

func _update_object(blocked:bool) -> void:
	if room.get("orbit_view")==null:return
	var view=room.orbit_view
	var near:bool=room.player.position.distance_to(room.block_ground_position())<room.INTERACT_RADIUS
	object_panel.visible=not blocked and not view.dragging and (view.weight_hovered or near or room.interacting)
	if not object_panel.visible:return
	var target:Vector2=view.logic_to_screen(room.block_ground_position(),.5+room.state.elevation/view.HEIGHT_PIXELS)
	var at:=target+Vector2(46,-42)
	var actor:Vector2=view.logic_to_screen(room.player.position)
	if Rect2(at,object_panel.size).intersects(Rect2(actor+Vector2(-26,-125),Vector2(52,135))):at=target+Vector2(-256,-42)
	var dimensions:=get_viewport().get_visible_rect().size
	at.x=clampf(at.x,24,dimensions.x-object_panel.size.x-24);at.y=clampf(at.y,125,dimensions.y-225)
	object_panel.position=at

func toggle_menu() -> void:
	if dialogue_modal or room.arrival_busy():return
	if menu.visible:menu.close()
	else:menu.open(menu_button)

func request_reset() -> void:
	if room.arrival_busy() or dialogue_modal:return
	menu.request_action("reset")

func _menu_changed(opened:bool) -> void:
	room.player.cancel_navigation();room._pending_click=false;room._pending_push=false;room.orbit_view.cancel_drag();task_tracker.collapse()
	room.player.controls_locked=opened or room.casting or room.seal_active or room.interacting or room.arrival_busy()
	var d=room.get_parent().get("dialogue")
	if is_instance_valid(d):
		d.voice.player.stream_paused=opened
		if opened:d.view.root.hide()
		elif not d.active.is_empty():d.view.root.show()
	if opened:entry_hint.hide();object_panel.hide();law_popup.hide();footer.hide()

func _menu_action(action:String) -> void:
	match action:
		"view":view_reset_requested.emit()
		"hub":hub_requested.emit()
		"reset":reset_requested.emit()
		"hint":hint_requested.emit()
		"title":room.get_parent().request_title_return()

func blocks_map(at:Vector2) -> bool:
	if menu.visible:return true
	for control in [task_tracker,task_tracker.popup,task_tracker.hover_bridge,skill_panel,law_badge,menu_button]:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(at):return true
	return false

func _input(event:InputEvent) -> void:
	if dialogue_modal:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE and not menu.visible:
			if task_tracker.popup.visible:task_tracker.collapse()
			else:toggle_menu()
			get_viewport().set_input_as_handled()
		if event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT] and not room.player.controls_locked:entry_hint.dismiss()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] and not blocks_map(event.position) and not room.player.controls_locked:entry_hint.dismiss()
