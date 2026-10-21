extends CanvasLayer
signal world_requested(index: int)
signal reset_requested
signal hint_requested
signal hub_requested
signal view_reset_requested
var view_angle_label: Label
var worlds: Array[Button] = []
var task_tracker: Control
var law_label: Label
var object_label: Label
var message_label: Label
var world_heading: Label
var muted := false
var font := SystemFont.new()
var skill_panel: Panel
var menu_buttons: Array[Button] = []
var arrival_title: Control
var cooldown_bar: ColorRect
var cooldown_fill: ColorRect
var skill_status: Label
var current_world_label: Label
var current_world := 0
var completion_label: Label

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei","Arial"])
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var menu := panel(root,Vector2(22,20),Vector2(184,194))
	var menu_titles := ["复位视角", "返回机构", "重置    R", "提示    H"]
	for i in range(4):
		menu_buttons.append(button(menu,menu_titles[i],Vector2(10,10+i*39),Vector2(164,33)))
	menu_buttons[0].pressed.connect(func():view_reset_requested.emit())
	menu_buttons[1].pressed.connect(func():hub_requested.emit())
	menu_buttons[2].pressed.connect(func():reset_requested.emit())
	menu_buttons[3].pressed.connect(func():hint_requested.emit())
	view_angle_label=label(menu,"视角 +0°",Vector2(10,167),12,Color("89908b"))
	view_angle_label.size.x=164
	view_angle_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	skill_panel = panel(root,Vector2(22,226),Vector2(184,140))
	label(skill_panel,"世界折叠",Vector2(12,9),16,Color("3c596b"))
	current_world_label=label(skill_panel,"",Vector2(12,34),11,Color("7a847e"))
	skill_status=label(skill_panel,"就绪",Vector2(113,13),11,Color("4d827e"))
	for i in range(3):
		var index := i
		var item = preload("res://scripts/world_skill_button.gd").new()
		item.world = i
		item.position = Vector2(10+i*56,55)
		item.size = Vector2(52,57)
		skill_panel.add_child(item)
		item.pressed.connect(func(): world_requested.emit(index))
		worlds.append(item)
	cooldown_bar = ColorRect.new()
	cooldown_bar.position=Vector2(12,123)
	cooldown_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cooldown_bar.color=Color("e4ddce")
	cooldown_bar.size=Vector2(160,4)
	skill_panel.add_child(cooldown_bar)
	cooldown_fill=ColorRect.new()
	cooldown_fill.color=Color("8faeab")
	cooldown_fill.size=Vector2(160,4)
	cooldown_fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cooldown_bar.add_child(cooldown_fill)
	arrival_title = preload("res://scripts/map_arrival_title.gd").new()
	root.add_child(arrival_title)
	task_tracker=preload("res://scripts/task_tracker.gd").new()
	root.add_child(task_tracker)
	var rules := panel(root,Vector2(1015,20),Vector2(243,190))
	world_heading = label(rules,"",Vector2(14,12),17,Color("4d6978"))
	law_label = label(rules,"",Vector2(14,44),15,Color("63757d"))
	law_label.size = Vector2(215,70)
	law_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	object_label = label(rules,"",Vector2(14,119),14,Color("8a7153"))
	label(rules,"磁力靴：衍月保持贴地行走",Vector2(14,170),11,Color("90928d"))
	var footer := panel(root,Vector2(22,711),Vector2(1236,76))
	label(footer,"WASD / 左键移动   ·   右键镇纸 / E 推动   ·   1 / 2 / 3 切换世界   ·   左 Alt + 左键拖动视角",Vector2(17,10),16,Color("354d5d"))
	message_label = label(footer,"",Vector2(17,40),15,Color("728086"))
	message_label.size = Vector2(1200,28)
	completion_label=label(root,"世界关系已稳定",Vector2(420,112),27,Color("508c78"))
	completion_label.size=Vector2(440,45)
	completion_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	completion_label.add_theme_font_override("font",preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf"))
	completion_label.add_theme_color_override("font_outline_color",Color("fcfaf3"))
	completion_label.add_theme_constant_override("outline_size",5)
	completion_label.hide()

func panel(parent: Node, at: Vector2, size: Vector2) -> Panel:
	var result := Panel.new()
	result.position = at
	result.size = size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("panel",style(Color(0.99,0.98,0.95,0.97),Color("cdbf9e")))
	parent.add_child(result)
	return result

func style(fill: Color, edge: Color, width: int=1) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = edge
	result.set_border_width_all(width)
	result.set_corner_radius_all(9)
	result.shadow_color = Color(0.15,0.15,0.2,0.08)
	result.shadow_size = 3
	return result

func label(parent: Node, text: String, at: Vector2, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.position = at
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font",font)
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color)
	parent.add_child(result)
	return result

func button(parent: Node, text: String, at: Vector2, size: Vector2) -> Button:
	var result := Button.new()
	result.text = text
	result.position = at
	result.size = size
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_override("font",font)
	result.add_theme_font_size_override("font_size",14)
	result.add_theme_color_override("font_color",Color("425869"))
	result.add_theme_color_override("font_disabled_color",Color("7b7872"))
	result.add_theme_stylebox_override("normal",style(Color("f2eee5"),Color("cec2aa")))
	result.add_theme_stylebox_override("hover",style(Color("e2ebe9"),Color("78959e")))
	result.add_theme_stylebox_override("pressed",style(Color("d5e2e4"),Color("597d8a"),2))
	result.add_theme_stylebox_override("disabled",style(Color("eee9de"),Color("d6cebb")))
	parent.add_child(result)
	return result

func refresh(state: RefCounted) -> void:
	current_world=state.world
	task_tracker.refresh(state)
	world_heading.text = ["冰晶 · 惯性滑行","重力 · 向下受力","倒悬 · 向上受力"][state.world]
	law_label.text = ["低摩擦：推动后持续滑行，碰到挡块才停。", "重量增至 4 倍：可以压板，但人物推不动。", "未固定物体向上浮起，可触碰高处装置。"][state.world]
	object_label.text = "镇纸：%s\n%s"%["悬空 %.0f"%state.elevation if state.elevation>0.3 else "位于导轨上",["可推动 · 重量 ×1","不可推动 · 重量 ×4","向上重力 · 自动上浮"][state.world]]

func message(text: String) -> void:
	message_label.text = text

func update_completion(active: bool,complete: bool,age: float) -> void:
	if active:
		task_tracker.current_heading.text="机关已激活 · 稳定中"
		task_tracker.current_label.text="界缝正在合拢…"
		task_tracker.current_label.add_theme_color_override("font_color",task_tracker.CURRENT_COLOR)
	elif task_tracker.current_step==3:
		task_tracker.current_heading.text="阶段目标已完成"
		task_tracker.current_label.text="返回机构"
		task_tracker.current_label.add_theme_color_override("font_color",task_tracker.DONE_COLOR.lightened(0.45))
	completion_label.visible=complete and age<2.4
	completion_label.modulate.a=smoothstep(1.0,1.12,age)*(1.0-smoothstep(1.6,2.4,age))

func update_skill(remaining: float,casting: bool,pending: int=-1) -> void:
	var names: Array[String]=["冰晶","重力","倒悬"]
	skill_status.text="折叠中…" if casting else ("冷却 %.1fs"%maxf(0.1,remaining) if remaining>0.001 else "就绪")
	skill_status.add_theme_color_override("font_color",Color("8b8296") if remaining>0.001 else Color("4d827e"))
	current_world_label.text="正在前往：%s"%names[pending] if pending>=0 else "当前：%s   ·   共享冷却 1.5s"%names[current_world]
	cooldown_fill.size=Vector2(160*(1.0-clampf(remaining/1.5,0.0,1.0)),4)
	for i in range(3):
		worlds[i].set("selected",i==current_world)
		worlds[i].set("cooldown_remaining",remaining)
		worlds[i].disabled=remaining>0.001 or casting or i==current_world
		worlds[i].tooltip_text="当前世界" if i==current_world else ("世界折叠冷却中" if remaining>0.001 else "切换到%s世界"%names[i])
