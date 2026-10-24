extends RefCounted
## Application-wide audio preferences, separate from the three story records.
var path := "user://audio_settings.cfg"
var volume := 100.0
var audible_volume := 100.0
var channels: Dictionary={"music":100.0,"sfx":100.0,"dialogue":100.0}
var motion_enabled:=true

func load_settings() -> void:
	if path.is_empty():return
	var config:=ConfigFile.new()
	if config.load(path)!=OK:return
	var motion:Variant=config.get_value("visual","motion_enabled",true)
	if motion is bool:motion_enabled=motion
	var stored: Variant=config.get_value("audio","volume",100.0)
	var previous: Variant=config.get_value("audio","audible_volume",100.0)
	if (stored is float or stored is int) and is_finite(float(stored)):
		volume=clampf(float(stored),0.0,100.0)
	if (previous is float or previous is int) and is_finite(float(previous)):
		audible_volume=clampf(float(previous),1.0,100.0)
	if volume>0:audible_volume=volume
	for channel in channels:
		var value: Variant=config.get_value("audio",channel,100.0)
		if (value is float or value is int) and is_finite(float(value)):
			channels[channel]=clampf(float(value),0.0,100.0)

func save_settings() -> Error:
	if path.is_empty():return OK
	var error:=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error!=OK:return error
	var config:=ConfigFile.new()
	config.set_value("visual","motion_enabled",motion_enabled)
	config.set_value("audio","volume",volume)
	config.set_value("audio","audible_volume",audible_volume)
	for channel in channels:config.set_value("audio",channel,channels[channel])
	return config.save(path)
