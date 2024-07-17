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

func checkMesh(file: String):
	# print("Checking %s" % file)
	var dependencies = ResourceLoader.get_dependencies(file)
	for dep in dependencies:
		var uid = dep.get_slice("::", 0)
		var path = dep.get_slice("::", 2)
		if path == "":
			print("Empty path found for %s" % uid)
			continue # Skip empty paths
		path = path + ".import"
		# Verify the path matches case sensitivity to the actual path
		if !file_exists(path):
			print("Path does not exist: %s" % path)
			continue
		
		var import_uid = parse_import_file(path)
		if import_uid and import_uid != uid:
			print("UID mismatch found for %s: expected %s, found %s" % [path, uid, import_uid])
			var loader = ResourceLoader.load(file)
			ResourceSaver.save(loader, file)
	pass

func fix_UUID():
	var tscn_files = find_tscn_files("res://")
	for tscn_file in tscn_files:
		if (tscn_file.ends_with(".mesh")):
			checkMesh(tscn_file)
		else:
			# print("Checking %s" % tscn_file)
			var resources = parse_tscn(tscn_file)
			for resource in resources:
				var import_path = resource.path + ".import"
				if file_exists(import_path):
					var import_uid = parse_import_file(import_path)
					var uid = resource.uid
					if import_uid and import_uid != uid:
						print("Fixing UUID for %s" % tscn_file)
						print("Old UUID: %s" % uid)
						print("New UUID: %s" % import_uid)
						# Replace the old UUID with the new one
						var fixFile = FileAccess.open(tscn_file, FileAccess.READ_WRITE)
						if not fixFile:
							print("Failed to open file: %s" % fixFile)
							return
						var contents = fixFile.get_as_text()
						contents = contents.replace(uid, import_uid)
						fixFile.store_string(contents)
						fixFile.close()

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

func parse_tscn(tscn_path: String) -> Array:
	var file = FileAccess.open(tscn_path, FileAccess.READ)
	if not file:
		print("Failed to open file: %s" % tscn_path)
		return []
	
	var resources = []
	var is_ext_resource = false

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		var current_uid = ""
		var current_path = ""
		if line.begins_with("[ext_resource"):
			is_ext_resource = true
			var items = line.split(" ")
			for item in items:
				if item.begins_with("uid"):
					current_uid = item.split("=")[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
				elif item.find("path") != - 1:
					current_path = item.split("=")[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
			if current_uid and current_path:
				# print("found resource: %s, %s" % [current_uid, current_path])
				resources.append({"uid": current_uid, "path": current_path})
				current_uid = ""
				current_path = ""
	
	file.close()
	return resources

func file_exists(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		file.close()
		return true
	return false

func parse_import_file(import_path: String) -> String:
	var file = FileAccess.open(import_path, FileAccess.READ)
	if not file:
		print("Failed to open import file: %s" % import_path)
		return ""
	
	var import_uid = ""

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.begins_with("uid"):
			import_uid = line.split("=")[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
			break
	
	file.close()
	return import_uid