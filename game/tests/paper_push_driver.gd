extends RefCounted
## Automated play uses actual right-click selection and left-click arrows.
var steps:Array[Dictionary]=[]
var error:=""

func route(state:RefCounted,index:int,destination:String) -> Array:
	var origin:String=state.weights[index].station
	var queue:Array=[[origin]];var seen:Dictionary={origin:true}
	while not queue.is_empty():
		var path:Array=queue.pop_front();var last:String=path[-1]
		if last==destination:return path.slice(1)
		for next in state.neighbors(index,last):
			if seen.has(next):continue
			seen[next]=true;queue.append(path+[next])
	return []

func click(room:Node,at:Vector2,button:int) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=button;event.pressed=down
		room.get_viewport().push_input(event,true)

func start(room:Node,index:int,direction:Vector2) -> bool:
	var w:Dictionary=room.state.weights[index]
	if room.player_layer!=w.layer:error="人物不在镇纸所在层";return false
	room.hud.record.hide();room.view.set_focus(w.pos);room.view_layer=w.layer
	for frame in range(25):await room.get_tree().physics_frame
	var height:float=room.state.weight_height(index)-(room.State.HEIGHT if w.layer==0 else 0.0)+.3
	click(room,room.view.screen(w.pos,w.layer,height),MOUSE_BUTTON_RIGHT)
	for frame in range(3):await room.get_tree().physics_frame
	var picker=room.hud.push_picker
	if not picker.visible or picker.selected!=index:error="右键未打开正确镇纸的方向选择";return false
	var arrow_index:int=picker.DIRECTIONS.find(room.State.snap_direction(direction))
	if arrow_index<0 or picker.arrows[arrow_index].disabled:
		error="方向不可用："+room.push_preview(index,direction).error;return false
	var at:Vector2=picker.arrows[arrow_index].get_global_rect().get_center()
	var hover:=InputEventMouseMotion.new();hover.position=at;hover.global_position=at;room.get_viewport().push_input(hover,true)
	for frame in range(3):await room.get_tree().physics_frame
	click(room,picker.arrows[arrow_index].get_global_rect().get_center(),MOUSE_BUTTON_LEFT)
	for frame in range(2):await room.get_tree().physics_frame
	if room.pending.is_empty() and not room.interacting and w.mode!="slide":error="左键方向未启动自动走位或推动";return false
	return true

func segment(room:Node,index:int,next:String) -> bool:
	var w:Dictionary=room.state.weights[index]
	var path:=route(room.state,index,next)
	if path.is_empty():error="无相连路径 "+next;return false
	var direction:Vector2=(room.state.stops(index)[path[0]]-w.pos).normalized()
	var plan:Dictionary=room.state.push_route(index,direction)
	if not plan.error.is_empty():error=plan.error;return false
	if not await start(room,index,direction):return false
	for frame in range(2400):
		await room.get_tree().physics_frame
		if room.pending.is_empty() and not room.interacting and w.mode=="rest":break
	steps.append({"index":index,"station":w.station,"via":plan.stations,"player":[room.player_plan().x,room.player_plan().y],"direction":[direction.x,direction.y]})
	if w.station!=plan.target:error="未到达预计停靠点 "+str(plan.target)+"，实际 "+str(w.station);return false
	return true

func push_to(room:Node,index:int,destination:String) -> bool:
	for hop in range(12):
		if room.state.weights[index].station==destination:return true
		if not await segment(room,index,destination):return false
	error="超过运输分段上限";return false
