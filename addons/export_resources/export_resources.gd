@tool
extends EditorPlugin


func _enter_tree():
	print("Export Resources Plugin Loaded")
	add_tool_menu_item("Export Resources", export_resources)
	# Initialization of the plugin goes here.
	pass


func _exit_tree():
	remove_tool_menu_item("Export Resources")
	# Clean-up of the plugin goes here.
	pass

func export_resources():
	# This function is called when the menu item is clicked.
	# It should open a dialog to export resources.

	#lets give a file picker where we choose the resource
	var dialog = EditorFileDialog.new()
	dialog.title = "Select the resources to export"
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES 
	dialog.file_selected.connect( _on_file_selected)
	dialog.files_selected.connect( _on_files_selected)
	dialog.popup_centered()
	EditorInterface.popup_dialog(dialog)
	pass
var currentExport:Array[String];

func _on_file_selected(file):
	print("on file selected");
	#this function is called when the file is selected
	#lets get the file path
	currentExport.clear()
	add_all_dependencies(file)
	process_output()
	pass

func _on_files_selected(files:PackedStringArray):
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
	dialog.dir_selected.connect( _on_dir_selected)
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
		var directory = DirAccess.copy_absolute(file,newFile)
		print(newFile)
	print(dir)
	pass