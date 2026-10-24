extends Control
## Four screen-projected directions; every preview is the actual physics route.
const Instruments=preload("res://scripts/instrument_theme.gd")
const DIRECTIONS:=[Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]
class Arrow:
	extends Button
	var vector:=Vector2.RIGHT
	func _draw() -> void:
		var center:=size*.5
		var color:=Color("d0c093") if not disabled else Color("959c90",.6)
		var tip:=center+vector*12
		draw_line(center-vector*11,tip,color,2,true)
		for side in [-1,1]:draw_line(tip,tip-vector*8+Vector2(-vector.y,vector.x)*side*6,color,2,true)
		if disabled:draw_line(Vector2(12,37),Vector2(37,12),Color("b6a18c",.65),1.2,true)

var room:Node
var selected:=-1
var arrows:Array[Button]=[]
var options:Array[Dictionary]=[]
var hovered:=-1
var origin:=Vector2.ZERO
var center:=Vector2.ZERO
var nameplate:=Panel.new()
var name_label:Label
var detail:=Panel.new()
var detail_label:Label
var refresh_age:=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for p in [nameplate,detail]:
		p.mouse_filter=Control.MOUSE_FILTER_STOP;p.add_theme_stylebox_override("panel",Instruments.style(false,.88,true));add_child(p)
	nameplate.size=Vector2(252,35);detail.size=Vector2(300,64)
	name_label=Instruments.label(nameplate,"",Vector2(10,3),Vector2(232,29),19,Instruments.COPPER_TEXT)
	detail_label=Instruments.label(detail,"",Vector2(10,5),Vector2(280,56),17);detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for i in range(4):
		var index:=i;var b:=Arrow.new();b.size=Vector2(50,50);b.custom_minimum_size=b.size
		Instruments.apply_button(b,18,true,false);add_child(b);arrows.append(b)
		b.pressed.connect(func():choose(index))
		b.mouse_entered.connect(func():hovered=index;queue_redraw())
		b.mouse_exited.connect(func():if hovered==index:hovered=-1;queue_redraw())
	hide()

func open(index:int) -> bool:
	if selected==index and visible:close();return true
	if room.interacting or room.state.has_sliding_weight() or not room.pending.is_empty():return false
	if room.player_layer!=room.state.weights[index].layer or room.view_layer!=room.player_layer:
		room.hud.message("人物在另一层，请先经楼梯前往镇纸所在层。");return false
	room.player.cancel_navigation()
	selected=index;hovered=-1;refresh_age=0;show();refresh_options();_layout();return true

func close() -> void:
	selected=-1;hovered=-1;options.clear();hide();queue_redraw()

func refresh_options() -> void:
	if selected<0:return
	options.clear()
	for i in range(4):
		var option:Dictionary=room.push_preview(selected,DIRECTIONS[i]);options.append(option)
		arrows[i].disabled=not option.valid
		arrows[i].tooltip_text=option.error if not option.valid else "至"+room.hud.station_name(option.destination)

func choose(index:int) -> bool:
	if selected<0:return false
	var id:=selected;var direction:Vector2=DIRECTIONS[index]
	var preview:Dictionary=room.push_preview(id,direction)
	if not preview.valid:room.hud.message(preview.error);refresh_options();return false
	close();return room.request_push(id,direction)

func blocks_map(at:Vector2) -> bool:
	if not visible:return false
	for c in arrows+[nameplate,detail]:
		if c.get_global_rect().has_point(at):return true
	return false

func occupied_rect() -> Rect2:
	if not visible:return Rect2()
	var area:=nameplate.get_global_rect().merge(detail.get_global_rect())
	for b in arrows:area=area.merge(b.get_global_rect())
	return area

func _layout() -> void:
	var w:Dictionary=room.state.weights[selected];var view=room.view
	origin=view.screen(w.pos,w.layer,room.state.weight_height(selected)-(room.State.HEIGHT if w.layer==0 else 0.0)+.25)
	var dimensions:=get_viewport().get_visible_rect().size
	var bottom:float=room.hud.subtitle_panel.position.y-175 if room.story_time>0 else dimensions.y-250
	center=Vector2(clampf(origin.x,188,dimensions.x-188),clampf(origin.y,250,maxf(250,bottom)))
	if room.hud.record.visible and center.x<548:center.x=548
	var actor:Vector2=view.screen(room.player_plan(),room.player_layer,.9)
	var actor_rect:=Rect2(actor-Vector2(38,60),Vector2(76,116))
	var preferred:=center;var chosen:=center;var best_overlap:=INF
	for offset in [Vector2.ZERO,Vector2(-72,0),Vector2(72,0),Vector2(0,-70),Vector2(0,70),Vector2(-72,-70),Vector2(72,-70),Vector2(-72,70),Vector2(72,70)]:
		var candidate:Vector2=preferred+offset
		candidate.x=clampf(candidate.x,548 if room.hud.record.visible else 188,dimensions.x-188)
		candidate.y=clampf(candidate.y,250,maxf(250,bottom))
		var overlap:float=candidate.distance_to(preferred)*.2
		for direction:Vector2 in DIRECTIONS:
			var projected:Vector2=(view.screen(w.pos+direction,w.layer,.4)-view.screen(w.pos,w.layer,.4)).normalized()
			var hit:=Rect2(candidate+projected*82-Vector2(25,25),Vector2(50,50))
			overlap+=hit.intersection(actor_rect).get_area()*5
			overlap+=hit.intersection(Rect2(origin-Vector2(20,24),Vector2(40,48))).get_area()*4
		if overlap<best_overlap:best_overlap=overlap;chosen=candidate
	center=chosen
	for i in range(4):
		var projected:Vector2=(view.screen(w.pos+DIRECTIONS[i],w.layer,.4)-view.screen(w.pos,w.layer,.4)).normalized()
		arrows[i].vector=projected;arrows[i].position=center+projected*82-Vector2(25,25);arrows[i].queue_redraw()
	nameplate.position=center+Vector2(-126,-133);detail.position=center+Vector2(-150,108)
	var safe:=Rect2(20,118,dimensions.x-40,(room.hud.subtitle_panel.position.y-124 if room.story_time>0 else dimensions.y-198))
	var score:=INF;var best:Vector2=detail.position
	for candidate in [center+Vector2(-150,108),center+Vector2(-150,-219),center+Vector2(128,-28),center+Vector2(-428,-28)]:
		var box:=Rect2(candidate,detail.size)
		if not safe.encloses(box):continue
		var overlap:float=box.intersection(actor_rect).get_area()*5
		for b in arrows:overlap+=box.intersection(b.get_global_rect()).get_area()
		if room.hud.record.visible:overlap+=box.intersection(room.hud.record.get_global_rect()).get_area()*3
		if overlap<score:score=overlap;best=candidate
	detail.position=best
	name_label.text=("山纹镇纸" if selected==0 else "水纹镇纸")+" · 选择方向"
	if hovered>=0 and hovered<options.size():
		var option:Dictionary=options[hovered]
		detail_label.text=option.error if not option.valid else "至"+room.hud.station_name(option.destination)+(" · "+option.blocked_reason if not option.blocked_reason.is_empty() else "\n左键推动，普通连接点连续通过")
	else:detail_label.text="左键选择箭头推动\n右键空白或 Esc 取消"

func _process(delta:float) -> void:
	if not visible:return
	if room.hud.menu.visible or room.arrival_busy() or room.state.has_sliding_weight() or room.player_layer!=room.view_layer or room.state.weights[selected].layer!=room.player_layer:close();return
	refresh_age-=delta
	if refresh_age<=0:refresh_age=.2;refresh_options()
	_layout();queue_redraw()

func _draw() -> void:
	if not visible or selected<0:return
	if center.distance_to(origin)>26:draw_dashed_line(origin,center,Color("b39a69",.55),1,5,true)
	if hovered<0 or hovered>=options.size() or not options[hovered].valid:return
	var w:Dictionary=room.state.weights[selected];var at:Vector2=w.pos
	var color:=Color("c7b580",.86)
	for point:Vector2 in options[hovered].points:
		var a:Vector2=room.view.screen(at,w.layer,.16);var b:Vector2=room.view.screen(point,w.layer,.16)
		draw_dashed_line(a,b,color,2,7,true);at=point
	var end:Vector2=room.view.screen(at,w.layer,.16)
	draw_polyline(PackedVector2Array([end+Vector2(0,-8),end+Vector2(8,0),end+Vector2(0,8),end+Vector2(-8,0),end+Vector2(0,-8)]),color,2,true)
