extends Node2D
## Cutout animation: continuous, distance-driven legs with independent knee joints.

const STRIDE_DISTANCE := 180.0
const FOOT_SWING := 18.0
const ARM_SWING := 0.12
const BODY_HEIGHT := 85.0
var gait_phase := 0.0
var moving := false
var facing_row := 1
var near_foot := Vector2.ZERO
var far_foot := Vector2.ZERO
var near_knee := Vector2.ZERO
var far_knee := Vector2.ZERO
var body := Sprite2D.new()
var near_arm := Sprite2D.new()
var far_arm := Sprite2D.new()
var near_leg := Polygon2D.new()
var far_leg := Polygon2D.new()
var near_joint_cover := Node2D.new()
var far_joint_cover := Node2D.new()
var _sheet: Texture2D
var _views: Array
var _view := -1
var _body_anchor := Vector2.ZERO
var _body_scale := 1.0
var _leg_region := Rect2()
var _lean := 0.0
var _locomotion_weight := 0.0
var _near_shoulder := Vector2.ZERO
var _far_shoulder := Vector2.ZERO
var _near_arm_rest := 0.0
var _far_arm_rest := 0.0
var cast_amount := 0.0
var push_amount := 0.0

func _ready() -> void:
	_sheet = load("res://assets/yanyue_rig_v02.png")
	_views = JSON.parse_string(FileAccess.get_file_as_string("res://assets/rig_layout.json"))["views"]
	for part in [far_arm, far_joint_cover, far_leg, near_joint_cover, near_leg, body, near_arm]:
		add_child(part)
	near_joint_cover.draw.connect(func() -> void:
		near_joint_cover.draw_circle(near_knee,2.5,Color("72584f"))
		near_joint_cover.draw_circle(near_foot+Vector2(-2,-10),2.1,Color("393339"))
	)
	far_joint_cover.draw.connect(func() -> void:
		far_joint_cover.draw_circle(far_knee,2.5,Color("634c47"))
		far_joint_cover.draw_circle(far_foot+Vector2(-2,-10),2.1,Color("302d33"))
	)
	for arm in [near_arm, far_arm]:
		arm.centered = false
	body.centered = false
	for leg in [near_leg, far_leg]:
		leg.texture = _sheet
	far_leg.modulate = Color(0.88,0.90,0.94)
	far_arm.modulate = Color(0.97,0.98,1.0)
	pose(0.0, false, 1, Vector2.ZERO, 1.0)

func _rect(values: Array) -> Rect2:
	return Rect2(values[0],values[1],values[2],values[3])

func _texture(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _sheet
	atlas.region = region
	atlas.filter_clip = true
	return atlas

func _select_view(view: int) -> void:
	if _view == view:
		return
	_view = view
	var parts: Dictionary = _views[view]
	var region := _rect(parts["body"])
	body.texture = _texture(region)
	_body_scale = BODY_HEIGHT/region.size.y
	body.scale = Vector2.ONE*_body_scale
	# Waist center anchors the illustration, independently of the moving feet.
	_body_anchor = Vector2(region.size.x*0.54,region.size.y)
	_leg_region = _rect(parts["leg"])
	# Front and back illustrations expose opposite shoulders. Their pivots
	# are measured independently; the far sleeve stays behind the torso.
	_near_shoulder = Vector2(-13,-80) if view==0 else Vector2(14,-87)
	_far_shoulder = Vector2(14,-89) if view==0 else Vector2(-15,-92)
	_near_arm_rest = 0.28 if view==0 else -0.09
	_far_arm_rest = 0.25 if view==0 else -0.15
	var anchors := [Vector2(39,45),Vector2(35,38)] if view==0 else [Vector2(58,48),Vector2(103,48)]
	var lengths := [43.0,46.0] if view==0 else [48.0,49.0]
	var arm_index := 0
	for name_and_arm in [["near_arm",near_arm],["far_arm",far_arm]]:
		var arm: Sprite2D = name_and_arm[1]
		var arm_region := _rect(parts[name_and_arm[0]])
		arm.texture = _texture(arm_region)
		arm.scale = Vector2(0.105 if arm_index==0 else 0.10,lengths[arm_index]/arm_region.size.y)
		arm.offset = -anchors[arm_index]
		arm_index += 1

func pose(distance: float, is_moving: bool, row: int, direction: Vector2, delta: float, speed_ratio: float=1.0) -> void:
	moving = is_moving
	facing_row = row
	if moving:
		gait_phase = fposmod(distance/STRIDE_DISTANCE,1.0)
	_locomotion_weight=move_toward(_locomotion_weight,clampf(speed_ratio,0.0,1.0) if moving else 0.0,delta/(0.10 if moving else 0.14))
	_select_view(0 if row < 2 else 1)
	scale.x = 1.0 if row % 2 == 0 else -1.0
	var target_lean:=0.009*_locomotion_weight
	_lean = move_toward(_lean,target_lean,delta*0.3)
	# Horizontal travel has a shallow ground axis, vertical travel a steeper one.
	var ground_y := (0.10 if absf(direction.y)<0.2 else 0.22)*(1.0 if row<2 else -1.0)
	var axis := Vector2(1.0,ground_y).normalized()
	var bob := -0.18*(1.0-cos(gait_phase*TAU*2.0))*_locomotion_weight
	var reach:=Vector2(2.7,-0.9)*push_amount
	body.position = Vector2(0,-43+bob)+reach
	body.offset = -_body_anchor
	body.rotation = _lean-0.012*cast_amount+0.025*push_amount
	var near_hip := Vector2(-5,-53+bob) if _view==0 else Vector2(7,-53+bob)
	var far_hip := Vector2(6,-56+bob) if _view==0 else Vector2(-6,-56+bob)
	var near_rest := Vector2(-7,0) if _view==0 else Vector2(7,0)
	var far_rest := Vector2(7,-4) if _view==0 else Vector2(-7,-4)
	near_foot = _foot(gait_phase,near_rest,axis)
	far_foot = _foot(fposmod(gait_phase+0.5,1.0),far_rest,axis)
	near_knee = _leg(near_leg,near_hip,near_foot)
	far_knee = _leg(far_leg,far_hip,far_foot)
	var swing := cos(gait_phase*TAU)*ARM_SWING*_locomotion_weight
	near_arm.position = _near_shoulder+Vector2(0,bob)+reach
	far_arm.position = _far_shoulder+Vector2(0,bob)+reach
	near_arm.rotation = _near_arm_rest+swing-0.64*cast_amount-(0.92 if _view==0 else 0.80)*push_amount
	far_arm.rotation = _far_arm_rest-swing+0.08*cast_amount-0.14*push_amount
	near_joint_cover.queue_redraw()
	far_joint_cover.queue_redraw()
	queue_redraw()

func _foot(phase: float, rest: Vector2, axis: Vector2) -> Vector2:
	if _locomotion_weight<=0.0001:
		return rest
	var travel: float
	var lift := 0.0
	if phase < 0.5:
		travel = FOOT_SWING-phase*FOOT_SWING*4.0
	else:
		var t := (phase-0.5)*2.0
		travel = lerpf(-FOOT_SWING,FOOT_SWING,smoothstep(0.0,1.0,t))
		lift = sin(t*PI)*3.2
	return rest+(axis*travel+Vector2(0,-lift))*_locomotion_weight

func _leg(mesh: Polygon2D, hip: Vector2, foot: Vector2) -> Vector2:
	var ankle := foot+Vector2(-2,-10)
	# Use a gentle bend around the anatomical center line. The previous
	# two-bone solve forced deeply bent knees even when standing still.
	var knee := hip.lerp(ankle,0.48)+Vector2(3.0,-0.5)*_locomotion_weight
	# A subdivided textured mesh keeps the knee attached while it bends.
	var knots := [hip,knee,ankle,foot]
	var source_knots := [0.0,0.325,0.695,1.0]
	var center_x := [0.31,0.44,0.31,0.53] if _view==0 else [0.43,0.34,0.33,0.45]
	var pixels := PackedVector2Array()
	var uvs := PackedVector2Array()
	var left_points: Array[Vector2] = []
	var right_points: Array[Vector2] = []
	var left_uv: Array[Vector2] = []
	var right_uv: Array[Vector2] = []
	var width_scale := 0.105 if _view==0 else 0.112
	for i in range(19):
		var source_t := float(i)/18.0
		var segment := 0 if source_t<source_knots[1] else (1 if source_t<source_knots[2] else 2)
		var local_t: float = inverse_lerp(source_knots[segment],source_knots[segment+1],source_t)
		var center: Vector2 = knots[segment].lerp(knots[segment+1],local_t)
		# Keep UV slices parallel: rotated cross-sections can fold over one
		# another at a deep knee bend and leave an unrendered bow-tie quad.
		var cross := Vector2.RIGHT
		var source_center: float = lerpf(center_x[segment],center_x[segment+1],local_t)
		left_points.append(center-cross*source_center*_leg_region.size.x*width_scale)
		right_points.append(center+cross*(1.0-source_center)*_leg_region.size.x*width_scale)
		left_uv.append(_leg_region.position+Vector2(0,_leg_region.size.y*source_t))
		right_uv.append(_leg_region.position+Vector2(_leg_region.size.x,_leg_region.size.y*source_t))
	for i in range(19):
		pixels.append(left_points[i]); uvs.append(left_uv[i])
	for i in range(18,-1,-1):
		pixels.append(right_points[i]); uvs.append(right_uv[i])
	mesh.polygon = pixels
	mesh.uv = uvs
	var quads: Array[PackedInt32Array] = []
	for i in range(18):
		quads.append(PackedInt32Array([i,i+1,36-i,37-i]))
	mesh.polygons = quads
	return knee
