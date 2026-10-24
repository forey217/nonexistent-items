extends CanvasLayer
const Cues=preload("res://scripts/paper_mission_cues.gd")
const Instruments=preload("res://scripts/instrument_theme.gd")
var room:Node
var root:=Control.new()
var exhibit=preload("res://scripts/paper_mission_exhibit.gd").new()
var schedule:Array[Dictionary]=[]
var cursor:=0
var line_age:=0.0
var line_id:=""
var line_live:=false
var spoken:=false
var strengths:Dictionary={}
var remaining:Dictionary={}
var rings:Dictionary={}
var shown:Dictionary={}
var history:Array[Dictionary]=[]
var exhibit_hold:=0.0
var exhibit_alpha:=0.0
var active_object:=""
var queued_object:=""
var manual:=false
var catalog_index:=0
var clock:=0.0
var pointers:Array[Button]=[]
var pointer_objects:Array[String]=[]
var tick_materials:Dictionary={}
var protected: Array[Rect2]=[]
var response_ages:Dictionary={}
var repeat_exhibits:=false
const CATALOG:=["tool","w0","w1","catch_pad","sluice_pad","catch","bridge","lift","upper_anchor","lower_anchor"]

func _ready() -> void:
	layer=8;root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root);root.add_child(exhibit)
	exhibit.dismissed.connect(func():exhibit_hold=0;manual=false;queued_object="")
	exhibit.next_requested.connect(func():catalog_index=(catalog_index+1)%CATALOG.size();inspect(CATALOG[catalog_index]))
	exhibit.locate_requested.connect(func():focus_object(active_object))
	for i in range(3):
		var b:=Button.new();Instruments.apply_button(b,16,true);b.hide();root.add_child(b);pointers.append(b);pointer_objects.append("")
		var index:=i;b.pressed.connect(func():focus_object(pointer_objects[index]))
	get_viewport().size_changed.connect(func():_place_exhibit(true))

func begin_line(line:Dictionary,node:String,index:int,context:String,duration:float,record:Dictionary) -> void:
	cancel_line();line_id=line.id;line_age=0;line_live=true
	repeat_exhibits=node.begins_with("hint:")
	# Resume may filter earlier, already-read lines. Match the immutable voice ID
	# back to the approved sequence instead of relying on the shortened array index.
	var original:Array=Cues.Lines.sequence(node)
	for i in range(original.size()):
		if original[i].id==line.id:index=i;break
	spoken=room.communications.voice.current_id==line.id
	var hint_context:=node.split(":")[1] if node.begins_with("hint:") else context
	var hint_index:int=room.hint_level-1 if node.begins_with("hint:") else index
	schedule=Cues.plan(line,node,hint_index,hint_context,room.communications.first_target,record,duration);cursor=0

func cancel_line() -> void:
	line_live=false;schedule.clear();cursor=0
	for id in remaining:remaining[id]=minf(float(remaining[id]),.38)
	if not manual:exhibit_hold=0;queued_object=""

func inspect(id:String) -> void:
	if not Cues.ITEMS.has(id):return
	manual=true;queued_object="";catalog_index=CATALOG.find(id) if id in CATALOG else 0
	emphasize([id],false);_show_object(id,true)

func emphasize(ids:Array,with_exhibit:bool) -> void:
	for id:String in ids:
		var continuing:bool=float(remaining.get(id,0))>0 or float(strengths.get(id,0))>.01
		remaining[id]=maxf(float(remaining.get(id,0)),2.25)
		if not continuing:response_ages[id]=0.0
		if not strengths.has(id):strengths[id]=0.0
	if with_exhibit and not ids.is_empty():
		var id:String=ids[0]
		if Cues.ITEMS.has(id) and not Cues.ITEMS[id][0].is_empty() and not manual:
			if not shown.has(id) or repeat_exhibits:
				shown[id]=true
				_show_object(id,false)
				if ids.size()>1 and Cues.ITEMS.has(ids[1]) and not str(Cues.ITEMS[ids[1]][0]).is_empty() and Cues.ITEMS[ids[1]][0]!=Cues.ITEMS[id][0]:
					queued_object=ids[1];shown[ids[1]]=true

func target(id:String) -> Dictionary:
	var s=room.state;var at:=Vector2.ZERO;var layer_index:=0;var height:=.4;var surface:=true;var stored:=false
	match id:
		"tool":
			if s.clip_owned:
				if s.clip_target in ["catch","bridge"]:
					var fixed:=target(s.clip_target);fixed.name="留影夹 · "+fixed.name;return fixed
				stored=true
			at=s.TOOL;height=.65
		"w0","w1":
			var index:=int(id.trim_prefix("w"));var w:Dictionary=s.weights[index];at=w.pos;layer_index=int(w.layer);height=s.weight_height(index)-(s.HEIGHT if layer_index==0 else 0.0)+.65
		"catch_pad":at=s.CATCH_PLATE;layer_index=1;height=.3
		"sluice_pad":at=s.SLUICE;layer_index=1;height=.3
		"catch":at=s.DROP+Vector2(1.4,0);layer_index=1;height=.5+s.catch_height*.15
		"bridge":at=s.BRIDGE+Vector2(.9,-.5);height=.40;surface=s.bridge_solid()
		"lift":at=s.LIFT;layer_index=0 if s.lift_height>s.HEIGHT*.5 else 1;height=s.lift_height-(s.HEIGHT if layer_index==0 else 0.0)+.42
		"upper_anchor":at=s.UPPER_ANCHOR;height=.35
		"lower_anchor":at=s.LOWER_ANCHOR;layer_index=1;height=2.62
		"corridor":at=Vector2(5,9.55);height=.15;surface=s.old_corridor_solid()
		"support":at=s.DROP+Vector2(-1.4,0);height=.6
		"exit":at=s.EXIT;height=1.0
		_:return {}
	return {"pos":at,"layer":layer_index,"height":height,"surface":surface,"stored":stored,"name":Cues.ITEMS.get(id,["",id,""])[1]}

func focus_object(id:String) -> void:
	var t:=target(id)
	if t.is_empty():return
	if t.stored:room.hud.message("留影夹已在左下工具袋中，可直接召回。");return
	room.view_layer=t.layer;room.view.set_focus(t.pos);room.view.focused_target=id
	inspect(id)

func _show_object(id:String,is_manual:bool) -> void:
	if not Cues.ITEMS.has(id) or str(Cues.ITEMS[id][0]).is_empty():return
	if active_object==id and exhibit.visible and exhibit_alpha>.01 and exhibit.next_button.visible==is_manual:
		exhibit_hold=maxf(exhibit_hold,12.0 if is_manual else 4.8);return
	active_object=id;manual=is_manual;exhibit_hold=12.0 if is_manual else 4.8
	exhibit_alpha=0.0
	var info:Array=Cues.ITEMS[id];var t:=target(id)
	var where:="工具袋内" if t.get("stored",false) else ("上层 · 晒纸院" if t.get("layer",0)==0 else "下层 · 水碓坊")
	exhibit.show_model(info[0],info[1],info[2],where,is_manual);_place_exhibit(true)

func occupied_rect() -> Rect2:
	return exhibit.get_global_rect() if exhibit.visible and exhibit_alpha>.05 and not room.hud.menu.visible else Rect2()

func blocks_map(at:Vector2) -> bool:
	if not root.visible:return false
	if exhibit.is_visible_in_tree() and exhibit.plate.get_global_rect().has_point(at):return true
	for b in pointers+[exhibit.close_button,exhibit.next_button,exhibit.locate_button]:
		if b.is_visible_in_tree() and b.get_global_rect().has_point(at):return true
	return false

func _place_exhibit(force:=false) -> void:
	if not exhibit.visible:return
	var size:=get_viewport().get_visible_rect().size;var view=room.view
	var actor_pixel:Vector2=view.to_ui(view.camera.unproject_position(view.actor.position+Vector3.UP*.9))
	var avoids:Array[Rect2]=[Rect2(actor_pixel-Vector2(45,90),Vector2(90,125))]
	var t:=target(active_object)
	if not t.is_empty() and t.layer==room.view_layer and not t.stored:
		var at:Vector2=view.screen(t.pos,t.layer,t.height);avoids.append(Rect2(at-Vector2(70,70),Vector2(140,140)))
	if room.hud.record.visible:avoids.append(room.hud.record.get_global_rect())
	if room.hud.push_picker.visible:avoids.append(room.hud.push_picker.occupied_rect())
	protected=avoids
	if not force and avoids.all(func(r):return not r.intersects(exhibit.get_global_rect())):return
	var spots:Array[Vector2]=[Vector2(size.x-288,142),Vector2(24,142),Vector2(size.x-288,size.y-438),Vector2(24,size.y-438)]
	var best:Vector2=spots[0];var score:=INF
	for at in spots:
		var rect:=Rect2(at,exhibit.size);var overlap:=0.0
		for obstacle in avoids:overlap+=rect.intersection(obstacle).get_area()
		if overlap<score:score=overlap;best=at
	# Relocate only when a cue starts or content would actually be covered.
	exhibit.position=best

func _ensure_ticks(id:String) -> void:
	if rings.has(id):return
	var n:=Node3D.new();n.name="ObservationTicks_"+id;room.view.world_root.add_child(n);rings[id]=n
	var m:=StandardMaterial3D.new();m.albedo_color=Color("d3bf8e");m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;tick_materials[id]=m
	for x in [-.57,.57]:
		for z in [-.57,.57]:
			room.view.beam(n,Vector3(x,.03,z),Vector3(x-signf(x)*.18,.03,z),.014,m)
			room.view.beam(n,Vector3(x,.03,z),Vector3(x,.03,z-signf(z)*.18),.014,m)

func _process(delta:float) -> void:
	if room.hud.menu.visible:
		root.hide();exhibit.suspend();return
	root.show();clock+=delta
	if line_live:
		line_age+=delta
		var elapsed:float=room.communications.voice.position_seconds() if spoken else line_age
		while cursor<schedule.size() and elapsed>=float(schedule[cursor].at):
			var c:Dictionary=schedule[cursor];emphasize(c.objects,c.exhibit)
			history.append({"line":line_id,"objects":c.objects,"at":elapsed,"scheduled":c.at,"source":c.timing_source});cursor+=1
			if history.size()>150:history.pop_front()
	for id in strengths:
		remaining[id]=maxf(0,float(remaining[id])-delta);response_ages[id]=float(response_ages.get(id,0))+delta
		var wanted:float=smoothstep(0,.38,float(remaining[id])) if remaining[id]>0 else 0.0
		strengths[id]=move_toward(float(strengths[id]),wanted,delta*5)
		var t:=target(id);var amount:float=strengths[id]*(.88+.12*sin(float(response_ages[id])*3.8))
		if room.view.mission_models.has(id):
			var model=room.view.mission_models[id];var same:bool=not t.is_empty() and t.layer==room.view_layer and not t.stored
			model.set_response(amount if same else 0.0,float(response_ages[id]))
		if id=="tool" and room.state.clip_owned:room.view.clamp.set_response(amount if room.state.clip_target!="" and t.layer==room.view_layer else 0.0)
		if id=="lift":
			var destination:=0 if room.state.lift_target_height()>room.State.HEIGHT*.5 else 1
			for dock_layer in room.view.lift_arrival_materials:
				var dock:StandardMaterial3D=room.view.lift_arrival_materials[dock_layer]
				dock.emission_enabled=true;dock.emission=Color("d6c18b")
				dock.emission_energy_multiplier=amount*.7*smoothstep(.8,1.05,float(response_ages[id])) if dock_layer==destination and dock_layer==room.view_layer else 0.0
		_ensure_ticks(id);var mark:Node3D=rings[id];var visible_here:bool=not t.is_empty() and t.layer==room.view_layer and not t.stored
		mark.visible=amount>.01 and visible_here
		if mark.visible:
			# Hidden corridors get entrance ticks, never a visible/solid bridge.
			mark.position=room.view.point(t.pos,(room.State.HEIGHT if t.layer==0 else 0.0)+maxf(.06,t.height-.25));tick_materials[id].albedo_color.a=amount*.6
	_update_pointers()
	exhibit_hold=maxf(0,exhibit_hold-delta)
	if not queued_object.is_empty() and exhibit_hold<=1.5:
		var next:=queued_object;queued_object="";_show_object(next,false)
	exhibit_alpha=move_toward(exhibit_alpha,1.0 if exhibit_hold>0 else 0.0,delta*4)
	exhibit.modulate.a=exhibit_alpha;exhibit.scale=Vector2.ONE*lerpf(.98,1.0,exhibit_alpha)
	if exhibit_alpha<=0:
		exhibit.hide();exhibit.suspend();manual=false
	elif exhibit.visible:
		var live:=target(active_object)
		exhibit.location.text="工具袋内" if live.get("stored",false) else ("上层 · 晒纸院" if live.get("layer",0)==0 else "下层 · 水碓坊")
		_place_exhibit();exhibit.refresh_frame()

func _update_pointers() -> void:
	for p in pointers:p.hide()
	var index:=0;var dimensions:=get_viewport().get_visible_rect().size
	var sorted:Array=strengths.keys();sorted.sort_custom(func(a,b):return float(strengths[a])>float(strengths[b]))
	for id:String in sorted:
		if index>=pointers.size() or strengths[id]<.05:continue
		var t:=target(id)
		if t.is_empty():continue
		var p:Button=pointers[index];var at:=Vector2.ZERO;var caption:=""
		if t.stored:
			at=room.hud.bag_shade.position+Vector2(175,-34);caption="↓ 留影夹 · 工具袋"
		elif t.layer!=room.view_layer:
			at=Vector2(dimensions.x-258,110+index*34);caption=("↑ 上层 · " if t.layer==0 else "↓ 下层 · ")+t.name
		else:
			var pixel:Vector2=room.view.screen(t.pos,t.layer,t.height)
			if Rect2(30,118,dimensions.x-60,dimensions.y-300).has_point(pixel):continue
			var direction:Vector2=(pixel-dimensions*.5).normalized()
			at=Vector2(clampf(pixel.x,25,dimensions.x-250),clampf(pixel.y,124,dimensions.y-205))
			caption=("→ " if direction.x>0 else "← ")+t.name
		p.text=caption;p.position=at;p.size=Vector2(225,30);p.modulate.a=strengths[id];p.show();pointer_objects[index]=id;index+=1
