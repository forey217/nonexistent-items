extends Node
var app: Node
var results: Array[Dictionary]=[]
var failures:=0
var directory:=""

class FailingBook extends "res://scripts/save_book.gd":
	var fail_backup:=false
	var fail_metadata:=false
	func _erase_file(path: String) -> Error:
		if fail_backup and path.ends_with("record_1.json.bak"):return ERR_FILE_NO_PERMISSION
		return super._erase_file(path)
	func _commit(path: String,data: Dictionary) -> bool:
		if fail_metadata and path.ends_with("recent.json"):return false
		return super._commit(path,data)

func frames(count: int) -> void:
	for i in range(count):await get_tree().physics_frame

func until(condition: Callable,limit:=1200) -> bool:
	for i in range(limit):
		await frames(1)
		if condition.call():return true
	return false

func check(title: String,passed: bool) -> void:
	results.append({"test":title,"passed":passed})
	if not passed:failures+=1;push_error("SAVE_DELETE_FAILED "+title)

func key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
		get_viewport().push_input(event,true)

func click(at: Vector2) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		get_viewport().push_input(event,true)

func put(path: String,value: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(value);file.close()

func bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func absent(book: RefCounted,slot: int) -> bool:
	var path: String=book.path_for(slot)
	return [path,path+".bak",path+".tmp"].all(func(p):return not FileAccess.file_exists(p))

func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func storage_checks() -> void:
	var book:=FailingBook.new();book.directory=app.save_book.directory.path_join("io-probes")
	var one: Dictionary=book.create(1);book.write(1,one);book.create(2);book.remember(1)
	put(book.path_for(1)+".tmp","interrupted write")
	put(book.directory.path_join("settings.cfg"),"preserve settings")
	var other:=bytes(book.path_for(2))
	check("delete_removes_main_backup_and_temporary",book.delete_record(1) and absent(book,1))
	check("deletion_preserves_other_slot_and_settings",bytes(book.path_for(2))==other and FileAccess.get_file_as_string(book.directory.path_join("settings.cfg"))=="preserve settings")
	check("recent_selection_moves_to_remaining_record",book.last_slot()==2)
	var reader=preload("res://scripts/save_book.gd").new();reader.directory=book.directory
	check("new_reader_cannot_recover_deleted_backup",reader.inspect(1).status=="empty")
	check("deleted_slot_can_be_created_fresh",not book.create(1).is_empty() and book.inspect(1).data.checkpoint==0)
	check("out_of_range_delete_cannot_touch_records",not book.delete_record(0) and not book.delete_record(4) and book.inspect(1).status=="ready")
	book.write(1,book.inspect(1).data);book.remember(1)
	var original:=bytes(book.path_for(1));var backup:=bytes(book.path_for(1)+".bak")
	var recent:=bytes(book.directory.path_join("recent.json"))
	book.fail_backup=true
	check("partial_delete_failure_rolls_back_main_and_backup",not book.delete_record(1) and bytes(book.path_for(1))==original and bytes(book.path_for(1)+".bak")==backup)
	check("failed_delete_preserves_recent_selection",bytes(book.directory.path_join("recent.json"))==recent)
	book.fail_backup=false;book.fail_metadata=true
	check("metadata_failure_rolls_back_entire_record",not book.delete_record(1) and bytes(book.path_for(1))==original and bytes(book.path_for(1)+".bak")==backup and bytes(book.directory.path_join("recent.json"))==recent)
	book.fail_metadata=false;book.delete_record(1)
	put(book.path_for(3),"broken record");put(book.path_for(3)+".bak","broken backup")
	check("damaged_records_can_be_deleted",book.inspect(3).status=="damaged" and book.delete_record(3) and absent(book,3))
	put(book.path_for(1)+".bak",JSON.stringify(one))
	check("backup_only_record_is_deleted_without_resurrection",book.inspect(1).status=="ready" and book.delete_record(1) and reader.inspect(1).status=="empty")
	put(book.path_for(3)+".tmp","temporary")
	check("orphan_temporary_file_is_removed",book.delete_record(3) and absent(book,3))
	book.create(1);original=bytes(book.path_for(1))
	DirAccess.make_dir_absolute(book.path_for(1)+".bak")
	check("directory_collision_fails_before_deleting_anything",not book.delete_record(1) and bytes(book.path_for(1))==original)
	DirAccess.remove_absolute(book.path_for(1)+".bak")

func open_picker() -> void:
	app.current.motion_enabled=false;app.current.begin()
	check("save_picker_opens",await until(func():return is_instance_valid(app.save_picker) and app.save_picker.ready_for_input()))
	await frames(2)

func open_delete(slot: int) -> void:
	var card=app.save_picker.cards[slot-1]
	click(card.to_global(card.DELETE_RECT.get_center()));await frames(2)
	check("trash_opens_pinned_modal_without_entering_game",is_instance_valid(app.save_picker.delete_dialog) and app.save_picker.delete_target==slot and not app.save_picker.busy and app.current.has_signal("start_requested"))

func wait_ready() -> void:
	await until(func():return app.save_picker.ready_for_input());await frames(2)

func run(flow: Node) -> void:
	app=flow
	var args:=OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--artifacts="):directory=arg.trim_prefix("--artifacts=")
	if not Array(args).any(func(arg):return arg.begins_with("--save-dir=")):
		push_error("Deletion tests require isolated --save-dir");get_tree().quit(1);return
	if directory.is_empty():directory=app.save_book.directory.path_join("reports")
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(5)
	var settings_path:=ProjectSettings.globalize_path("user://audio_settings.cfg")
	var settings_before:=bytes(settings_path)
	if "--save-delete-reopen" in args:
		await open_picker()
		check("fresh_process_keeps_deleted_slots_empty",app.save_book.inspect(1).status=="empty" and app.save_book.inspect(3).status=="empty" and absent(app.save_book,1) and absent(app.save_book,3))
		check("fresh_process_preserves_other_record",app.save_book.inspect(2).status=="ready" and app.save_book.last_slot()==2)
		check("only_existing_record_has_delete_button",not app.save_picker.cards[0].delete_button.visible and app.save_picker.cards[1].delete_button.visible and not app.save_picker.cards[2].delete_button.visible)
		await snapshot("05-reopened-records");await finish();return
	await storage_checks()
	var book=app.save_book
	book.create(1)
	var two: Dictionary=book.create(2);two.scene="tutorial";two.checkpoint=2;book.write(2,two);book.remember(2)
	put(book.path_for(2)+".tmp","unfinished write");put(book.path_for(3),"unreadable record")
	var one_before:=bytes(book.path_for(1));var two_before:=bytes(book.path_for(2))
	await open_picker()
	check("ready_and_damaged_cards_offer_delete",app.save_picker.cards.all(func(card):return card.delete_button.visible))
	check("delete_targets_are_at_least_32_pixels",app.save_picker.cards.all(func(card):return card.DELETE_RECT.size.x>=32 and card.DELETE_RECT.size.y>=32))
	await snapshot("01-delete-buttons")
	await open_delete(2)
	check("keep_record_has_default_keyboard_focus",app.save_picker.delete_dialog.cancel_button.has_focus())
	await snapshot("02-delete-confirmation")
	key(KEY_ENTER);await wait_ready()
	check("default_enter_cancels_without_modifying_save",not is_instance_valid(app.save_picker.delete_dialog) and bytes(book.path_for(2))==two_before)
	await open_delete(2)
	var old_selected: int=app.save_picker.selected
	click(app.save_picker.cards[0].to_global(Vector2(0,-20)));key(KEY_RIGHT)
	check("modal_blocks_background_entry_and_selection",app.save_picker.selected==old_selected and app.save_picker.delete_target==2 and not app.save_picker.busy)
	key(KEY_ESCAPE);await wait_ready()
	check("escape_cancels_without_modifying_save",bytes(book.path_for(2))==two_before)
	await open_delete(2)
	click(app.save_picker.delete_dialog.cancel_button.get_global_rect().get_center());await wait_ready()
	check("mouse_keep_record_cancels",not is_instance_valid(app.save_picker.delete_dialog) and bytes(book.path_for(2))==two_before)
	# Simulate returning from an active profile, including stale progress in memory.
	app.active_slot=2;app.active_record=two.duplicate(true);app.play_seconds=87;app.completed_runs=3
	await open_delete(2)
	var confirm_at: Vector2=app.save_picker.delete_dialog.confirm_button.get_global_rect().get_center()
	click(confirm_at);click(confirm_at);await wait_ready()
	check("confirmed_delete_clears_only_pinned_slot",absent(book,2) and bytes(book.path_for(1))==one_before and book.inspect(3).status=="damaged")
	check("deleted_active_profile_is_cleared_from_memory",app.active_slot==0 and app.active_record.is_empty() and app.play_seconds==0 and app.completed_runs==0)
	check("success_updates_card_without_reentering_or_replaying",app.save_picker.cards[1].record.status=="empty" and not app.save_picker.cards[1].delete_button.visible and not app.save_picker.busy and app.save_picker.age>0.3)
	check("success_shows_target_number",app.save_picker.caption.text=="存档 02 已删除")
	await snapshot("03-record-deleted")
	app._save_progress(true);await frames(12)
	check("autosave_cannot_recreate_deleted_profile",absent(book,2))
	app.save_picker.select(3);key(KEY_DELETE);await frames(2)
	check("keyboard_delete_opens_damaged_record",is_instance_valid(app.save_picker.delete_dialog) and app.save_picker.delete_target==3 and app.save_picker.delete_dialog.record.status=="damaged")
	await snapshot("04-damaged-record")
	key(KEY_RIGHT);key(KEY_ENTER);await wait_ready()
	check("keyboard_confirm_deletes_damaged_record",absent(book,3) and app.save_picker.cards[2].record.status=="empty")
	book.create(2);book.remember(2);app.save_picker.refresh();await frames(2)
	var failing:=FailingBook.new();failing.directory=book.directory;failing.fail_metadata=true
	app.save_picker.book=failing
	var intact:=bytes(book.path_for(2))
	await open_delete(2);key(KEY_RIGHT);key(KEY_ENTER);await frames(3)
	check("failed_delete_keeps_modal_and_card_intact",is_instance_valid(app.save_picker.delete_dialog) and app.save_picker.delete_dialog.error_label.text.contains("删除失败") and app.save_picker.cards[1].record.status=="ready" and bytes(book.path_for(2))==intact)
	check("failure_restores_keep_record_focus",app.save_picker.delete_dialog.cancel_button.has_focus() and not app.save_picker.delete_dialog.confirm_button.disabled)
	await snapshot("06-delete-failure")
	key(KEY_ESCAPE);await wait_ready();app.save_picker.book=book
	# Enter via card body, return, delete actual active record, then recreate an empty card.
	click(app.save_picker.cards[0].to_global(Vector2(0,-20)))
	check("whole_existing_card_still_enters",await until(func():return app.save_picker==null and not app.menu_revealing and not app.current.has_signal("start_requested")))
	check("existing_card_restores_correct_profile",app.active_slot==1)
	key(KEY_F10);await frames(8);await open_picker();await open_delete(1)
	key(KEY_RIGHT);key(KEY_ENTER);await wait_ready()
	check("delete_after_return_clears_real_active_record",absent(book,1) and app.active_slot==0)
	click(app.save_picker.cards[2].to_global(Vector2(0,-20)))
	check("empty_card_can_start_fresh_after_delete",await until(func():return app.save_picker==null and not app.menu_revealing and app.active_slot==3))
	check("recreated_profile_has_fresh_story",book.inspect(3).status=="ready" and not app.dialogue.intro_seen and app.completed_runs==0)
	key(KEY_F10);await frames(8);await open_picker();await open_delete(3)
	key(KEY_RIGHT);key(KEY_ENTER);await wait_ready()
	book.remember(2)
	check("other_profile_survives_full_delete_and_recreate_flow",book.inspect(2).status=="ready" and bytes(book.path_for(2))==intact)
	check("global_audio_preferences_are_unchanged",bytes(settings_path)==settings_before)
	await finish()

func finish() -> void:
	var report:={"checks":results.size(),"failures":failures,"results":results}
	put(directory.path_join("save-delete-report.json"),JSON.stringify(report,"\t"))
	print("SAVE_DELETE_REPORT ",JSON.stringify({"checks":results.size(),"failures":failures}))
	await app.shutdown_audio();get_tree().quit(0 if failures==0 else 1)
