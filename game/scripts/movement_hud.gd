extends CanvasLayer

signal reset_requested
signal debug_requested

var status_label: Label
var mode_label: Label
var debug_button: Button
var _font := SystemFont.new()

func _ready() -> void:
	_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	var header := Panel.new()
	header.position = Vector2(28,18)
	header.size = Vector2(1224,66)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", _panel_style())
	root_control.add_child(header)
	_label(header, "不存在的物品", Vector2(22,10), 25, Color("283d4d"))
	_label(header, "衍月移动 v0.3  /  世界观察局试验室", Vector2(230,22), 14, Color("687477"))
	mode_label = _label(header,"",Vector2(690,22),14,Color("44748c"))
	var reset := _button(header,"重置  R",Vector2(920,15),Vector2(116,36))
	reset.pressed.connect(func() -> void: reset_requested.emit())
	debug_button = _button(header,"碰撞显示  F2",Vector2(1046,15),Vector2(160,36))
	debug_button.pressed.connect(func() -> void: debug_requested.emit())
	var footer := Panel.new()
	footer.position = Vector2(42,716)
	footer.size = Vector2(1196,64)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_stylebox_override("panel", _panel_style())
	root_control.add_child(footer)
	_label(footer,"WASD / 方向键走动    ·    左键点击空地绕行    ·    Esc 取消路线",Vector2(18,9),15,Color("384b55"))
	status_label = _label(footer,"点击空地，或用 WASD 走动。",Vector2(18,35),14,Color("69777a"))
	_label(footer,"F3 放大查看四向步态",Vector2(913,35),12,Color("869092"))

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98,0.97,0.94,0.97)
	style.border_color = Color("d1c7b7")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.2,0.18,0.12,0.07)
	style.shadow_size = 4
	return style

func _label(parent: Node, text: String, at: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, at: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font",_font)
	button.add_theme_font_size_override("font_size",13)
	button.add_theme_color_override("font_color",Color("355369"))
	button.add_theme_stylebox_override("normal",_panel_style())
	var hover := _panel_style()
	hover.bg_color = Color("e3edf1")
	button.add_theme_stylebox_override("hover",hover)
	parent.add_child(button)
	return button

func set_status(message: String, warning: bool = false) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color",Color("a25942") if warning else Color("557282"))

func show_mode(moving: bool, automatic: bool) -> void:
	mode_label.text = "点击绕行中" if automatic else ("手动走动" if moving else "待机")
