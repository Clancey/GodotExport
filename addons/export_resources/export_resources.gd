@tool
extends EditorPlugin

func _enter_tree():
	print("Export Resources Plugin Loaded")
	add_tool_menu_item("Export Resources", export_resources)
	add_tool_menu_item("Fix Resource UID errors", fix_UUID)
	# Initialization of the plugin goes here.
	pass

func _exit_tree():
	remove_tool_menu_item("Export Resources")
	remove_tool_menu_item("Fix Resource UID errors")
	# Clean-up of the plugin goes here.
	pass

func export_resources():
	# This function is called when the menu item is clicked.
	# It should open a dialog to export resources.

	#lets give a file picker where we choose the resource
	var dialog = EditorFileDialog.new()
	dialog.title = "Select the resources to export"
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	dialog.file_selected.connect(_on_file_selected)
	dialog.files_selected.connect(_on_files_selected)
	dialog.popup_centered()
	EditorInterface.popup_dialog(dialog)
	pass
var currentExport: Array[String];

func _on_file_selected(file):
	print("on file selected");
	#this function is called when the file is selected
	#lets get the file path
	currentExport.clear()
	add_all_dependencies(file)
	process_output()
	pass

func _on_files_selected(files: PackedStringArray):
	print("on file selected");
	#this function is called when the file is selected
	#lets get the file path
	currentExport.clear()
	for file in files:
		add_all_dependencies(file)
	process_output()
	pass

func add_all_dependencies(file):
	if currentExport.has(file):
		return
	currentExport.append(file)
	var dependencies = ResourceLoader.get_dependencies(file)
	for dependency in dependencies:
		add_all_dependencies(dependency.get_slice("::", 2))
		print(dependency)
	pass
func process_output():
	#this function will process the output
	#lets create a file

	#Lets use a dialog to pick a folder
	var dialog = FileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Select a folder to save the exported resources"
	dialog.dir_selected.connect(_on_dir_selected)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.popup_centered()
	EditorInterface.popup_dialog(dialog)
	pass

func _on_dir_selected(dir):
	#we will loop through each file in currentExport and copy them to the new folder
	for file in currentExport:
		#lets get the file name
		var fileName = file.get_file()
		#lets get the file path
		var filePath = file.get_base_dir()
		if filePath.find("res://") == 0:
			filePath = filePath.substr(6)
		#lets get the new file path
		var newFilePath = dir + "/" + filePath
		var newFile = newFilePath + "/" + fileName
		#lets copy the file
		DirAccess.make_dir_recursive_absolute(newFilePath)
		var directory = DirAccess.copy_absolute(file, newFile)
		print(newFile)
	print(dir)
	pass

func checkDependencies(file: String):
	# print("Checking %s" % file)
	var dependencies = ResourceLoader.get_dependencies(file)
	for dep in dependencies:
		var uid = dep.get_slice("::", 0)
		var path = dep.get_slice("::", 2)
		if path == "" or not uid.begins_with("uid://"):
			continue # Skip empty paths and uid
		# Verify the path matches case sensitivity to the actual path
		if !file_exists(path):
			print("Path does not exist: %s" % path)
			continue
		var iuid = ResourceLoader.get_resource_uid(path)
		if iuid == -1:
			continue
		var import_uid = ResourceUID.id_to_text(iuid)
		if import_uid and import_uid != uid:
			print("UID mismatch found for %s: expected %s, found %s" % [path, uid, import_uid])
			var loader = ResourceLoader.load(file)
			ResourceSaver.save(loader, file)
	pass

func fix_UUID():
	var tscn_files = find_tscn_files("res://")
	for tscn_file in tscn_files:
		checkDependencies(tscn_file);
	print("Done fixing UID errors")
	pass

func find_tscn_files(path: String) -> Array:
	var result = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var file_path = path + "/" + file_name
				if dir.current_is_dir():
					result += find_tscn_files(file_path)
				elif file_name.ends_with(".tscn") or file_name.ends_with(".tres") or file_name.ends_with(".mesh"):
					result.append(file_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	return result


func file_exists(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		file.close()
		return true
	return false
