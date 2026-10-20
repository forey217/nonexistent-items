extends CanvasLayer
signal world_requested(index: int)
signal reset_requested
signal hint_requested
signal hub_requested
signal view_reset_requested
var view_angle_label: Label
var worlds: Array[Button] = []
var objective_label: Label
var progress_label: Label
var law_label: Label
var object_label: Label
var message_label: Label
var world_heading: Label
var muted := false
var font := SystemFont.new()
var _last_world := -1
var skill_button
var skill_status: Label
var current_world_label: Label
var next_world_label: Label
var current_world := 0

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei","Arial"])
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var header := panel(root,Vector2(22,12),Vector2(1236,65))
	label(header,"不存在的物品",Vector2(18,8),24,Color("304555"))
	label(header,"观察局 · 新手校准室",Vector2(225,16),16,Color("687982"))
	view_angle_label=label(header,"视角 +0°",Vector2(620,18),14,Color("687982"))
	button(header,"复位视角",Vector2(765,8),Vector2(100,33)).pressed.connect(func():view_reset_requested.emit())
	button(header,"返回机构",Vector2(880,8),Vector2(108,33)).pressed.connect(func(): hub_requested.emit())
	button(header,"重置 R",Vector2(998,8),Vector2(100,33)).pressed.connect(func(): reset_requested.emit())
	button(header,"提示 H",Vector2(1108,8),Vector2(108,33)).pressed.connect(func(): hint_requested.emit())
	var skill := panel(root,Vector2(22,94),Vector2(247,180))
	label(skill,"世界折叠",Vector2(15,10),19,Color("3c596b"))
	label(skill,"共享冷却 3秒",Vector2(135,15),12,Color("8c816d"))
	skill_button=preload("res://scripts/world_skill_button.gd").new()
	skill_button.position=Vector2(13,43)
	skill_button.size=Vector2(70,70)
	skill.add_child(skill_button)
	skill_button.pressed.connect(func(): world_requested.emit((current_world+1)%3))
	skill_status=label(skill,"就绪",Vector2(96,44),18,Color("4d827e"))
	current_world_label=label(skill,"",Vector2(96,74),14,Color("6b7d84"))
	next_world_label=label(skill,"",Vector2(96,97),13,Color("8b7a64"))
	var titles := ["1 冰晶","2 重力","3 倒悬"]
	for i in range(3):
		var index := i
		var item := button(skill,titles[i],Vector2(12+i*77,132),Vector2(71,33))
		item.pressed.connect(func(): world_requested.emit(index))
		worlds.append(item)
	var goal := panel(root,Vector2(22,526),Vector2(247,174))
	label(goal,"本次目标",Vector2(15,12),16,Color("947c50"))
	objective_label = label(goal,"",Vector2(15,44),18,Color("344957"))
	objective_label.size = Vector2(217,55)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label = label(goal,"",Vector2(15,109),14,Color("6b7f7d"))
	var rules := panel(root,Vector2(1015,94),Vector2(243,190))
	world_heading = label(rules,"",Vector2(14,12),17,Color("4d6978"))
	law_label = label(rules,"",Vector2(14,44),15,Color("63757d"))
	law_label.size = Vector2(215,70)
	law_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	object_label = label(rules,"",Vector2(14,119),14,Color("8a7153"))
	label(rules,"磁力靴：衍月保持贴地行走",Vector2(14,170),11,Color("90928d"))
	var footer := panel(root,Vector2(22,711),Vector2(1236,76))
	label(footer,"WASD / 左键移动   ·   右键镇纸 / E 推动   ·   Q 或 1 / 2 / 3 切世界   ·   左 Alt + 左键拖动视角",Vector2(17,10),16,Color("354d5d"))
	message_label = label(footer,"",Vector2(17,40),15,Color("728086"))
	message_label.size = Vector2(1200,28)

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
	objective_label.text = ["把镇纸送到\n第一块压板","压力不足\n想办法让镇纸变重","挡块已释放\n把镇纸运到末端","点亮镇纸上方的\n接收器","让镇纸落回末端\n并压住压板","归位门已开启\n走入门内返回机构"][state.stage()]
	progress_label.text = "%s 挡块释放    %s 上部校准\n%s 末端压力"%["●" if state.first_latched else "○","●" if state.receiver_latched else "○","●" if state.final_pressed else "○"]
	world_heading.text = ["冰晶 · 惯性滑行","重力 · 向下受力","倒悬 · 向上受力"][state.world]
	law_label.text = ["低摩擦：推动后持续滑行，碰到挡块才停。", "重量增至 4 倍：可以压板，但人物推不动。", "未固定物体向上浮起，可触碰高处装置。"][state.world]
	object_label.text = "镇纸：%s\n%s"%["悬空 %.0f"%state.elevation if state.elevation>0.3 else "位于导轨上",["可推动 · 重量 ×1","不可推动 · 重量 ×4","向上重力 · 自动上浮"][state.world]]
	if _last_world!=state.world:
		_last_world=state.world
		var colors := [Color("78adbf"),Color("b87556"),Color("9c8dbc")]
		for i in range(3):
			worlds[i].add_theme_stylebox_override("normal",style(colors[i].lightened(0.70) if i==state.world else Color("f2eee5"),colors[i] if i==state.world else Color("cec2aa"),2 if i==state.world else 1))
			worlds[i].add_theme_stylebox_override("disabled",style(colors[i].lightened(0.83) if i==state.world else Color("eee9de"),colors[i].lightened(0.5) if i==state.world else Color("d6cebb")))

func message(text: String) -> void:
	message_label.text = text

func update_skill(remaining: float,casting: bool,pending: int=-1) -> void:
	var names: Array[String]=["冰晶","重力","倒悬"]
	skill_button.cooldown_remaining=remaining
	skill_button.world=current_world
	skill_button.disabled=remaining>0.001 or casting
	skill_button.tooltip_text="世界折叠：切换到%s世界，施放后共享冷却3秒。"%names[(current_world+1)%3]
	skill_status.text="折叠中…" if casting else ("冷却 %.1f秒"%maxf(0.1,remaining) if remaining>0.001 else "就绪 · Q")
	skill_status.add_theme_color_override("font_color",Color("8b8296") if remaining>0.001 else Color("4d827e"))
	current_world_label.text="当前：%s世界"%names[current_world]
	next_world_label.text="正在前往：%s"%names[pending] if pending>=0 else "下一个：%s"%names[(current_world+1)%3]
	for i in range(3):
		worlds[i].disabled=remaining>0.001 or casting or i==current_world
		worlds[i].tooltip_text="当前世界" if i==current_world else ("世界折叠冷却中" if remaining>0.001 else "切换到%s世界"%names[i])
