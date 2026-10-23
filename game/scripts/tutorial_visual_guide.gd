extends Node2D
## Read-only annotations use the current camera projection and real object position.
var view: Node2D
var mode := ""
var age := 0.0
var anchor_index := -1
var anchor_history: Array[int]=[]
var law_world := -1
var label_rect := Rect2()
var font := SystemFont.new()
var speech: Node
var speech_id := ""
var speech_cues: Dictionary={}
var speech_end := 0.0
const COLORS = [Color("8cdef0"),Color("efc579"),Color("c9b3f4")]

func _ready() -> void:
	z_index=60;font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	stop()

func start(visual: String) -> void:
	if visual not in ["anchors","law-ice","law-heavy","law-inverted"]:stop();return
	mode=visual;age=0;anchor_index=-1;anchor_history.clear()
	law_world=["law-ice","law-heavy","law-inverted"].find(visual)
	show();set_process(true);_sync_anchor();queue_redraw()

func stop() -> void:
	speech=null;speech_id="";speech_cues={};speech_end=0
	mode="";anchor_index=-1;law_world=-1
	if is_instance_valid(view):view.landmarks.teaching_index=-1
	hide();set_process(false);queue_redraw()

func _sync_anchor() -> void:
	if mode!="anchors":view.landmarks.teaching_index=-1;return
	if is_instance_valid(speech) and speech.current_id==speech_id:
		var time: float=speech.position_seconds()
		anchor_index=2 if time>=float(speech_cues.get("界缝",999.0)) else (1 if time>=float(speech_cues.get("月痕",999.0)) else (0 if time>=float(speech_cues.get("星位",0.0)) else -1))
	else:anchor_index=mini(int(age/1.30),2)
	view.landmarks.teaching_index=anchor_index
	if anchor_index>=0 and not anchor_history.has(anchor_index):anchor_history.append(anchor_index)

func _process(delta: float) -> void:
	age+=delta
	if mode=="anchors":
		if is_instance_valid(speech):
			if speech.current_id!=speech_id or age>=speech_end:stop();return
		elif age>=4.15:stop();return
	_sync_anchor();queue_redraw()

func sync_speech(source: Node,cues: Dictionary,end: float) -> void:
	if mode!="anchors" or not cues.has("月痕") or not cues.has("界缝"):return
	speech=source;speech_id=source.current_id;speech_cues=cues;speech_end=end
	anchor_history.clear()
	_sync_anchor()

func target_position() -> Vector2:
	return view.logic_to_screen(view.room.block_ground_position(),0.22+view.room.state.elevation/view.HEIGHT_PIXELS)

func arrow(from: Vector2,to: Vector2,color: Color,width: float=2.6) -> void:
	if from.distance_to(to)<4:return
	var direction: Vector2=(to-from).normalized()
	draw_line(from,to,Color("1b3443"),width+2.5,true)
	draw_line(from,to,color,width,true)
	draw_colored_polygon(PackedVector2Array([to,to-direction.rotated(0.48)*12,to-direction.rotated(-0.48)*12]),color)

func occupied_rects() -> Array[Rect2]:
	var room=view.room
	var feet: Vector2=view.logic_to_screen(room.player.position)
	var head: Vector2=view.logic_to_screen(room.player.position,1.95)
	var receiver_low: Vector2=view.logic_to_screen(room.rail_end,0)
	var receiver_high: Vector2=view.logic_to_screen(room.rail_end,3.25)
	var portal: Vector2=view.logic_to_screen(room.portal_position)
	var star: Vector2=view.logic_to_screen(room.first_plate,0.25)
	return [view.weight_screen_rect().grow(12),Rect2(Vector2(feet.x-33,head.y-12),Vector2(66,feet.y-head.y+24)),Rect2(Vector2(receiver_low.x-75,receiver_high.y-20),Vector2(150,receiver_low.y-receiver_high.y+50)),Rect2(portal-Vector2(73,143),Vector2(146,160)),Rect2(star-Vector2(38,28),Vector2(76,56)),Rect2(22,20,184,386),Rect2(22,526,247,174),Rect2(1015,20,243,190),Rect2(0,707,1280,93)]

func safe_label_rect(at: Vector2) -> Rect2:
	var center:=target_position()
	var occupied:=occupied_rects()
	for candidate in [at,center+Vector2(-115,68),Vector2(501,132),Vector2(295,132),Vector2(728,132)]:
		var rect:=Rect2(Vector2(clampf(candidate.x,288,895),clampf(candidate.y,126,645)),Vector2(278,36))
		if occupied.all(func(area):return not rect.intersects(area)):return rect
	return Rect2(501,132,278,36)

func badge(at: Vector2,text: String,_color: Color) -> void:
	label_rect=safe_label_rect(at)
	draw_style_box(preload("res://scripts/instrument_theme.gd").style(false,.90),label_rect)
	draw_string(font,label_rect.position+Vector2(11,24),text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("fcf5e5"))

func _draw() -> void:
	if mode.is_empty():return
	if mode=="anchors":
		if anchor_index<0:return
		var target: Vector2=view.camera.unproject_position(view.landmarks.anchor_position(anchor_index))
		var pulse:=fposmod(age,1.30)/1.30
		draw_arc(target,24+pulse*19,0,TAU,64,Color(1.0,0.83,0.43,0.7*(1.0-pulse)),2,true)
		if anchor_index==2:
			var seam: Vector2=view.logic_to_screen(view.room.portal_position,1.0)
			draw_arc(seam,25,0,TAU,48,Color(0.80,0.68,0.97,0.7),1.7,true)
		return
	var center:=target_position()
	var color: Color=COLORS[law_world]
	var preview: bool=view.room.state.world!=law_world
	var outline: PackedVector2Array=view.weight_screen_hull()
	draw_polyline(outline+PackedVector2Array([outline[0]]),Color(color,0.55 if preview else 0.95),2.2,true)
	if law_world==0:
		var state=view.room.state
		var stop: Vector2=view.room.rail_end if state.first_latched else view.room.first_plate
		if state.rail_speed<0 or (absf(state.rail_speed)<0.1 and state.rail_position>= (state.RAIL_LENGTH if state.first_latched else state.FIRST_STOP)-0.2):stop=view.room.rail_start
		var end: Vector2=view.logic_to_screen(stop,0.25)
		if center.distance_to(end)>12:
			arrow(center.lerp(end,0.13),end,color,2.0)
			var direction: Vector2=(end-center).normalized()
			for i in range(3):
				var p:=center.lerp(end,fposmod(age*0.45+i*0.30,1.0))
				draw_polyline(PackedVector2Array([p-direction.rotated(0.65)*7,p,p-direction.rotated(-0.65)*7]),color,2,true)
	else:
		for side in [-1,1]:
			var x: float=center.x+float(side)*45.0
			var top:=Vector2(x,center.y-64);var bottom:=Vector2(x,center.y+30)
			arrow(top if law_world==1 else bottom,bottom if law_world==1 else top,color,3.0)
			var p:=fposmod(age*0.75+side*0.25,1.0)
			draw_circle(top.lerp(bottom,p if law_world==1 else 1.0-p),3.0,Color("fff4d1"))
		if law_world==1:
			var pressure:=PackedVector2Array()
			var ground: Vector3=view.to_world(view.room.block_ground_position(),0.26)
			for i in range(49):
				var a:=i*TAU/48.0
				pressure.append(view.camera.unproject_position(ground+Vector3(cos(a),0,sin(a))*0.43))
			draw_polyline(pressure,Color(color,0.8),2.4,true)
	var text: String=["低摩擦 · 推动后持续滑行","重量 ×4 · 向下压住机关","重力朝上 · 镇纸自动上浮"][law_world]
	if preview:text="切换后："+["冰晶低摩擦","重力向下 · 重量 ×4","倒悬重力朝上"][law_world]
	badge(center+Vector2(-115,-115),text,color)
