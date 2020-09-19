tool
extends TextEdit

signal property_edited(property)

var focused_objects
var undo_redo

var _object_orig_text = ""

func _ready():
	set_as_toplevel(true)
	connect("focus_exited", self, "_on_focused_exited")
	connect("text_changed", self, "_on_text_changed")
	hide()

func _on_text_changed():
	if focused_objects:
		# TODO: Option to set bbcode_text if is RichTextLabel
		focused_objects.back().set("text", text)

func _on_focused_exited():
	if get_menu().visible: # Support right-click context menu
		return

	hide()
	# TODO: More efficient way to handle undo/redo of text, right now, whole chunks of string is cached everytime
	change_text(focused_objects.back(), text)

# Popup at mouse position
func popup():
	if not focused_objects:
		return

	var focused_object = focused_objects.back()
	if not ("text" in focused_object):
		return

	show()
	rect_global_position = get_viewport().get_mouse_position()
	rect_size = focused_object.rect_size
	text = focused_object.text
	grab_focus()

	_object_orig_text = focused_object.text

# Change text with undo/redo
func change_text(object, to):
	var from = _object_orig_text
	undo_redo.create_action("Change Text")
	undo_redo.add_do_method(self, "set_object_text", object, to)
	undo_redo.add_undo_method(self, "set_object_text", object, from)
	undo_redo.commit_action()
	_object_orig_text = ""

func set_object_text(object, text):
	object.set("text", text)
	emit_signal("property_edited", "text")
