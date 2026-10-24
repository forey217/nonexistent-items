extends CanvasLayer
signal chosen(slot: int)
signal record_deleted(slot: int)
const CARD_DURATION := 0.32
var book: RefCounted
var selected:=1
var cards: Array[Node2D]=[]
var centers: Array[Vector2]=[Vector2(326,502),Vector2(640,526),Vector2(954,502)]
var angles: Array[float]=[-0.105,0.0,0.105]
var root:=Control.new()
var veil:=ColorRect.new()
var background: TextureRect
var fixed_globe_center:=Vector2(640,300)
var caption:=Label.new()
var back_button: Button
var age:=0.0
var motion_enabled:=true
var busy:=false
var pointer:=Vector2(-10000,-10000)
var paper: Texture2D
var thumbnail: Texture2D
var hub_thumbnail: Texture2D
var title:=Label.new()
var delete_dialog: Control
var delete_target:=0
var delete_fade_slot:=0
var delete_fade_age:=0.0
var delete_refreshed:=false
var input_cooldown:=0.0
var notice_age:=0.0

func _ready() -> void:
	layer=55
	root.size=Vector2(1280,800);root.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(root)
	# Transfer the actual painted background node, preserving every material value.
	# The picker only fades in its controls; it never moves or replaces the scene.
	background.reparent(root)
	background.z_index=0
	root.move_child(background,0)
	paper=load("res://assets/save_slots_v39/card.png")
	thumbnail=load("res://assets/save_slots_v39/thumbnail.png")
	hub_thumbnail=load("res://assets/save_slots_v39/hub_thumbnail.png")
	title.text="选择存档";title.position=Vector2(440,35);title.size=Vector2(400,58)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font",preload("res://assets/fonts/zcool_xiaowei/ZCOOLXiaoWei-Regular.ttf"))
	title.add_theme_font_size_override("font_size",40);title.add_theme_color_override("font_color",Color("f1ddb0"))
	title.add_theme_color_override("font_outline_color",Color("203b4a"));title.add_theme_constant_override("outline_size",2)
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
		card.delete_requested.connect(_request_delete.bind(i+1))
	selected=book.last_slot();refresh()
	veil.size=Vector2(1280,800);veil.color=Color("f2e9d4");veil.modulate.a=0
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(veil)
	title.modulate.a=0.0;caption.modulate.a=0.0;back_button.modulate.a=0.0;back_button.disabled=true
	for i in range(cards.size()):
		cards[i].modulate.a=0.0;cards[i].position=centers[i];cards[i].rotation=angles[i]

func ready_for_input() -> bool:
	return not busy and not is_instance_valid(delete_dialog) and delete_fade_slot==0 and input_cooldown<=0 and age>=(CARD_DURATION if motion_enabled else 0.25)

func _request_delete(slot: int) -> void:
	if not ready_for_input() or slot<1 or slot>3:return
	var record: Dictionary=book.inspect(slot)
	if record.status=="empty":return
	delete_target=slot
	delete_dialog=preload("res://scripts/save_delete_dialog.gd").new()
	delete_dialog.slot=slot;delete_dialog.record=record.duplicate(true);delete_dialog.book=book
	delete_dialog.cancelled.connect(_close_delete)
	delete_dialog.confirmed.connect(_confirm_delete)
	root.add_child(delete_dialog)
	get_parent().ambience.play_ui()

func _close_delete() -> void:
	if is_instance_valid(delete_dialog):
		delete_dialog.hide();delete_dialog.set_process_input(false);delete_dialog.queue_free()
	delete_dialog=null;delete_target=0;input_cooldown=0.15

func _confirm_delete() -> void:
	if delete_target<1 or delete_target>3 or not is_instance_valid(delete_dialog):return
	var target:=delete_target
	if not book.delete_record(target):
		delete_dialog.show_failure(book.last_error if not book.last_error.is_empty() else "删除失败，请重试。")
		return
	_close_delete()
	record_deleted.emit(target)
	delete_fade_slot=target;delete_fade_age=0.0;delete_refreshed=false
	caption.text="存档 %02d 已删除"%target;notice_age=3.0

func globe_center() -> Vector2:
	return fixed_globe_center

func refresh() -> void:
	for card in cards:
		card.record=book.inspect(card.index);card.selected=card.index==selected
		card.location=book.location(card.record.data);card.progress=book.progress(card.record.data)
		card.thumbnail=thumbnail if card.record.data.get("scene")=="tutorial" else hub_thumbnail
		card.queue_redraw()

func select(slot: int) -> void:
	if not ready_for_input() or slot<1 or slot>3:return
	selected=slot;refresh()
	get_parent().ambience.play_ui()

func enter() -> void:
	if not ready_for_input():return
	if cards[selected-1].record.status=="damaged":retry("这份记录暂时无法读取，原文件已保留。请选择其他档位。");return
	busy=true;back_button.disabled=true
	get_parent().ambience.play_entry()
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
	busy=false;age=CARD_DURATION;back_button.disabled=false
	veil.modulate.a=0
	for card in cards:card.modulate.a=1;card.scale=Vector2.ONE
	caption.text=message;refresh()

func reveal_scene() -> void:
	for child in root.get_children():
		if child!=veil:child.hide()
	var tween:=create_tween();tween.tween_property(veil,"modulate:a",0.0,0.40)
	await tween.finished

func cancel() -> void:
	if not ready_for_input():return
	busy=true;chosen.emit(0)

func _process(delta: float) -> void:
	age+=delta
	input_cooldown=maxf(0.0,input_cooldown-delta)
	if notice_age>0:
		notice_age=maxf(0.0,notice_age-delta)
		if notice_age==0:caption.text="选择一份记录，继续你的旅程"
	if delete_fade_slot>0:
		delete_fade_age+=delta
		if delete_fade_age>=0.125 and not delete_refreshed:
			refresh();delete_refreshed=true
		if delete_fade_age>=0.25:delete_fade_slot=0
	var ui_age:=age
	var ui_alpha:=smoothstep(0.0,CARD_DURATION if motion_enabled else 0.25,ui_age)
	title.modulate.a=ui_alpha;caption.modulate.a=ui_alpha;back_button.modulate.a=ui_alpha
	back_button.disabled=not ready_for_input()
	if busy:return
	for i in range(cards.size()):
		var card=cards[i]
		card.hovered=ready_for_input() and card.contains(pointer)
		card.delete_hovered=ready_for_input() and card.on_delete(pointer)
		card.delete_button.disabled=not ready_for_input()
		var fade:=1.0
		if card.index==delete_fade_slot:fade=absf(delete_fade_age-0.125)/0.125
		card.modulate.a=ui_alpha*fade;card.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:pointer=event.position
	if is_instance_valid(delete_dialog):return
	if busy:return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		match key:
			KEY_LEFT,KEY_A:select(wrapi(selected-2,0,3)+1)
			KEY_RIGHT,KEY_D:select(wrapi(selected,0,3)+1)
			KEY_ENTER,KEY_SPACE:enter()
			KEY_ESCAPE:cancel()
			KEY_DELETE:_request_delete(selected)
			_:return
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and ready_for_input():
		for i in range(cards.size()-1,-1,-1):
			if cards[i].on_delete(event.position):
				_request_delete(i+1)
				get_viewport().set_input_as_handled();return
			if cards[i].contains(event.position):
				select(i+1)
				enter()
				get_viewport().set_input_as_handled();return
