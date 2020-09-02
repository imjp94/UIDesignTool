tool
extends EditorPlugin
const TypographyMenu = preload("TypographyMenu.gd")
const TypographyMenuScene = preload("TypographyMenu.tscn")

var menu
var editor_inspector = get_editor_interface().get_inspector()


func _enter_tree():
	menu = TypographyMenuScene.instance()
	menu.connect("property_edited", self, "_on_TypographyMenu_property_edited")

	editor_inspector.connect("property_selected", self, "_on_property_selected")

	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_BOTTOM, menu)

func _exit_tree():
	if menu:
		menu.queue_free()

func handles(object):
	if object is Control:
		make_visible(true)
		return true
	make_visible(false)
	return false

func edit(object):
	menu.focused_object = object

func make_visible(visible):
	if menu:
		menu.visible = visible

func _on_property_selected(property):
	menu.focused_property = property
	menu.focused_inspector = editor_inspector.get_focus_owner()

func _on_TypographyMenu_property_edited(property):
	editor_inspector.refresh()
