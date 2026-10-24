extends Node2D
## Illustrated title screen with archive-paper settings and a shared audio slider.
signal start_requested
signal quit_requested

const INK := Color("e5e6df")
const GOLD := Color("b59a67")
const PAPER := Color("142932")
const COLORS := [Color("82d4e4"), Color("e4b776"), Color("b5a0ed")]
var world := 0
var elapsed := 0.0
var motion_enabled := true
var starting := false
var entry_progress := 0.0
const SAVE_ENTRY_DURATION := 1.4
const SAVE_ENTRY_ZOOM := 4.65
const GLOBE_UV := Vector2(0.8897, 0.503)
const SAVE_GLOBE_CENTER := Vector2(640, 300)
var save_entry := false
var entry_start_zoom := 1.06
var entry_start_focus := Vector2(0.5, 0.5)
var camera_zoom := 1.06
var camera_focus := Vector2(0.5, 0.5)
var title_font: Font = preload("res://assets/fonts/ma_shan_zheng/MaShanZheng-Regular.ttf")
var title_group := Control.new()
var main_title: Label
var background_rect := TextureRect.new()
var background_material := ShaderMaterial.new()
var title_material := ShaderMaterial.new()
var pointer_offset := Vector2.ZERO
var font := FontVariation.new()
var options_button: Button
var manual_button: Button
var options_page: Control
var options_panel: Control
var options_shade: Control
var active_index := 0
var main_buttons: Array[Button] = []
var root := Control.new()
var start_button: Button
var help_panel: Control
var quit_button: Button
var scene_art: Texture2D
var fade: ColorRect
var sound = preload("res://scripts/tutorial_audio.gd").new()

func _ready() -> void:
	font.base_font=preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf")
	font.variation_embolden=0.16
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
	start_button = _menu_button("进入世界观察局", 0)
	start_button.pressed.connect(begin)
	options_button = _menu_button("选项", 1)
	options_button.pressed.connect(open_options)
	quit_button = _menu_button("退出游戏", 2)
	quit_button.pressed.connect(func(): quit_requested.emit())
	for i in range(main_buttons.size()):
		main_buttons[i].focus_neighbor_top = main_buttons[(i + 2) % 3].get_path()
		main_buttons[i].focus_neighbor_bottom = main_buttons[(i + 1) % 3].get_path()
	_center_label("同一件东西，换个世界，就有另一种解法。", Rect2(200, 710, 880, 30), 16, Color("d2d6cd"))
	_label(preload("res://scripts/build_info.gd").LABEL, Vector2(34, 757), 13, Color("c7d2cd"))
	_label("↑ ↓ 选择    Enter 确认    M 声音    F11 全屏", Vector2(917, 757), 11, Color("a8b7b8"))
	_build_options()
	fade = ColorRect.new()
	fade.color = Color("102632")
	fade.size = Vector2(1280, 800)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0
	root.add_child(fade)
	root.z_index = 5
	start_button.grab_focus()
	for arg in OS.get_cmdline_user_args():
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
	button.mouse_exited.connect(_refresh_main_button_styles)
	button.focus_entered.connect(func(): _set_active(index))
	main_buttons.append(button)
	_set_active(0)
	return button

func _set_active(index: int) -> void:
	active_index = index
	_refresh_main_button_styles()

func _refresh_main_button_styles() -> void:
	for i in range(main_buttons.size()):
		main_buttons[i].add_theme_font_size_override("font_size", 28 if main_buttons[i].is_hovered() else 24)
		main_buttons[i].add_theme_color_override("font_color", Color("fff9e8") if i == active_index else Color("d7d7cb"))
	queue_redraw()

func _build_options() -> void:
	options_page=preload("res://scripts/archive_options.gd").new()
	options_page.audio=get_parent().ambience
	root.add_child(options_page)
	options_panel=options_page.sheet
	options_shade=options_page
	help_panel=options_page.manual_content
	manual_button=options_page.manual_button
	options_page.closed.connect(_options_closed)

func open_options() -> void:
	if starting:return
	for control in main_buttons:control.focus_mode=Control.FOCUS_NONE
	options_page.open()
	queue_redraw()

func close_options() -> void:
	options_page.close()

func _options_closed() -> void:
	for control in main_buttons:control.focus_mode=Control.FOCUS_ALL
	options_button.grab_focus()
	queue_redraw()

func open_help() -> void:
	if not options_page.visible:open_options()
	options_page.open_manual()

func close_help() -> void:
	options_page.close_manual()

func begin() -> void:
	if starting or help_panel.visible or options_shade.visible: return
	starting = true
	start_button.disabled = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	get_parent().ambience.play_entry()
	start_requested.emit()

func set_entry_progress(value: float) -> void:
	entry_progress = value
	root.modulate.a = 1.0 - smoothstep(0.0, 0.42, value)
	if save_entry:
		var progress := smoothstep(0.0, 1.0, value) if motion_enabled else 0.0
		# Interpolate the visible image rectangle: both endpoints cover the viewport,
		# so every intermediate rectangle stays inside the original painting too.
		camera_zoom = 1.0 / lerpf(1.0 / entry_start_zoom, 1.0 / SAVE_ENTRY_ZOOM, progress)
		var final_focus := GLOBE_UV - (SAVE_GLOBE_CENTER / Vector2(1280, 800) - Vector2(0.5, 0.5)) / SAVE_ENTRY_ZOOM
		camera_focus = entry_start_focus.lerp(final_focus, progress)
		background_material.set_shader_parameter("camera_zoom", camera_zoom)
		background_material.set_shader_parameter("camera_focus", camera_focus)
		queue_redraw()
		return
	background_material.set_shader_parameter("entry_phase", smoothstep(0.0, 1.0, value) if motion_enabled else 0.0)
	queue_redraw()

func prepare_save_entry() -> void:
	# Capture the exact currently rendered camera, including mouse parallax.
	# The same material and TextureRect continue into the save picker.
	save_entry = true
	entry_start_zoom = 1.06 + 0.014 * sin(elapsed * 0.45)
	entry_start_focus = Vector2(0.5, 0.5) + Vector2(sin(elapsed * 0.48) * 0.011, sin(elapsed * 0.36) * 0.006) + pointer_offset
	background_material.set_shader_parameter("fixed_camera", true)
	set_entry_progress(0.0)

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

func _process(delta: float) -> void:
	if save_entry:return
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
	var agency := _center_label("世界观察局", Rect2(180, 108, 920, 26), 16, Color("dbc69c"))
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
	if save_entry:return ((uv - camera_focus) * camera_zoom + Vector2(0.5, 0.5)) * Vector2(1280, 800)
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
	if not options_shade or options_shade.visible: return
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
