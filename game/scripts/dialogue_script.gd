extends RefCounted
## Reviewed screenplay. Gameplay segments expire when the player advances.
static func line(who: String,text: String,style: String="subtitle",cue: String="",exhibit: String="",visual: String="") -> Dictionary:
	return {"speaker":who,"text":text,"style":style,"cue":cue,"exhibit":exhibit,"visual":visual}

static func opening() -> Array:
	return [
		line("tesla","衍月？欢迎来到世界检查局。我是特斯拉，今天由我带你熟悉工作。","story"),
		line("yanyue","我来的时候，看见外面的楼梯通向了两片不同的天空。","story"),
		line("tesla","看来你已经见过我们要处理的问题了。","story"),
		line("yanyue","那不是这里的建筑风格？","story"),
		line("tesla","至少不在设计图上。","story"),
		line("tesla","平行世界通常各走各的路。但有些时候，它们会靠得太近，甚至重叠在一起。","story","","","overlap"),
		line("tesla","同一个地方，会同时出现几套不同的规则。物品受哪一套影响，也就变得不稳定。","story","","","overlap"),
		line("yanyue","所以，我们要把它们分开？","story"),
		line("tesla","先锚定，让每个世界找回自己的位置。我们用这个——镇纸。","story","","paperweight"),
		line("yanyue","压住纸的那个镇纸？","story"),
		line("tesla","原理很接近。只不过这里要压稳的，是世界。","story"),
		line("tesla","复杂的重叠区先交给其他检查员。你从一处简单的开始。","story"),
		line("tesla","我们把它隔离成了校准室。里面的界缝还没封合，但变化范围可控，适合练习。","story"),
		line("yanyue","你会一起进去吗？","story"),
		line("tesla","我在这里看着读数，也能通过通讯听见你。遇到问题，随时问。","story"),
		line("tesla","先到星系仪旁边，找出那片区域。","story")
	]

static func debrief() -> Array:
	return [
		line("tesla","欢迎回来，衍月。第一份现场记录已经归档。","story"),
		line("yanyue","出发前，我以为你会给我一套修理工具。","story"),
		line("tesla","结果呢？","story"),
		line("yanyue","你给了我一块镇纸，和三个不太讲道理的世界。","story"),
		line("tesla","它们各有各的道理。麻烦出在碰到一起的时候。","story"),
		line("yanyue","所以先看清规则，再想办法让它们配合。","story"),
		line("tesla","正是如此。","story"),
		line("yanyue","下一处，也会这么简单吗？","story"),
		line("tesla","下一处的镇纸，未必还肯这样滑、这样升。到现场再判断。","story"),
		line("yanyue","看来这份工作，确实不能只看说明书。","story"),
		line("tesla","说明书可以带着。记得抬头看看世界。","story"),
		line("tesla","准备好了，就到星系仪旁边来。","story")
	]

static func selection(expanded: bool) -> Array:
	if not expanded:return [line("yanyue","要去的地方，就在这块水晶里面？"),line("tesla","它记录着各处区域的坐标。轻触水晶，让坐标展开。")]
	return [line("tesla","找到了。01号，新手校准室。"),line("tesla","选中它，星系仪会送你过去。"),line("yanyue","第一次上班，从修补世界开始。"),line("tesla","先修补一小块。")]

static func tutorial(stage: int,world: int=0,replay: bool=false) -> Array:
	match stage:
		0:
			var lines: Array=[]
			if not replay:lines=[
				line("tesla","通讯正常。听得见吗？"),line("yanyue","听得见。这里看起来……比外面安静。"),
				line("tesla","重叠不一定会发出声音。看导轨上的镇纸，还有那三处黄铜机关。"),
				line("tesla","先定星位，再压月痕，最后封界缝。这一片区域就能稳定下来。","subtitle","","","anchors"),
				line("yanyue","一块镇纸，要做三件事？"),line("tesla","看你怎么利用它。")]
			else:lines=[line("tesla","还是这三个步骤。试着自己完成，我在这里看着。")]
			lines.append_array([
				line("tesla","这里重叠着三个世界。你可以切换，让其中一个世界的规则生效。","light","1 / 2 / 3"),
				line("tesla","现在是冰晶世界。导轨的摩擦很小，镇纸受到推动后，会一直滑到挡块前。" if world==0 else "先试试冰晶世界。那里的导轨摩擦很小，适合运送镇纸。","light","1  冰晶","","law-ice"),
				line("yanyue","那我只需要推它一下？","light"),
				line("tesla","试试看。先观察它会停在哪里。","light","E / 右键推动")])
			return lines
		1:return [
			line("yanyue","到地方了。星位怎么没亮？","light"),
			line("tesla","位置对了，重量还不够。","light"),
			line("tesla","切到重力世界。同一块镇纸在那里会变得更重，足以压下踏板。","light","2  重力","","law-heavy"),
			line("yanyue","切换以后，它还会留在这里吗？","light"),
			line("tesla","会。改变的是它遵循的规则，位置会接着保留。","light","2  重力")]
		2:return [
			line("yanyue","星位亮了，挡块也打开了。","aside","","","law-heavy"),
			line("tesla","第一处坐标已经锁定。接下来找月痕，就在导轨尽头的上方。"),
			line("yanyue","换回去，刚才的星位会松开吗？"),line("tesla","不会。星位机关已经锁住了，你可以继续。"),
			line("tesla","先把镇纸运到月痕正下方。"),line("yanyue","重力世界里这么沉，恐怕推不动。"),
			line("tesla","那就借用你已经试过的规则。")]
		3:return [
			line("yanyue","下面到了。可月痕在那么高的地方。","light"),
			line("tesla","还记得第三个世界吗？倒悬世界的重力朝上。","light","3  倒悬","","law-inverted"),
			line("yanyue","让镇纸自己升上去？","light"),line("tesla","对。切过去，看着它沿导向架上升。","light","3  倒悬")]
		4:return [
			line("yanyue","月痕也亮了。可那道裂缝还在。"),
			line("tesla","星位确定位置，月痕校准重叠的边界。现在还差最后一步，把界缝封住。"),
			line("tesla","看镇纸下面的踏板，它和界缝上刻着相同的纹路。"),
			line("yanyue","要让镇纸落回来，压住它？"),line("tesla","对，而且要有足够的重量。"),
			line("yanyue","重力世界。"),line("tesla","试试。这一次，由你来完成。")]
		5:return [
			line("yanyue","裂缝合上了。"),line("tesla","读数稳定，三处校准全部完成。做得不错。","aside"),
			line("yanyue","原来同一块镇纸，真的能做完这三件事。"),
			line("tesla","你已经知道什么时候让它滑，什么时候让它升，什么时候让它压住了。"),
			line("tesla","保持现在的世界，让镇纸继续压着踏板。通过归位门回来。"),
			line("yanyue","它要一直留在这里？"),line("tesla","等你离开，检查局会接手后续的锚定。你已经完成现场工作了。")]
	return []
