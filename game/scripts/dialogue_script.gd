extends RefCounted
## Audio IDs depend on speaker and exact text, never a mutable page index.
static func line(who: String,text: String,style: String="subtitle",cue: String="",exhibit: String="",visual: String="") -> Dictionary:
	return {"id":voice_id(who,text),"speaker":who,"text":text,"style":style,"cue":cue,"exhibit":exhibit,"visual":visual}

static func voice_id(who: String,text: String) -> String:
	return "vo_%s_%s"%[who,(who+"\n"+text).sha256_text().left(16)]

static func opening() -> Array:
	return [
		line("tesla","衍月，欢迎来到世界观察局。我是特斯拉，今天由我带你熟悉工作。","story"),
		line("yanyue","外面的楼梯通向两片天空……也是设计的一部分？","story"),
		line("tesla","至少不在设计图上。有些平行世界靠得太近，规则就混在一起了。","story","","","overlap"),
		line("yanyue","那该怎么修？","story"),
		line("tesla","先用这个——镇纸，把它们压稳。","story","","paperweight"),
		line("yanyue","压纸的镇纸？","story"),
		line("tesla","对，只不过这里压稳的是世界。","story"),
		line("tesla","去星系仪选01号校准室。我会通过通讯带你。","story")
	]

static func debrief() -> Array:
	return [
		line("tesla","欢迎回来。第一份观测记录已经归档。","story"),
		line("yanyue","一块镇纸，三个不讲道理的世界。原来还能这么用。","story"),
		line("tesla","世界各有各的道理。你学会让它们配合了。","story"),
		line("yanyue","看来这份工作，确实不能只看说明书。","story"),
		line("tesla","可以带着。记得抬头看看世界。","story")
	]

static func selection(expanded: bool) -> Array:
	# Keep the existing recorded line/voice ID while removing duplicate instructions.
	if not expanded:return [line("tesla","轻触水晶，让坐标展开。")]
	return []

static func tutorial(stage: int,world: int=0,replay: bool=false) -> Array:
	match stage:
		0:
			var start:=line("tesla","先试试导轨上的镇纸。靠近它，右键或按E推一下；冰晶导轨摩擦很小。","subtitle","E / 右键互动","","law-ice")
			if world!=0:start=line("tesla","先试试冰晶世界。靠近导轨上的镇纸，右键或按E推一下。","subtitle","1 冰晶 · E / 右键互动","","law-ice")
			if replay:start=line("tesla","还是这三个步骤。右键或E互动，试着自己完成，我在这里看着。")
			return [start,
				line("tesla","1、2、3切换世界规则。镇纸的位置会保留。","light","1 / 2 / 3"),
				line("tesla","先定星位，再压月痕，最后封界缝。","subtitle","","","anchors")]
		1:return [
			line("yanyue","到地方了。星位怎么没亮？","light"),
			line("tesla","位置对了，重量还不够。","light"),
			line("tesla","切到重力世界。同一块镇纸会变重，压下踏板；位置会保留。","light","2 重力","","law-heavy")]
		2:return [
			line("yanyue","星位亮了，挡块也打开了。","aside","","","law-heavy"),
			line("tesla","星位已经锁定。下一个目标是月痕印座，在导轨尽头的上方。")]
		3:return [
			line("yanyue","月痕在上面，镇纸却还在下面。"),
			line("tesla","看看现有的规则，有没有办法让镇纸接近它。","subtitle")]
		4:return [
			line("tesla","月痕稳了。现在看它下方的封界踏板。"),
			line("yanyue","踏板和界缝刻着同样的纹路……它们连在一起。")]
		5:return [
			line("yanyue","裂缝合上了。"),
			line("tesla","读数稳定，三处校准全部完成。","aside"),
			line("tesla","保持锚定，通过归位门回来。后续由世界观察局接手。")]
	return []

static func event(name: String) -> Array:
	match name:
		"after-skip":return [line("tesla","准备好了，就到星系仪旁边来。")]
		"reminder":return [line("tesla","先到星系仪旁边，找出那片区域。","story")]
		"reset":return [line("tesla","现场已复位。右键或E互动镇纸，从冰晶导轨开始。","light","1 冰晶 · E / 右键互动")]
		"archive":return [line("tesla","现场校准完成。开始归档。")]
		"gate-lost":return [line("yanyue","门又关了。"),line("tesla","封界踏板需要持续受压。观察镇纸现在的状态。","light")]
		"gate-restored":return [line("tesla","归位门已经稳定。保持锚定，通过归位门回来。")]
		"first-push":return [line("yanyue","真的只推了一下……它自己滑过去了。","subtitle","","","law-ice")]
		"first-float":return [line("yanyue","纸片也飘起来了……我怎么还站在地上？","subtitle","","","law-inverted"),line("tesla","观察员的靴子有固定装置。工作时，你得先站得稳。")]
		"early-float":return [line("yanyue","升起来了，可这里没有印座。"),line("tesla","月痕在导轨尽头的上方。先观察位置。","light")]
		"idle":return [line("tesla","需要帮助时，按 H 联系特斯拉。","light","H 联系特斯拉")]
	return []

static func notices() -> Array[String]:
	return ["出口还不稳定。先完成当前的校准，我会在这里等你。","它现在太重，无法推动。看看现有的规则。","先让它接触导轨，才能推动。"]
