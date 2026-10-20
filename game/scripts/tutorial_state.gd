extends RefCounted
## Shared world laws. Position, momentum and latched calibration survive switches.
enum World { ICE, HEAVY, INVERTED }
const RAIL_LENGTH := 365.15
const FIRST_STOP := 118.30
const CEILING := 134.0
const SLIDE_SPEED := 112.0
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
	if rail_speed>0.1: return "镇纸正在滑行，会在挡块前停下。"
	if rail_position>=RAIL_LENGTH-0.2: return "已到导轨末端：观察它上方的接收器。"
	if not first_latched and rail_position>=FIRST_STOP-0.2:
		return "挡块未释放，压板显示重量不足。"
	rail_speed = SLIDE_SPEED
	return "已推动：低摩擦会让镇纸持续滑行。"

func step(delta: float) -> void:
	# Substeps keep gravity and contacts reliable during a frame hitch.
	var remaining := clampf(delta,0.0,0.5)
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120.0)
		remaining -= dt
		if world==World.ICE and elevation<=0.3 and rail_speed>0.0:
			var stop := RAIL_LENGTH if first_latched else FIRST_STOP
			rail_position = minf(stop,rail_position+rail_speed*dt)
			if rail_position>=stop-0.001: rail_speed=0.0
		var gravity := 160.0 if world==World.INVERTED else (-640.0 if world==World.HEAVY else -160.0)
		vertical_speed = clampf(vertical_speed+gravity*dt,-150.0,105.0)
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
	return ["把镇纸送到第一块压板", "压力不足：想办法让镇纸变重", "挡块已释放，把镇纸运到末端", "点亮镇纸上方的接收器", "让镇纸落回末端，并压住压板", "归位门已开启，走入门内返回机构"][stage()]

func hint(level: int) -> String:
	var clues := [
		["低摩擦世界中，物品受到推动就会滑行。", "镇纸被挡块接住后，会停在第一块压板上。", "靠近镇纸，右键点击它，或按 E 推动。"],
		["这里需要的是更大的重量。", "切换世界不会重置镇纸位置。", "按 2 切到重力世界，让镇纸压下压板。"],
		["重力世界里镇纸太重，无法运送。", "挡块已经机械锁定，不会随切换复原。", "按 1 回冰晶世界，再次右键推动镇纸。"],
		["地面上的镇纸碰不到上方接收器。", "有一个世界的重力方向与这里相反。", "按 3 切到倒悬世界，等镇纸上浮到顶。"],
		["上方校准已记录，还缺下方足够的压力。", "普通重力能让它落下，但重量还不够。", "按 2 回重力世界，等镇纸落回末端压板。"],
		["右侧发光的门就是出口。", "保持重力世界，镇纸才能持续压住压板。", "左键点击发光的归位门，衍月会走过去。"]
	]
	return clues[stage()][clampi(level-1,0,2)]
