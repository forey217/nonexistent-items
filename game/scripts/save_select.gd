extends CanvasLayer
signal chosen(slot: int)
var book: RefCounted
var selected:=1
var cards: Array[Node2D]=[]
var centers: Array[Vector2]=[Vector2(326,502),Vector2(640,526),Vector2(954,502)]
var angles: Array[float]=[-0.105,0.0,0.105]
var root:=Control.new()
var veil:=ColorRect.new()
var background:=TextureRect.new()
var caption:=Label.new()
var back_button: Button
var age:=0.0
var clock:=0.0
var motion_enabled:=true
var busy:=false
var pointer:=Vector2(-10000,-10000)
var approach_from:=Vector2(640,340)
var paper: Texture2D
var thumbnail: Texture2D
var hub_thumbnail: Texture2D
var star_ink:=Node2D.new()

func _ready() -> void:
	layer=55
	root.size=Vector2(1280,800);root.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(root)
	background.texture=load("res://assets/save_slots_v39/background.png")
	background.size=Vector2(1280,800);background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_SCALE;background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	root.add_child(star_ink);star_ink.draw.connect(_draw_globe)
	paper=load("res://assets/save_slots_v39/card.png")
	thumbnail=load("res://assets/save_slots_v39/thumbnail.png")
	hub_thumbnail=load("res://assets/save_slots_v39/hub_thumbnail.png")
	var title:=Label.new();title.text="选择存档";title.position=Vector2(440,35);title.size=Vector2(400,58)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font",preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf"))
	title.add_theme_font_size_override("font_size",40);title.add_theme_color_override("font_color",Color("f1ddb0"))
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(title)
	var ui=preload("res://scripts/tutorial_hud.gd").new()
	back_button=ui.button(root,"返回   Esc",Vector2(30,26),Vector2(140,34));back_button.pressed.connect(cancel)
	back_button.add_theme_font_size_override("font_size",16);ui.free()
	caption.text="选择一份记录，继续你的旅程"
	caption.position=Vector2(280,750);caption.size=Vector2(720,30)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",preload("res://assets/fonts/source_han_serif/SourceHanSerifCN-Regular.otf"))
	caption.add_theme_font_size_override("font_size",18);caption.add_theme_color_override("font_color",Color("f0dbb0"))
	caption.add_theme_color_override("font_outline_color",Color("203b4a"));caption.add_theme_constant_override("outline_size",2)
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(caption)
	for i in range(3):
		var card:=preload("res://scripts/save_record_card.gd").new()
		card.index=i+1;card.paper=paper;card.thumbnail=thumbnail;root.add_child(card);cards.append(card)
	selected=book.last_slot();refresh()
	veil.size=Vector2(1280,800);veil.color=Color("f2e9d4");veil.modulate.a=0
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(veil)
	root.modulate.a=0.0

func refresh() -> void:
	for card in cards:
		card.record=book.inspect(card.index);card.selected=card.index==selected
		card.location=book.location(card.record.data);card.progress=book.progress(card.record.data)
		card.thumbnail=thumbnail if card.record.data.get("scene")=="tutorial" else hub_thumbnail
		card.queue_redraw()

func select(slot: int) -> void:
	if busy or slot<1 or slot>3:return
	selected=slot;refresh()
	get_parent().ambience.play_ui()

func enter() -> void:
	if busy or age<0.65:return
	if cards[selected-1].record.status=="damaged":retry("这份记录暂时无法读取，原文件已保留。请选择其他档位。");return
	busy=true;back_button.disabled=true
	get_parent().ambience.play_world_gate("fold")
	var tween:=create_tween().set_parallel(true)
	for i in range(3):
		if i+1==selected and motion_enabled:
			tween.tween_property(cards[i],"position",Vector2(640,375),0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.tween_property(cards[i],"scale",Vector2.ONE*0.25,0.42)
			tween.tween_property(cards[i],"rotation",-0.20,0.42)
		tween.tween_property(cards[i],"modulate:a",0.0,0.42)
	tween.tween_property(veil,"modulate:a",1.0,0.42)
	await tween.finished;chosen.emit(selected)

func retry(message: String) -> void:
	busy=false;age=0;back_button.disabled=false
	veil.modulate.a=0
	for card in cards:card.modulate.a=1;card.scale=Vector2.ONE
	caption.text=message;refresh()

func reveal_scene() -> void:
	for child in root.get_children():
		if child!=veil:child.hide()
	var tween:=create_tween();tween.tween_property(veil,"modulate:a",0.0,0.40)
	await tween.finished

func cancel() -> void:
	if busy:return
	busy=true;chosen.emit(0)

func _process(delta: float) -> void:
	age+=delta
	if motion_enabled:clock+=delta
	star_ink.queue_redraw()
	root.modulate.a=minf(1.0,age/0.25)
	var approach:=smoothstep(0.0,0.55,age) if motion_enabled else 1.0
	background.scale=Vector2.ONE*lerpf(0.68,1.0,approach)
	background.position=(approach_from-Vector2(640,340)*0.68).lerp(Vector2.ZERO,approach)
	if busy:return
	for i in range(cards.size()):
		var card=cards[i]
		card.hovered=card.contains(pointer)
		var progress:=smoothstep(0.0,0.60,age-i*0.08) if motion_enabled else 1.0
		var lift: float=5.0 if card.hovered else 0.0
		var float_y:=sin(clock*1.1+i*0.7)*1.3 if motion_enabled else 0.0
		card.position=Vector2(640,630).lerp(centers[i]+Vector2(0,-lift+float_y),progress)
		card.rotation=lerpf(angles[i]*2.0,angles[i]*(0.60 if card.hovered else 1.0),progress)
		card.modulate.a=progress;card.queue_redraw()

func _draw_globe() -> void:
	if not motion_enabled:return
	for i in range(8):
		var at:=Vector2(640,340)+Vector2(cos(i*2.3)*110,sin(i*3.1)*106)
		var alpha: float=0.12+0.20*maxf(0.0,sin(clock*1.4+i))
		star_ink.draw_circle(at,1.4,Color(0.78,0.93,1.0,alpha))
	if busy:star_ink.draw_arc(Vector2(640,340),134,clock,clock+PI*0.8,64,Color(0.52,0.85,1,0.35),1.5,true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:pointer=event.position
	if busy:return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		match key:
			KEY_LEFT,KEY_A:select(wrapi(selected-2,0,3)+1)
			KEY_RIGHT,KEY_D:select(wrapi(selected,0,3)+1)
			KEY_ENTER,KEY_SPACE:enter()
			KEY_ESCAPE:cancel()
			_:return
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and age>=0.65:
		for i in range(cards.size()-1,-1,-1):
			if cards[i].contains(event.position):
				var action: bool=cards[i].on_action(event.position)
				select(i+1)
				if action:enter()
				get_viewport().set_input_as_handled();return
