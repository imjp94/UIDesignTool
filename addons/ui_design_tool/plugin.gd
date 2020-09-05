tool
extends EditorPlugin
const Toolbar = preload("scenes/Toolbar.tscn")
const OverlayTextEdit = preload("scenes/OverlayTextEdit.tscn")

var menu
var overlay_text_edit

var editor_inspector = get_editor_interface().get_inspector()


func _enter_tree():
	menu = Toolbar.instance()
	menu.undo_redo = get_undo_redo()
	menu.connect("property_edited", self, "_on_Toolbar_property_edited")
	overlay_text_edit = OverlayTextEdit.instance()
	overlay_text_edit.undo_redo = get_undo_redo()
	overlay_text_edit.connect("property_edited", self, "_on_OverlayTextEdit_property_edited")

	editor_inspector.connect("property_selected", self, "_on_property_selected")

	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_BOTTOM, menu)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_BOTTOM, overlay_text_edit)

func _exit_tree():
	if menu:
		menu.queue_free()
	if overlay_text_edit:
		overlay_text_edit.queue_free()

func handles(object):
	if object is Control:
		make_visible(true)
		return true
	make_visible(false)
	return false

func edit(object):
	menu.focused_object = object
	overlay_text_edit.focused_object = object

func forward_canvas_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.doubleclick:
				if menu.focused_object:
					overlay_text_edit.popup()
				return true
	return false

func make_visible(visible):
	if menu:
		menu.visible = visible
	# overlay_text_edit only visible on double click

func _on_property_selected(property):
	menu.focused_property = property
	menu.focused_inspector = editor_inspector.get_focus_owner()

func _on_Toolbar_property_edited(property):
	editor_inspector.refresh()

func _on_OverlayTextEdit_property_edited(property):
	editor_inspector.refresh()
