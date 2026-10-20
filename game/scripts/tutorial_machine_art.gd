extends Node2D
var room: Node2D
var kind:="weight"
var clock:=0.0
var hovered:=false
var textures: Array[Texture2D]=[]
var font:=SystemFont.new()

func _ready() -> void:
	font.font_names=PackedStringArray(["Microsoft YaHei","Arial"])
	var asset: String="gate" if kind=="portal" else kind
	for i in range(3):textures.append(load("res://assets/calibration_v03/%s-%d.png"%[asset,i]))

func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()

func _draw() -> void:
	if room==null or textures.is_empty():return
	var texture: Texture2D=textures[room.state.world]
	var active:=Color("86dcb8")
	if kind=="receiver":
		draw_texture_rect(texture,Rect2(-128,-230,256,300),false)
		var light:=active if room.state.receiver_latched else Color("ddbd80")
		draw_circle(Vector2(0,-166),4,light)
		# Side scale follows the real vertical position of the paperweight.
		draw_line(Vector2(41,-6),Vector2(41,-140),Color("485863"),3,true)
		draw_line(Vector2(41,-6),Vector2(41,-6-room.state.elevation),active,2,true)
		draw_circle(Vector2(41,-6-room.state.elevation),3,light)
		badge(Vector2(-40,-193),Vector2(86,20),"上部校准"+(" ✓" if room.state.receiver_latched else ""))
	elif kind=="portal":
		var opened: bool=room.state.gate_open
		var color:=Color("79d8c6") if opened else Color("8b8ba3")
		draw_set_transform(Vector2.ZERO,0,Vector2(1,0.38))
		draw_circle(Vector2.ZERO,49,Color(color,0.12))
		draw_arc(Vector2.ZERO,45,0,TAU,48,Color("ab9a70"),2,true)
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(-41,-100,82,101),Color(color,0.2 if opened else 0.07))
		if opened:
			for i in range(8):
				var y: float=-7-fposmod(clock*22+i*13,94)
				draw_line(Vector2(-35,y),Vector2(35,y),Color(0.63,0.92,0.86,0.12),1,true)
				draw_circle(Vector2(sin(i*2.4)*28,y),1.5,Color("d6fff3"))
		else:
			for i in range(5):draw_line(Vector2(-34+i*17,-3),Vector2(-34+i*17,-99),Color("8c899a"),1.4,true)
			draw_line(Vector2(-40,-52),Vector2(40,-52),Color("ae9277"),3,true)
		draw_texture_rect(texture,Rect2(-128,-205,256,256),false)
		for i in range(2):
			var lit: bool=room.state.receiver_latched if i==0 else room.state.final_pressed
			draw_circle(Vector2(-14+i*28,-127),4,active if lit else Color("6b737c"))
		badge(Vector2(-42,22),Vector2(84,20),"归位门 · "+("开启" if opened else "待校准"))
	else:
		var height: float=room.state.elevation
		draw_set_transform(Vector2.ZERO,0,Vector2(1,0.42))
		draw_circle(Vector2.ZERO,19-height*0.035,Color(0.09,0.15,0.22,0.20-height*0.0008))
		if hovered:draw_arc(Vector2.ZERO,23,0,TAU,32,Color("e1be75"),2,true)
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(texture,Rect2(-64,-88-height,128,128),false,Color(1.12,1.12,1.06) if hovered else Color.WHITE)
		if height>5:
			for i in range(3):
				var y: float=-height+30+i*13
				draw_line(Vector2(-3,y),Vector2(3,y+4),Color(0.75,0.72,0.95,0.5),1.2,true)

func badge(at: Vector2,size: Vector2,text: String) -> void:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("344a55")
	style.border_color=Color("a99a75")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	draw_style_box(style,Rect2(at,size))
	draw_string(font,at+Vector2(6,14),text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("e5e6dc"))
