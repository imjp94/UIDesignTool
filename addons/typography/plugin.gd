tool
extends EditorPlugin
const TypographyMenu = preload("TypographyMenu.tscn")
const OverlayTextEdit = preload("OverlayTextEdit.tscn")

var menu
var overlay_text_edit
var editor_inspector = get_editor_interface().get_inspector()


func _enter_tree():
	menu = TypographyMenu.instance()
	menu.undo_redo = get_undo_redo()
	menu.connect("property_edited", self, "_on_TypographyMenu_property_edited")
	overlay_text_edit = OverlayTextEdit.instance()
	overlay_text_edit.set_as_toplevel(true)
	overlay_text_edit.connect("focus_exited", self, "_on_OverlayTextEdit_focused_exited")
	overlay_text_edit.connect("text_changed", self, "_on_OverlayTextEdit_text_changed")

	editor_inspector.connect("property_selected", self, "_on_property_selected")

	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_BOTTOM, menu)

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

func forward_canvas_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.doubleclick:
				if menu.focused_object:
					_on_double_click_object(menu.focused_object)
				return true

	return false

func make_visible(visible):
	if menu:
		menu.visible = visible

func _on_double_click_object(object):
	if "text" in object:
		if overlay_text_edit.get_parent():
			overlay_text_edit.get_parent().remove_child(overlay_text_edit)
		menu.add_child(overlay_text_edit) 
		overlay_text_edit.rect_global_position = get_viewport().get_mouse_position()
		overlay_text_edit.rect_size = object.rect_size
		overlay_text_edit.text = object.text
		overlay_text_edit.grab_focus()

func _on_OverlayTextEdit_text_changed():
	if menu.focused_object:
		menu.focused_object.set("text", overlay_text_edit.text)

func _on_OverlayTextEdit_focused_exited():
	if overlay_text_edit.get_menu().visible: # Support right-click context menu
		return

	if overlay_text_edit.get_parent():
		overlay_text_edit.get_parent().remove_child(overlay_text_edit)

func _on_property_selected(property):
	menu.focused_property = property
	menu.focused_inspector = editor_inspector.get_focus_owner()

func _on_TypographyMenu_property_edited(property):
	editor_inspector.refresh()
