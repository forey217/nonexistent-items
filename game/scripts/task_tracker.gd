extends Control
signal anchor_hovered(index:int)
const Instruments=preload("res://scripts/instrument_theme.gd")
const MAIN_COLOR=Instruments.TEXT
const CURRENT_COLOR=Instruments.TEXT
const DONE_COLOR=Color("b5cdb4")
const FUTURE_COLOR=Instruments.MUTED
const STEPS:Array[String]=[
	"激活星位踏板，定位星位",
	"激活月痕印座，压稳月痕",
	"激活封界踏板，封闭界缝"
]
var font:=Instruments.body()
var main_area:Button
var main_label:Label
var current_label:Label
var current_heading:Label
var popup:Panel
var hover_bridge:Control
var step_labels:Array[Label]=[]
var step_bands:Array[Panel]=[]
var hide_timer:Timer
var reveal:Tween
var current_step:=-1
var hovered_anchor:=-1
var _follow_current:=false
var _current_hover:=false
var pinned:=false
var mark:Label

func _ready() -> void:
	position=Vector2(24,24);size=Vector2(320,78);mouse_filter=Control.MOUSE_FILTER_IGNORE
	var card:=_panel(self,Vector2.ZERO,size)
	card.mouse_filter=Control.MOUSE_FILTER_STOP
	main_area=Button.new();main_area.position=Vector2(12,5);main_area.size=Vector2(296,30)
	Instruments.apply_button(main_area,17)
	for key in ["normal","hover","pressed"]:main_area.add_theme_stylebox_override(key,StyleBoxEmpty.new())
	card.add_child(main_area)
	current_heading=_text(main_area,"",Vector2(4,1),17,Instruments.COPPER_TEXT)
	main_area.pressed.connect(func():pinned=not pinned;_show_steps() if pinned else _hide_steps())
	var current:=Control.new();current.position=Vector2(16,35);current.size=Vector2(288,37);current.mouse_filter=Control.MOUSE_FILTER_STOP;card.add_child(current)
	current.mouse_entered.connect(func():_current_hover=true;_focus_current())
	current.mouse_exited.connect(func():_current_hover=false;_set_hovered_anchor(-1))
	current.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			pinned=not pinned;_show_steps() if pinned else _hide_steps();accept_event())
	current_label=_text(current,"",Vector2.ZERO,22,CURRENT_COLOR)
	current_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;current_label.size=Vector2(288,37)
	mark=_text(card,"◇",Vector2(288,7),17,Instruments.BLUE)
	popup=_panel(self,Vector2(332,0),Vector2(356,205));popup.z_index=10;popup.mouse_filter=Control.MOUSE_FILTER_STOP
	main_label=_text(popup,"稳固世界关系，返回机构",Vector2(16,12),19,MAIN_COLOR)
	_text(popup,"观测阶段",Vector2(16,43),16,Instruments.COPPER_TEXT)
	for i in range(STEPS.size()):
		var index:=i
		var band:=_panel(popup,Vector2(10,73+i*38),Vector2(336,34),false)
		band.mouse_filter=Control.MOUSE_FILTER_STOP
		band.mouse_entered.connect(func():hide_timer.stop();_follow_current=false;_set_hovered_anchor(index))
		band.mouse_exited.connect(_schedule_hide)
		var row:=_text(band,"",Vector2(8,4),17,FUTURE_COLOR)
		step_bands.append(band);step_labels.append(row)
	popup.hide()
	hide_timer=Timer.new();hide_timer.one_shot=true;hide_timer.wait_time=.20;add_child(hide_timer);hide_timer.timeout.connect(_hide_steps)
	hover_bridge=Control.new();hover_bridge.position=Vector2(308,0);hover_bridge.size=Vector2(24,88);hover_bridge.z_index=10
	hover_bridge.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(hover_bridge);hover_bridge.hide()
	hover_bridge.mouse_entered.connect(func():hide_timer.stop());hover_bridge.mouse_exited.connect(_schedule_hide)
	main_area.mouse_entered.connect(_show_steps);main_area.mouse_exited.connect(_schedule_hide)
	popup.mouse_entered.connect(func():hide_timer.stop());popup.mouse_exited.connect(_schedule_hide)
	var transition=preload("res://scripts/task_transition.gd").new();transition.label=current_label;transition.idle_mark=mark;add_child(transition)
	refresh_step(0)

func refresh(state:RefCounted) -> void:refresh_step(state.goal_stage())

func refresh_step(index:int) -> void:
	var next_step:=clampi(index,0,STEPS.size())
	if next_step==current_step:
		current_label.text="返回机构" if current_step==STEPS.size() else STEPS[current_step]
		return
	current_step=next_step
	var done:=current_step==STEPS.size()
	current_heading.text="观测校准　✓ 已完成" if done else "观测校准　%s / Ⅲ"%["Ⅰ","Ⅱ","Ⅲ"][current_step]
	current_label.text="返回机构" if done else STEPS[current_step]
	current_label.add_theme_color_override("font_color",DONE_COLOR if done else CURRENT_COLOR)
	for i in range(STEPS.size()):
		var completed:=i<current_step;var active:=i==current_step
		step_labels[i].text="%s  %02d　%s"%["✓" if completed else ("›" if active else "·"),i+1,STEPS[i]]
		step_labels[i].add_theme_color_override("font_color",DONE_COLOR if completed else (CURRENT_COLOR if active else FUTURE_COLOR))
		step_bands[i].add_theme_stylebox_override("panel",Instruments.state_style(true) if active else StyleBoxEmpty.new())
	if _follow_current:_set_hovered_anchor(mini(current_step,STEPS.size()-1))

func _show_steps() -> void:
	hide_timer.stop();_focus_current()
	if popup.visible:return
	if is_instance_valid(reveal):reveal.kill()
	popup.position.x=328;popup.modulate.a=1;popup.show();hover_bridge.show()
	reveal=create_tween();reveal.tween_property(popup,"position:x",332.0,.14)

func _hide_steps() -> void:
	if pinned:return
	if is_instance_valid(reveal):reveal.kill()
	popup.hide();hover_bridge.hide()
	if not _current_hover:_follow_current=false;_set_hovered_anchor(-1)

func collapse() -> void:
	pinned=false;_current_hover=false;hide_timer.stop();_hide_steps()

func _focus_current() -> void:
	_follow_current=true;_set_hovered_anchor(mini(maxi(current_step,0),STEPS.size()-1))

func _set_hovered_anchor(index:int) -> void:
	if hovered_anchor==index:return
	hovered_anchor=index;anchor_hovered.emit(index)

func _schedule_hide() -> void:
	if is_inside_tree() and is_instance_valid(hide_timer) and hide_timer.is_inside_tree():hide_timer.start()

func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(popup):collapse()

func _text(parent:Node,text:String,at:Vector2,points:int,color:Color) -> Label:
	return Instruments.label(parent,text,at,Vector2.ZERO,points,color)

func _panel(parent:Node,at:Vector2,dimensions:Vector2,framed:=true) -> Panel:
	var p:=Panel.new();p.position=at;p.size=dimensions;p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel",Instruments.style() if framed else StyleBoxEmpty.new());parent.add_child(p);return p
