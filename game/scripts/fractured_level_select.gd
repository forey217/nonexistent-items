extends "res://scripts/level_select.gd"
enum Phase { CLOSED, OPENING, EXPANDED, ENTERING }
const OPEN_TIME=0.88
const COMMIT_TIME=2.42
const FINISH_TIME=2.77
var phase:int=Phase.CLOSED
var opening_age:=-1.0
var hover_amount:=0.0
var pointer:=Vector2(-10000,-10000)
var shards:Array[Node2D]=[]
var whole:=PackedVector2Array([Vector2(-7,-118),Vector2(65,-62),Vector2(54,42),Vector2(14,114),Vector2(-62,60),Vector2(-74,-42)])
var spread:Array[Vector2]=[Vector2(880,389),Vector2(804,586),Vector2(476,581),Vector2(336,385),Vector2(477,194),Vector2(808,196)]
var spread_scale:Array[float]=[1.65,1.55,1.44,1.38,1.58,1.48]
var spread_angle:Array[float]=[-0.15,0.10,-0.22,0.17,-0.12,0.20]
var selected:=-1
var selected_origin:=Vector2.ZERO
var start_rotations:Array[float]=[]
var white_veil:ColorRect

func _ready() -> void:
	super._ready()
	enter_button.hide();enter_button.disabled=true
	heading.text="万千宇宙，一条归途"
	subtitle.text="轻触水晶，展开世界"
	clock_material.shader=preload("res://shaders/cosmic_panorama.gdshader")
	clock_material.set_shader_parameter("panorama",preload("res://assets/level_select/cosmos_bright_v23.png"))
	var seam:=Vector2(-4,7)
	var cuts:=PackedVector2Array()
	for i in range(6):
		var offset:float=[5.0,-4.0,4.0,-5.0,5.0,-4.0][i]
		cuts.append(whole[i].lerp(seam,0.52)+(seam-whole[i]).normalized().orthogonal()*offset)
	for i in range(6):
		var next:=(i+1)%6
		var polygon:=PackedVector2Array([whole[i],whole[next],cuts[next],seam,cuts[i]])
		var shard=preload("res://scripts/level_crystal_shard.gd").new()
		shard.configure(polygon,PackedVector2Array([whole[i],whole[next]]),i==0)
		art.add_child(shard);shards.append(shard)
	white_veil=ColorRect.new()
	white_veil.size=Vector2(1280,800);white_veil.color=Color("f3fff6")
	white_veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;white_veil.modulate.a=0
	white_veil.z_index=100;root.add_child(white_veil)
	_update_shards(0.0)

func core_transform() -> Transform2D:
	var transform:=Transform2D(sin(age*0.20)*0.018,CENTER)
	return transform.scaled_local(Vector2(0.92,1.16)*(1.0+sin(age*1.4)*0.007))

func core_hit(at:Vector2) -> bool:
	if shards.is_empty():return false
	var projected:=PackedVector2Array()
	var back:=PackedVector2Array()
	var pose:Transform2D=shards[0].surface_basis
	for vertex in whole:
		projected.append(pose*vertex)
		back.append(pose*vertex+shards[0].thickness)
	var solid:=Geometry2D.convex_hull(projected+back)
	return Geometry2D.is_point_in_polygon(core_transform().affine_inverse()*at,solid)

func shard_at(at:Vector2) -> int:
	for i in range(shards.size()-1,-1,-1):
		if shards[i].hit_test(at):return i
	return -1

func expand_crystal() -> void:
	if phase!=Phase.CLOSED:return
	phase=Phase.OPENING;opening_age=0.0
	subtitle.text="选择亮起的关卡碎片"
	cue.emit("fold")

func select_level() -> void:
	# Keyboard and automation use the same two steps as mouse input.
	if phase==Phase.CLOSED:expand_crystal()
	elif phase==Phase.EXPANDED:choose_shard(0)

func choose_shard(index:int) -> void:
	if phase!=Phase.EXPANDED:return
	if index!=0:
		if index>=0:shards[index].lock_pulse=1.0
		return
	selected=index;selected_origin=shards[index].position
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
	return clampf((time-0.10-index*0.035)/1.42,0,1)

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
			var separation:Vector2=shard.source_center.normalized()*hover_amount*3.4
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
			shard.rotation=start_rotations[i]-t*TAU*0.88 if i!=selected else start_rotations[i]+smoothstep(0.9,2.4,selection_age)*1.0
			shard.scale=Vector2.ONE*spread_scale[i]*(1.0-t*0.80 if i!=selected else 1.0)
			shard.modulate.a=1.0-smoothstep(0.86,1.0,t) if i!=selected else 1.0
			shard.update_look(age,smoothstep(0.75,2.37,selection_age) if i==selected else t*0.5,1.0-smoothstep(0.1,0.55,selection_age),0,0,1.0)

func _process(delta:float) -> void:
	age+=delta
	if phase==Phase.OPENING:
		opening_age+=delta
		if opening_age>=OPEN_TIME:opening_age=OPEN_TIME;phase=Phase.EXPANDED
	if phase==Phase.ENTERING:selection_age+=delta
	hovered=core_hit(pointer) if phase==Phase.CLOSED else false
	hover_amount=move_toward(hover_amount,1.0 if hovered else 0.0,delta*3.0)
	_update_shards(delta)
	var over:int=shard_at(pointer) if phase==Phase.EXPANDED else -1
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered or over==0 else Input.CURSOR_ARROW)
	clock_material.set_shader_parameter("clock",age)
	if phase==Phase.ENTERING:
		var zoom:=1.0+pow(clampf((selection_age-1.66)/0.74,0,1),2.6)*24.0
		var roll:=-smoothstep(1.15,2.40,selection_age)*0.42
		var camera:=Transform2D(roll,Vector2.ZERO).scaled_local(Vector2.ONE*zoom)
		var focus:=focus_at(selection_age)
		camera.origin=focus-camera.basis_xform(focus)
		art.transform=camera
		clock_material.set_shader_parameter("camera_roll",roll*0.7)
		clock_material.set_shader_parameter("convergence",smoothstep(0.15,2.4,selection_age))
		heading.modulate.a=1.0-smoothstep(0.05,0.30,selection_age);subtitle.modulate.a=heading.modulate.a
		if selection_age>=COMMIT_TIME and not committed:
			committed=true;sky.hide();art.hide();heading.hide();subtitle.hide()
			level_committed.emit();cue.emit("arrived")
		white_veil.modulate.a=smoothstep(2.13,2.41,selection_age)*(1.0-smoothstep(2.46,FINISH_TIME,selection_age))
		if selection_age>=FINISH_TIME:set_process(false);finished.emit()
	art.queue_redraw()

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

func _draw_map() -> void:
	if committed:return
	if phase==Phase.CLOSED or phase==Phase.OPENING:
		var transform:=core_transform()
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
