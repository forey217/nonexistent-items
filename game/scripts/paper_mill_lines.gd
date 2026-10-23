extends RefCounted
const Shared=preload("res://scripts/dialogue_script.gd")
const NODES:=["P2-01","P2-02","P2-03","P2-04-catch","P2-04-bridge","P2-04-confirm","clip-limit","P2-05","P2-06","P2-06-bridge","P2-07","P2-08","idle"]

static func line(speaker:String,text:String) -> Dictionary:return Shared.line(speaker,text)
static func sequence(node:String) -> Array:
	match node:
		"P2-01":return [line("tesla","这里是泽雅纸山。两座纸坊错位重叠，连水路和机关都串到一起了。"),line("yanyue","看来，这次一块镇纸不够用了。"),line("tesla","对。先去上层工具间找到留影夹，再让山纹、水纹两块镇纸稳住各自的锚位。")]
		"P2-02":return [line("yanyue","工具间就在那边，可中间这一段廊道不见了。")]
		"P2-03":return [line("yanyue","留影夹……真能把一个世界的样子夹住？"),line("tesla","找带黄铜夹环的机关。它能固定机关当前的姿态，切换世界后也会保留。"),line("tesla","取回夹子后，机关恢复原来的规则。"),line("tesla","先让楼下的接物台保持在接物高度，为山纹镇纸准备一个安全落点。")]
		"P2-04-catch":return [line("yanyue","接物台留在这个高度了。现在换个世界，它也不会落下吧。")]
		"P2-04-bridge":return [line("yanyue","桥留下来了。看来，它记住的是刚才的样子。")]
		"P2-04-confirm":return [line("tesla","没错，它保留住了。")]
		"clip-limit":return [line("tesla","留影夹一次只能固定一处。取回后，原来的机关会恢复变化。")]
		"P2-05":return [line("yanyue","接住了！楼上的东西，真的能交给楼下来接。")]
		"P2-06":return [line("tesla","山纹镇纸回到楼上了。下一步，把它送到上层锚座。")]
		"P2-06-bridge":return [line("yanyue","锚座就在桥那边，得让这条路保持畅通。")]
		"P2-07":return [line("yanyue","上层稳住了，楼下的保护罩也打开了。"),line("tesla","还差水纹镇纸。把它送到下层导向井，让它接触上方的锚位。")]
		"P2-08":return [line("yanyue","一张纸，原来要两个世界一起压平。"),line("tesla","两处读数都稳定了。纸页已恢复完整，通过上层归位门，回局里归档。")]
		"idle":return [line("tesla","如果需要一起分析，按 H 联系我。")]
	return []

static func hint_cases() -> Dictionary:
	return {
		"tool":["工具间在上层旧廊后面，先观察缺失的通路。","显影能让这个世界里隐去的结构重新出现。","在上层按4显影，再走过旧廊，到工具间取得留影夹。"],
		"cage":["水纹镇纸还在下层封存架里，锁扣在它上方。","倒悬能让未固定的镇纸向上浮起。","在下层切到倒悬，让水纹镇纸上浮触碰顶部锁扣。"],
		"water-to-catch":["接物台需要先升到能接住落物的高度。","水纹镇纸可以沿下层导轨运送，接物踏板是它的一个止挡。","在下层切到冰晶，将水纹镇纸送向接物踏板。"],
		"raise-catch":["水纹镇纸到了接物踏板，但接物台还没升到位。","接物踏板需要足够的重量才能工作。","在下层切到重力，等待接物台完全升起。"],
		"fix-catch":["接物台升起来了，需要让它保持在接物高度。","留影夹能固定带黄铜夹环的机关当前姿态。","靠近下层接物台的黄铜夹环，使用留影夹固定接物台。"],
		"support":["下层已有安全落点，楼上的落料板仍被检修撑支住。","落料板的检修联锁，需要接物台先固定到位。","到上层落料口旁，操作检修撑将它解除。"],
		"drop":["检修撑已解除，山纹镇纸仍在落料板上。","更大的向下压力能作用于落料板。","在上层切到重力，让山纹镇纸压开落料板。"],
		"release-water":["山纹镇纸已经到楼下，水纹镇纸可以离开接物踏板了。","接物台由夹子固定后，不再需要水纹镇纸一直压着。","在下层切回冰晶，让水纹镇纸落回导轨。"],
		"mountain-to-lift":["山纹镇纸需要回到上层，先找到运纸吊台。","下层导轨连接着接物区、转运止挡和吊台。","在下层冰晶规则中，将山纹镇纸经中央止挡送到运纸吊台。"],
		"water-to-sluice":["山纹镇纸到了吊台，水轮还需要水闸踏板来驱动。","水纹镇纸和山纹镇纸可以分别承担运输与驱动任务。","在下层冰晶规则中，将水纹镇纸经中央止挡送到水闸踏板。"],
		"power-lift":["吊台上的山纹镇纸等待水轮将它送回上层。","水闸踏板受重压后，会驱动水轮和吊台。","在下层切到重力，等待吊台将山纹镇纸送到上层。"],
		"leave-lift":["山纹镇纸到了上层，下一站是固定中转台。","上层和下层的规则独立，运送镇纸需要低摩擦导轨。","在上层切到冰晶，将山纹镇纸从吊台推出到固定中转台。"],
		"show-bridge":["桥那边就是上层锚座，需要先保证运输通路。","显影能让木桥出现，留影夹可以保留机关当前的姿态。","在上层切到显影，让跨渠木桥重新出现。"],
		"fix-bridge":["木桥出现了，需要在运送镇纸时仍然保持通畅。","留影夹一次只能固定一处，可以从接物台取回，再用于木桥。","取回留影夹，靠近木桥的黄铜夹环，将显影木桥固定。"],
		"transport-upper":["木桥已经保留，山纹镇纸的目标是上层锚座。","冰晶适合沿导轨运送镇纸，夹住的木桥不随规则消失。","在上层切到冰晶，将山纹镇纸经桥后止挡送到上层锚座。"],
		"anchor-upper":["山纹镇纸已到上层锚座，但锚位还没有稳定。","上层锚座需要持续的向下压力。","在上层切到重力，让山纹镇纸压稳锚座。"],
		"lower-passage":["上层稳住了，下层导向井前的低位通道仍未打开。","山纹镇纸离开吊台后，吊台归底才能释放通道联锁。","在下层切到冰晶，移开压着水闸的水纹镇纸，让吊台归底。"],
		"water-to-guide":["最后一个锚位在下层导向井的上方。","低位通道已经打开，水纹镇纸可以沿导轨前往导向井。","在下层冰晶规则中，将水纹镇纸经中央止挡送到导向井。"],
		"anchor-lower":["水纹镇纸到了导向井，需要接触上方的锚位。","倒悬会使未固定的镇纸向上浮起。","在下层切到倒悬，等待水纹镇纸上浮到顶部锚位。"],
		"exit":["两层都已稳定，可以带着这次观测结果返回。","归位门在上层山纹锚座后方。","经楼梯回到上层，走入已经打开的归位门。"]
	}

static func hint_key(state:RefCounted) -> String:
	var mountain:Dictionary=state.weights[0];var water:Dictionary=state.weights[1]
	if state.lower_anchored:return "exit"
	if state.upper_anchored:
		if not state.lowpass_open:return "lower-passage"
		return "anchor-lower" if water.station=="guide" else "water-to-guide"
	if state.lifted_once and int(mountain.layer)==0:
		if mountain.station=="lift":return "leave-lift"
		if mountain.station=="anchor":return "anchor-upper"
		if state.clip_target=="bridge":return "transport-upper"
		return "fix-bridge" if state.bridge_solid() else "show-bridge"
	if state.hatch_broken and int(mountain.layer)==1:
		if water.station=="catch" and float(water.elevation)>.05:return "release-water"
		if mountain.station!="lift":return "mountain-to-lift"
		return "power-lift" if water.station=="sluice" else "water-to-sluice"
	if state.support_released:return "drop"
	if state.clip_target=="catch" and state.catch_height>=.98:return "support"
	if not state.clip_owned:return "tool"
	if not state.cage_open:return "cage"
	if water.station!="catch":return "water-to-catch"
	if state.catch_height<.98:return "raise-catch"
	return "fix-catch"
