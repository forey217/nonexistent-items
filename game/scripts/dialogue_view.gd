extends CanvasLayer
signal advanced
signal skipped
const DISPLAY_FONT = preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf")
const SUBTITLE_FONT = preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf")
const YANYUE = preload("res://assets/dialogue_v31/yanyue_portrait.png")
const TESLA = preload("res://assets/npc/tesla_v01.png")
var root: Control
var shade: ColorRect
var paper: Control
var portrait: TextureRect
var name_label: Label
var body: Label
var caption: Label
var subtitle: RichTextLabel
var subtitle_avatar=preload("res://scripts/dialogue_chibi.gd").new()
var subtitle_dark_background:=false
var subtitle_font := FontVariation.new()
var subtitle_name_font := FontVariation.new()
var next_button: Button
var skip_button: Button
var body_font := SystemFont.new()
var mode := ""
var shown_text := ""
var age := 0.0
var reveal := 0.0
var modal := false
var item_exhibit: Control
var pending_exhibit := ""
var exhibit_character := -1
var world_overlap: Control
var pending_visual := ""
var visual_character := 0

func _ready() -> void:
	layer=35
	body_font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","Arial"])
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	shade=ColorRect.new();shade.size=Vector2(1280,800);shade.color=Color(0.04,0.08,0.12,0.25)
	shade.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(shade)
	world_overlap=preload("res://scripts/dialogue_world_overlap.gd").new();root.add_child(world_overlap)
	item_exhibit=preload("res://scripts/dialogue_item_exhibit.gd").new();root.add_child(item_exhibit)
	paper=preload("res://scripts/dialogue_panel.gd").new();root.add_child(paper)
	portrait=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(portrait)
	name_label=_label(28,DISPLAY_FONT,Color("253e50"));root.add_child(name_label)
	body=_label(26,DISPLAY_FONT,Color("253e50"));body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_constant_override("line_spacing",5);root.add_child(body)
	caption=_label(13,body_font,Color("8c7758"));root.add_child(caption)
	subtitle_font.base_font=SUBTITLE_FONT
	subtitle_font.variation_embolden=0.12
	subtitle_font.spacing_glyph=1;subtitle_font.spacing_top=-1;subtitle_font.spacing_bottom=-1
	subtitle_name_font.base_font=SUBTITLE_FONT
	subtitle_name_font.spacing_glyph=1;subtitle_name_font.spacing_top=-1;subtitle_name_font.spacing_bottom=-1
	subtitle_name_font.variation_embolden=0.12
	subtitle=RichTextLabel.new();subtitle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	subtitle.bbcode_enabled=true;subtitle.scroll_active=false;subtitle.selection_enabled=false
	subtitle.add_theme_font_override("normal_font",subtitle_font)
	subtitle.add_theme_font_override("bold_font",subtitle_name_font)
	subtitle.add_theme_font_size_override("normal_font_size",26)
	subtitle.add_theme_font_size_override("bold_font_size",26)
	subtitle.add_theme_color_override("default_color",Color("203b4a"))
	subtitle.add_theme_color_override("font_outline_color",Color("faf6eb"))
	subtitle.add_theme_constant_override("outline_size",1)
	subtitle.add_theme_color_override("font_shadow_color",Color(0.04,0.09,0.14,0.12))
	subtitle.add_theme_constant_override("shadow_offset_x",0)
	subtitle.add_theme_constant_override("shadow_offset_y",1)
	subtitle.add_theme_constant_override("shadow_outline_size",1)
	subtitle.add_theme_constant_override("line_separation",1)
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	subtitle.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle.position=Vector2(370,711);subtitle.size=Vector2(858,78);root.add_child(subtitle)
	subtitle_avatar.position=Vector2(292,718);root.add_child(subtitle_avatar)
	next_button=_button("继续  /  空格",Vector2(1020,724),Vector2(158,35));next_button.pressed.connect(advance)
	skip_button=_button("跳过本段  Esc",Vector2(1080,548),Vector2(152,32));skip_button.pressed.connect(func():skipped.emit())
	clear()

func _label(points: int,font: Font,color: Color) -> Label:
	var item:=Label.new();item.mouse_filter=Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_override("font",font);item.add_theme_font_size_override("font_size",points)
	item.add_theme_color_override("font_color",color)
	return item

func _button(text: String,at: Vector2,dimensions: Vector2) -> Button:
	var item:=Button.new();item.text=text;item.position=at;item.size=dimensions;item.focus_mode=Control.FOCUS_NONE
	item.add_theme_font_override("font",body_font);item.add_theme_font_size_override("font_size",14)
	item.add_theme_color_override("font_color",Color("536b79"))
	var normal:=StyleBoxFlat.new();normal.bg_color=Color("f5f1e7");normal.border_color=Color("c6b58f")
	normal.set_border_width_all(1);normal.set_corner_radius_all(3)
	item.add_theme_stylebox_override("normal",normal)
	var hover:=normal.duplicate();hover.bg_color=Color("e1eceb")
	item.add_theme_stylebox_override("hover",hover);root.add_child(item)
	return item

func clear() -> void:
	pending_visual="";world_overlap.hide_demo()
	pending_exhibit="";exhibit_character=-1;item_exhibit.hide_item()
	mode="";modal=false;root.hide()
	subtitle_avatar.hide()

func set_subtitle_background(dark: bool) -> void:
	subtitle_dark_background=dark
	layer=60 if dark else 35
	subtitle.add_theme_color_override("default_color",Color("f5f1e6") if dark else Color("203b4a"))
	subtitle.add_theme_color_override("font_outline_color",Color("173447") if dark else Color("faf6eb"))

func present(speaker: String,text: String,kind: String="subtitle",cue: String="",exhibit: String="",visual: String="") -> void:
	pending_visual=visual if kind=="story" else ""
	visual_character=text.find("平行世界")+4 if text.contains("平行世界") else 0
	if pending_visual!="overlap":world_overlap.hide_demo()
	item_exhibit.hide_item()
	pending_exhibit=exhibit if kind=="story" else ""
	exhibit_character=text.find("镇纸")+2 if not pending_exhibit.is_empty() else -1
	mode=kind;modal=kind=="story";age=0;reveal=0;shown_text=text
	root.show();shade.visible=modal
	for node in [paper,portrait,name_label,body,caption]:node.visible=kind!="subtitle"
	subtitle.visible=kind=="subtitle";next_button.visible=modal;skip_button.visible=modal
	subtitle_avatar.visible=kind=="subtitle"
	var heroine := speaker=="yanyue"
	var who := "衍月" if heroine else "特斯拉"
	if kind=="subtitle":
		subtitle_avatar.set_speaker(speaker)
		subtitle.text=text.replace("[","[lb]")
		return
	paper.speaker=speaker;paper.kind=kind
	var atlas:=AtlasTexture.new()
	atlas.atlas=YANYUE if heroine else TESLA
	# Runtime regions only; keep original illustrations intact.
	atlas.region=Rect2(155,0,900,1300) if heroine else Rect2(200,0,750,850)
	if not modal:atlas.region=Rect2(225,30,720,720) if heroine else Rect2(340,0,570,550)
	portrait.texture=atlas
	name_label.text=who+("  ·  观测通讯" if not heroine and kind=="light" else "")
	body.text=text;body.visible_characters=0 if modal else -1
	if modal:
		next_button.position=Vector2(1020 if heroine else 84,724)
		skip_button.position=Vector2(1080 if heroine else 736,548)
		paper.position=Vector2(48,590);paper.size=Vector2(1184,174)
		portrait.position=Vector2(59 if heroine else 903,354);portrait.size=Vector2(318,410)
		var x:=390.0 if heroine else 84.0
		name_label.position=Vector2(x,600);name_label.size=Vector2(720,39)
		name_label.add_theme_font_size_override("font_size",29)
		body.position=Vector2(x,648);body.size=Vector2(780 if heroine else 810,73)
		body.add_theme_font_override("font",DISPLAY_FONT);body.add_theme_font_size_override("font_size",26)
		body.add_theme_constant_override("line_spacing",5)
		caption.position=Vector2(x,556);caption.size=Vector2(650,25)
		caption.text="世界检查局  /  接待记录                 左键、空格或回车继续"
	else:
		var compact:=kind=="aside"
		paper.position=Vector2(398 if compact else 292,707)
		paper.size=Vector2(830 if compact else 936,88)
		portrait.position=Vector2(paper.position.x+9 if heroine else 1139,709)
		portrait.size=Vector2(80,80)
		var x:float=paper.position.x+(106 if heroine else 25)
		name_label.position=Vector2(x,710);name_label.size=Vector2(700,27)
		name_label.add_theme_font_size_override("font_size",19)
		body.position=Vector2(x,734);body.size=Vector2(paper.size.x-139,60)
		body.add_theme_font_override("font",body_font);body.add_theme_font_size_override("font_size",22)
		body.add_theme_constant_override("line_spacing",1)
		caption.visible=false
		if not cue.is_empty():name_label.text+="     [ "+cue+" ]"
	paper.queue_redraw()

func _process(delta: float) -> void:
	if mode.is_empty():return
	age+=delta
	if modal and body.visible_characters>=0:
		reveal+=delta*42.0
		body.visible_characters=mini(int(reveal),shown_text.length())
		if body.visible_characters>=shown_text.length():body.visible_characters=-1
	_sync_exhibit()
	_sync_visual()

func _sync_visual() -> void:
	if pending_visual!="overlap" or not modal:return
	if body.visible_characters<0 or body.visible_characters>=visual_character:world_overlap.show_demo()

func _sync_exhibit() -> void:
	if pending_exhibit.is_empty() or not modal:return
	if body.visible_characters<0 or body.visible_characters>=exhibit_character:
		item_exhibit.show_item(pending_exhibit)

func advance() -> void:
	if not modal or age<0.12:return
	if body.visible_characters>=0:
		body.visible_characters=-1
		_sync_exhibit()
		_sync_visual()
	else:advanced.emit()

func _input(event: InputEvent) -> void:
	if not modal:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE,KEY_ENTER,KEY_E]:
			advance();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_ESCAPE:
			skipped.emit();get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if not next_button.get_global_rect().has_point(event.position) and not skip_button.get_global_rect().has_point(event.position):
			advance();get_viewport().set_input_as_handled()
