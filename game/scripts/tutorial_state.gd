extends RefCounted
## Shared world laws. Position, momentum and latched calibration survive switches.
enum World { ICE, HEAVY, INVERTED }
const RAIL_LENGTH := 365.15
const FIRST_STOP := 118.30
const CEILING := 134.0
const SLIDE_SPEED := 112.0
const HEAVY_FALL_ACCELERATION := 800.0
const HEAVY_MAX_FALL_SPEED := 190.0
var world: int = World.ICE
var rail_position := 0.0
var rail_speed := 0.0
var elevation := 0.0
var vertical_speed := 0.0
var first_latched := false
var receiver_latched := false
var final_pressed := false
var gate_open := false
var revision := 0

func reset() -> void:
	world = World.ICE
	rail_position = 0.0
	rail_speed = 0.0
	elevation = 0.0
	vertical_speed = 0.0
	first_latched = false
	receiver_latched = false
	final_pressed = false
	gate_open = false
	revision += 1

func switch_world(next: int) -> void:
	if next<0 or next>2 or next==world: return
	world = next
	if world!=World.ICE: rail_speed = 0.0
	# Gravity changes acceleration, not the instantaneous position or height.
	_update_contacts()
	revision += 1

func push() -> String:
	if world==World.HEAVY: return "镇纸太重，推不动。试试另一个世界。"
	if world==World.INVERTED: return "向上的重力正在作用，先让镇纸落回导轨。"
	if elevation>0.3: return "镇纸还在空中，等它落回导轨再推。"
	if absf(rail_speed)>0.1: return "镇纸正在沿导轨滑行。"
	if rail_position>=RAIL_LENGTH-0.2 or (not first_latched and rail_position>=FIRST_STOP-0.2):
		rail_speed=-SLIDE_SPEED
		return "已反向推动：镇纸沿导轨滑回起点。"
	rail_speed = SLIDE_SPEED
	return "已推动：低摩擦会让镇纸持续滑行。"

func step(delta: float) -> void:
	# Substeps keep gravity and contacts reliable during a frame hitch.
	var remaining := clampf(delta,0.0,0.5)
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120.0)
		remaining -= dt
		if world==World.ICE and elevation<=0.3 and absf(rail_speed)>0.0:
			if rail_speed<0:
				rail_position=maxf(0.0,rail_position+rail_speed*dt)
				if rail_position<=0.001:rail_speed=0.0
			else:
				var stop := RAIL_LENGTH if first_latched else FIRST_STOP
				rail_position = minf(stop,rail_position+rail_speed*dt)
				if rail_position>=stop-0.001: rail_speed=0.0
		var gravity := 160.0 if world==World.INVERTED else (-HEAVY_FALL_ACCELERATION if world==World.HEAVY else -160.0)
		var max_fall_speed := HEAVY_MAX_FALL_SPEED if world==World.HEAVY else 150.0
		vertical_speed = clampf(vertical_speed+gravity*dt,-max_fall_speed,105.0)
		elevation += vertical_speed*dt
		if elevation<=0.0:
			elevation=0.0
			vertical_speed=0.0
		if elevation>=CEILING:
			elevation=CEILING
			vertical_speed=0.0
		_update_contacts()

func _update_contacts() -> void:
	var grounded := elevation<0.2
	if world==World.HEAVY and grounded and absf(rail_position-FIRST_STOP)<1.0:
		first_latched=true
	if rail_position>=RAIL_LENGTH-0.2 and elevation>=CEILING-0.2:
		receiver_latched=true
	final_pressed = world==World.HEAVY and grounded and rail_position>=RAIL_LENGTH-0.2
	gate_open = receiver_latched and final_pressed

func stage() -> int:
	if gate_open: return 5
	if receiver_latched: return 4
	if rail_position>=RAIL_LENGTH-0.2: return 3
	if first_latched: return 2
	if rail_position>=FIRST_STOP-0.2: return 1
	return 0

func objective() -> String:
	return ["激活星位踏板，定位星位", "激活月痕印座，压稳月痕", "激活封界踏板，封闭界缝", "界缝已封，世界关系恢复稳定。可以返回机构。"][goal_stage()]

func goal_stage() -> int:
	if not first_latched:return 0
	if not receiver_latched:return 1
	if not gate_open:return 2
	return 3

func hint(level: int) -> String:
	return hint_set()[clampi(level-1,0,2)]

func hint_set() -> Array:
	if rail_position<RAIL_LENGTH-0.2 and elevation>0.3 and not receiver_latched:
		return ["镇纸离开了导轨，暂时无法运送。", "先让它重新接触导轨，再考虑目标的位置。", "按1切到冰晶世界，等待镇纸落回导轨，再靠近按E或右键推动。"]
	if receiver_latched and rail_position<RAIL_LENGTH-0.2:
		return ["月痕已经锁定，但镇纸离开了封界踏板。", "先把镇纸运回导轨末端；封界踏板需要足够的压力。", "按1切回冰晶，等镇纸落稳后推向末端，再按2让它压住封界踏板。"]
	var clues := [
		["星位在带五角星的踏板上。", "冰晶世界摩擦很小，挡块会接住滑来的镇纸。", "按1切到冰晶世界，靠近镇纸，右键或按E推动。"],
		["镇纸到达了星位，但锚座还没稳定。", "这里需要更大的重量；切换世界不会重置镇纸位置。", "按 2 切到重力世界，让镇纸压稳星位。"],
		["星位已定，下一个目标是高处的月痕。", "月痕印座下方有导轨；重力世界里的镇纸太重，无法运送。", "按 1 回冰晶世界，再次右键推动镇纸到导轨末端。"],
		["印座在镇纸上方，需要让它向上接近。", "倒悬世界会改变重力方向。", "按3切到倒悬世界，等待镇纸升到印座。"],
		["月痕已压稳，还需要让界缝封印持续运作。", "界缝与末端压板相连；普通重力下的重量还不够。", "按 2 回重力世界，等镇纸落回末端压板，为封界缝供能。"],
		["界缝已封，修复后的门可通往机构。", "保持重力世界，镇纸才能持续维持封印。", "左键点击修复后的归位门，衍月会走过去。"]
	]
	return clues[stage()]
