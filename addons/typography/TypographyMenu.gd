tool
extends Control
const Utils = preload("Utils.gd")
const FontManager = preload("FontManager.gd")

signal property_edited(name)

const CONFIG_DIR = "res://addons/typography/plugin.cfg"
const CONFIG_SECTION_META = "meta"
const CONFIG_KEY_FONTS_DIR = "fonts_dir"
const PROPERTY_FONT_COLOR = "custom_colors/font_color"
const PROPERTY_FONT = "custom_fonts/font"
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
		print("An error occurred when trying to access the path, ERROR: ", result)

func _ready():
	# FontFamily
	$FontFamily.connect("item_selected", self, "_on_FontFamily_item_selected")
	$FontWeight.connect("item_selected", self, "_on_FontWeight_item_selected")
	$FontFamilyLoadButton/FontFamilyFileDialog.connect("dir_selected", self, "_on_FontFamilyFileDialog_dir_selected")
	$FontFamilyLoadButton.connect("pressed", self, "_on_FontFamilyLoadButton_pressed")
	$FontFamilyRefresh.connect("pressed", self, "_on_FontFamilyRefresh_pressed")
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
		_on_FontFamilyFileDialog_dir_selected(fonts_dir)

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

func reflect_font_family_control():
	var dynamic_font = focused_object.get(PROPERTY_FONT) if focused_object else null
	if dynamic_font:
		if dynamic_font.font_data:
			var font_and_weight_name = font_manager.get_font_and_weight_name(dynamic_font.font_data)
			for i in $FontFamily.get_item_count():
				if $FontFamily.get_item_text(i) == font_and_weight_name.font_name:
					$FontFamily.selected = i
					reset_font_weight_control()
					reflect_font_weight_control()
					break
		else:
			reset_font_family_control()
	else:
		reset_font_family_control()

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
	var font_name = $FontFamily.get_item_text($FontFamily.selected)
	var weight_name = $FontWeight.get_item_text($FontWeight.selected).to_lower().replace(" ", "_") if font_name != "None" else ""
	var font_data = font_manager.get_font_data(font_name)

	$Bold.disabled = not font_data.weights.bold if font_data else true
	$Italic.disabled = not font_data.weights.regular_italic if font_data else true
	$Bold.pressed = false
	$Italic.pressed = false
	match weight_name:
		"bold_italic":
			$Bold.pressed = true
			$Italic.pressed = true
		"bold":
			$Bold.pressed = true
		_:
			if weight_name.find("italic") > -1:
				$Italic.pressed = true

func reflect_font_color_control():
	var focused_object_font_color = focused_object.get(PROPERTY_FONT_COLOR) if focused_object else null
	var font_color = Color.white
	if focused_object_font_color != null:
		font_color = focused_object_font_color
	$FontColor/ColorRect.color = font_color
	$FontColor/PopupPanel/ColorPicker.color = font_color

func reflect_highlight_control():
	var focused_object_highlight = focused_object.get(PROPERTY_HIGHLIGHT) if focused_object else null
	var highlight = Color.white # default modulate color
	if focused_object_highlight != null:
		if focused_object_highlight is StyleBoxFlat:
			highlight = focused_object_highlight.bg_color
	$Highlight/ColorRect.color = highlight
	$Highlight/PopupPanel/ColorPicker.color = highlight

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

func reset_font_family_control():
	$FontFamily.selected = $FontFamily.get_item_count() - 1
	$FontWeight.clear()

func reset_font_weight_control():
	var font_name = $FontFamily.get_item_text($FontFamily.selected)
	var font_data = font_manager.get_font_data(font_name)
	$FontWeight.clear()
	for property in inst2dict(font_data.weights).keys():
		if property == "@subpath" or property == "@path":
			continue

		if font_data.weights.get(property):
			$FontWeight.add_item(property.capitalize())

func _on_FontFamily_item_selected(index):
	if not focused_object:
		return

	var font_name = $FontFamily.get_item_text(index)
	if font_name == "None":
		_on_FontClear_pressed()
		return

	var dynamic_font = focused_object.get(PROPERTY_FONT)
	var font_data = font_manager.get_font_data(font_name)
	if not font_data:
		return

	if not dynamic_font:
		dynamic_font = DynamicFont.new()
		dynamic_font.use_filter = true
		dynamic_font.font_data = font_data.weights.regular
		dynamic_font.size = int($FontSize/FontSizePreset.get_item_text($FontSize/FontSizePreset.selected)) # TODO: set_font_size
		change_font(focused_object, dynamic_font)
	else:
		change_font_data(focused_object, font_data.weights.regular) # TODO: Get fallback weight if regular not found

func _on_FontWeight_item_selected(index):
	if not focused_object:
		return

	var font_name = $FontFamily.get_item_text($FontFamily.selected)
	var weight_name = $FontWeight.get_item_text(index).to_lower().replace(" ", "_")
	var font_data = font_manager.get_font_data(font_name)
	
	var dynamic_font = focused_object.get(PROPERTY_FONT)
	if dynamic_font:
		change_font_data(focused_object, font_data.weights.get(weight_name))
	
func _on_FontFamilyLoadButton_pressed():
	$FontFamilyLoadButton/FontFamilyFileDialog.popup()

func _on_FontFamilyFileDialog_dir_selected(dir):
	selected_font_root_dir = dir
	# Load fonts
	if font_manager.load_root_dir(dir):
		for font_data in font_manager.font_datas:
			$FontFamily.add_item(font_data.name)
		$FontFamily.add_item("None")

		_on_FontFamily_item_selected($FontFamily.selected)
		config.set_value(CONFIG_SECTION_META, CONFIG_KEY_FONTS_DIR, dir)
		config.save(CONFIG_DIR)
	else:
		print("Failed to load fonts")

func _on_FontFamilyRefresh_pressed():
	_on_FontFamilyFileDialog_dir_selected(selected_font_root_dir)

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

	if focused_object is RichTextLabel:
		if focused_property == "bbcode_text" and focused_inspector is TextEdit:
			print(focused_inspector.get_selection_text())
			Utils.markup_text_edit_selection(focused_inspector, "[b]", "[/b]")
	else:
		var font_data = _bold_or_italic()

		if not font_data:
			return

		var bold = $Bold.pressed
		var italic = $Italic.pressed
		if bold == italic:
			if not bold:
				can_italic_active(font_data)
		else:
			can_italic_active(font_data)

		if $Italic.disabled:
			$Italic.pressed = false

func _on_Italic_pressed():
	if not focused_object:
		return

	if focused_object is RichTextLabel:
		if focused_property == "bbcode_text" and focused_inspector is TextEdit:
			print(focused_inspector.get_selection_text())
			Utils.markup_text_edit_selection(focused_inspector, "[i]", "[/i]")
	else:
		var font_data = _bold_or_italic()

		if not font_data:
			return

		var bold = $Italic.pressed
		var italic = $Bold.pressed
		if bold == italic:
			if not bold:
				can_bold_active(font_data)
		else:
			can_bold_active(font_data)

		if $Bold.disabled:
			$Bold.pressed = false

func _bold_or_italic():
	var bold = $Bold.pressed
	var italic = $Italic.pressed

	var font_family = $FontFamily.get_item_text($FontFamily.selected)
	var font_data = font_manager.get_font_data(font_family)
	if not font_data:
		return null
	
	var weight = font_data.weights.regular_italic if $Italic.pressed else font_data.weights.regular
	weight = font_data.weights.bold_italic if $Bold.pressed else weight
	if bold and italic:
		weight = font_data.weights.bold_italic
	elif bold:
		weight = font_data.weights.bold
	elif italic:
		weight = font_data.weights.regular_italic
	else:
		weight = font_data.weights.regular

	change_font_data(focused_object, weight)

	return font_data

func _on_FontColor_pressed():
	$FontColor/PopupPanel.popup()

	if focused_object:
		_object_orig_font_color = focused_object.get(PROPERTY_FONT_COLOR)

func _on_FontColor_ColorPicker_color_changed(color):
	if not focused_object:
		return

	# Preview only, doesn't stack undo/redo as this is called very frequently
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

	change_font(focused_object, null)

	_on_focused_object_changed(focused_object) # Update ui default state

func _on_ColorClear_pressed():
	if not focused_object:
		return

	_object_orig_font_color = focused_object.get(PROPERTY_FONT_COLOR)
	_object_orig_highlight = focused_object.get(PROPERTY_HIGHLIGHT)
	change_font_color(focused_object, null)
	change_highlight(focused_object, null)

func _on_RectSizeRefresh_pressed():
	if focused_object:
		focused_object.set("rect_size", Vector2.ZERO)

func _on_focused_object_changed(new_focused_object):
	reflect_font_family_control() # Font family must be reflected first
	reflect_font_size_control()
	reflect_font_color_control()
	reflect_highlight_control()
	reflect_bold_italic_control()
	reflect_align_control()
	reflect_font_style_control()

func _on_font_data_changed(new_font_data):
	var font_and_weight_name = font_manager.get_font_and_weight_name(new_font_data)
	# TODO: Change name of FontManager.FontData, current new_font_data != font_data
	var font_data = font_manager.get_font_data(font_and_weight_name.font_name) 
	if font_and_weight_name:
		reflect_font_family_control()

	$Bold.disabled = not font_data.weights.bold
	$Italic.disabled = not font_data.weights.regular_italic
	$Bold.pressed = false
	$Italic.pressed = false
	match font_and_weight_name.weight_name:
		"bold_italic":
			$Bold.pressed = true
			$Italic.pressed = true
		"bold":
			$Bold.pressed = true
		_:
			if font_and_weight_name.weight_name.find("italic") > -1:
				$Italic.pressed = true

	emit_signal("property_edited", PROPERTY_FONT)

func _on_font_changed(new_font):
	var font_name = $FontFamily.get_item_text($FontFamily.selected)
	var font_data = font_manager.get_font_data(font_name)
	if not new_font:
		reset_font_family_control()
	else:
		if not font_data: # Current font not equal to FontFamily selected
			var font_and_weight_name = font_manager.get_font_and_weight_name(new_font.font_data)
			font_data = font_manager.get_font_data(font_and_weight_name.font_name)
			if font_and_weight_name:
				reflect_font_family_control()
		else:
			reset_font_weight_control()
			reflect_font_weight_control()

	$FontSize/FontSizePreset.disabled = false
	$FontSize.mouse_filter = Control.MOUSE_FILTER_STOP
	$FontSize.set(PROPERTY_FONT_COLOR, Color.white)
	$Bold.disabled = font_data.weights.bold == null if new_font else true
	$Italic.disabled = font_data.weights.regular_italic == null if new_font else true
	$FontStyle.disabled = false
	emit_signal("property_edited", PROPERTY_FONT)

func _on_font_size_changed(new_font_size):
	var new_font_size_str = str(new_font_size)
	$FontSize.text = new_font_size_str

	emit_signal("property_edited", PROPERTY_FONT)

func _on_font_color_changed(new_font_color):
	$FontColor/ColorRect.color = new_font_color if new_font_color else Color.white

	emit_signal("property_edited", PROPERTY_FONT_COLOR)

func _on_highlight_changed(new_highlight):
	if new_highlight:
		if new_highlight.bg_color:
			$Highlight/ColorRect.color = new_highlight.bg_color
		else:
			$Highlight/ColorRect.color = Color.white
	else:
		$Highlight/ColorRect.color = Color.white

	emit_signal("property_edited", PROPERTY_HIGHLIGHT)

func _on_align_changed(align):
	match align:
		Label.ALIGN_LEFT:
			$AlignLeft.pressed = true
			$AlignCenter.pressed = false
			$AlignRight.pressed = false
		Label.ALIGN_CENTER:
			$AlignLeft.pressed = false
			$AlignCenter.pressed = true
			$AlignRight.pressed = false
		Label.ALIGN_RIGHT:
			$AlignLeft.pressed = false
			$AlignCenter.pressed = false
			$AlignRight.pressed = true

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

func set_font_size(object, font_size):
	object.get(PROPERTY_FONT).size = font_size
	_on_font_size_changed(font_size)

func set_font_color(object, font_color):
	font_color = font_color if font_color else null
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

	set_font_data(object, font_manager.get_font_data($FontFamily.get_item_text($FontFamily.selected)).weights.get(font_style.weight))
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
