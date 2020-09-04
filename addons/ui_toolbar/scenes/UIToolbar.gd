tool
extends Control
const Utils = preload("../scripts/Utils.gd")
const FontManager = preload("../scripts/FontManager.gd")

signal property_edited(name)

const CONFIG_DIR = "res://addons/ui_toolbar/plugin.cfg" # Must be abosulte path
const CONFIG_SECTION_META = "meta"
const CONFIG_KEY_FONTS_DIR = "fonts_dir"
# Generic font properties
const PROPERTY_FONT_COLOR = "custom_colors/font_color"
const PROPERTY_FONT = "custom_fonts/font"
# RichTextLabel font properties
const PROPERTY_FONT_NORMAL = "custom_fonts/normal_font"
const PROPERTY_FONT_BOLD = "custom_fonts/bold_font"
const PROPERTY_FONT_ITALIC = "custom_fonts/italics_font"
const PROPERTY_FONT_BOLD_ITALIC = "custom_fonts/bold_italics_font"
const PROPERTY_FONT_COLOR_DEFAULT = "custom_colors/default_color"
# Others generic properties
const PROPERTY_HIGHLIGHT = "custom_styles/normal"
const PROPERTY_ALIGN = "align"

const DEFAULT_FONT_SIZE = 16

var focused_object setget set_focused_object
var focused_property setget set_focused_property
var focused_inspector setget set_focused_inspector
var selected_font_root_dir = "res://"
var undo_redo

var font_manager = FontManager.new()
var config = ConfigFile.new()

var _object_orig_font_color = Color.white # Font color of object when color picker button pressed
var _object_orig_highlight
var _object_orig_font_style

func _init():
	var result = config.load(CONFIG_DIR)
	if config.load(CONFIG_DIR):
		push_warning("UIToolbar: An error occurred when trying to access %s, ERROR: %d" % [CONFIG_DIR, result])

func _ready():
	# FontName
	$FontName.connect("item_selected", self, "_on_FontName_item_selected")
	$FontWeight.connect("item_selected", self, "_on_FontWeight_item_selected")
	$FontNameLoadButton/FontNameFileDialog.connect("dir_selected", self, "_on_FontNameFileDialog_dir_selected")
	$FontNameLoadButton.connect("pressed", self, "_on_FontNameLoadButton_pressed")
	$FontNameRefresh.connect("pressed", self, "_on_FontNameRefresh_pressed")
	# FontSize
	$FontSize/FontSizePreset.connect("item_selected", self, "_on_FontSizePreset_item_selected")
	$FontSize.connect("text_entered", self, "_on_FontSize_text_entered")
	# Bold
	$Bold.connect("pressed", self, "_on_Bold_pressed")
	# Italic
	$Italic.connect("pressed", self, "_on_Italic_pressed")
	# FontColor
	$FontColor.connect("pressed", self, "_on_FontColor_pressed")
	$FontColor/PopupPanel/ColorPicker.connect("color_changed", self, "_on_FontColor_ColorPicker_color_changed")
	$FontColor/PopupPanel.connect("popup_hide", self, "_on_FontColor_PopupPanel_popup_hide")
	# Highlight
	$Highlight.connect("pressed", self, "_on_Highlight_pressed")
	$Highlight/PopupPanel/ColorPicker.connect("color_changed", self, "_on_Highlight_ColorPicker_color_changed")
	$Highlight/PopupPanel.connect("popup_hide", self, "_on_Highlight_PopupPanel_popup_hide")
	# Align
	$AlignLeft.connect("pressed", self, "_on_AlignLeft_pressed")
	$AlignCenter.connect("pressed", self, "_on_AlignCenter_pressed")
	$AlignRight.connect("pressed", self, "_on_AlignRight_pressed")
	# FontStyle
	$FontStyle.connect("item_selected", self, "_on_FontStyle_item_selected")
	# Format Clear
	$FontClear.connect("pressed", self, "_on_FontClear_pressed")
	$ColorClear.connect("pressed", self, "_on_ColorClear_pressed")
	# Others
	$RectSizeRefresh.connect("pressed", self, "_on_RectSizeRefresh_pressed")

	var fonts_dir = config.get_value(CONFIG_SECTION_META, CONFIG_KEY_FONTS_DIR, "")
	if not fonts_dir.empty():
		_on_FontNameFileDialog_dir_selected(fonts_dir)

func change_font(object, to):
	var from = object.get(PROPERTY_FONT)
	undo_redo.create_action("Change Font")
	undo_redo.add_do_method(self, "set_font", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_font", object, from if from else false)
	undo_redo.commit_action()

func change_font_data(object, to):
	var from = object.get(PROPERTY_FONT).font_data
	undo_redo.create_action("Change Font Data")
	undo_redo.add_do_method(self, "set_font_data", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_font_data", object, from if from else false)
	undo_redo.commit_action()

func change_rich_text_fonts(object, to):
	var from = {}
	from["regular"] = object.get(PROPERTY_FONT_NORMAL)
	from["bold"] = object.get(PROPERTY_FONT_BOLD)
	from["regular_italic"] = object.get(PROPERTY_FONT_ITALIC)
	from["bold_italic"] = object.get(PROPERTY_FONT_BOLD_ITALIC)
	undo_redo.create_action("Change Rich Text Fonts")
	undo_redo.add_do_method(self, "set_rich_text_fonts", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_rich_text_fonts", object, from if from else false)
	undo_redo.commit_action()

func change_font_size(object, to):
	var from = object.get(PROPERTY_FONT).size
	undo_redo.create_action("Change Font Size")
	undo_redo.add_do_method(self, "set_font_size", object, to)
	undo_redo.add_undo_method(self, "set_font_size", object, from)
	undo_redo.commit_action()

func change_font_color(object, to):
	var from = _object_orig_font_color
	undo_redo.create_action("Change Font Color")
	undo_redo.add_do_method(self, "set_font_color", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_font_color", object, from if from else false)
	undo_redo.commit_action()

func change_highlight(object, to):
	var from = _object_orig_highlight
	undo_redo.create_action("Change Highlight")
	undo_redo.add_do_method(self, "set_highlight", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_highlight", object, from if from else false)
	undo_redo.commit_action()

func change_align(object, to):
	var from = object.get(PROPERTY_ALIGN)
	undo_redo.create_action("Change Align")
	undo_redo.add_do_method(self, "set_align", object, to)
	undo_redo.add_undo_method(self, "set_align", object, from)
	undo_redo.commit_action()	

func change_font_style(object, to):
	var from = _object_orig_font_style
	undo_redo.create_action("Change Font Style")
	undo_redo.add_do_method(self, "set_font_style", object, to if to else false) # Godot bug, varargs ignore null
	undo_redo.add_undo_method(self, "set_font_style", object, from if from else false)
	undo_redo.commit_action()

func reflect_font_name_control():
	var dynamic_font = focused_object.get(PROPERTY_FONT) if focused_object else null
	if dynamic_font:
		if dynamic_font.font_data:
			var font_and_weight_name = font_manager.get_font_and_weight_name(dynamic_font.font_data)
			for i in $FontName.get_item_count():
				if $FontName.get_item_text(i) == font_and_weight_name.font_name:
					$FontName.selected = i
					reset_font_weight_control()
					reflect_font_weight_control()
					break
		else:
			reset_font_name_control()
	else:
		reset_font_name_control()

func reflect_font_weight_control():
	var dynamic_font = focused_object.get(PROPERTY_FONT) if focused_object else null
	if dynamic_font:
		if dynamic_font.font_data:
			var font_and_weight_name = font_manager.get_font_and_weight_name(dynamic_font.font_data)
			for i in $FontWeight.get_item_count():
				if $FontWeight.get_item_text(i).to_lower().replace(" ", "_") == font_and_weight_name.weight_name:
					$FontWeight.selected = i
					return true
	return false

func reflect_font_size_control():
	var dynamic_font = focused_object.get(PROPERTY_FONT) if focused_object else null
	$FontSize.text = str(dynamic_font.size) if dynamic_font else str(DEFAULT_FONT_SIZE)
	$FontSize.mouse_filter = Control.MOUSE_FILTER_IGNORE if dynamic_font == null else Control.MOUSE_FILTER_STOP
	var font_size_color = Color.white
	font_size_color.a = 0.5 if dynamic_font == null else 1
	$FontSize.set(PROPERTY_FONT_COLOR, font_size_color)
	$FontSize/FontSizePreset.disabled = dynamic_font == null

func reflect_bold_italic_control():
	if $FontName.get_item_count():
		var font_name = $FontName.get_item_text($FontName.selected)
		var weight_name = $FontWeight.get_item_text($FontWeight.selected).to_lower().replace(" ", "_") if font_name != "None" else ""
		var font_resource = font_manager.get_font_resource(font_name)

		$Bold.disabled = not font_resource.weights.bold if font_resource else true
		$Italic.disabled = not font_resource.weights.regular_italic if font_resource else true
		$Bold.pressed = false
		$Italic.pressed = false
		match weight_name:
			"bold_italic":
				$Bold.pressed = true
				$Italic.pressed = true
			"bold":
				$Bold.pressed = true
				$Italic.disabled = not font_resource.weights.bold_italic
			_:
				if weight_name.find("italic") > -1:
					$Italic.pressed = true
					$Bold.disabled = not font_resource.weights.bold_italic
	else:
		$Bold.disabled = true
		$Italic.disabled = true
		$Bold.pressed = false
		$Italic.pressed = false

func reflect_font_color_control():
	var focused_object_font_color = focused_object.get(PROPERTY_FONT_COLOR) if focused_object else null
	var font_color = Color.white
	if focused_object_font_color != null:
		font_color = focused_object_font_color
	$FontColor/ColorRect.color = font_color
	$FontColor/PopupPanel/ColorPicker.color = font_color

func reflect_highlight_control():
	var focused_object_highlight = focused_object.get(PROPERTY_HIGHLIGHT) if focused_object else null
	var highlight_color = Color.white # default modulate color
	if focused_object_highlight != null:
		if focused_object_highlight is StyleBoxFlat:
			highlight_color = focused_object_highlight.bg_color
	$Highlight/ColorRect.color = highlight_color
	$Highlight/PopupPanel/ColorPicker.color = highlight_color

func reflect_align_control():
	var align = focused_object.get(PROPERTY_ALIGN) if focused_object else null
	$AlignLeft.pressed = false
	$AlignCenter.pressed = false
	$AlignRight.pressed = false
	if align != null:
		$AlignLeft.disabled = false
		$AlignCenter.disabled = false
		$AlignRight.disabled = false
		match align:
			Label.ALIGN_LEFT:
				$AlignLeft.pressed = true
			Label.ALIGN_CENTER:
				$AlignCenter.pressed = true
			Label.ALIGN_RIGHT:
				$AlignRight.pressed = true
	else:
		$AlignLeft.disabled = true
		$AlignCenter.disabled = true
		$AlignRight.disabled = true

func reflect_font_style_control():
	# Font Style is not required to be accurate
	var dynamic_font = focused_object.get(PROPERTY_FONT) if focused_object else null
	$FontStyle.disabled = dynamic_font == null

func reset_font_name_control():
	if $FontName.get_item_count():
		$FontName.selected = $FontName.get_item_count() - 1
	$FontWeight.clear()

func reset_font_weight_control():
	if focused_object is RichTextLabel:
		$FontWeight.disabled = true
		return
	else:
		$FontWeight.disabled = false

	if $FontName.get_item_count():
		var font_name = $FontName.get_item_text($FontName.selected)
		var font_resource = font_manager.get_font_resource(font_name)
		$FontWeight.clear()
		for property in inst2dict(font_resource.weights).keys():
			if property == "@subpath" or property == "@path":
				continue

			if font_resource.weights.get(property):
				$FontWeight.add_item(property.capitalize())
	else:
		$FontWeight.clear()

func _on_FontName_item_selected(index):
	if not focused_object:
		return

	var font_name = $FontName.get_item_text(index)
	if font_name == "None":
		_on_FontClear_pressed()
		return

	var font_resource = font_manager.get_font_resource(font_name)
	if not font_resource:
		return

	if focused_object is RichTextLabel:
		var to = {}
		to["regular"] = create_new_font_obj(font_resource.weights.regular) if font_resource.weights.regular else null
		to["bold"] = create_new_font_obj(font_resource.weights.bold) if font_resource.weights.bold else null
		to["regular_italic"] = create_new_font_obj(font_resource.weights.regular_italic) if font_resource.weights.regular_italic else null
		to["bold_italic"] = create_new_font_obj(font_resource.weights.bold_italic) if font_resource.weights.bold_italic else null
		change_rich_text_fonts(focused_object, to)
	else:
		var dynamic_font = focused_object.get(PROPERTY_FONT)
		if not dynamic_font:
			var font_size = int($FontSize/FontSizePreset.get_item_text($FontSize/FontSizePreset.selected))
			dynamic_font = create_new_font_obj(font_resource.weights.regular, font_size)
			change_font(focused_object, dynamic_font)
		else:
			change_font_data(focused_object, font_resource.weights.regular) # TODO: Get fallback weight if regular not found

func _on_FontWeight_item_selected(index):
	if not focused_object:
		return

	if focused_object is RichTextLabel:
		return

	var font_name = $FontName.get_item_text($FontName.selected)
	var weight_name = $FontWeight.get_item_text(index).to_lower().replace(" ", "_")
	var font_resource = font_manager.get_font_resource(font_name)
	
	var dynamic_font = focused_object.get(PROPERTY_FONT)
	if dynamic_font:
		change_font_data(focused_object, font_resource.weights.get(weight_name))
	
func _on_FontNameLoadButton_pressed():
	$FontNameLoadButton/FontNameFileDialog.popup()

func _on_FontNameFileDialog_dir_selected(dir):
	selected_font_root_dir = dir
	# Load fonts
	if font_manager.load_root_dir(dir):
		$FontName.clear()
		for font_data in font_manager.font_resources:
			$FontName.add_item(font_data.name)
		$FontName.add_item("None")

		reflect_font_name_control()
		config.set_value(CONFIG_SECTION_META, CONFIG_KEY_FONTS_DIR, dir)
		config.save(CONFIG_DIR)
	else:
		print("Failed to load fonts")

func _on_FontNameRefresh_pressed():
	_on_FontNameFileDialog_dir_selected(selected_font_root_dir)

func _on_FontSizePreset_item_selected(index):
	if not focused_object:
		return

	var new_font_size_str = $FontSize/FontSizePreset.get_item_text(index)
	change_font_size(focused_object, int(new_font_size_str))

func _on_FontSize_text_entered(new_text):
	if not focused_object:
		return

	change_font_size(focused_object, int($FontSize.text))

func _on_Bold_pressed():
	if not focused_object:
		return

	var font_resource = _bold_or_italic()
	if not font_resource:
		return

	var bold = $Bold.pressed
	var italic = $Italic.pressed
	if bold == italic:
		if not bold:
			can_italic_active(font_resource)
	else:
		can_italic_active(font_resource)

	if $Italic.disabled:
		$Italic.pressed = false

func _on_Italic_pressed():
	if not focused_object:
		return

	var font_resource = _bold_or_italic()
	if not font_resource:
		return

	var bold = $Italic.pressed
	var italic = $Bold.pressed
	if bold == italic:
		if not bold:
			can_bold_active(font_resource)
	else:
		can_bold_active(font_resource)

	if $Bold.disabled:
		$Bold.pressed = false

func _bold_or_italic():
	var bold = $Bold.pressed
	var italic = $Italic.pressed

	var font_name = $FontName.get_item_text($FontName.selected)
	var font_resource = font_manager.get_font_resource(font_name)
	if not font_resource:
		return null
	
	var weight = font_resource.weights.regular_italic if $Italic.pressed else font_resource.weights.regular
	weight = font_resource.weights.bold_italic if $Bold.pressed else weight
	if bold and italic:
		weight = font_resource.weights.bold_italic
	elif bold:
		weight = font_resource.weights.bold
	elif italic:
		weight = font_resource.weights.regular_italic
	else:
		weight = font_resource.weights.regular

	change_font_data(focused_object, weight)

	return font_resource

func _on_FontColor_pressed():
	$FontColor/PopupPanel.popup()

	if focused_object:
		if focused_object is RichTextLabel:
			_object_orig_font_color = focused_object.get(PROPERTY_FONT_COLOR_DEFAULT) 
		else:
			_object_orig_font_color = focused_object.get(PROPERTY_FONT_COLOR) 

func _on_FontColor_ColorPicker_color_changed(color):
	if not focused_object:
		return

	# Preview only, doesn't stack undo/redo as this is called very frequently
	if focused_object is RichTextLabel:
		focused_object.set(PROPERTY_FONT_COLOR_DEFAULT, $FontColor/PopupPanel/ColorPicker.color)
	else:
		focused_object.set(PROPERTY_FONT_COLOR, $FontColor/PopupPanel/ColorPicker.color)
	$FontColor/ColorRect.color = $FontColor/PopupPanel/ColorPicker.color

func _on_FontColor_PopupPanel_popup_hide():
	if not focused_object:
		return

	# Color selected
	change_font_color(focused_object, $FontColor/PopupPanel/ColorPicker.color)

func _on_Highlight_pressed():
	$Highlight/PopupPanel.popup()

	if focused_object:
		var style_box_flat = focused_object.get(PROPERTY_HIGHLIGHT)
		if style_box_flat:
			_object_orig_highlight = StyleBoxFlat.new()
			_object_orig_highlight.bg_color = style_box_flat.bg_color
		else:
			_object_orig_highlight = null

func _on_Highlight_ColorPicker_color_changed(color):
	if not focused_object:
		return

	# Preview only, doesn't stack undo/redo as this is called very frequently
	$Highlight/ColorRect.color = color
	var style_box_flat = StyleBoxFlat.new()

	style_box_flat.bg_color = $Highlight/PopupPanel/ColorPicker.color
	focused_object.set(PROPERTY_HIGHLIGHT, style_box_flat)

func _on_Highlight_PopupPanel_popup_hide():
	if not focused_object:
		return

	# Color selected
	var style_box_flat = StyleBoxFlat.new()
	style_box_flat.bg_color = $Highlight/PopupPanel/ColorPicker.color
	change_highlight(focused_object, style_box_flat)

func _on_AlignLeft_pressed():
	if focused_object:
		change_align(focused_object, Label.ALIGN_LEFT)

func _on_AlignCenter_pressed():
	if focused_object:
		change_align(focused_object, Label.ALIGN_CENTER)

func _on_AlignRight_pressed():
	if focused_object:
		change_align(focused_object, Label.ALIGN_RIGHT)

func _on_FontStyle_item_selected(index):
	if not focused_object:
		return

	var dynamic_font = focused_object.get(PROPERTY_FONT)
	if not dynamic_font:
		return
	var font_style = font_manager.FONT_STYLES[$FontStyle.get_item_text(index)]

	_object_orig_font_style = FontManager.FontStyle.new(
		$FontWeight.get_item_text($FontWeight.selected).to_lower().replace(" ", "_"), dynamic_font.size, dynamic_font.extra_spacing_char)
	change_font_style(focused_object, font_style)

func _on_FontClear_pressed():
	if not focused_object:
		return

	if focused_object is RichTextLabel:
		var to = {
			"regular": null,
			"bold": null,
			"regular_italic": null,
			"bold_italic": null
		}
		change_rich_text_fonts(focused_object, to)
	else:
		change_font(focused_object, null)

	_on_focused_object_changed(focused_object) # Update ui default state

func _on_ColorClear_pressed():
	if not focused_object:
		return

	if focused_object is RichTextLabel:
		_object_orig_font_color = focused_object.get(PROPERTY_FONT_COLOR_DEFAULT) 
	else:
		_object_orig_font_color = focused_object.get(PROPERTY_FONT_COLOR) 
	_object_orig_highlight = focused_object.get(PROPERTY_HIGHLIGHT)
	change_font_color(focused_object, null)
	change_highlight(focused_object, null)

func _on_RectSizeRefresh_pressed():
	if focused_object:
		focused_object.set("rect_size", Vector2.ZERO)

func _on_focused_object_changed(new_focused_object):
	reflect_font_name_control() # Font family must be reflected first
	reflect_font_size_control()
	reflect_font_color_control()
	reflect_highlight_control()
	reflect_bold_italic_control()
	reflect_align_control()
	reflect_font_style_control()

func _on_font_data_changed(new_font_data):
	var font_and_weight_name = font_manager.get_font_and_weight_name(new_font_data)
	var font_resource = font_manager.get_font_resource(font_and_weight_name.font_name)
	if font_and_weight_name:
		reflect_font_name_control()

	reflect_bold_italic_control()
	emit_signal("property_edited", PROPERTY_FONT)

func _on_font_changed(new_font):
	var font_name = $FontName.get_item_text($FontName.selected)
	var font_resource = font_manager.get_font_resource(font_name)
	if not new_font:
		reset_font_name_control()
	else:
		if not font_resource: # Current font not equal to FontName selected
			var font_and_weight_name = font_manager.get_font_and_weight_name(new_font.font_data)
			font_resource = font_manager.get_font_resource(font_and_weight_name.font_name)
			if font_and_weight_name:
				reflect_font_name_control()
		else:
			reset_font_weight_control()
			reflect_font_weight_control()

	reflect_font_size_control()
	reflect_bold_italic_control()
	reflect_font_style_control()
	emit_signal("property_edited", PROPERTY_FONT)

func _on_rich_text_fonts_changed(fonts):
	# TODO: Reflect font name of rich text font
	emit_signal("property_edited", PROPERTY_FONT)

func _on_font_size_changed(new_font_size):
	var new_font_size_str = str(new_font_size)
	$FontSize.text = new_font_size_str

	emit_signal("property_edited", PROPERTY_FONT)

func _on_font_color_changed(new_font_color):
	$FontColor/ColorRect.color = new_font_color if new_font_color else Color.white

	emit_signal("property_edited", PROPERTY_FONT_COLOR)

func _on_highlight_changed(new_highlight):
	reflect_highlight_control()

	emit_signal("property_edited", PROPERTY_HIGHLIGHT)

func _on_align_changed(align):
	reflect_align_control()

	emit_signal("property_edited", PROPERTY_ALIGN)

func _on_focused_property_changed(new_property):
	pass

func _on_focused_inspector_changed(new_inspector):
	pass

func set_font_data(object, font_data):
	font_data = font_data if font_data else null # font might be bool false, as Godot ignore null for varargs
	object.get(PROPERTY_FONT).font_data = font_data
	_on_font_data_changed(font_data)

func set_font(object, font):
	font = font if font else null 
	object.set(PROPERTY_FONT, font) 
	_on_font_changed(font)

func set_rich_text_fonts(object, fonts):
	object.set(PROPERTY_FONT_NORMAL, fonts.regular)
	object.set(PROPERTY_FONT_BOLD, fonts.bold)
	object.set(PROPERTY_FONT_ITALIC, fonts.regular_italic)
	object.set(PROPERTY_FONT_BOLD_ITALIC, fonts.bold_italic)
	_on_rich_text_fonts_changed(fonts)

func set_font_size(object, font_size):
	object.get(PROPERTY_FONT).size = font_size
	_on_font_size_changed(font_size)

func set_font_color(object, font_color):
	font_color = font_color if font_color else null
	if object is RichTextLabel:
		object.set(PROPERTY_FONT_COLOR_DEFAULT, font_color)
	else:
		object.set(PROPERTY_FONT_COLOR, font_color)
	_on_font_color_changed(font_color)

func set_highlight(object, highlight):
	highlight = highlight if highlight else null
	object.set(PROPERTY_HIGHLIGHT, highlight)
	_on_highlight_changed(highlight)

func set_align(object, align):
	object.set(PROPERTY_ALIGN, align)
	_on_align_changed(align)

func set_font_style(object, font_style):
	if not font_style:
		return

	var font_data = font_manager.get_font_resource($FontName.get_item_text($FontName.selected)).weights.get(font_style.weight)
	if not font_data:
		# Use current weight if desired weight not found
		font_data = object.get(PROPERTY_FONT).font_data
	set_font_data(object, font_data)
	set_font_size(object, font_style.size)
	set_font_extra_spacing_char(object, font_style.letter_spacing)

func set_font_extra_spacing_char(object, new_spacing):
	object.get(PROPERTY_FONT).extra_spacing_char = new_spacing
	# TODO: Add gui for font extra spacing

func set_focused_object(obj):
	if focused_object != obj:
		focused_object = obj
		_on_focused_object_changed(focused_object)

func set_focused_property(prop):
	if focused_property != prop:
		focused_property = prop
		_on_focused_property_changed(focused_property)

func set_focused_inspector(insp):
	if focused_inspector != insp:
		focused_inspector = insp
		_on_focused_inspector_changed(focused_inspector)

func create_new_font_obj(font_data, size=null):
	var font  = DynamicFont.new()
	font.use_filter = true
	font.font_data = font_data
	if size:
		font.size = size
	return font

func can_bold_active(font_data):
	if $Italic.pressed:
		$Bold.disabled = not font_data.weights.bold_italic
	else:
		$Bold.disabled = not font_data.weights.bold

func can_italic_active(font_data):
	if $Bold.pressed:
		$Italic.disabled = not font_data.weights.bold_italic
	else:
		$Italic.disabled = not font_data.weights.bold
