extends RefCounted
## Production presentation itinerary. Every operation uses the live room API.
static func steps() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var add:=func(op:String,title:String,data:Dictionary={}):
		var item:Dictionary={"op":op,"title":title,"rate":2.2};item.merge(data,true);result.append(item)
	add.call("wait","纸山叠影 · 完整演示",{"condition":"arrival","rate":1.25,"hold":.4})
	add.call("world","显影旧廊，寻找留影夹",{"layer":0,"world":3})
	add.call("interact","取得留影夹",{"id":"tool"})
	add.call("stairs","前往下层水碓坊")
	add.call("world","倒悬解开封存架",{"layer":1,"world":2})
	add.call("wait","水纹触碰顶部锁扣",{"condition":"cage","rate":1.25,"hold":.35})
	add.call("world","冰晶规则，水纹回到导轨",{"layer":1,"world":0})
	add.call("wait","水纹落稳后开始运输",{"condition":"water_ground"})
	add.call("push","将水纹送至接物踏板",{"weight":1,"destination":"catch"})
	add.call("world","重压踏板，升起接物台",{"layer":1,"world":1})
	add.call("wait","接物台升到安全高度",{"condition":"catch_up","rate":1.25})
	add.call("interact","固定接物台",{"id":"catch","hold":.7,"voice":"P2-04-catch","rate":1.25})
	add.call("world","接物台保持固定",{"layer":1,"world":0,"hold":.4})
	add.call("stairs","回上层解除检修撑")
	add.call("interact","解除落料板检修撑",{"id":"support"})
	add.call("world","重力压开落料板",{"layer":0,"world":1})
	add.call("wait","接住山纹镇纸",{"condition":"mountain_landed","rate":1.1,"hold":.7,"voice":"P2-05"})
	add.call("stairs","前往下层接物区")
	add.call("push","将山纹送入停靠吊台",{"weight":0,"destination":"lift"})
	add.call("push","水纹经过分岔",{"weight":1,"destination":"guide_turn"})
	add.call("push","将水纹送至水闸踏板",{"weight":1,"destination":"sluice"})
	add.call("world","水车驱动吊台",{"layer":1,"world":1})
	add.call("wait","山纹随吊台回到上层",{"condition":"lift_top","rate":1.25,"hold":.7,"voice":"P2-06"})
	add.call("stairs","返回上层晒纸院")
	add.call("world","沿上层冰晶导轨运输",{"layer":0,"world":0})
	add.call("push","山纹到达木桥前止挡",{"weight":0,"destination":"dock"})
	add.call("recall","收回留影夹")
	add.call("world","显影跨渠木桥",{"layer":0,"world":3,"rate":1.25})
	add.call("interact","固定木桥",{"id":"bridge","hold":.7,"rate":1.25})
	add.call("world","木桥保留，继续运输",{"layer":0,"world":0})
	add.call("push","山纹通过木桥抵达锚座",{"weight":0,"destination":"anchor"})
	add.call("world","重力稳定上层锚点",{"layer":0,"world":1})
	add.call("wait","上层锚定，下层保护罩打开",{"condition":"upper","rate":1.25,"hold":.7})
	add.call("stairs","前往下层完成另一处锚点")
	add.call("world","解除水闸重压，让吊台归底",{"layer":1,"world":0})
	add.call("wait","吊台归底，低位通道开放",{"condition":"lowpass","rate":1.25,"hold":.35})
	add.call("push","水纹返回真实分岔",{"weight":1,"destination":"guide_turn"})
	add.call("push","将水纹送入导向井",{"weight":1,"destination":"guide"})
	add.call("world","倒悬稳定高处锚位",{"layer":1,"world":2})
	add.call("wait","上下双锚共同稳定",{"condition":"dual","rate":1.1,"hold":.8,"voice":"P2-08"})
	add.call("stairs","返回上层归位门")
	add.call("exit","走入归位门，带回观测记录",{"rate":1.6})
	return result

static func next_direction(state:RefCounted,index:int,destination:String) -> Vector2:
	var origin:String=state.weights[index].station
	var paths:Array=[[origin]];var visited:Dictionary={origin:true}
	while not paths.is_empty():
		var path:Array=paths.pop_front();var last:String=path[-1]
		if last==destination:
			return (state.stops(index)[path[1]]-state.weights[index].pos).normalized() if path.size()>1 else Vector2.ZERO
		for next:String in state.neighbors(index,last):
			if not visited.has(next):visited[next]=true;paths.append(path+[next])
	return Vector2.ZERO
