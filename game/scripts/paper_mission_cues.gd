extends RefCounted
## Reviewed semantic targets per line. The anchor locates a word timing, never
## guesses which scene object a generic word such as "踏板" means.
const Lines=preload("res://scripts/paper_mill_lines.gd")
const ITEMS={
	"tool":["clip","留影夹","夹住机关，保留当前姿态"],
	"w0":["mountain","山纹镇纸","沿轨运送，以重量压稳锚座"],
	"w1":["water","水纹镇纸","运送至踏板，驱动水路机关"],
	"catch_pad":["catch_pad","接物踏板","受重压后升起接物台"],
	"sluice_pad":["sluice_pad","水闸踏板","受重压后驱动水轮与吊台"],
	"catch":["ring","接物台夹环","夹住接物台，保留当前高度"],
	"bridge":["ring","木桥夹环","夹住显影木桥，保留跨渠通路"],
	"lift":["lift","运纸吊台","跨层提升，停靠后才能进出"],
	"upper_anchor":["upper_anchor","山纹锚座","山纹镇纸重压，稳定上层"],
	"lower_anchor":["lower_anchor","水纹锚位","水纹镇纸上浮，接触高处锚位"],
	"corridor":["","显影旧廊","仅上层显影时有支撑"],
	"support":["","落料板检修撑","接物台固定后才能解除"],
	"exit":["","归位门","双锚稳定后返回观察局"]}

static func cue(objects:Array,anchor:String,exhibit:=false) -> Dictionary:
	return {"objects":objects,"anchor":anchor,"exhibit":exhibit}

static func specs(node:String,index:int,context:String,first_target:String) -> Array:
	match node:
		"P2-01":
			if index==1:return [cue(["w0","w1"],"镇纸")]
			if index==2:return [cue(["tool"],"留影夹",true),cue(["w0","w1"],"山纹",true)]
		"P2-02":return [cue(["corridor"],"廊道")]
		"P2-03":
			match index:
				0:return [cue(["tool"],"留影夹",true)]
				1:return [cue(["catch","bridge"],"黄铜夹环",true)]
				2:return [cue(["tool"],"夹子")]
				3:return [cue(["catch"],"接物台",true),cue(["w0"],"山纹镇纸")]
		"P2-04-catch":return [cue(["catch"],"接物台")]
		"P2-04-bridge":return [cue(["bridge"],"桥")]
		"P2-04-confirm":return [cue([first_target] if first_target in ["catch","bridge"] else [],"保留")]
		"clip-limit":return [cue(["tool"],"留影夹")]
		"P2-05":return [cue(["catch","w0"],"接住")]
		"P2-06":return [cue(["w0"],"山纹镇纸"),cue(["upper_anchor"],"上层锚座",true)]
		"P2-06-bridge":return [cue(["bridge"],"桥"),cue(["upper_anchor"],"锚座")]
		"P2-07":
			if index==0:return [cue(["upper_anchor"],"上层")]
			return [cue(["w1"],"水纹镇纸"),cue(["lower_anchor"],"导向井",true)]
		"P2-08":return [cue(["upper_anchor","lower_anchor"],"两处") ,cue(["exit"],"归位门")] if index==1 else []
	if node.begins_with("hint:"):
		match context:
			"tool":return [cue(["corridor"],"通路" if index==0 else "显影"),cue(["tool"],"留影夹",true)]
			"cage":return [cue(["w1"],"水纹镇纸",true)]
			"water-to-catch","raise-catch":return [cue(["w1"],"水纹镇纸"),cue(["catch_pad"],"接物踏板",true),cue(["catch"],"接物台")]
			"fix-catch":return [cue(["catch"],"接物台",true)]
			"support","drop":return [cue(["support"],"检修撑"),cue(["w0"],"山纹镇纸")]
			"release-water":return [cue(["w1"],"水纹镇纸"),cue(["catch_pad"],"接物踏板")]
			"mountain-to-lift","leave-lift":return [cue(["w0"],"山纹镇纸"),cue(["lift"],"吊台",true)]
			"water-to-sluice","power-lift":return [cue(["sluice_pad"],"水闸踏板",true),cue(["lift"],"吊台",true),cue(["w1"],"水纹镇纸")]
			"show-bridge","fix-bridge","transport-upper":return [cue(["bridge"],"木桥",true),cue(["w0"],"山纹镇纸")]
			"anchor-upper":return [cue(["upper_anchor"],"锚座",true),cue(["w0"],"山纹镇纸")]
			"lower-passage":return [cue(["lift"],"吊台",true)]
			"water-to-guide","anchor-lower":return [cue(["lower_anchor"],"锚位",true),cue(["w1"],"水纹镇纸")]
			"exit":return [cue(["exit"],"归位门")]
	return []

static func plan(line:Dictionary,node:String,index:int,context:String,first_target:String,record:Dictionary,duration:float) -> Array[Dictionary]:
	var result:Array[Dictionary]=[];var text:String=line.text
	for spec:Dictionary in specs(node,index,context,first_target):
		if spec.objects.is_empty():continue
		var offset:=text.find(spec.anchor)
		if offset<0:continue # A higher hint level need not name every earlier object.
		var timing:=word_time(record,spec.anchor)
		var estimated:=timing<0
		if estimated:timing=float(offset)/maxi(1,text.length())*duration
		var item:=spec.duplicate(true);item["at"]=timing;item["timing_source"]="reading_estimate" if estimated else "recorded_word_boundary"
		result.append(item)
	result.sort_custom(func(a,b):return a.at<b.at)
	return result

static func word_time(record:Dictionary,anchor:String) -> float:
	var joined:="";var starts:Array[float]=[]
	for word:Dictionary in record.get("words",[]):
		for character in str(word.text):
			joined+=character;starts.append(float(word.start))
	var at:=joined.find(anchor)
	return starts[at] if at>=0 and at<starts.size() else -1.0
