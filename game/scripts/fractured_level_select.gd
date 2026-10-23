extends "res://scripts/level_select.gd"
enum Phase { CLOSED, OPENING, EXPANDED, ENTERING }
const OPEN_TIME=1.0
const COMMIT_TIME=2.18
const FINISH_TIME=2.40
var phase:int=Phase.CLOSED
var opening_age:=-1.0
var hover_amount:=0.0
var pointer:=Vector2(-10000,-10000)
var shards:Array[Node2D]=[]
var whole:=PackedVector2Array([Vector2(0,-170),Vector2(49,-124),Vector2(98,-78),Vector2(98,4),Vector2(98,85),Vector2(49,127),Vector2(0,170),Vector2(-49,127),Vector2(-98,85),Vector2(-98,4),Vector2(-98,-78),Vector2(-49,-124)])
var spread:Array[Vector2]=[Vector2(972,370),Vector2(842,590),Vector2(470,590),Vector2(318,390),Vector2(475,221),Vector2(795,221)]
var spread_scale:Array[float]=[1.80,1.70,1.45,1.50,1.48,1.43]
var spread_angle:Array[float]=[-0.15,0.10,-0.22,0.17,-0.12,0.20]
var selected:=-1
var paper_unlocked:=false
var selected_origin:=Vector2.ZERO
var start_rotations:Array[float]=[]
var white_veil:ColorRect
var glass_renderer:Node2D
var accents:=Node2D.new()
var agency:Label
var expanded_age:=0.0

func _ready() -> void:
	super._ready()
	enter_button.hide();enter_button.disabled=true
	heading.text="世界坐标档案"
	heading.position=Vector2(360,59);heading.add_theme_font_size_override("font_size",36)
	heading.add_theme_color_override("font_color",Color("f7edd6"))
	subtitle.text="";subtitle.position.y=112
	subtitle.add_theme_color_override("font_color",Color("d3e2e3"))
	agency=Label.new();agency.text="世 界 观 察 局"
	agency.position=Vector2(490,29);agency.size=Vector2(300,25)
	agency.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	agency.add_theme_font_override("font",TITLE);agency.add_theme_font_size_override("font_size",15)
	agency.add_theme_color_override("font_color",Color("d2bc8b"));root.add_child(agency)
	close_button.text="返回接待室  Esc";close_button.size=Vector2(172,36)
	clock_material.shader=preload("res://shaders/cosmic_panorama.gdshader")
	clock_material.set_shader_parameter("panorama",preload("res://assets/observatory_v45/sealed_observatory.png"))
	glass_renderer=preload("res://scripts/star_glass_renderer.gd").new();art.add_child(glass_renderer)
	var seam:=Vector2(0,0)
	var cuts:=PackedVector2Array()
	for i in range(6):
		var anchor:Vector2=whole[i*2]
		cuts.append(anchor.lerp(seam,0.52)+(seam-anchor).normalized().orthogonal()*[3.0,-3.0,3.0,-3.0,3.0,-3.0][i])
	for i in range(6):
		var next:=(i+1)%6
		var polygon:=PackedVector2Array([whole[i*2],whole[i*2+1],whole[(i*2+2)%12],cuts[next],seam,cuts[i]])
		var shard=preload("res://scripts/level_crystal_shard.gd").new()
		shard.configure(polygon,PackedVector2Array([whole[i*2],whole[i*2+1],whole[(i*2+2)%12]]),i==0 or (i==1 and paper_unlocked))
		if i==1:
			shard.level_number="02";shard.level_name="纸山叠影"
		art.add_child(shard);shards.append(shard);shard.attach_renderer(glass_renderer)
	art.add_child(accents);accents.draw.connect(_draw_glass_accents)
	white_veil=ColorRect.new()
	white_veil.size=Vector2(1280,800);white_veil.color=Color("f3fff6")
	white_veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;white_veil.modulate.a=0
	white_veil.z_index=100;root.add_child(white_veil)
	_update_shards(0.0)

func core_transform() -> Transform2D:
	var transform:=Transform2D(sin(age*0.20)*0.012,CENTER+Vector2(0,40+sin(age*1.1)*4-hover_amount*5))
	return transform.scaled_local(Vector2(1.06,1.12))

func core_hit(at:Vector2) -> bool:
	return shards.any(func(shard):return shard.hit_test(at))

func shard_at(at:Vector2) -> int:
	for i in range(shards.size()-1,-1,-1):
		if shards[i].hit_test(at):return i
	return -1

func expand_crystal() -> void:
	if phase!=Phase.CLOSED:return
	phase=Phase.OPENING;opening_age=0.0
	subtitle.text="";expanded_age=0
	cue.emit("fold")

func select_level() -> void:
	# Keyboard and automation use the same two steps as mouse input.
	if phase==Phase.CLOSED:expand_crystal()
	elif phase==Phase.EXPANDED:choose_shard(0)

func choose_shard(index:int) -> void:
	if phase!=Phase.EXPANDED:return
	if index<0 or index>=shards.size():return
	if index!=0 and not (index==1 and paper_unlocked):
		shards[index].lock_pulse=1.0
		return
	selected=index;selected_origin=shards[index].position
	heading.text="世界正在汇聚"
	subtitle.text="建立通往"+("纸山叠影" if index==1 else "新手校准室")+"的裂隙…"
	phase=Phase.ENTERING;selection_age=0.0
	rift_starts.clear();start_rotations.clear()
	for shard in shards:
		rift_starts.append(shard.position);start_rotations.append(shard.rotation)
	close_button.disabled=true;close_button.hide()
	cue.emit("fold")

func _input(event:InputEvent) -> void:
	if event is InputEventMouse:pointer=event.position
	if event is InputEventKey and (event.physical_keycode==KEY_M or event.keycode==KEY_M):return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE or event.keycode==KEY_ESCAPE:close()
		elif event.physical_keycode in [KEY_ENTER,KEY_SPACE] or event.keycode in [KEY_ENTER,KEY_SPACE]:select_level()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if phase==Phase.CLOSED and core_hit(event.position):expand_crystal();get_viewport().set_input_as_handled()
		elif phase==Phase.EXPANDED:
			var index:=shard_at(event.position)
			if index>=0:choose_shard(index);get_viewport().set_input_as_handled()
	if event is InputEventKey:get_viewport().set_input_as_handled()

func rift_position(index:int) -> Vector2:
	return spread[index]+Vector2(sin(age*0.32+index)*4,cos(age*0.38+index)*5)

func focus_at(time:float) -> Vector2:
	return selected_origin.lerp(CENTER,smoothstep(0.0,0.75,time))

func travel_progress(index:int,time:float) -> float:
	return clampf((time-0.10-index*0.035)/1.16,0,1)

func flight_position(index:int,time:float) -> Vector2:
	if index==selected:return focus_at(time)
	var t:=travel_progress(index,time)
	var offset:=rift_starts[index]-selected_origin
	return focus_at(time)+offset.rotated(-t*TAU*0.93)*pow(1.0-t,0.90)

func _update_shards(delta:float) -> void:
	var transform:=core_transform()
	var p:=clampf(opening_age/OPEN_TIME,0,1) if opening_age>=0 else 0.0
	var out:=1.0-pow(1.0-p,3.0)
	var reveal:=smoothstep(0.42,0.90,p)
	var over:int=shard_at(pointer) if phase==Phase.EXPANDED else -1
	for i in range(shards.size()):
		var shard:Node2D=shards[i]
		shard.lock_pulse=move_toward(shard.lock_pulse,0.0,delta*2.4)
		if phase!=Phase.ENTERING:
			var separation:Vector2=shard.source_center.normalized()*hover_amount*1.2
			var joined:Vector2=transform*(shard.source_center+separation)
			var destination:=rift_position(i)
			var direction:Vector2=(destination-CENTER).normalized()
			shard.position=joined.lerp(destination,out)+direction*sin(p*PI)*16.0
			shard.rotation=lerpf(transform.get_rotation(),spread_angle[i],out)
			shard.scale=transform.get_scale().lerp(Vector2.ONE*spread_scale[i],out)
			shard.modulate.a=1.0
			shard.update_look(age,0.0,reveal,1.0 if over==i else 0.0,hover_amount*(1.0-out),out)
		else:
			var t:=travel_progress(i,selection_age)
			shard.position=flight_position(i,selection_age)
			shard.rotation=start_rotations[i]-t*TAU*0.88 if i!=selected else lerpf(start_rotations[i],0,smoothstep(0.0,0.45,selection_age))+smoothstep(0.9,2.15,selection_age)*0.75
			shard.scale=Vector2.ONE*spread_scale[i]*(1.0-t*0.80 if i!=selected else 1.0)
			shard.modulate.a=1.0-smoothstep(0.86,1.0,t) if i!=selected else 1.0
			shard.update_look(age,smoothstep(1.40,2.15,selection_age) if i==selected else t*0.5,1.0 if i==selected else 1.0-smoothstep(0.1,0.55,selection_age),0,0,1.0)

func _process(delta:float) -> void:
	age+=delta
	if phase==Phase.EXPANDED:
		expanded_age+=delta
		subtitle.text="选择亮起的世界碎片" if expanded_age<3.0 else ""
		subtitle.modulate.a=1.0-smoothstep(2.0,3.0,expanded_age)
	if phase==Phase.OPENING:
		opening_age+=delta
		if opening_age>=OPEN_TIME:opening_age=OPEN_TIME;phase=Phase.EXPANDED
	if phase==Phase.ENTERING:selection_age+=delta
	hovered=core_hit(pointer) if phase==Phase.CLOSED else false
	hover_amount=move_toward(hover_amount,1.0 if hovered else 0.0,delta*5.0)
	_update_shards(delta)
	var over:int=shard_at(pointer) if phase==Phase.EXPANDED else -1
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered or over==0 or (over==1 and paper_unlocked) else Input.CURSOR_ARROW)
	clock_material.set_shader_parameter("clock",age)
	if phase==Phase.ENTERING:
		var zoom:=1.0+pow(clampf((selection_age-1.40)/0.77,0,1),2.6)*24.0
		var roll:=-smoothstep(0.95,2.17,selection_age)*0.42
		var camera:=Transform2D(roll,Vector2.ZERO).scaled_local(Vector2.ONE*zoom)
		var focus:=focus_at(selection_age)
		camera.origin=focus-camera.basis_xform(focus)
		art.transform=camera
		clock_material.set_shader_parameter("camera_roll",roll*0.7)
		clock_material.set_shader_parameter("convergence",smoothstep(0.15,2.4,selection_age))
		heading.modulate.a=1.0-smoothstep(0.05,0.30,selection_age);subtitle.modulate.a=heading.modulate.a;agency.modulate.a=heading.modulate.a
		if selection_age>=COMMIT_TIME and not committed:
			committed=true;sky.hide();art.hide();heading.hide();subtitle.hide();agency.hide();glass_renderer.shutdown()
			level_committed.emit();cue.emit("arrived")
		white_veil.modulate.a=smoothstep(1.98,COMMIT_TIME,selection_age)*(1.0-smoothstep(2.20,FINISH_TIME,selection_age))
		if selection_age>=FINISH_TIME:set_process(false);finished.emit()
	art.queue_redraw();accents.queue_redraw()

func _draw_trail(index:int) -> void:
	var p:=travel_progress(index,selection_age)
	if index==selected or p<0.001 or p>0.997:return
	var points:=PackedVector2Array()
	var glow:=PackedColorArray()
	var line:=PackedColorArray()
	for j in range(42):
		var fraction:=j/41.0
		var time:=selection_age-(1.0-fraction)*0.50
		if travel_progress(index,time)<0.001:continue
		points.append(flight_position(index,time))
		var fade:=pow(fraction,1.7)*(1.0-smoothstep(0.9,1.0,p))
		glow.append(Color(0.51,0.83,0.91,fade*0.14))
		line.append(Color(0.78,0.96,0.94,fade*0.85))
	if points.size()<2:return
	art.draw_polyline_colors(points,glow,27.0,true)
	art.draw_polyline_colors(points,line,2.8,true)
	var gold:=PackedVector2Array()
	for point in points:gold.append(point+Vector2(2,-1))
	art.draw_polyline(gold,Color(0.93,0.79,0.48,0.38*(1.0-p)),0.8,true)
	for j in range(4):
		var time:=selection_age-j*0.065
		if travel_progress(index,time)>0:
			art.draw_circle(flight_position(index,time),1.5,Color(0.85,0.95,1.0,(1.0-j/4.0)*(1.0-p)),true,-1,true)

func _draw_glass_accents() -> void:
	if committed:return
	for shard in shards:
		var outline:PackedVector2Array=shard.front_projected
		if outline.size()<6:continue
		var fade:float=shard.modulate.a
		# One polished exterior lip per petal; the split seams are hover-only at rest.
		var rim:=PackedVector2Array([outline[0],outline[1],outline[2]])
		accents.draw_polyline(rim,Color(0.78,0.94,0.93,0.53*fade),1.0,true)
		var cracking:float=hover_amount if phase==Phase.CLOSED else (1.0 if phase==Phase.OPENING else shard.hovered*0.55+0.12)
		var seam:=PackedVector2Array([outline[2],outline[3],outline[4],outline[5],outline[0]])
		if cracking>0.01:
			accents.draw_polyline(seam,Color(0.51,0.89,1.0,0.065*cracking*fade),6.0,true)
			accents.draw_polyline(seam,Color(0.78,0.95,1.0,0.64*cracking*fade),0.9,true)
		if phase==Phase.EXPANDED and shard.hovered>0.05:
			var center:Vector2=shard.position
			var text:String=(shard.level_number+" · "+shard.level_name) if shard.available else "坐标尚未解锁"
			var size:=18 if shard.available else 15
			var width:float=TITLE.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
			var at:=Vector2(clampf(center.x-width*0.5,240,1040-width),center.y+100)
			var plate:=Rect2(at+Vector2(-14,-23),Vector2(width+28,33))
			accents.draw_style_box(_caption_style(),plate)
			accents.draw_string(TITLE,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0.97,0.92,0.79,shard.hovered))

var caption_style:StyleBoxFlat
func _caption_style() -> StyleBoxFlat:
	if caption_style==null:
		caption_style=StyleBoxFlat.new();caption_style.bg_color=Color(0.025,0.085,0.13,0.90)
		caption_style.border_color=Color(0.64,0.54,0.33,0.65)
		caption_style.set_border_width_all(1);caption_style.set_corner_radius_all(7)
	return caption_style

func _draw_locator(at:Vector2,top:bool,release:float) -> void:
	var side:=-1.0 if top else 1.0
	var center:=at+Vector2(0,side*(15+release*26))
	art.draw_set_transform(center,0,Vector2(1,0.28))
	art.draw_arc(Vector2.ZERO,28,0,TAU,64,Color("243443"),9,true)
	art.draw_arc(Vector2(0,-1),28,0,PI,32,Color("e1cb95"),2.3,true)
	art.draw_arc(Vector2(0,3),28,PI,TAU,32,Color("8c7045"),3.0,true)
	art.draw_set_transform(Vector2.ZERO)
	for x in [-23.0,23.0]:
		var p:=center+Vector2(x,-side*3)
		art.draw_line(p,p+Vector2(-signf(x)*9,-side*12),Color("826943"),4.0,true)
		art.draw_circle(p,2.0,Color("e0d2ab"),true,-1,true)

func _draw_map() -> void:
	if committed:return
	if phase!=Phase.ENTERING:
		# Fine calibration motion stays out of the central picking area.
		for i in range(2):
			art.draw_set_transform(CENTER+Vector2(0,45),-0.18+i*0.34+sin(age*0.05)*0.01,Vector2(1,0.48))
			art.draw_arc(Vector2.ZERO,310+i*48,0,TAU,160,Color(0.75,0.68,0.45,0.12),0.8,true)
		art.draw_set_transform(Vector2.ZERO)
	if phase==Phase.CLOSED or phase==Phase.OPENING:
		var transform:=core_transform()
		var release:=smoothstep(0.0,0.45,maxf(opening_age,0))
		_draw_locator(transform*Vector2(0,-170),true,release)
		_draw_locator(transform*Vector2(0,170),false,release)
		var alpha:float=(0.012+hover_amount*0.022)*(1.0-clampf(opening_age/OPEN_TIME,0,1))
		for i in range(6,0,-1):
			var shape:=PackedVector2Array()
			for vertex in whole:shape.append(transform*(vertex*(1.0+i*0.04)))
			art.draw_colored_polygon(shape,Color(0.50,0.87,0.91,alpha))
	if phase==Phase.OPENING:
		var p:=opening_age/OPEN_TIME
		art.draw_arc(CENTER,30+p*230,0,TAU,96,Color(0.67,0.92,0.88,sin(p*PI)*0.25),1.2,true)
	elif phase==Phase.ENTERING:
		for i in range(shards.size()):_draw_trail(i)
		var focus:=focus_at(selection_age)
		for i in range(2):
			var radius:=22.0+fposmod(selection_age*55+i*27,70)
			art.draw_arc(focus,radius,age*0.5+i,age*0.5+i+TAU*0.70,64,Color(0.69,0.96,0.89,smoothstep(0.6,1.5,selection_age)*0.25),1.0,true)
