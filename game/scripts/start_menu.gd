extends Node2D
## Local title screen. World previews are illustrative; gameplay starts in ice.
signal start_requested

const INK := Color("263d4b")
const GOLD := Color("b59a67")
const PAPER := Color("f3efe5")
const COLORS := [Color("82d4e4"), Color("e4b776"), Color("b5a0ed")]
const WORLD_NAMES := ["冰晶", "重力", "倒悬"]
const WORLD_RULES := ["让惯性，带你走得更远。", "轻如镇纸，也能重若千钧。", "换个世界，向上坠落。"]
var world := 0
var elapsed := 0.0
var motion_enabled := true
var starting := false
var title_font := SystemFont.new()
var font := SystemFont.new()
var root := Control.new()
var start_button: Button
var rule_label: Label
var world_label: Label
var help_panel: Panel
var selectors: Array[Button] = []
var scene_art: Texture2D
var fade: ColorRect
var sound = preload("res://scripts/tutorial_audio.gd").new()

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	title_font.font_names = PackedStringArray(["STZhongsong", "SimSun", "Noto Serif CJK SC", "serif"])
	add_child(sound)
	scene_art = load("res://assets/start_menu/parallel-worlds-v2.png")
	add_child(root)
	root.size = Vector2(1280, 800)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label("平 行 世 界 观 察 局", Vector2(64, 42), 16, INK)
	_label("BUREAU OF PARALLEL WORLDS", Vector2(64, 71), 10, GOLD)
	_label("世界不按", Vector2(62, 167), 65, INK, true)
	_label("说明书", Vector2(62, 241), 78, INK, true)
	_label("同一件东西，换个世界，", Vector2(67, 357), 18, INK)
	_label("就有另一种解法。", Vector2(67, 390), 18, INK)
	_label("衍月的平行世界解谜", Vector2(68, 445), 12, Color("89918e"))
	start_button = _button("开 始 旅 程     →", Rect2(66, 490, 370, 62), true)
	start_button.pressed.connect(begin)
	var help := _button("操作说明", Rect2(66, 568, 173, 42))
	help.pressed.connect(func(): help_panel.show(); help_panel.get_node("Close").grab_focus())
	var quit := _button("退出游戏", Rect2(255, 568, 181, 42))
	quit.pressed.connect(func(): get_tree().quit())
	_label("选择一种世界，看看规则如何改变", Vector2(67, 650), 12, Color("8a8e86"))
	for i in range(3):
		var button := _button("0%d  %s" % [i + 1, WORLD_NAMES[i]], Rect2(66 + i * 127, 682, 116, 38))
		button.pressed.connect(func(): select_world(i))
		selectors.append(button)
	_label("本地试玩  /  新手校准室", Vector2(67, 756), 11, Color("92978f"))
	_label("F11  全屏", Vector2(1163, 39), 11, Color("bbccce"))
	world_label = _label("", Vector2(564, 649), 24, Color("f4efe1"), true)
	rule_label = _label("", Vector2(565, 695), 15, Color("d2dedf"))
	_label("同一块镇纸 · 三种物性 · 一条归途", Vector2(584, 754), 12, Color("728d98"))
	var motion := _button("动态画面：开", Rect2(1076, 741, 145, 32))
	motion.pressed.connect(func():
		motion_enabled = not motion_enabled
		motion.text = "动态画面：开" if motion_enabled else "动态画面：关"
	)
	_build_help()
	fade = ColorRect.new()
	fade.color = Color("102632")
	fade.size = Vector2(1280, 800)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0
	root.add_child(fade)
	# Keep controls above the illustrated scene and its atmospheric particles.
	root.z_index = 5
	select_world(0)
	start_button.grab_focus()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu-world="):
			select_world(arg.trim_prefix("--menu-world=").to_int())
		if arg == "--menu-help":
			help_panel.show()
			help_panel.get_node("Close").grab_focus()
	_capture_if_requested.call_deferred()

func _label(text: String, pos: Vector2, size: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", title_font if display else font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
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
	button.add_theme_color_override("font_color", PAPER if primary else INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _style(INK if primary else Color("eeeade"), GOLD if primary else Color("d9d3c3")))
	button.add_theme_stylebox_override("hover", _style(Color("e1d3b2"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("cab992"), GOLD))
	var focus := _style(Color.TRANSPARENT, GOLD)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	root.add_child(button)
	button.mouse_entered.connect(func(): sound.tone(610, 0.035))
	return button

func _build_help() -> void:
	help_panel = Panel.new()
	help_panel.position = Vector2(50, 135)
	help_panel.size = Vector2(425, 495)
	help_panel.add_theme_stylebox_override("panel", _style(PAPER, GOLD))
	root.add_child(help_panel)
	var copy := Label.new()
	copy.position = Vector2(27, 25)
	copy.add_theme_font_override("font", font)
	copy.add_theme_font_size_override("font_size", 17)
	copy.add_theme_color_override("font_color", INK)
	copy.text = "观 察 员 行 动 手 册\n\nWASD / 方向键     移动\n鼠标左键               点击寻路\n右键镇纸 / E         推动镇纸\nQ / 1、2、3           切换世界\nH                              逐步提示\nR                              重置校准室\nAlt + 左键拖动      旋转视角\nF10                          返回启动界面\n\n同一块镇纸，在不同世界拥有不同物性。\n从冰晶世界开始你的第一次校准。"
	help_panel.add_child(copy)
	var close := _button("合上手册  /  Esc", Rect2(25, 425, 375, 44), true)
	root.remove_child(close)
	help_panel.add_child(close)
	close.name = "Close"
	close.pressed.connect(close_help)
	help_panel.hide()

func close_help() -> void:
	help_panel.hide()
	start_button.grab_focus()

func select_world(index: int) -> void:
	world = clampi(index, 0, 2)
	world_label.text = "0%d  /  %s世界" % [world + 1, WORLD_NAMES[world]]
	rule_label.text = WORLD_RULES[world]
	for i in range(selectors.size()):
		selectors[i].add_theme_stylebox_override("normal", _style(Color("dbd9c9") if i == world else Color("eeeade"), GOLD if i == world else Color("d9d3c3")))
	queue_redraw()

func begin() -> void:
	if starting: return
	starting = true
	start_button.disabled = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	sound.tone(440, 0.25)
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.45)
	tween.tween_callback(func(): start_requested.emit())

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or starting: return
	if event.keycode == KEY_ESCAPE and help_panel.visible:
		close_help()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not help_panel.visible and event.keycode in [KEY_1, KEY_2, KEY_3]:
		select_world(event.keycode - KEY_1)

func _process(delta: float) -> void:
	if motion_enabled:
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), PAPER)
	draw_rect(Rect2(520, 0, 760, 800), Color("102632"))
	draw_line(Vector2(520, 0), Vector2(520, 800), GOLD, 1)
	draw_line(Vector2(66, 125), Vector2(435, 125), Color("d8cbb0"), 1)
	draw_line(Vector2(66, 631), Vector2(435, 631), Color("d8cbb0"), 1)
	var accent: Color = COLORS[world]
	# The painting is one coherent scene; fit and crop it without stretching.
	if scene_art:
		var image_size := scene_art.get_size()
		var crop_scale := maxf(760.0 / image_size.x, 800.0 / image_size.y)
		var source_size := Vector2(760, 800) / crop_scale
		var source := Rect2((image_size - source_size) * 0.5, source_size)
		draw_texture_rect_region(scene_art, Rect2(520, 0, 760, 800), source)
	# A world-dependent wash and a restrained veil preserve caption contrast.
	draw_rect(Rect2(520, 0, 760, 800), Color(accent, 0.045))
	_veil(Rect2(520, 545, 760, 135), 0.0, 0.9)
	_veil(Rect2(520, 680, 760, 120), 0.9, 0.96)
	_veil(Rect2(520, 0, 760, 100), 0.35, 0.0)
	# A few firefly-like particles are native animation above the illustration.
	for i in range(12):
		var x := 560.0 + fmod(i * 131.3, 670)
		var direction := -1.0 if world == 2 else 1.0
		var drift := elapsed * (5 if world == 0 else 12) * direction
		var y := 100 + fposmod(i * 81.7 + drift, 490)
		var pos := Vector2(x + sin(elapsed * 0.3 + i) * 6.0, y)
		draw_circle(pos, 5, Color(accent, 0.045))
		draw_circle(pos, 1.3, Color(accent, 0.6), true, -1, true)
	draw_line(Vector2(565, 730), Vector2(1220, 730), Color("536773"), 1)

func _veil(rect: Rect2, top_alpha: float, bottom_alpha: float) -> void:
	var top := Color(Color("102632"), top_alpha)
	var bottom := Color(Color("102632"), bottom_alpha)
	draw_polygon(PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]), PackedColorArray([top, top, bottom, bottom]))

func _capture_if_requested() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu-capture="):
			await get_tree().create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			var error := get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--menu-capture="))
			get_tree().quit(error)
