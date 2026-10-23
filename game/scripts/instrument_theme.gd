extends RefCounted
## Shared, engine-drawn instruments for in-world HUDs.
const INK=Color("353d3a")
const DEEP=Color("29332e")
const TEXT=Color("e7e2d4")
const GOLD=Color("b39a69")
const COPPER_TEXT=Color("d0bb8d")
const MUTED=Color("adb8ae")
const BLUE=Color("c2d3bd")
const Glass=preload("res://scripts/instrument_glass.gd")
const SERIF=preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf")
const TITLE=preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf")

static func body() -> FontVariation:
	var font:=FontVariation.new();font.base_font=SERIF;font.variation_embolden=.2;return font

static func style(active:=false,opacity:=.86,mill:=false) -> StyleBox:
	var s:=Glass.new();s.active=active;s.opacity=opacity;s.mill=mill
	s.content_margin_left=12;s.content_margin_right=12;s.content_margin_top=6;s.content_margin_bottom=6
	return s

static func state_style(selected:=false,hover:=false) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=Color("91a091")*Color(1,1,1,.14 if hover else .075 if selected else 0)
	s.border_color=GOLD;s.border_width_bottom=1 if selected else 0
	s.content_margin_left=8;s.content_margin_right=8;s.content_margin_top=4;s.content_margin_bottom=4
	return s

static func focus_style() -> StyleBoxFlat:
	var focus:=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=Color(GOLD,.95)
	focus.border_width_left=1;focus.border_width_bottom=1
	focus.expand_margin_left=-2;focus.expand_margin_right=-2;focus.expand_margin_top=-2;focus.expand_margin_bottom=-2
	return focus

static func apply_button(b:Button,points:=20,mill:=false,grouped:=false) -> void:
	b.focus_mode=Control.FOCUS_ALL;b.mouse_force_pass_scroll_events=false
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font",body());b.add_theme_font_size_override("font_size",points)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(key,TEXT)
	b.add_theme_color_override("font_disabled_color",Color("8d9a90"))
	b.add_theme_stylebox_override("normal",StyleBoxEmpty.new() if grouped else style(false,.86,mill))
	b.add_theme_stylebox_override("disabled",StyleBoxEmpty.new() if grouped else style(false,.81,mill))
	b.add_theme_stylebox_override("hover",state_style(false,true) if grouped else style(true,.90,mill))
	b.add_theme_stylebox_override("pressed",state_style(true,true) if grouped else style(true,.94,mill))
	b.add_theme_stylebox_override("focus",focus_style())

static func label(parent:Node,text:String,at:Vector2,dimensions:Vector2,points:=18,color:=TEXT) -> Label:
	var n:=Label.new();n.text=text;n.position=at;n.size=dimensions;n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	n.add_theme_font_override("font",body());n.add_theme_font_size_override("font_size",points);n.add_theme_color_override("font_color",color)
	parent.add_child(n);return n

static func caption_pages(text:String,width:float,points:int) -> Array[String]:
	var pages:Array[String]=[];var page:="";var font:=body()
	# Shape with the same real font as the controls, including punctuation and newlines.
	for character in text:
		var paragraph:=TextParagraph.new();paragraph.width=width-8
		paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
		paragraph.add_string(page+character,font,points)
		if not page.is_empty() and paragraph.get_line_count()>2:
			pages.append(page);page=""
		page+=character
	if not page.is_empty():pages.append(page)
	return pages

static func caption_display(page:String,width:float,points:int) -> String:
	var text:=page.strip_edges()
	if text.contains("\n"):return text
	var font:=body();var paragraph:=TextParagraph.new();paragraph.width=width-8;paragraph.add_string(text,font,points)
	paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
	if paragraph.get_line_count()!=2:return text
	var last:=paragraph.get_line_range(1)
	if last.y-last.x>=6:return text
	# A sentence should not leave just one or two characters stranded on line two.
	var cut:=-1;var difference:=INF
	for i in range(8,text.length()-6):
		if not text[i-1] in "。，；！？":continue
		var left:=font.get_string_size(text.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,points).x
		var right:=font.get_string_size(text.substr(i),HORIZONTAL_ALIGNMENT_LEFT,-1,points).x
		if maxf(left,right)<=width-8 and absf(left-right)<difference:cut=i;difference=absf(left-right)
	return text.left(cut)+"\n"+text.substr(cut) if cut>0 else text
