extends Node2D
## Teammate's illustrated title screen. Previews do not change gameplay state.
signal start_requested
signal quit_requested

const INK := Color("e5e6df")
const GOLD := Color("b59a67")
const PAPER := Color("142932")
const COLORS := [Color("82d4e4"), Color("e4b776"), Color("b5a0ed")]
const WORLD_NAMES := ["冰晶", "重力", "倒悬"]
const WORLD_RULES := ["让惯性，带你走得更远。", "轻如镇纸，也能重若千钧。", "换个世界，向上坠落。"]
var world := 0
var elapsed := 0.0
var motion_enabled := true
var starting := false
var entry_progress := 0.0
var title_font: Font = preload("res://assets/fonts/ma_shan_zheng/MaShanZheng-Regular.ttf")
var title_group := Control.new()
var main_title: Label
var background_rect := TextureRect.new()
var background_material := ShaderMaterial.new()
var title_material := ShaderMaterial.new()
var pointer_offset := Vector2.ZERO
var font := SystemFont.new()
var options_button: Button
var manual_button: Button
var options_panel: Panel
var options_shade: ColorRect
var active_index := 0
var main_buttons: Array[Button] = []
var root := Control.new()
var start_button: Button
var rule_label: Label
var world_label: Label
var help_panel: Panel
var help_shade: ColorRect
var help_copy: Label
var mute_button: Button
var motion_button: Button
var quit_button: Button
var selectors: Array[Button] = []
var scene_art: Texture2D
var fade: ColorRect
var sound = preload("res://scripts/tutorial_audio.gd").new()

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	add_child(sound)
	scene_art = load("res://assets/start_menu/bureau-interior-v4.png")
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.texture = scene_art
	background_rect.size = Vector2(1280, 800)
	background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_rect.z_index = -2
	background_material.shader = preload("res://shaders/bureau_title_ambience.gdshader")
	background_rect.material = background_material
	add_child(background_rect)
	add_child(root)
	root.size = Vector2(1280, 800)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_floating_title()
	start_button = _menu_button("进入观察局", 0)
	start_button.pressed.connect(begin)
	options_button = _menu_button("选项", 1)
	options_button.pressed.connect(open_options)
	quit_button = _menu_button("退出游戏", 2)
	quit_button.pressed.connect(func(): quit_requested.emit())
	for i in range(main_buttons.size()):
		main_buttons[i].focus_neighbor_top = main_buttons[(i + 2) % 3].get_path()
		main_buttons[i].focus_neighbor_bottom = main_buttons[(i + 1) % 3].get_path()
	_center_label("同一件东西，换个世界，就有另一种解法。", Rect2(200, 710, 880, 30), 16, Color("d2d6cd"))
	_label("平行世界观察局  ·  本地试玩", Vector2(34, 757), 11, Color("a8b7b8"))
	_label("↑ ↓ 选择    Enter 确认    M 声音    F11 全屏", Vector2(917, 757), 11, Color("a8b7b8"))
	_build_options()
	_build_help()
	fade = ColorRect.new()
	fade.color = Color("102632")
	fade.size = Vector2(1280, 800)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0
	root.add_child(fade)
	root.z_index = 5
	select_world(0)
	start_button.grab_focus()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu-world="): select_world(arg.trim_prefix("--menu-world=").to_int())
		if arg == "--menu-options": open_options()
		if arg == "--menu-help": open_help()
	_capture_if_requested.call_deferred()

func _label(text: String, pos: Vector2, size: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", title_font if display else font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.03,0.06,0.09,0.65))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style

func _button(text: String, rect: Rect2, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 18 if primary else 13)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color("fff1ca"))
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _style(Color("203943"), GOLD if primary else Color("526067")))
	button.add_theme_stylebox_override("hover", _style(Color("34505a"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("142a34"), GOLD))
	var focus := _style(Color.TRANSPARENT, GOLD)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	root.add_child(button)
	button.mouse_entered.connect(func(): sound.tone(610, 0.035))
	return button

func _center_label(text: String, rect: Rect2, size: int, color: Color, display := false) -> Label:
	var label := _label(text, rect.position, size, color, display)
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _menu_button(text: String, index: int) -> Button:
	var button := _button(text, Rect2(440, 426 + index * 62, 400, 52), true)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_font_override("font", font)
	button.add_theme_color_override("font_hover_color", Color("fff8df"))
	button.add_theme_color_override("font_focus_color", Color("fff8df"))
	button.add_theme_color_override("font_shadow_color", Color("172839"))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.13, 0.3))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.mouse_entered.connect(func(): _set_active(index))
	button.focus_entered.connect(func(): _set_active(index))
	main_buttons.append(button)
	_set_active(0)
	return button

func _set_active(index: int) -> void:
	active_index = index
	for i in range(main_buttons.size()):
		main_buttons[i].add_theme_font_size_override("font_size", 28 if i == index else 24)
		main_buttons[i].add_theme_color_override("font_color", Color("fff9e8") if i == index else Color("d7d7cb"))
	queue_redraw()

func _panel_label(text: String, pos: Vector2, size: int) -> Label:
	var label := _label(text, pos, size, INK)
	root.remove_child(label)
	options_panel.add_child(label)
	return label

func _panel_button(text: String, rect: Rect2) -> Button:
	var button := _button(text, rect)
	root.remove_child(button)
	options_panel.add_child(button)
	return button

func _build_options() -> void:
	options_shade = ColorRect.new()
	options_shade.size = Vector2(1280, 800)
	options_shade.color = Color(0.025, 0.045, 0.075, 0.68)
	root.add_child(options_shade)
	options_panel = Panel.new()
	options_panel.position = Vector2(350, 140)
	options_panel.size = Vector2(580, 520)
	options_panel.add_theme_stylebox_override("panel", _style(Color("182f39"), Color("6b7776")))
	options_shade.add_child(options_panel)
	_panel_label("旅 途 选 项", Vector2(210, 28), 24)
	_panel_label("世界氛围预览", Vector2(40, 91), 14)
	for i in range(3):
		var button := _panel_button(WORLD_NAMES[i], Rect2(40 + i * 170, 125, 160, 40))
		button.pressed.connect(func(): select_world(i))
		selectors.append(button)
	world_label = _panel_label("", Vector2(40, 190), 17)
	rule_label = _panel_label("", Vector2(40, 225), 14)
	mute_button = _panel_button("声音：开  M", Rect2(40, 275, 240, 44))
	mute_button.pressed.connect(func(): get_parent().ambience.toggle_mute())
	motion_button = _panel_button("动态画面：开", Rect2(300, 275, 240, 44))
	motion_button.pressed.connect(func():
		motion_enabled = not motion_enabled
		motion_button.text = "动态画面：开" if motion_enabled else "动态画面：关"
		queue_redraw()
	)
	manual_button = _panel_button("操作说明", Rect2(40, 339, 500, 44))
	manual_button.pressed.connect(open_help)
	var back := _panel_button("返回旅途  /  Esc", Rect2(40, 430, 500, 46))
	back.pressed.connect(close_options)
	options_shade.hide()

func _focus_options(enabled: bool) -> void:
	for control in options_panel.get_children():
		if control is Button: control.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func open_options() -> void:
	if starting: return
	for control in main_buttons: control.focus_mode = Control.FOCUS_NONE
	options_shade.show()
	selectors[world].grab_focus()
	queue_redraw()

func close_options() -> void:
	options_shade.hide()
	for control in main_buttons: control.focus_mode = Control.FOCUS_ALL
	options_button.grab_focus()
	queue_redraw()


func _build_help() -> void:
	help_shade = ColorRect.new()
	help_shade.size = Vector2(1280,800)
	help_shade.color = Color(0.02,0.05,0.07,0.8)
	root.add_child(help_shade)
	help_panel = Panel.new()
	help_panel.position = Vector2(415, 135)
	help_panel.size = Vector2(425, 495)
	help_panel.add_theme_stylebox_override("panel", _style(PAPER, GOLD))
	help_shade.add_child(help_panel)
	var copy := Label.new()
	help_copy = copy
	copy.position = Vector2(27, 25)
	copy.add_theme_font_override("font", font)
	copy.add_theme_font_size_override("font_size", 16)
	copy.add_theme_color_override("font_color", INK)
	copy.text = "观 察 员 行 动 手 册\n\nWASD / 方向键       移动\n鼠标左键                 点击地面寻路\n右键镇纸 / E           互动镇纸\n1、2、3                    切换世界（冷却1.5秒）\nH                                逐步提示\nR                                重置校准室\n左Alt + 左键拖动     旋转视角\nM / F11                    静音 / 全屏\nF10                            返回启动界面\n\n开始旅程后，点击大厅星系仪选择关卡。\n这里的世界按钮仅用于规则预览。"
	help_panel.add_child(copy)
	var close := _button("合上手册  /  Esc", Rect2(25, 425, 375, 44), true)
	root.remove_child(close)
	help_panel.add_child(close)
	close.name = "Close"
	close.pressed.connect(close_help)
	help_panel.hide()
	help_shade.hide()

func open_help() -> void:
	_focus_options(false)
	for control in root.get_children():
		if control is Button:control.focus_mode=Control.FOCUS_NONE
	help_shade.show()
	help_panel.show()
	help_panel.get_node("Close").grab_focus()

func close_help() -> void:
	_focus_options(true)
	help_panel.hide()
	help_shade.hide()
	for control in root.get_children():
		if control is Button:control.focus_mode=Control.FOCUS_ALL
	if options_shade.visible:
		for control in main_buttons: control.focus_mode = Control.FOCUS_NONE
		manual_button.grab_focus()
	else:
		start_button.grab_focus()

func select_world(index: int) -> void:
	world = clampi(index, 0, 2)
	world_label.text = "0%d  /  %s世界" % [world + 1, WORLD_NAMES[world]]
	rule_label.text = WORLD_RULES[world]
	for i in range(selectors.size()):
		selectors[i].add_theme_stylebox_override("normal", _style(Color("35505a") if i == world else Color("203943"), GOLD if i == world else Color("d9d3c3")))
	queue_redraw()

func begin() -> void:
	if starting or help_panel.visible or options_shade.visible: return
	starting = true
	start_button.disabled = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	sound.tone(440, 0.25)
	start_requested.emit()

func set_entry_progress(value: float) -> void:
	entry_progress = value
	root.modulate.a = 1.0 - smoothstep(0.0, 0.42, value)
	background_material.set_shader_parameter("entry_phase", smoothstep(0.0, 1.0, value) if motion_enabled else 0.0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or starting: return
	if event.keycode == KEY_ESCAPE:
		if help_panel.visible: close_help()
		elif options_shade.visible: close_options()
		else: return
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
	elif not help_panel.visible and event.keycode in [KEY_1, KEY_2, KEY_3]:
		select_world(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if is_instance_valid(mute_button):
		mute_button.text = "声音：关  M" if get_parent().ambience.muted else "声音：开  M"
	if motion_enabled:
		elapsed += delta
		var target := (get_viewport().get_mouse_position() / Vector2(1280, 800) - Vector2(0.5, 0.5)).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)) * 0.004
		pointer_offset = pointer_offset.lerp(target, 1.0 - exp(-delta * 2.0))
		_apply_motion()
		queue_redraw()

func _build_floating_title() -> void:
	title_group.size = Vector2(1280, 330)
	title_group.pivot_offset = Vector2(640, 210)
	title_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_group)
	var agency := _center_label("平行世界观察局", Rect2(180, 108, 920, 26), 16, Color("dbc69c"))
	main_title = _center_label("世界不按说明书", Rect2(80, 150, 1120, 118), 86, Color("fff0cf"), true)
	title_material.shader = preload("res://shaders/bureau_title_sheen.gdshader")
	main_title.material = title_material
	main_title.add_theme_color_override("font_shadow_color", Color(0.88, 0.66, 0.27, 0.22))
	main_title.add_theme_constant_override("shadow_offset_y", 0)
	main_title.add_theme_constant_override("shadow_outline_size", 7)
	main_title.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.45))
	main_title.add_theme_constant_override("outline_size", 1)
	var subtitle := _center_label("衍月的平行世界解谜", Rect2(180, 281, 920, 30), 18, Color("e2d7c1"))
	for label in [agency, main_title, subtitle]:
		root.remove_child(label)
		title_group.add_child(label)

func _apply_motion() -> void:
	background_material.set_shader_parameter("motion_time", elapsed)
	background_material.set_shader_parameter("pointer_offset", pointer_offset)
	title_group.position = Vector2.ZERO
	title_group.rotation = 0.0
	title_group.scale = Vector2.ONE
	main_title.modulate = Color.WHITE
	title_material.set_shader_parameter("motion_time", elapsed)

func _scene_point(uv: Vector2) -> Vector2:
	# Match the background shader so the orbit lights stay attached to the globe.
	var zoom := 1.06 + 0.014 * sin(elapsed * 0.45)
	var drift := Vector2(sin(elapsed * 0.48) * 0.011, sin(elapsed * 0.36) * 0.006)
	var approach := smoothstep(0.0, 1.0, entry_progress) if motion_enabled else 0.0
	zoom *= lerpf(1.0, 1.16, approach)
	var focus := Vector2(0.5, 0.5).lerp(Vector2(0.70, 0.503), approach)
	return ((uv - focus - drift - pointer_offset) * zoom + Vector2(0.5, 0.5)) * Vector2(1280, 800)

func _draw_globe_orbits() -> void:
	var center := _scene_point(Vector2(0.8897, 0.503))
	for i in range(3):
		var angle := elapsed * (0.75 + i * 0.17) + i * TAU / 3.0
		var radius := 61.0 + i * 8.0
		draw_set_transform(center, -0.35 + i * 0.36, Vector2(1.0, 0.62))
		for trail in range(6):
			var a := angle - trail * 0.1
			draw_arc(Vector2.ZERO, radius, a - 0.11, a, 8, Color(0.38, 0.75, 1.0, 0.65 - trail * 0.09), 2.0, true)
		var head := Vector2.from_angle(angle) * radius
		draw_circle(head, 7, Color(0.38, 0.75, 1.0, 0.18))
		draw_circle(head, 2.6, Color("def8ff"), true, -1, true)
		draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	var menu_opacity := 1.0 - smoothstep(0.0, 0.6, entry_progress)
	_veil(Rect2(0, 0, 1280, 310), 0.28 * menu_opacity, 0.0)
	_veil(Rect2(0, 360, 1280, 440), 0.0, 0.77 * menu_opacity)
	if starting:return
	draw_rect(Rect2(0, 0, 1280, 800), Color(COLORS[world], 0.025))
	_draw_globe_orbits()
	for i in range(58):
		var x := fposmod(i * 137.7 + elapsed * (4 + i % 4) + sin(elapsed * 0.4 + i) * 20, 1240) + 20
		var y := 50 + fposmod(i * 73.3 - elapsed * (18 + i % 5 * 3) * (-1 if world == 1 else 1), 700)
		var alpha := 0.3 + 0.4 * (0.5 + 0.5 * sin(elapsed * 1.2 + i))
		draw_circle(Vector2(x, y), 7, Color(COLORS[world], alpha * 0.13))
		draw_circle(Vector2(x, y), 1.8 + i % 3 * 0.3, Color(COLORS[world], alpha), true, -1, true)
	if not options_shade or not help_shade or options_shade.visible or help_shade.visible: return
	var y := 452.0 + active_index * 62
	var pulse := 0.7 + 0.15 * sin(elapsed * 1.4)
	for i in range(10, 0, -1):
		draw_set_transform(Vector2(640, y + 2), 0, Vector2(140 + i * 18, 1.3 + i))
		draw_circle(Vector2.ZERO, 1, Color(0.88, 0.77, 0.54, 0.04 * pulse))
	draw_set_transform(Vector2.ZERO)
	for side in [-1, 1]:
		var p := Vector2(640 + side * 120, y + 2)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4)]), Color("ebdfbd"))

func _veil(rect: Rect2, top_alpha: float, bottom_alpha: float) -> void:
	var top := Color(Color("102632"), top_alpha)
	var bottom := Color(Color("102632"), bottom_alpha)
	draw_polygon(PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]), PackedColorArray([top, top, bottom, bottom]))

func _capture_if_requested() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu-clip-dir="):
			var directory := arg.trim_prefix("--menu-clip-dir=")
			DirAccess.make_dir_recursive_absolute(directory)
			motion_enabled = false
			pointer_offset = Vector2.ZERO
			for frame in range(64):
				elapsed = float(frame) / 8.0
				_apply_motion()
				queue_redraw()
				await RenderingServer.frame_post_draw
				var capture_error := get_viewport().get_texture().get_image().save_png(directory.path_join("frame-%03d.png" % frame))
				if capture_error != OK:
					await get_parent().shutdown_audio()
					get_tree().quit(capture_error)
					return
			await get_parent().shutdown_audio()
			get_tree().quit()
			return
		if arg.begins_with("--menu-capture="):
			await get_tree().create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			var error := get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--menu-capture="))
			await get_parent().shutdown_audio()
			get_tree().quit(error)
