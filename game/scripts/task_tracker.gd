extends Control
signal anchor_hovered(index: int)
## Display outcomes only. Detailed solving actions belong in opt-in hints.
const MAIN_COLOR := Color("202526")
const CURRENT_COLOR := Color("f4df9d")
const DONE_COLOR := Color("4b8b69")
const FUTURE_COLOR := Color("8d9692")
const STEPS: Array[String] = [
	"激活星位踏板，定位星位",
	"激活月痕印座，压稳月痕",
	"激活封界踏板，封闭界缝"
]
var font := SystemFont.new()
var main_area: Control
var main_label: Label
var current_label: Label
var current_heading: Label
var popup: Panel
var hover_bridge: Control
var step_labels: Array[Label] = []
var step_bands: Array[Panel] = []
var hide_timer: Timer
var reveal: Tween
var current_step := -1
var hovered_anchor := -1
var _follow_current := false
var _current_hover := false

func _ready() -> void:
	position=Vector2(22,526)
	size=Vector2(247,174)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	var card := _panel(self,Vector2.ZERO,size,Color("fcfaf3"),Color("cdbf9e"))
	card.mouse_filter=Control.MOUSE_FILTER_STOP
	main_area=Control.new()
	main_area.position=Vector2(12,10)
	main_area.size=Vector2(223,62)
	main_area.mouse_filter=Control.MOUSE_FILTER_STOP
	main_area.mouse_default_cursor_shape=Control.CURSOR_HELP
	card.add_child(main_area)
	_text(main_area,"主任务 · 悬停查看阶段目标",Vector2(3,1),12,Color("8f8268"))
	main_label=_text(main_area,"稳固世界关系，返回机构",Vector2(3,27),17,MAIN_COLOR)
	var current := _panel(card,Vector2(12,84),Vector2(223,74),Color("405760"),Color("405760"))
	current.mouse_filter=Control.MOUSE_FILTER_STOP
	current.mouse_entered.connect(func():
		_current_hover=true
		_focus_current()
	)
	current.mouse_exited.connect(func():
		_current_hover=false
		_set_hovered_anchor(-1)
	)
	current_heading=_text(current,"",Vector2(11,7),11,CURRENT_COLOR.darkened(0.09))
	current_label=_text(current,"",Vector2(11,28),16,CURRENT_COLOR)
	current_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	current_label.size=Vector2(201,43)
	# Only three outcomes; no movement, item, or world-order walkthrough.
	popup=_panel(self,Vector2(259,2),Vector2(326,172),Color("fcfaf3"),Color("cdbf9e"))
	popup.z_index=10
	popup.mouse_filter=Control.MOUSE_FILTER_STOP
	_text(popup,"阶段目标",Vector2(16,12),16,MAIN_COLOR)
	_text(popup,"已完成 / 当前 / 未开始",Vector2(16,37),11,Color("8d8779"))
	for i in range(STEPS.size()):
		var index := i
		var band := _panel(popup,Vector2(10,62+i*32),Vector2(306,29),Color.TRANSPARENT,Color.TRANSPARENT)
		band.mouse_filter=Control.MOUSE_FILTER_STOP
		band.mouse_entered.connect(func():
			hide_timer.stop()
			_follow_current=false
			_set_hovered_anchor(index)
		)
		band.mouse_exited.connect(_schedule_hide)
		var row := _text(band,"",Vector2(9,4),14,FUTURE_COLOR)
		step_bands.append(band)
		step_labels.append(row)
	popup.hide()
	hide_timer=Timer.new()
	hide_timer.one_shot=true
	hide_timer.wait_time=0.20
	add_child(hide_timer)
	hide_timer.timeout.connect(_hide_steps)
	hover_bridge=Control.new()
	hover_bridge.position=Vector2(235,10)
	hover_bridge.size=Vector2(24,62)
	hover_bridge.z_index=10
	hover_bridge.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(hover_bridge)
	hover_bridge.hide()
	hover_bridge.mouse_entered.connect(func():hide_timer.stop())
	hover_bridge.mouse_exited.connect(_schedule_hide)
	main_area.mouse_entered.connect(_show_steps)
	main_area.mouse_exited.connect(_schedule_hide)
	popup.mouse_entered.connect(func():hide_timer.stop())
	popup.mouse_exited.connect(_schedule_hide)
	refresh_step(0)

func refresh(state: RefCounted) -> void:
	refresh_step(state.goal_stage())

func refresh_step(index: int) -> void:
	var next_step := clampi(index,0,STEPS.size())
	if next_step==current_step:return
	current_step=next_step
	var all_done := current_step==STEPS.size()
	current_heading.text="阶段目标已完成" if all_done else "当前分任务 · %d / %d"%[current_step+1,STEPS.size()]
	current_label.text="返回机构" if all_done else STEPS[current_step]
	current_label.add_theme_color_override("font_color",DONE_COLOR.lightened(0.45) if all_done else CURRENT_COLOR)
	current_heading.add_theme_color_override("font_color",DONE_COLOR.lightened(0.30) if all_done else CURRENT_COLOR.darkened(0.09))
	for i in range(STEPS.size()):
		var completed := i<current_step
		var active := i==current_step
		var color := DONE_COLOR if completed else (CURRENT_COLOR if active else FUTURE_COLOR)
		step_labels[i].text="%s  %02d   %s"%["✓" if completed else ("›" if active else "·"),i+1,STEPS[i]]
		step_labels[i].add_theme_color_override("font_color",color)
		step_bands[i].add_theme_stylebox_override("panel",_style(Color("405760") if active else Color.TRANSPARENT,Color.TRANSPARENT))
	if _follow_current:_set_hovered_anchor(mini(current_step,STEPS.size()-1))

func _show_steps() -> void:
	hide_timer.stop()
	_focus_current()
	if popup.visible:return
	if reveal and reveal.is_valid():reveal.kill()
	popup.position.x=251
	popup.modulate.a=0.0
	popup.show()
	hover_bridge.show()
	reveal=create_tween().set_parallel(true)
	reveal.tween_property(popup,"modulate:a",1.0,0.14)
	reveal.tween_property(popup,"position:x",259.0,0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _hide_steps() -> void:
	if reveal and reveal.is_valid():reveal.kill()
	popup.hide()
	hover_bridge.hide()
	if not _current_hover:
		_follow_current=false
		_set_hovered_anchor(-1)

func _focus_current() -> void:
	_follow_current=true
	_set_hovered_anchor(mini(maxi(current_step,0),STEPS.size()-1))

func _set_hovered_anchor(index: int) -> void:
	if hovered_anchor==index:return
	hovered_anchor=index
	anchor_hovered.emit(index)

func _schedule_hide() -> void:
	if is_inside_tree() and is_instance_valid(hide_timer) and hide_timer.is_inside_tree():
		hide_timer.start()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(popup):
		_current_hover=false
		hide_timer.stop()
		_hide_steps()

func _text(parent: Node,text: String,at: Vector2,points: int,color: Color) -> Label:
	var result := Label.new()
	result.text=text
	result.position=at
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font",font)
	result.add_theme_font_size_override("font_size",points)
	result.add_theme_color_override("font_color",color)
	parent.add_child(result)
	return result

func _panel(parent: Node,at: Vector2,dimensions: Vector2,fill: Color,edge: Color) -> Panel:
	var result := Panel.new()
	result.position=at
	result.size=dimensions
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("panel",_style(fill,edge))
	parent.add_child(result)
	return result

func _style(fill: Color,edge: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color=fill
	result.border_color=edge
	result.set_border_width_all(1 if edge.a>0 else 0)
	result.set_corner_radius_all(8)
	if edge.a>0:
		result.shadow_color=Color(0.15,0.15,0.2,0.08)
		result.shadow_size=3
	return result
