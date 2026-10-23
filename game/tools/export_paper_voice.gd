extends SceneTree
const Lines=preload("res://scripts/paper_mill_lines.gd")
func _initialize() -> void:
	var items:Dictionary={}
	for node:String in Lines.NODES:
		for line:Dictionary in Lines.sequence(node):
			if not items.has(line.id):items[line.id]={"id":line.id,"speaker":line.speaker,"display_text":line.text,"file":line.id+".mp3","nodes":[]}
			items[line.id].nodes.append(node)
	for key:String in Lines.hint_cases():
		for i in range(3):
			var line:Dictionary=Lines.line("tesla",Lines.hint_cases()[key][i])
			if not items.has(line.id):items[line.id]={"id":line.id,"speaker":line.speaker,"display_text":line.text,"file":line.id+".mp3","nodes":[]}
			items[line.id].nodes.append("H-"+key+"-"+str(i+1))
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if output.is_empty():quit(2);return
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"items":items.values()},"\t"));file.close()
	print("PAPER_LINES ",items.size());quit()
